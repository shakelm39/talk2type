import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/tone_modes.dart';
import '../../core/native/native_bridge.dart';
import '../../core/services/app_update_service.dart';
import '../providers/voiceflow_provider.dart';
import 'api_key_setup_screen.dart';

class TestAiDialog extends StatefulWidget {
  const TestAiDialog({super.key});

  @override
  State<TestAiDialog> createState() => _TestAiDialogState();
}

class _TestAiDialogState extends State<TestAiDialog> {
  final TextEditingController _primaryKeyController = TextEditingController();
  final TextEditingController _backupKeyController = TextEditingController();
  final TextEditingController _groqKeyController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _customPromptController = TextEditingController();
  final TextEditingController _newWordController = TextEditingController();
  final TextEditingController _testInputController = TextEditingController();

  int _selectedOrbSize = AppConfig.orbSize;
  double _selectedOrbOpacity = AppConfig.orbOpacity;
  bool _freeOnlineEngine = AppConfig.freeOnlineEngine;
  bool _isSaving = false;
  String _injectionStatus = "";
  String _selectedPromptMode = ToneModes.bangla;

  @override
  void initState() {
    super.initState();
    _primaryKeyController.text = AppConfig.primaryGeminiApiKey.isNotEmpty
        ? AppConfig.primaryGeminiApiKey
        : AppConfig.directGeminiApiKey;
    _backupKeyController.text = AppConfig.backupGeminiApiKey;
    _groqKeyController.text = AppConfig.backupGroqApiKey;
    _endpointController.text = AppConfig.aiProcessEndpoint;
    _selectedOrbSize = AppConfig.orbSize;
    _selectedOrbOpacity = AppConfig.orbOpacity;
    _freeOnlineEngine = AppConfig.freeOnlineEngine;

    final vfProv = Provider.of<VoiceFlowProvider>(context, listen: false);
    _selectedPromptMode = vfProv.activeMode;
    _loadPromptForMode(_selectedPromptMode);
  }

  Future<void> _loadPromptForMode(String modeKey) async {
    final modeInfo = ToneModes.getByKey(modeKey);
    final saved = await AppConfig.getCustomPrompt(modeInfo.key);
    if (mounted) {
      setState(() {
        _selectedPromptMode = modeInfo.key;
        _customPromptController.text = (saved != null && saved.isNotEmpty)
            ? saved
            : modeInfo.defaultSystemPrompt;
      });
    }
  }

