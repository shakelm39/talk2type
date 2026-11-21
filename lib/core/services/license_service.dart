import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../native/native_bridge.dart';
import '../network/dio_client.dart';
import '../../data/models/license_activation_response.dart';

class LicenseService {
  static final LicenseService instance = LicenseService._internal();
  LicenseService._internal();

  /// Check whether the license is currently active and valid.
  /// When [AppConfig.enableLicenseCheck] is false, this immediately returns true (bypass).
  /// When true, checks for non-empty token and validates expiration date.
  Future<bool> isLicenseValid() async {
    if (!AppConfig.enableLicenseCheck) {
      // Plug-and-play toggle: bypass license gate completely for local/direct testing
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.keyLicenseToken);
    if (token == null || token.trim().isEmpty) {
      return false;
    }

    final expiresAtStr = prefs.getString(AppConfig.keyExpiresAt);
    if (expiresAtStr != null && expiresAtStr.trim().isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresAtStr.trim());
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        debugPrint("[LicenseService] License has expired at: $expiresAt");
        return false;
      }
    }

    return true;
  }

  /// Get unique Android device hardware identifier with fallback
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.id.isNotEmpty) {
          return androidInfo.id;
        }
      }
    } catch (e) {
      debugPrint("[LicenseService] DeviceInfoPlugin failed: $e");
    }

    return await NativeBridge.getDeviceId();
  }

  /// Activate license key with unique device binding via Ayyzan License Hub (license.ayyzan.com)
  Future<LicenseActivationResponse> activateLicense(String licenseKey, {String? customAppId}) async {
    final cleanKey = licenseKey.trim();
    if (cleanKey.isEmpty) {
      return LicenseActivationResponse(
        success: false,
        message: "অনুগ্রহ করে আপনার লাইসেন্স কী দিন।",
      );
    }

    final deviceId = await getDeviceId();
    final baseUrl = AppConfig.licenseApiEndpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final appId = (customAppId ?? AppConfig.licenseAppId).trim();

    // Ayyzan License Hub API endpoint
    final targetUrl = '$baseUrl/api/v1/activate';

    try {
      final dio = DioClient.createDio();
      final response = await dio.post(
        targetUrl,
        data: {
          'appId': appId,
          'key': cleanKey,
          'deviceId': deviceId,
          // Fallback legacy field aliases
          'license_key': cleanKey,
          'device_id': deviceId,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Talk2Type)',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final result = LicenseActivationResponse.fromJson(response.data);
      if (result.success && result.token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConfig.keyLicenseToken, result.token!);
        await prefs.setString(AppConfig.keyLicenseKey, cleanKey);
        await prefs.setString(AppConfig.keyDeviceId, deviceId);
        await prefs.setString(AppConfig.keyLicenseAppId, appId);

        if (result.planName != null) {
          await prefs.setString(AppConfig.keyPlanName, result.planName!);
        }
        if (result.expiresAt != null) {
          await prefs.setString(AppConfig.keyExpiresAt, result.expiresAt!);
        }

        await AppConfig.setIsPro(true);
        await AppConfig.setLastVerifiedAt(DateTime.now().toIso8601String());

        debugPrint("[LicenseService] License activated successfully! Plan: ${result.planName}");
      }
      return result;
    } on DioException catch (e) {
      final data = e.response?.data;
      String errMsg = "লাইসেন্স সার্ভারের সাথে সংযোগ করা যায়নি।";
      if (data is Map && data['message'] != null) {
        errMsg = data['message'].toString();
      } else if (e.message != null) {
        errMsg = e.message!;
      }
      return LicenseActivationResponse(success: false, message: errMsg);
    } catch (e) {
      return LicenseActivationResponse(success: false, message: "অপ্রত্যাশিত ত্রুটি: $e");
    }
  }

  /// Periodic license verification via Hub /api/v1/verify
  /// Runs at most once every 72 hours when online.
  /// Does not downgrade on network/server errors unless no successful verification for > 30 days.
  Future<bool> verifyLicensePeriodic({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.keyLicenseToken);
    final key = prefs.getString(AppConfig.keyLicenseKey);

    if (token == null || token.trim().isEmpty || key == null || key.trim().isEmpty) {
      await AppConfig.setIsPro(false);
      return false;
    }

    final lastVerifiedStr = prefs.getString(AppConfig.keyLastVerifiedAt) ?? "";
    DateTime? lastVerified;
    if (lastVerifiedStr.isNotEmpty) {
      lastVerified = DateTime.tryParse(lastVerifiedStr);
    }

    // 30-Day grace period check: if offline / unverified for > 30 days, treat as Free until next verify
    if (lastVerified != null) {
      final daysSinceLastVerify = DateTime.now().difference(lastVerified).inDays;
      if (daysSinceLastVerify > 30) {
        debugPrint("[LicenseService] 30 days exceeded without verification ($daysSinceLastVerify days). Treating as Free.");
        await AppConfig.setIsPro(false);
      }
    }

    // Throttle: don't call network if verified within last 72 hours
    if (!force && lastVerified != null) {
      final hoursSinceLastVerify = DateTime.now().difference(lastVerified).inHours;
      if (hoursSinceLastVerify < 72) {
        return AppConfig.isPro;
      }
    }

    final baseUrl = AppConfig.licenseApiEndpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final targetUrl = '$baseUrl/api/v1/verify';
    final deviceId = await getDeviceId();

    try {
      final dio = DioClient.createDio();
      final response = await dio.post(
        targetUrl,
        data: {
          'appId': AppConfig.licenseAppId,
          'key': key,
          'deviceId': deviceId,
          'token': token,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final isValid = data['valid'] == true || data['status'] == 'active';
        if (isValid) {
          await AppConfig.setIsPro(true);
          await AppConfig.setLastVerifiedAt(DateTime.now().toIso8601String());
          if (data['planName'] != null) {
            await prefs.setString(AppConfig.keyPlanName, data['planName'].toString());
          }
          if (data['expiresAt'] != null) {
            await prefs.setString(AppConfig.keyExpiresAt, data['expiresAt'].toString());
          }
          debugPrint("[LicenseService] Periodic verification succeeded! Pro active.");
          return true;
        } else {
          final status = (data['status'] as String?)?.toLowerCase();
          if (status == 'revoked' || status == 'device_mismatch' || status == 'not_found') {
            debugPrint("[LicenseService] License revoked/invalidated by Hub (status: $status). Clearing license.");
            await clearLicense();
            await AppConfig.setIsPro(false);
            return false;
          }
        }
      }
      return AppConfig.isPro;
    } on DioException catch (e) {
      debugPrint("[LicenseService] Periodic verify network/HTTP error (${e.response?.statusCode}): ${e.message}. Keeping current Pro state within 30-day window.");
      // Do not downgrade on 404/405/5xx or timeout; keep current state
      if (lastVerifiedStr.isEmpty) {
        await AppConfig.setLastVerifiedAt(DateTime.now().toIso8601String());
      }
      return AppConfig.isPro;
    } catch (e) {
      debugPrint("[LicenseService] Periodic verify error: $e");
      return AppConfig.isPro;
    }
  }

  /// Fetch dynamic pricing and purchase info from License Hub
  Future<void> fetchHubAppInfo() async {
    try {
      final baseUrl = AppConfig.licenseApiEndpoint.trim().replaceAll(RegExp(r'/+$'), '');
      final dio = DioClient.createDio();
      final response = await dio.get(
        '$baseUrl/v1/apps/${AppConfig.licenseAppId}/info',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final purchaseUrl = data['purchase_url'] as String?;
        final priceText = data['price_text'] as String?;
        await AppConfig.setAppPricing(url: purchaseUrl, price: priceText);
      }
    } catch (_) {
      // Quiet ignore; fallback constants in AppConfig remain active
    }
  }

  /// Clears stored license token and resets activation
  Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.keyLicenseToken);
    await prefs.remove(AppConfig.keyLicenseKey);
    await prefs.remove(AppConfig.keyPlanName);
    await prefs.remove(AppConfig.keyExpiresAt);
    await AppConfig.setIsPro(false);
  }
}
