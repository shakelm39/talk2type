import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import 'license_activation_screen.dart';
import 'permission_dashboard_screen.dart';
import 'upgrade_screen.dart';

class WelcomeChoiceScreen extends StatelessWidget {
  const WelcomeChoiceScreen({super.key});

  Future<void> _continueWithFree(BuildContext context) async {
    await AppConfig.setUserChoseFree(true);
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PermissionDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Logo & App Name
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.mic_rounded, size: 44, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Talk2Type এ স্বাগতম",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "যেকোনো অ্যাপে কথা বলে দ্রুত ও নির্ভুল বাংলা ও ইংরেজি টাইপ করুন।",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),

              const SizedBox(height: 24),

              // Option 1: Pro Activation Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE11D48).withValues(alpha: 0.2),
                      const Color(0xFF9333EA).withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.workspace_premium_rounded, color: Color(0xFFFB7185), size: 24),
                        SizedBox(width: 10),
                        Text(
                          "Talk2Type Pro (লাইফটাইম)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "সব ৫টি মোড (অফিসিয়াল, কাস্টমার সার্ভিস, আড্ডা, ইংলিশ অনুবাদ) ও দৈনিক সীমাহীন ভয়েস টাইপিং।",
                      style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LicenseActivationScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("লাইসেন্স কী দিন", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                          child: const Text("কিনুন"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Option 2: Free Version Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.volunteer_activism_rounded, color: AppColors.success, size: 22),
                        SizedBox(width: 10),
                        Text(
                          "ফ্রি সংস্করণ (Free Edition)",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "দৈনিক ২০টি ভয়েস টাইপিং এবং প্রাকৃতিক বাংলা পাংচুয়েশন সম্পূর্ণ ফ্রি। কোনো কার্ড বা পেমেন্ট ছাড়াই শুরু করুন।",
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _continueWithFree(context),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text(
                          "ফ্রি ভার্সনে চালান (Continue Free)",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF475569)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