  @override
  void dispose() {
    _primaryKeyController.dispose();
    _backupKeyController.dispose();
    _groqKeyController.dispose();
    _endpointController.dispose();
    _customPromptController.dispose();
    _newWordController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await AppConfig.setPrimaryGeminiApiKey(_primaryKeyController.text.trim());
    await AppConfig.setBackupGeminiApiKey(_backupKeyController.text.trim());
    await AppConfig.setBackupGroqApiKey(_groqKeyController.text.trim());
    await AppConfig.setFreeOnlineEngine(_freeOnlineEngine);
    await AppConfig.setAiProcessEndpoint(_endpointController.text.trim());
    await AppConfig.saveOrbAppearance(size: _selectedOrbSize, opacity: _selectedOrbOpacity);
    await NativeBridge.updateOrbAppearance(sizeDp: _selectedOrbSize, opacity: _selectedOrbOpacity);

    // Save custom prompt for currently selected mode
    final modeInfo = ToneModes.getByKey(_selectedPromptMode);
    final promptText = _customPromptController.text.trim();
    if (promptText == modeInfo.defaultSystemPrompt.trim()) {
      await AppConfig.setCustomPrompt(modeInfo.key, "");
    } else {
      await AppConfig.setCustomPrompt(modeInfo.key, promptText);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("কনফিগারেশন সফলভাবে সেভ করা হয়েছে!"),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _testDirectAutoType() async {
    final textToType = _testInputController.text.trim().isNotEmpty
        ? _testInputController.text.trim()
        : "Talk2Type এআই দিয়ে সরাসরি টাইপ সফল হয়েছে!";
    setState(() => _injectionStatus = "ইনজেকশন চেষ্টা করা হচ্ছে...");

    final success = await NativeBridge.testTextInjection(textToType);
    if (!mounted) return;

    setState(() {
      _injectionStatus = success
          ? "সফল! ফোকাসকৃত ফিল্ডে টাইপ সম্পন্ন হয়েছে।"
          : "ক্লিপবোর্ডে কপি হয়েছে (সরাসরি ফিল্ড ফোকাস না থাকলে)।";
    });
  }

  @override
  Widget build(BuildContext context) {
    final modeInfo = ToneModes.getByKey(_selectedPromptMode);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppColors.primaryLight, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Talk2Type - এআই সেটিংস",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // API Key Onboarding Wizard Button
                      InkWell(
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ApiKeySetupScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.35),
                                AppColors.surfaceLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "✨ সহজ ধাপে API Key সেট করুন (উইজার্ড)",
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "গাইড দেখে ১ মিনিটে আপনার নিজস্ব ফ্রি কী নিন ও টেস্ট করুন।",
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Free Online Engine Toggle (Task 2.4)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            "ফ্রি অনলাইন ইঞ্জিন (key ছাড়া)",
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              "key না থাকলে বাক্য সাজাতে/অনুবাদে তৃতীয় পক্ষের ফ্রি সার্ভিস ব্যবহার হবে। ব্যক্তিগত তথ্যের জন্য বন্ধ রাখুন।",
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                            ),
                          ),
                          value: _freeOnlineEngine,
                          activeThumbColor: AppColors.primaryLight,
                          onChanged: (val) async {
                            setState(() => _freeOnlineEngine = val);
                            await AppConfig.setFreeOnlineEngine(val);
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Section 1: Fallback Chain Engine 1 (Primary Gemini)
                      Row(
                        children: const [
                          Icon(Icons.looks_one_rounded, color: AppColors.primaryLight, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Tier 1: Primary Gemini Key (gemini-2.5-flash)",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "প্রধান এআই ইঞ্জিন হিসেবে ব্যবহৃত হবে। কোটা বা ৫০৩ থাকলে অটো-সুইচ হবে।",
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _primaryKeyController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "AIzaSy... (Primary Key)",
                          prefixIcon: const Icon(Icons.key_rounded, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.save_rounded, color: AppColors.primaryLight),
                            onPressed: _saveSettings,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section 2: Fallback Chain Engine 2 (Backup Gemini Lite)
                      Row(
                        children: const [
                          Icon(Icons.looks_two_rounded, color: AppColors.success, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Tier 2: Backup Gemini Key (gemini-2.5-flash-lite)",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Model 1 ফেইল বা লিমিট রিচ করলে স্বয়ংক্রিয়ভাবে এতে সুইচ করবে।",
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _backupKeyController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "AIzaSy... (ঐচ্ছিক ব্যাকআপ কি)",
                          prefixIcon: Icon(Icons.key_rounded, size: 18),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section 3: Fallback Chain Engine 3 (Backup Groq Whisper + LLaMA)
                      Row(
                        children: const [
                          Icon(Icons.looks_3_rounded, color: AppColors.warning, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Tier 3: Backup Groq Key (Whisper Turbo + LLaMA)",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "জেমিনাই অফলাইন বা সম্পূর্ণ ব্লক থাকলে দ্রুততম ফলব্যাক হিসেবে গ্রোক কাজ করবে।",
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _groqKeyController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "gsk_... (ঐচ্ছিক Groq API Key)",
                          prefixIcon: Icon(Icons.speed_rounded, size: 18),
                        ),
                      ),

                      // Developer tools (debug builds ONLY)
                      if (kDebugMode) ...[
                        const SizedBox(height: 18),

                        // License Hub Gate (Plug-and-play Switch)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppConfig.enableLicenseCheck
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppConfig.enableLicenseCheck
                                  ? AppColors.primaryLight
                                  : const Color(0xFF334155),
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              "Enable License Hub Gate (পাবলিক লঞ্চ মোড)",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            subtitle: Text(
                              AppConfig.enableLicenseCheck
                                  ? "সক্রিয়: সব ভয়েস ব্যাকএন্ডে (POST /api/process-voice) যাবে এবং লাইসেন্স গেট প্রযোজ্য হবে।"
                                  : "বন্ধ (টেস্টিং মোড): লাইসেন্স ছাড়া সরাসরি এআই দিয়ে আনলিমিটেড টাইপিং চলবে।",
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            value: AppConfig.enableLicenseCheck,
                            activeThumbColor: AppColors.primaryLight,
                            onChanged: (val) {
                              setState(() {
                                AppConfig.enableLicenseCheck = val;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Backend AI Endpoint
                        const Text(
                          "Backend AI Endpoint (বাণিজ্যিক সার্ভার)",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _endpointController,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "https://license.ayyzan.com",
                            prefixIcon: Icon(Icons.cloud_outlined, size: 20),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Section: Custom System Prompt for Mode
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "কাস্টম সিস্টেম প্রম্পট (F18)",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          TextButton(
                            onPressed: () async {
                              final currentInfo = ToneModes.getByKey(_selectedPromptMode);
                              await AppConfig.setCustomPrompt(currentInfo.key, "");
                              setState(() {
                                _customPromptController.text = currentInfo.defaultSystemPrompt;
                              });
                            },
                            child: const Text("Reset Default", style: TextStyle(fontSize: 12, color: AppColors.secondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Dropdown / selector for which mode's prompt to edit
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPromptMode,
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryLight),
                            items: ToneModes.allModes.map((m) {
                              return DropdownMenuItem<String>(
                                value: m.key,
                                child: Row(
                                  children: [
                                    Icon(m.icon, size: 16, color: m.accentColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${m.bengaliTitle} (${m.key})",
                                      style: TextStyle(fontSize: 13, color: m.accentColor, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newKey) {
                              if (newKey != null) {
                                _loadPromptForMode(newKey);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customPromptController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: "${modeInfo.bengaliTitle} মোডের জন্য কাস্টম প্রম্পট লিখুন...",
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Section 4: Custom Vocabulary / Personal Dictionary
                      const Text(
                        "Custom Vocabulary (কাস্টম শব্দকোষ)",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "যেসব স্থানীয় শব্দ বা ব্র্যান্ডের নাম (যেমন: বিকাশ, নগদ, চালডাল) এআই যাতে ভুল না করে:",
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: AppConfig.customVocabulary.map((word) {
                          return Chip(
                            backgroundColor: AppColors.surfaceLight,
                            label: Text(word, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                            onDeleted: () async {
                              await AppConfig.removeVocabularyWord(word);
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newWordController,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "নতুন শব্দ লিখুন (যেমন: পাঠাও)...",
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onSubmitted: (val) async {
                                if (val.trim().isNotEmpty) {
                                  await AppConfig.addVocabularyWord(val.trim());
                                  _newWordController.clear();
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () async {
                              final val = _newWordController.text.trim();
                              if (val.isNotEmpty) {
                                await AppConfig.addVocabularyWord(val);
                                _newWordController.clear();
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Section 5: Floating Orb Appearance Settings
                      const Text(
                        "Floating Orb Appearance (অর্বের সাইজ ও স্বচ্ছতা)",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text("সাইজ:", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text("ছোট (46dp)", style: TextStyle(fontSize: 11)),
                            selected: _selectedOrbSize == 46,
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedOrbSize = 46);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text("মাঝারি (58dp)", style: TextStyle(fontSize: 11)),
                            selected: _selectedOrbSize == 58,
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedOrbSize = 58);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text("বড় (68dp)", style: TextStyle(fontSize: 11)),
                            selected: _selectedOrbSize == 68,
                            onSelected: (sel) {
                              if (sel) setState(() => _selectedOrbSize = 68);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "স্বচ্ছতা: ${(_selectedOrbOpacity * 100).toInt()}%",
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          Expanded(
                            child: Slider(
                              value: _selectedOrbOpacity,
                              min: 0.4,
                              max: 1.0,
                              divisions: 6,
                              activeColor: AppColors.primaryLight,
                              onChanged: (val) {
                                setState(() => _selectedOrbOpacity = val);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Section 6: Live AutoType Direct Field Test (R2)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "🎯 টাইপিং টেস্ট (Live AutoType)",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "নিচের ফিল্ডটিতে ক্লিক করে কার্সর রাখুন, তারপর নিচের বোতাম চাপলে এক্সেসিবিলিটি সার্ভিস স্বয়ংক্রিয়ভাবে টাইপ করবে:",
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _testInputController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: "এখানে কার্সর রাখুন (Focus this input field)...",
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _testDirectAutoType,
                              icon: const Icon(Icons.flash_on_rounded, size: 18),
                              label: const Text("স্বয়ংক্রিয় টাইপ পরীক্ষা করুন"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.black,
                              ),
                            ),
                            if (_injectionStatus.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _injectionStatus,
                                style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  AppUpdateService.instance.checkForUpdate(
                    context: context,
                    isManual: true,
                  );
                },
                icon: const Icon(Icons.system_update_rounded, size: 16),
                label: const Text("অ্যাপ আপডেট চেক করুন"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: AppColors.primaryLight, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Save and Close Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("বন্ধ করুন"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("সেটিংস সেভ করুন"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
