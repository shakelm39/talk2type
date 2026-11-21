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

  /// Fallback running app version (SemVer format)
  static const String defaultAppVersion = "1.0.1";

  /// Cache for resolved app version
  String? _cachedAppVersion;

  /// Get current running app version (dynamically from Android package or fallback)
  Future<String> getCurrentAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final v = await NativeBridge.getAppVersion();
      if (v.isNotEmpty) {
        _cachedAppVersion = v.replaceAll(RegExp(r'\+.*'), '').trim();
        return _cachedAppVersion!;
      }
    } catch (_) {}
    _cachedAppVersion = defaultAppVersion;
    return _cachedAppVersion!;
  }

  /// Check whether a newer version is available from License Hub
  /// [isManual]: When true, shows explicit UI feedback (loading dialog, up-to-date notice, error toasts)
  Future<AppUpdateInfo?> checkForUpdate({
    BuildContext? context,
    bool isManual = false,
  }) async {
    BuildContext? loadingDialogContext;

    // Show loading indicator when manually triggered
    if (isManual && context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          loadingDialogContext = ctx;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                    ),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      "আপডেট চেক করা হচ্ছে...",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    try {
      final currentVer = await getCurrentAppVersion();
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

      // Dismiss loading dialog if open
      if (loadingDialogContext != null && loadingDialogContext!.mounted) {
        Navigator.of(loadingDialogContext!).pop();
        loadingDialogContext = null;
      }

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final latestVer = (data['version'] ?? '').toString().trim();

        if (latestVer.isNotEmpty && _isVersionGreater(latestVer, currentVer)) {
          // Hub download URL streams APK directly without exposing GitHub
          final downloadUrl = '$baseUrl/dl/$appId';
          final updateInfo = AppUpdateInfo(
            hasUpdate: true,
            currentVersion: currentVer,
            latestVersion: latestVer,
            downloadUrl: downloadUrl,
            releaseNotes: data['releaseNotes']?.toString() ?? "নতুন ফিচার ও দ্রুতগতির অভিজ্ঞতা পেতে অ্যাপটি আপডেট করুন।",
          );

          if (context != null && context.mounted) {
            showUpdateNotice(context, updateInfo);
          }
          return updateInfo;
        } else {
          // Already up to date
          if (isManual && context != null && context.mounted) {
            showUpToDateNotice(context, currentVer);
          }
          return AppUpdateInfo(
            hasUpdate: false,
            currentVersion: currentVer,
            latestVersion: latestVer.isNotEmpty ? latestVer : currentVer,
            downloadUrl: '$baseUrl/dl/$appId',
          );
        }
      }
    } catch (e) {
      debugPrint("[AppUpdateService] Check update error: $e");
      // Dismiss loading dialog if open
      if (loadingDialogContext != null && loadingDialogContext!.mounted) {
        Navigator.of(loadingDialogContext!).pop();
        loadingDialogContext = null;
      }
      if (isManual && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("আপডেট সার্ভারে সংযোগ করা যায়নি। ইন্টারনেট সংযোগ চেক করুন।"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    return null;
  }

  /// User-friendly popup confirming app is already on the newest version
  void showUpToDateNotice(BuildContext context, String currentVer) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
            SizedBox(width: 10),
            Text(
              "অ্যাপটি আপ-টু-ডেট আছে",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          "আপনি বর্তমানে সর্বশেষ সংস্করণটি ব্যবহার করছেন (v$currentVer)। কোনো নতুন আপডেটের প্রয়োজন নেই।",
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("ঠিক আছে"),
          ),
        ],
      ),
    );
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
                "নতুন আপডেট (${info.latestVersion.startsWith('v') ? info.latestVersion : 'v' + info.latestVersion})",
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
