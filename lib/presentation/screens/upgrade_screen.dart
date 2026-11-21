import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/native/native_bridge.dart';
import 'license_activation_screen.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Talk2Type Pro",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Talk2Type Pro — আজীবন অ্যাক্সেস",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "একবার কিনুন, সারাজীবন আনলিমিটেড ব্যবহার করুন। কোনো মাসিক বা বাৎসরিক সাবস্ক্রিপশন চার্জ নেই।",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        AppConfig.priceText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Benefits List Header
              const Text(
                "Pro সংস্করণের সুবিধাসমূহ",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _buildBenefitRow(
                icon: Icons.all_inclusive_rounded,
                title: "দৈনিক সীমাহীন (Unlimited) ভয়েস টাইপিং",
                subtitle: "ফ্রি সংস্করণের ২০টি ইনপুটের কোনো সীমা নেই। যত ইচ্ছা কথা বলে টাইপ করুন।",
                iconColor: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 10),

              _buildBenefitRow(
                icon: Icons.auto_awesome_rounded,
                title: "সব ৫টি প্রিমিয়াম এআই টাইপিং মোড",
                subtitle: "বাংলা ছাড়াও অফিসিয়াল, কাস্টমার সাপোর্ট, আড্ডা এবং সরাসরি বাংলা থেকে ইংলিশ অনুবাদ।",
                iconColor: const Color(0xFFA855F7),
              ),
              const SizedBox(height: 10),

              _buildBenefitRow(
                icon: Icons.file_download_rounded,
                title: "হিস্ট্রি এক্সপোর্ট ও ব্যাকআপ",
                subtitle: "টাইপকৃত সকল টেক্সট হিস্ট্রি এক ক্লিকে টেক্সট ফাইল হিসেবে এক্সপোর্ট করার সুবিধা।",
                iconColor: const Color(0xFF34D399),
              ),
              const SizedBox(height: 10),

              _buildBenefitRow(
                icon: Icons.flash_on_rounded,
                title: "সর্বোচ্চ গতি ও প্রাইমারি এআই চ্যানেল",
                subtitle: "আপনার নিজস্ব Gemini এবং Groq এআই কি দিয়ে দ্রুততম টাইপিং ও অটো-সুইচিং।",
                iconColor: const Color(0xFFFBBF24),
              ),
              const SizedBox(height: 10),

              _buildBenefitRow(
                icon: Icons.verified_rounded,
                title: "লাইফটাইম আপডেট ও সাপোর্ট",
                subtitle: "ভবিষ্যতের সকল ফিচার আপডেট ও অফিসিয়াল সাপোর্ট সম্পূর্ণ বিনামূল্যে অন্তর্ভুক্ত।",
                iconColor: const Color(0xFFF43F5E),
              ),

              const SizedBox(height: 24),

              // Action CTA: Purchase
              ElevatedButton.icon(
                onPressed: () => NativeBridge.openBrowserUrl(AppConfig.purchaseUrl),
                icon: const Icon(Icons.shopping_bag_rounded, size: 20),
                label: const Text(
                  "প্রো লাইসেন্স কিনুন (Buy Pro Now)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
              ),

              const SizedBox(height: 12),

              // Secondary CTA: I have a license key
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LicenseActivationScreen()),
                  );
                },
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const Text(
                  "আমার লাইসেন্স কী আছে (অ্যাক্টিভেট করুন)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 20),

              // Device ID copy box for support assistance
              FutureBuilder<String>(
                future: NativeBridge.getDeviceId(),
                builder: (context, snapshot) {
                  final devId = snapshot.data ?? "...";
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "আপনার ডিভাইস আইডি (সাপোর্টের জন্য):",
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                devId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: "ডিভাইস আইডি কপি করুন",
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: devId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("ডিভাইস আইডি ক্লিপবোর্ডে কপি হয়েছে"),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
