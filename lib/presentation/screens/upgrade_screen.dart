import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/native/native_bridge.dart';
import '../../core/services/license_service.dart';
import 'license_activation_screen.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  String _savedLicenseKey = "";
  String _planName = "Talk2Type Pro — আজীবন অ্যাক্সেস";
  String _deviceId = "...";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant UpgradeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedLicenseKey = prefs.getString(AppConfig.keyLicenseKey) ?? "";
      _planName = prefs.getString(AppConfig.keyPlanName) ?? "Talk2Type Pro — আজীবন অ্যাক্সেস";
    });

    final devId = await NativeBridge.getDeviceId();
    if (mounted) {
      setState(() {
        _deviceId = devId;
      });
    }

    // Refresh hub info on open (refresh price / button / links when it returns)
    await LicenseService.instance.fetchHubAppInfo();
    if (mounted) {
      setState(() {});
    }
  }

  String _formatMaskedKey(String key) {
    final clean = key.trim();
    if (clean.isEmpty) return "••••-••••-••••-PRO";
    if (clean.length <= 4) return "••••-••••-••••-$clean";
    final last4 = clean.substring(clean.length - 4);
    return "••••-••••-••••-$last4";
  }

  void _openWhatsAppSupport() {
    final phone = AppConfig.supportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    final target = phone.startsWith('88') ? phone : '88$phone';
    final msg = AppConfig.isPro
        ? 'হ্যালো Talk2Type সাপোর্ট, আমার ডিভাইস আইডি: $_deviceId'
        : 'হ্যালো Talk2Type সাপোর্ট, আমি Pro লাইসেন্স সম্পর্কে জানতে চাই। আমার ডিভাইস আইডি: $_deviceId';
    final url = "https://wa.me/$target?text=${Uri.encodeComponent(msg)}";
    NativeBridge.openBrowserUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = AppConfig.isPro;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isPro ? "লাইসেন্স তথ্য (Pro Active)" : "Talk2Type Pro",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: isPro ? _buildProView() : _buildFreeSalesView(),
        ),
      ),
    );
  }

  /// View shown to activated PRO users
  Widget _buildProView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Pro Status Banner
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.35),
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
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "✅ আপনি Talk2Type Pro (লাইফটাইম) ব্যবহার করছেন",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "আপনার ডিভাইসে Pro সংস্করণটি সফলভাবে সক্রিয় আছে। আপনি আজীবন সব ফিচার আনলিমিটেড ব্যবহার করতে পারবেন।",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // License Plan & Masked Key Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "লাইসেন্স প্ল্যান:",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      "PRO ACTIVE",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _planName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(height: 20, color: Color(0xFF334155)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "লাইসেন্স কী (শেষ ৪ সংখ্যা):",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    _formatMaskedKey(_savedLicenseKey),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Color(0xFF38BDF8),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Device ID Box
        _buildDeviceIdCard(),

        const SizedBox(height: 16),

        // WhatsApp Support Button
        ElevatedButton.icon(
          onPressed: _openWhatsAppSupport,
          icon: const Icon(Icons.chat_rounded, size: 20, color: Colors.white),
          label: const Text(
            "হোয়াটসঅ্যাপ সাপোর্ট (WhatsApp Support)",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),

        const SizedBox(height: 24),

        // Active Benefits List Header
        const Text(
          "আপনার সক্রিয় Pro সুবিধাসমূহ",
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
          isUnlocked: true,
        ),
        const SizedBox(height: 10),

        _buildBenefitRow(
          icon: Icons.auto_awesome_rounded,
          title: "সব ৫টি প্রিমিয়াম এআই টাইপিং মোড সক্রিয়",
          subtitle: "বাংলা ছাড়াও অফিসিয়াল, কাস্টমার সাপোর্ট, আড্ডা এবং সরাসরি বাংলা থেকে ইংলিশ অনুবাদ।",
          iconColor: const Color(0xFFA855F7),
          isUnlocked: true,
        ),
        const SizedBox(height: 10),

        _buildBenefitRow(
          icon: Icons.file_download_rounded,
          title: "হিস্ট্রি এক্সপোর্ট ও ব্যাকআপ সক্রিয়",
          subtitle: "টাইপকৃত সকল টেক্সট হিস্ট্রি এক ক্লিকে টেক্সট ফাইল হিসেবে এক্সপোর্ট করার সুবিধা।",
          iconColor: const Color(0xFF34D399),
          isUnlocked: true,
        ),
        const SizedBox(height: 10),

        _buildBenefitRow(
          icon: Icons.flash_on_rounded,
          title: "সর্বোচ্চ গতি ও প্রাইমারি এআই চ্যানেল",
          subtitle: "আপনার নিজস্ব Gemini এবং Groq এআই কি দিয়ে দ্রুততম টাইপিং ও অটো-সুইচিং।",
          iconColor: const Color(0xFFFBBF24),
          isUnlocked: true,
        ),
        const SizedBox(height: 10),

        _buildBenefitRow(
          icon: Icons.verified_rounded,
          title: "লাইফটাইম আপডেট ও সাপোর্ট",
          subtitle: "ভবিষ্যতের সকল ফিচার আপডেট ও অফিসিয়াল সাপোর্ট সম্পূর্ণ অন্তর্ভুক্ত।",
          iconColor: const Color(0xFFF43F5E),
          isUnlocked: true,
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  /// Sales view shown to FREE users
  Widget _buildFreeSalesView() {
    return Column(
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
          onPressed: () async {
            final res = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const LicenseActivationScreen()),
            );
            if (res == true || AppConfig.isPro) {
              await _loadData();
            }
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

        const SizedBox(height: 16),

        // Device ID copy box for support assistance
        _buildDeviceIdCard(),

        const SizedBox(height: 12),

        // Pre-sales WhatsApp Support
        TextButton.icon(
          onPressed: _openWhatsAppSupport,
          icon: const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primaryLight),
          label: const Text(
            "কেনার আগে কোনো প্রশ্ন আছে? হোয়াটসঅ্যাপে যোগাযোগ করুন",
            style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDeviceIdCard() {
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
                  _deviceId,
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
              Clipboard.setData(ClipboardData(text: _deviceId));
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
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    bool isUnlocked = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFF334155),
        ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  ],
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
