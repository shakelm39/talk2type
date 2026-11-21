import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../providers/license_provider.dart';
import '../providers/permission_provider.dart';
import 'home_control_screen.dart';
import 'permission_dashboard_screen.dart';

class LicenseActivationScreen extends StatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final TextEditingController _keyController = TextEditingController();
  late final TextEditingController _appIdController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _appIdController = TextEditingController(text: AppConfig.licenseAppId);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _appIdController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    final key = _keyController.text.trim();
    final appId = _appIdController.text.trim().isNotEmpty ? _appIdController.text.trim() : AppConfig.licenseAppId;

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("অনুগ্রহ করে আপনার লাইসেন্স কী প্রবেশ করান।"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final licenseProv = Provider.of<LicenseProvider>(context, listen: false);
    final success = await licenseProv.activateLicense(key, customAppId: appId);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("লাইসেন্স সফলভাবে সক্রিয় হয়েছে!"),
          backgroundColor: AppColors.success,
        ),
      );

      final permProv = Provider.of<PermissionProvider>(context, listen: false);
      await permProv.checkAllPermissions();

      if (!mounted) return;
      if (!permProv.allGranted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PermissionDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeControlScreen()),
        );
      }
    } else {
      final error = licenseProv.errorMessage ?? "সক্রিয়করণ ব্যর্থ হয়েছে।";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final licenseProv = Provider.of<LicenseProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Icon / Header
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Activate License",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "VoiceFlow AI ব্যবহার করতে আপনার ক্রয়কৃত বা অনুমোদিত লাইসেন্স কী দিয়ে অ্যাপটি অ্যাক্টিভেট করুন।",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Device ID Information Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.perm_device_information_rounded, color: AppColors.secondary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Device Hardware ID",
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              licenseProv.deviceId.isNotEmpty ? licenseProv.deviceId : "Loading Device ID...",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: licenseProv.deviceId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Device ID copied to clipboard")),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // App ID Input Field (Default: talk2type)
                TextField(
                  controller: _appIdController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    labelText: "App ID (অ্যাপ আইডি)",
                    hintText: "talk2type",
                    prefixIcon: Icon(Icons.apps_rounded, color: AppColors.secondary),
                  ),
                ),

                const SizedBox(height: 16),

                // License Key Input Field
                TextField(
                  controller: _keyController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: "License Key (লাইসেন্স কী)",
                    hintText: "VF-XXXX-XXXX-XXXX",
                    prefixIcon: const Icon(Icons.key_rounded, color: AppColors.primaryLight),
                    suffixIcon: _keyController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textMuted),
                            onPressed: () => setState(() => _keyController.clear()),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      "Hub: ${AppConfig.licenseApiEndpoint}",
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Activate Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleActivation,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("অ্যাক্টিভেট করুন (Activate)"),
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const PermissionDashboardScreen()),
                      );
                    },
                    child: const Text(
                      "টেস্ট মোডে প্রবেশ করুন (Skip for Testing)",
                      style: TextStyle(color: AppColors.secondary, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
