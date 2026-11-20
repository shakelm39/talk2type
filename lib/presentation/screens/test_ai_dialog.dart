import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/tone_modes.dart';
import '../../core/native/native_bridge.dart';
import '../providers/voiceflow_provider.dart';

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

  int _selectedOrbSize = AppConfig.orbSize;
  double _selectedOrbOpacity = AppConfig.orbOpacity;
  bool _isSaving = false;

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

    final vfProv = Provider.of<VoiceFlowProvider>(context, listen: false);
    final modeInfo = ToneModes.getByKey(vfProv.activeMode);
    _customPromptController.text = modeInfo.defaultSystemPrompt;
  }

  @override
  void dispose() {
    _primaryKeyController.dispose();
    _backupKeyController.dispose();
    _groqKeyController.dispose();
    _endpointController.dispose();
    _customPromptController.dispose();
    _newWordController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await AppConfig.setPrimaryGeminiApiKey(_primaryKeyController.text.trim());
    await AppConfig.setBackupGeminiApiKey(_backupKeyController.text.trim());
    await AppConfig.setBackupGroqApiKey(_groqKeyController.text.trim());
    await AppConfig.setAiProcessEndpoint(_endpointController.text.trim());
    await AppConfig.saveOrbAppearance(size: _selectedOrbSize, opacity: _selectedOrbOpacity);
    await NativeBridge.updateOrbAppearance(sizeDp: _selectedOrbSize, opacity: _selectedOrbOpacity);
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

  @override
  Widget build(BuildContext context) {
    final vfProv = Provider.of<VoiceFlowProvider>(context);
    final modeInfo = ToneModes.getByKey(vfProv.activeMode);

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

                      const SizedBox(height: 18),

                      // Section: Custom System Prompt for Mode
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "System Prompt (${modeInfo.title})",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _customPromptController.text = modeInfo.defaultSystemPrompt;
                              });
                            },
                            child: const Text("Reset Default", style: TextStyle(fontSize: 12, color: AppColors.secondary)),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _customPromptController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: "Enter custom prompt instructions for the AI...",
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

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
