import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import '../native/native_bridge.dart';
import '../network/dio_client.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
  });
}

class AppUpdateService {
  static final AppUpdateService instance = AppUpdateService._internal();
  AppUpdateService._internal();

  /// Current running app version (SemVer format)
  static const String currentAppVersion = "1.0.0";

  /// Check whether a newer version is available from License Hub
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final dio = DioClient.createDio();
      final baseUrl = AppConfig.licenseApiEndpoint.trim().replaceAll(RegExp(r'/+$'), '');
      final appId = AppConfig.licenseAppId.trim();

      // License Hub provides /v1/apps/{appId}/info which resolves latest version
      final url = '$baseUrl/v1/apps/$appId/info';

      final response = await dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final latestVer = (data['version'] ?? '').toString().trim();

        if (latestVer.isNotEmpty && _isVersionGreater(latestVer, currentAppVersion)) {
          // Hub download URL streams APK directly without exposing GitHub
          final downloadUrl = '$baseUrl/dl/$appId';
          return AppUpdateInfo(
            hasUpdate: true,
            currentVersion: currentAppVersion,
            latestVersion: latestVer,
            downloadUrl: downloadUrl,
            releaseNotes: data['releaseNotes']?.toString() ?? "নতুন ফিচার ও দ্রুতগতির অভিজ্ঞতা পেতে অ্যাপটি আপডেট করুন।",
          );
        }
      }
    } catch (e) {
      debugPrint("[AppUpdateService] Check update error (silently handled): $e");
    }
    return null;
  }

  /// Compares two Semantic Versions (e.g. "1.0.1" vs "1.0.0")
  bool _isVersionGreater(String serverVer, String currentVer) {
    try {
      final cleanServer = serverVer.toLowerCase().replaceAll('v', '').trim();
      final cleanCurrent = currentVer.toLowerCase().replaceAll('v', '').trim();

      final sParts = cleanServer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = sParts.length > cParts.length ? sParts.length : cParts.length;
      for (int i = 0; i < maxLen; i++) {
        final sVal = i < sParts.length ? sParts[i] : 0;
        final cVal = i < cParts.length ? cParts[i] : 0;
        if (sVal > cVal) return true;
        if (sVal < cVal) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Show the user-friendly update notice dialog
  void showUpdateNotice(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded, color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "নতুন আপডেট (v${info.latestVersion})",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Talk2Type অ্যাপটির একটি নতুন আপডেট এসেছে। সর্বশেষ সুবিধা পেতে এখনই আপডেট করুন।",
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
            ),
            if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  info.releaseNotes!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("পরে", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text("এখনই আপডেট করুন"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _startDownloadAndInstall(context, info);
            },
          ),
        ],
      ),
    );
  }

  /// Background download with zero exposure of URLs or technical endpoints
  void _startDownloadAndInstall(BuildContext context, AppUpdateInfo info) {
    final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
    final ValueNotifier<String> statusNotifier = ValueNotifier("ডাউনলোড শুরু হচ্ছে...");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.downloading_rounded, color: AppColors.primaryLight, size: 24),
              SizedBox(width: 10),
              Text(
                "আপডেট হচ্ছে...",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          content: ValueListenableBuilder<double>(
            valueListenable: progressNotifier,
            builder: (context, progress, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<String>(
                    valueListenable: statusNotifier,
                    builder: (context, status, _) {
                      return Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Execute Download
    () async {
      try {
        final tempDir = await getTemporaryDirectory();
        final savePath = '${tempDir.path}/talk2type_update_${DateTime.now().millisecondsSinceEpoch}.apk';

        final dio = DioClient.createDio();
        await dio.download(
          info.downloadUrl,
          savePath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final pct = received / total;
              progressNotifier.value = pct;
              statusNotifier.value = "ডাউনলোড হচ্ছে... ${(pct * 100).toInt()}%";
            } else {
              statusNotifier.value = "ডাউনলোড হচ্ছে...";
            }
          },
        );

        statusNotifier.value = "ইনস্টলেশন শুরু হচ্ছে...";
        await Future.delayed(const Duration(milliseconds: 400));

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Dismiss progress dialog
        }

        final file = File(savePath);
        if (await file.exists() && await file.length() > 0) {
          final installed = await NativeBridge.installApk(savePath);
          if (!installed && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("ইনস্টলার ওপেন করা যায়নি। অনুগ্রহ করে অ্যাপ পারমিশন দিন।"),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("[AppUpdateService] Download failed: $e");
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("আপডেট ডাউনলোড সম্পন্ন করা যায়নি। ইন্টারনেট চেক করুন।"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }();
  }
}
