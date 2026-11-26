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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PermissionProvider>(context, listen: false).checkAllPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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

  /// Prominent disclosure for Microphone permission (Play User Data Policy)
  Future<void> _showMicDisclosureDialog(BuildContext context, PermissionProvider permProv) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.mic_rounded, color: AppColors.primaryLight, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "মাইক্রোফোন ব্যবহারের অনুমতি",
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          "Talk2Type আপনার বলা কথা লেখায় রূপান্তর করতে মাইক্রোফোন ব্যবহার করে।\n\n"
          "• আপনার রেকর্ডকৃত অডিও শুধুমাত্র গুগল স্পিচ বা আপনার নিজস্ব Gemini API কী-তে পাঠানো হয় রূপান্তরের জন্য।\n"
          "• আমাদের কোনো নিজস্ব সার্ভারে আপনার কোনো অডিও বা ভয়েস ডাটা সংরক্ষণ করা হয় না।",
          style: TextStyle(fontSize: 13.5, color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("না (Decline)", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("রাজি আছি (Agree)", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (agreed == true) {
      await permProv.requestMicrophone();
    }
  }

  /// Prominent disclosure before opening Input Method Settings
  Future<void> _showKeyboardDisclosureDialog(BuildContext context, PermissionProvider permProv) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.keyboard_rounded, color: AppColors.primaryLight, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Talk2Type কিবোর্ড চালু করুন",
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          "Android সব কিবোর্ড চালুর সময় সতর্ক করে যে কিবোর্ড 'সব লেখা সংগ্রহ করতে পারে'।\n\n"
          "Talk2Type শুধু আপনার বলা কথা লেখায় রূপান্তর করে। পাসওয়ার্ডের ঘরে ভয়েস টাইপিং স্বয়ংক্রিয়ভাবে বন্ধ থাকে এবং কোনো সাধারণ টাইপ করা লেখা সংরক্ষণ বা লগ করা হয় না।",
          style: TextStyle(fontSize: 13.5, color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("পরে", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("কিবোর্ড চালু করুন", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await permProv.enableKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permProv = Provider.of<PermissionProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Talk2Type কিবোর্ড সেটআপ"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "রিফ্রেশ করুন",
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
                          child: const Icon(Icons.keyboard_alt_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "কিবোর্ড অ্যাক্টিভেশন সেটআপ",
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
                      "যেকোনো অ্যাপে (WhatsApp, Messenger, Chrome ইত্যাদি) মুখে বলে সরাসরি টাইপ করতে নিচের ধাপগুলো সম্পন্ন করুন।",
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

              // Step 1: Microphone
              _buildStepCard(
                title: "১. মাইক্রোফোন পারমিশন (Microphone)",
                subtitle: "আপনার বাংলা ও ইংরেজি কথা শোনার জন্য প্রয়োজন। অডিও কোথাও সংরক্ষণ করা হয় না।",
                isReady: permProv.microphoneGranted,
                icon: Icons.mic_rounded,
                buttonLabel: "মাইক অনুমতি দিন",
                onAction: () => _showMicDisclosureDialog(context, permProv),
              ),

              const SizedBox(height: 14),

              // Step 2: Enable Keyboard
              _buildStepCard(
                title: "২. Talk2Type কিবোর্ড চালু করুন (Enable Keyboard)",
                subtitle: "সিস্টেম কিবোর্ড তালিকায় Talk2Type অন করুন।",
                isReady: permProv.keyboardEnabled,
                icon: Icons.toggle_on_rounded,
                buttonLabel: "কিবোর্ড চালু করুন",
                onAction: () => _showKeyboardDisclosureDialog(context, permProv),
              ),

              const SizedBox(height: 14),

              // Step 3: Select Keyboard
              _buildStepCard(
                title: "৩. Talk2Type কিবোর্ড বেছে নিন (Select Keyboard)",
                subtitle: "কিবোর্ড মেনু থেকে Talk2Type নির্বাচন করুন।",
                isReady: permProv.keyboardSelected,
                icon: Icons.check_circle_outline_rounded,
                buttonLabel: "কিবোর্ড নির্বাচন করুন",
                onAction: () async {
                  _showTip("তালিকা থেকে Talk2Type নির্বাচন করুন");
                  await permProv.selectKeyboard();
                },
              ),

              const SizedBox(height: 14),

              // Step 4: Floating Mic (Optional)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppConfig.floatingMicEnabled
                        ? AppColors.success.withValues(alpha: 0.5)
                        : const Color(0xFF334155),
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
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bubble_chart_rounded, color: AppColors.primaryLight, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "৪. ভাসমান মাইক (ঐচ্ছিক)",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: AppConfig.floatingMicEnabled,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) async {
                            if (val) {
                              final canOverlay = await NativeBridge.checkOverlayPermission();
                              if (!canOverlay) {
                                _showTip("ভাসমান বোতামের জন্য 'Display over other apps' অনুমতি দিন");
                                await permProv.requestOverlay();
                                return;
                              }
                            }
                            await AppConfig.setFloatingMicEnabled(val);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "কিবোর্ডের পাশাপাশি স্ক্রিনের একপাশে ছোট ভাসমান বোতাম রাখতে চাইলে চালু করুন (Default OFF)।",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Step 5: Battery Optimization (Optional)
              _buildStepCard(
                title: "৫. ব্যাটারি সেভার বাইপাস (ঐচ্ছিক)",
                subtitle: "Xiaomi, Samsung, Oppo ফোনে ব্যাকগ্রাউন্ডে সার্ভিস সচল রাখতে।",
                isReady: permProv.batteryOptimizationIgnored,
                icon: Icons.battery_charging_full_rounded,
                buttonLabel: "বাইপাস অন করুন",
                onAction: () async {
                  await permProv.requestBatteryOptimization();
                },
              ),

              const SizedBox(height: 24),

              // Enter App Button
              ElevatedButton.icon(
                onPressed: () {
                  if (!AppConfig.hasAnyAiKey && !AppConfig.keySetupSkipped) {
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

              const SizedBox(height: 14),

              // Privacy Policy Link
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    NativeBridge.openBrowserUrl(AppConfig.privacyPolicyUrl);
                  },
                  icon: const Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.white60),
                  label: const Text(
                    "প্রাইভেসি পলিসি (Privacy Policy)",
                    style: TextStyle(color: Colors.white60, fontSize: 13, decoration: TextDecoration.underline),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required String subtitle,
    required bool isReady,
    required IconData icon,
    required String buttonLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady ? AppColors.success.withValues(alpha: 0.5) : const Color(0xFF334155),
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
                  color: isReady ? AppColors.success.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isReady ? AppColors.success : AppColors.primaryLight,
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
                  color: isReady ? AppColors.success.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isReady ? Icons.check_circle_rounded : Icons.pending_rounded,
                      size: 14,
                      color: isReady ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isReady ? "Ready" : "Pending",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isReady ? AppColors.success : AppColors.warning,
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
          if (!isReady)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: Text(buttonLabel),
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
                Expanded(
                  child: Text(
                    "সম্পন্ন ও সক্রিয় আছে",
                    style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
