import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../native/native_bridge.dart';
import '../network/dio_client.dart';

/// Service responsible for sending anonymous install and usage telemetry to Ayyzan License Hub.
/// Collects anonymous device hardware specifications (model, manufacturer, OS) and tier (free vs pro).
/// Never sends raw device ID; only a deterministic 64-hex SHA-256 hash.
class InstallPingService {
  static final InstallPingService instance = InstallPingService._internal();
  InstallPingService._internal();

  @visibleForTesting
  Future<int?> Function(String url, Map<String, dynamic> data)? pingSenderForTesting;

  /// Pure deterministic function to compute sha256(rawDeviceId + ":talk2type")
  static String computeInstallHash(String deviceId) {
    final cleanId = deviceId.trim();
    final bytes = utf8.encode("$cleanId:talk2type");
    return sha256.convert(bytes).toString().toLowerCase();
  }

  /// Get or compute and persist the unique anonymous install hash.
  /// Computed once and saved under [AppConfig.keyInstallHash].
  Future<String> getInstallHash() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(AppConfig.keyInstallHash);
    if (savedHash != null && savedHash.trim().length == 64) {
      return savedHash.trim().toLowerCase();
    }

    final rawId = await NativeBridge.getDeviceId();
    final hash = computeInstallHash(rawId);
    await prefs.setString(AppConfig.keyInstallHash, hash);
    return hash;
  }

  /// Determine active tier: "pro" if a valid license is active (AppConfig.isPro with a non-empty token), else "free".
  String determineTier({required bool isPro, required String? token}) {
    final hasValidToken = token != null && token.trim().isNotEmpty;
    return (isPro && hasValidToken) ? "pro" : "free";
  }

  /// Check whether ping is throttled (max once per 12 hours)
  bool isThrottled(String? lastPingAtStr, DateTime now) {
    if (lastPingAtStr == null || lastPingAtStr.trim().isEmpty) {
      return false;
    }
    final lastPing = DateTime.tryParse(lastPingAtStr.trim());
    if (lastPing == null) {
      return false;
    }
    return now.difference(lastPing) < const Duration(hours: 12);
  }

  /// Build request body for ping
  Future<Map<String, dynamic>> buildPayload({
    required SharedPreferences prefs,
    String? customInstallHash,
    String? customTier,
    String? customAppVersion,
    String? customManufacturer,
    String? customModel,
    String? customOsVersion,
  }) async {
    final installHash = customInstallHash ?? await getInstallHash();
    final token = prefs.getString(AppConfig.keyLicenseToken);
    final tier = customTier ?? determineTier(isPro: AppConfig.isPro, token: token);

    String appVersion = customAppVersion ?? await NativeBridge.getAppVersion();
    if (appVersion.isEmpty) appVersion = "2.0.7";

    String manufacturer = customManufacturer ?? "unknown";
    String model = customModel ?? "unknown";
    String osVersion = customOsVersion ?? "unknown";

    if (customManufacturer == null || customModel == null || customOsVersion == null) {
      try {
        if (Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (customManufacturer == null) manufacturer = androidInfo.manufacturer;
          if (customModel == null) model = androidInfo.model;
          if (customOsVersion == null) osVersion = androidInfo.version.release;
        }
      } catch (e) {
        debugPrint("[InstallPingService] Failed to read hardware device info: $e");
      }
    }

    final Map<String, dynamic> payload = {
      'installHash': installHash,
      'tier': tier,
      'appVersion': appVersion,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
    };

    // Include licenseToken ONLY when tier is pro and token is present
    if (tier == "pro" && token != null && token.trim().isNotEmpty) {
      payload['licenseToken'] = token.trim();
    }

    return payload;
  }

  /// Send anonymous install and usage ping to the License Hub.
  /// Fire-and-forget: 5 s timeout, never block UI, never show errors, swallow all failures.
  /// Logs only HTTP status code, never sensitive tokens or keys.
  Future<void> sendPing({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check opt-out setting
      final sendStats = prefs.getBool(AppConfig.keySendUsageStats) ?? AppConfig.sendUsageStats;
      if (!sendStats) {
        debugPrint("[InstallPingService] Usage statistics telemetry is disabled by user setting.");
        return;
      }

      // Check 12-hour throttling unless forced
      final now = DateTime.now();
      final lastPingStr = prefs.getString(AppConfig.keyLastPingAt);
      if (!force && isThrottled(lastPingStr, now)) {
        debugPrint("[InstallPingService] Ping throttled (last sent within 12h: $lastPingStr)");
        return;
      }

      final payload = await buildPayload(prefs: prefs);
      final baseUrl = AppConfig.licenseApiEndpoint.trim().replaceAll(RegExp(r'/+$'), '');
      final appId = AppConfig.licenseAppId.trim();
      final targetUrl = '$baseUrl/api/v1/apps/$appId/ping';

      // Avoid hitting external network during Flutter widget/unit tests unless mock sender is injected
      if (Platform.environment.containsKey('FLUTTER_TEST') && pingSenderForTesting == null) {
        return;
      }

      int? statusCode;
      if (pingSenderForTesting != null) {
        statusCode = await pingSenderForTesting!(targetUrl, payload);
      } else {
        final dio = DioClient.createDio();
        final response = await dio.post(
          targetUrl,
          data: payload,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Talk2Type)',
            },
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        statusCode = response.statusCode;
      }

      // Update last ping timestamp on dispatch
      await prefs.setString(AppConfig.keyLastPingAt, now.toIso8601String());
      debugPrint("[InstallPingService] Ping response status: $statusCode");
    } on DioException catch (e) {
      // Record timestamp so we don't spam on offline or 404/429
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.keyLastPingAt, DateTime.now().toIso8601String());
      debugPrint("[InstallPingService] Ping response status: ${e.response?.statusCode ?? 'network_error'}");
    } catch (e) {
      debugPrint("[InstallPingService] Ping response status: error ($e)");
    }
  }
}
