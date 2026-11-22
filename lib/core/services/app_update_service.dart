import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final bool isMandatory;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
    this.isMandatory = false,
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

  /// Snooze auto update popups for 24 hours (or specified duration)
  Future<void> snoozeUpdate({Duration duration = const Duration(hours: 24)}) async {
    final prefs = await SharedPreferences.getInstance();
    final snoozeUntil = DateTime.now().add(duration).millisecondsSinceEpoch;
    await prefs.setInt(AppConfig.keyUpdateSnoozeUntil, snoozeUntil);
    debugPrint("[AppUpdateService] Snoozed update until: ${DateTime.fromMillisecondsSinceEpoch(snoozeUntil)}");
  }

  /// Skip a specific version until a newer version appears
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanVer = version.trim();
    await prefs.setString(AppConfig.keyUpdateSkippedVersion, cleanVer);
    debugPrint("[AppUpdateService] Skipped version: $cleanVer");
  }

  /// Get stored snooze timestamp in millisecondsSinceEpoch
  Future<int> getSnoozeUntil() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConfig.keyUpdateSnoozeUntil) ?? 0;
  }

  /// Get stored skipped version string
  Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.keyUpdateSkippedVersion);
  }

  /// Clear update snooze and skip preferences (for testing/reset)
  Future<void> clearUpdatePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.keyUpdateSnoozeUntil);
    await prefs.remove(AppConfig.keyUpdateSkippedVersion);
  }

  /// Determines whether the update dialog should be presented to the user
  bool shouldShowUpdate({
    required AppUpdateInfo info,
    required bool isManual,
    required int snoozeUntilMs,
    required String? skippedVersion,
    int? currentTimestampMs,
  }) {
    // 1. Manual check ALWAYS shows the result
    if (isManual) return true;

    // 2. Mandatory update ALWAYS shows (overrides snooze and skip)
    if (info.isMandatory) return true;

    final now = currentTimestampMs ?? DateTime.now().millisecondsSinceEpoch;

    // 3. Check if snooze is active (within 24 hours)
    if (now < snoozeUntilMs) return false;

    // 4. Check if this exact version was skipped
    if (skippedVersion != null && skippedVersion.trim().isNotEmpty) {
      final cleanLatest = info.latestVersion.toLowerCase().replaceAll('v', '').trim();
      final cleanSkipped = skippedVersion.toLowerCase().replaceAll('v', '').trim();
      // If server version is not greater than the skipped version, skip it
      if (cleanLatest == cleanSkipped || !isVersionGreater(cleanLatest, cleanSkipped)) {
        return false;
      }
    }

    return true;
  }

  /// Check whether a newer version is available from License Hub
  /// [isManual]: When true, shows explicit UI feedback (loading dialog, up-to-date notice, error toasts)
  Future<AppUpdateInfo?> checkForUpdate({
    BuildContext? context,
    bool isManual = false,
  }) async {
    // In kDebugMode skip the AUTOMATIC update check entirely (manual still works)
    if (!isManual && kDebugMode) {
      debugPrint("[AppUpdateService] Automatic update check skipped in kDebugMode");
      return null;
    }

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
        final minVer = (data['minVersion'] ?? data['min_version'] ?? '').toString().trim();
        final forceUpdate = data['forceUpdate'] == true || data['force_update'] == true;
        final isMandatory = forceUpdate || (minVer.isNotEmpty && isVersionGreater(minVer, currentVer));

        if (latestVer.isNotEmpty && isVersionGreater(latestVer, currentVer)) {
          // Hub download URL streams APK directly without exposing GitHub
          final downloadUrl = '$baseUrl/dl/$appId';
          final updateInfo = AppUpdateInfo(
            hasUpdate: true,
            currentVersion: currentVer,
            latestVersion: latestVer,
            downloadUrl: downloadUrl,
            releaseNotes: data['releaseNotes']?.toString() ?? "নতুন ফিচার ও দ্রুতগতির অভিজ্ঞতা পেতে অ্যাপটি আপডেট করুন।",
            isMandatory: isMandatory,
          );

          final prefs = await SharedPreferences.getInstance();
          final snoozeUntil = prefs.getInt(AppConfig.keyUpdateSnoozeUntil) ?? 0;
          final skippedVer = prefs.getString(AppConfig.keyUpdateSkippedVersion);

          final canShow = shouldShowUpdate(
            info: updateInfo,
            isManual: isManual,
            snoozeUntilMs: snoozeUntil,
            skippedVersion: skippedVer,
          );

          if (canShow && context != null && context.mounted) {
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
            isMandatory: isMandatory,
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
  bool isVersionGreater(String serverVer, String currentVer) {
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
      barrierDismissible: !info.isMandatory,
      builder: (dialogCtx) => PopScope(
        canPop: !info.isMandatory,
        child: AlertDialog(
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
                  info.isMandatory
                      ? "জরুরি আপডেট (${info.latestVersion.startsWith('v') ? info.latestVersion : 'v${info.latestVersion}'})"
                      : "নতুন আপডেট (${info.latestVersion.startsWith('v') ? info.latestVersion : 'v${info.latestVersion}'})",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.isMandatory
                      ? "অ্যাপটি চালিয়ে যেতে এই আপডেটটি গ্রহণ করা বাধ্যতামূলক।"
                      : "Talk2Type অ্যাপটির একটি নতুন আপডেট এসেছে। সর্বশেষ সুবিধা পেতে এখনই আপডেট করুন।",
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
                if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
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
                if (!info.isMandatory) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () async {
                        await skipVersion(info.latestVersion);
                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("ভার্সন ${info.latestVersion} বাদ দেওয়া হয়েছে"),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Text(
                          "এই ভার্সন বাদ দিন",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                if (!info.isMandatory)
                  TextButton(
                    onPressed: () async {
                      await snoozeUpdate();
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    },
                    child: const Text(
                      "পরে",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text(
                    "এখনই আপডেট করুন",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _startDownloadAndInstall(context, info);
                  },
                ),
              ],
            ),
          ],
        ),
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
          // 1. Signature Verification Safety Check
          final signaturesMatch = await NativeBridge.verifyApkSignature(savePath);
          if (!signaturesMatch && context.mounted) {
            _showSignatureMismatchDialog(context, info);
            return;
          }

          // 2. Unknown app sources permission check
          final canInstall = await NativeBridge.canInstallUnknownApps();
          if (!canInstall && context.mounted) {
            await _showUnknownSourcesPermissionDialog(context);
          }

          // 3. Launch Package Installer
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

  void _showSignatureMismatchDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppColors.warning, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "নিরাপত্তা সাইন পরিবর্তন",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          "এই আপডেটটি নতুন নিরাপত্তা সাইনসহ এসেছে। একবার পুরোনো অ্যাপ আনইনস্টল করে নতুন অ্যাপ ইনস্টল করুন। (আপনার লাইসেন্স কী আবার দিতে হবে)",
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("বাতিল", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: const Text("ডাউনলোড পেজ খুলুন"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              final pageUrl = info.downloadUrl.isNotEmpty ? info.downloadUrl : "https://github.com/shakelm39/talk2type/releases";
              NativeBridge.openBrowserUrl(pageUrl);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showUnknownSourcesPermissionDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phonelink_setup_rounded, color: AppColors.primaryLight, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "ইনস্টলেশন পারমিশন",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          "সরাসরি নতুন সংস্করণ আপডেট করার জন্য Talk2Type-কে 'অজানা অ্যাপ ইনস্টল' (Install Unknown Apps) পারমিশন দিন।",
          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text("বাতিল", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              NativeBridge.openUnknownAppSourcesSettings();
            },
            child: const Text("সেটিংস খুলুন"),
          ),
        ],
      ),
    );
  }
}
