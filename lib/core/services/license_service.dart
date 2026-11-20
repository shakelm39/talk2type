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

  /// Clears stored license token and resets activation
  Future<void> clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.keyLicenseToken);
    await prefs.remove(AppConfig.keyLicenseKey);
    await prefs.remove(AppConfig.keyPlanName);
    await prefs.remove(AppConfig.keyExpiresAt);
  }
}
