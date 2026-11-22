import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/native/native_bridge.dart';
import '../providers/permission_provider.dart';
import 'api_key_setup_screen.dart';
import 'home_control_screen.dart';

class PermissionDashboardScreen extends StatefulWidget {
  const PermissionDashboardScreen({super.key});

  @override
  State<PermissionDashboardScreen> createState() => _PermissionDashboardScreenState();
}

class _PermissionDashboardScreenState extends State<PermissionDashboardScreen> with WidgetsBindingObserver {
  int _sdkInt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSdkInt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PermissionProvider>(context, listen: false).checkAllPermissions();
    });
  }

  Future<void> _loadSdkInt() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (mounted) {
          setState(() {
            _sdkInt = info.version.sdkInt;
          });
        }
      }
    } catch (_) {}
  }

  bool get _isAndroid13OrHigher => Platform.isAndroid && _sdkInt >= 33;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User just returned from Android Settings! Re-check all permissions automatically.
      Provider.of<PermissionProvider>(context, listen: false).checkAllPermissions();
    }
  }

  void _showTip(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permProv = Provider.of<PermissionProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Permissions Setup"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Re-check status",
            onPressed: () async {
              await permProv.checkAllPermissions();
              _showTip("পারমিশন স্ট্যাটাস রিফ্রেশ হয়েছে");
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.security_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "প্রয়োজনীয় পারমিশন সেটআপ",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Talk2Type যেকোনো অ্যাপের উপরে ভাসমান বোতাম প্রদর্শন ও স্বয়ংক্রিয়ভাবে সরাসরি টেক্সট টাইপ করতে নিচের অনুমতিগুলো প্রয়োজন।",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Checklist Card 1: Microphone
              _buildPermissionCard(
                title: "১. মাইক্রোফোন পারমিশন (Microphone)",
                subtitle: "আপনার বাংলা ও ইংরেজি ভয়েস রেকর্ড করার জন্য প্রয়োজন।",
                isGranted: permProv.microphoneGranted,
                icon: Icons.mic_rounded,
                onEnable: () async {
                  _showTip("মাইক্রোফোন অনুমতি দিতে 'Allow' নির্বাচন করুন");
                  await permProv.requestMicrophone();
                },
              ),

              const SizedBox(height: 14),

              // Checklist Card 2: Floating Overlay (Display Over Other Apps)
              _buildPermissionCard(
                title: "২. ডিসপ্লে ওভার আদার অ্যাপস (Display Overlay)",
                subtitle: "অন্যান্য অ্যাপের উপরে ভাসমান ভয়েস Orb বোতাম প্রদর্শন করার জন্য।",
                isGranted: permProv.overlayGranted,
                icon: Icons.layers_rounded,
                onEnable: () async {
                  _showTip("সেটিংস থেকে Talk2Type খুঁজে সুইচটি On করুন");
                  await permProv.requestOverlay();
                },
              ),

              const SizedBox(height: 14),

              // Android 13+ Restricted Settings Guide Card
              if (_isAndroid13OrHigher && !permProv.accessibilityGranted) ...[
                _buildRestrictedSettingsHelpCard(),
                const SizedBox(height: 14),
              ],

              // Checklist Card 3: AutoType Accessibility Service
              _buildPermissionCard(
                title: "৩. এক্সেসিবিলিটি সার্ভিস (AutoType Accessibility)",
                subtitle: "General > Downloaded apps > Talk2Type সিলেক্ট করে On করুন।",
                isGranted: permProv.accessibilityGranted,
                icon: Icons.accessibility_new_rounded,
                onEnable: () async {
                  _showTip("General > Downloaded apps > Talk2Type অন করুন");
                  await permProv.requestAccessibility();
                },
              ),

              const SizedBox(height: 14),

              // Checklist Card 4: Battery Optimization Whitelist
              _buildPermissionCard(
                title: "৪. ব্যাটারি সেভার বাইপাস (Battery Optimization)",
                subtitle: "Xiaomi, Samsung, Oppo ফোনে ব্যাকগ্রাউন্ডে সার্ভিস সচল রাখতে।",
                isGranted: permProv.batteryOptimizationIgnored,
                icon: Icons.battery_charging_full_rounded,
                onEnable: () async {
                  _showTip("ব্যাটারি অপ্টিমাইজেশন বাইপাস অন করুন");
                  await permProv.requestBatteryOptimization();
                },
              ),

              const SizedBox(height: 24),

              // Enter App Button (Always clickable so user is never blocked!)
              ElevatedButton.icon(
                onPressed: () {
                  if (!AppConfig.hasAnyAiKey) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ApiKeySetupScreen(isFirstLaunch: true),
                      ),
                    );
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeControlScreen()),
                    );
                  }
                },
                icon: Icon(
                  permProv.allGranted ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  permProv.allGranted
                      ? "সব প্রস্তুত! অ্যাপে প্রবেশ করুন"
                      : "অ্যাপে প্রবেশ করুন (Continue to Home)",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: permProv.allGranted ? AppColors.success : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 12),

              // Alternative: Open App Settings
              OutlinedButton.icon(
                onPressed: () async {
                  _showTip("Talk2Type App Info সেটিংস খোলা হচ্ছে...");
                  await permProv.openAppSettingsFallback();
                },
                icon: const Icon(Icons.settings_applications_rounded, size: 18),
                label: const Text("সরাসরি App Settings ওপেন করুন"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
    required VoidCallback onEnable,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? AppColors.success.withValues(alpha: 0.5) : const Color(0xFF334155),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGranted ? AppColors.success.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isGranted ? AppColors.success : AppColors.primaryLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted ? AppColors.success.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGranted ? Icons.check_circle_rounded : Icons.pending_rounded,
                      size: 14,
                      color: isGranted ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGranted ? "Granted" : "Pending",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isGranted ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (!isGranted)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onEnable,
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text("অনুমতি দিন (Enable)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          else
            const Row(
              children: [
                Icon(Icons.check_rounded, color: AppColors.success, size: 18),
                SizedBox(width: 6),
                Text(
                  "অনুমোদিত ও সক্রিয় আছে",
                  style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRestrictedSettingsHelpCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Color(0xFFFBBF24), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Accessibility চালু করতে না পারলে ('App was denied access' / 'Restricted setting'):",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "১) Settings → Apps → Talk2Type খুলুন\n"
            "২) উপরের ⋮ মেনু → 'Allow restricted settings' চাপুন\n"
            "৩) তারপর আবার Accessibility চালু করুন।",
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => NativeBridge.openAppDetailsSettings(),
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text("অ্যাপ সেটিংস খুলুন"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFBBF24),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
