import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/native/native_bridge.dart';
import '../../core/network/dio_client.dart';
import 'home_control_screen.dart';

class ApiKeySetupScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const ApiKeySetupScreen({
    super.key,
    this.isFirstLaunch = false,
  });

  @override
  State<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends State<ApiKeySetupScreen> {
  final TextEditingController _primaryController = TextEditingController();
  final TextEditingController _backupGeminiController = TextEditingController();
  final TextEditingController _backupGroqController = TextEditingController();

  bool _isAdvancedExpanded = false;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testStatus;
  bool _testSuccess = false;

  bool _isPrimaryEditing = false;
  bool _isBackupGeminiEditing = false;
  bool _isBackupGroqEditing = false;

  @override
  void initState() {
    super.initState();
    _loadExistingKeys();
  }

  void _loadExistingKeys() {
    _primaryController.text = AppConfig.primaryGeminiApiKey;
    _backupGeminiController.text = AppConfig.backupGeminiApiKey;
    _backupGroqController.text = AppConfig.backupGroqApiKey;

    _isPrimaryEditing = AppConfig.primaryGeminiApiKey.isEmpty;
    _isBackupGeminiEditing = AppConfig.backupGeminiApiKey.isEmpty;
    _isBackupGroqEditing = AppConfig.backupGroqApiKey.isEmpty;
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _backupGeminiController.dispose();
    _backupGroqController.dispose();
    super.dispose();
  }

  Future<void> _pasteTo(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      setState(() {
        controller.text = data.text!.trim();
        _testStatus = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ক্লিপবোর্ড থেকে কী পেস্ট করা হয়েছে"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _testKeys() async {
    final primaryKey = _primaryController.text.trim();
    if (primaryKey.isEmpty) {
      setState(() {
        _testStatus = "অনুগ্রহ করে প্রথমে Primary Gemini Key দিন।";
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testStatus = "Gemini Key পরীক্ষা করা হচ্ছে...";
      _testSuccess = false;
    });

    final dio = DioClient.createDio();
    String? successfulModel;
    String? failureReason;

    final candidateModels = [
      'gemini-1.5-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash-8b',
    ];

    for (final model in candidateModels) {
      try {
        final res = await dio.post(
          "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent",
          data: {
            "contents": [
              {
                "parts": [
                  {"text": "Hello"}
                ]
              }
            ],
            "generationConfig": {
              "maxOutputTokens": 5,
              "temperature": 0.1,
            }
          },
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': primaryKey,
            },
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        if (res.statusCode == 200) {
          successfulModel = model;
          break;
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 400 || code == 403) {
          failureReason = "API Key টি সঠিক নয় অথবা এতে অ্যাক্সেস নেই (Code $code)।";
          break; // Key invalid, no need to retry models
        } else if (code == 429) {
          failureReason = "কোটা শেষ হয়েছে (Rate Limit / Quota Exceeded)।";
          continue;
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          failureReason = "ইন্টারনেট সংযোগ নেই বা সংযোগ টাইমআউট হয়েছে।";
          break;
        } else {
          failureReason = "সার্ভার রেসপন্স ত্রুটি: ${code ?? e.message}";
        }
      } catch (e) {
        failureReason = "ত্রুটি: $e";
        break;
      }
    }

    // Optional Groq test if filled
    String groqNote = "";
    final groqKey = _backupGroqController.text.trim();
    if (successfulModel != null && groqKey.isNotEmpty) {
      try {
        final gRes = await dio.get(
          "https://api.groq.com/openai/v1/models",
          options: Options(
            headers: {'Authorization': 'Bearer $groqKey'},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        if (gRes.statusCode == 200) {
          groqNote = "\n✓ Groq ব্যাকআপ কী সক্রিয়!";
        }
      } catch (_) {
        groqNote = "\n⚠ Groq কী যাচাই করা যায়নি।";
      }
    }

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      if (successfulModel != null) {
        _testSuccess = true;
        _testStatus = "✅ সফল! মডেল $successfulModel সক্রিয় আছে।$groqNote";
      } else {
        _testSuccess = false;
        _testStatus = "❌ ${failureReason ?? 'যাচাই ব্যর্থ হয়েছে। কী ও ইন্টারনেট চেক করুন।'}";
      }
    });
  }

  Future<void> _saveAndProceed() async {
    final primary = _primaryController.text.trim();
    final backupGemini = _backupGeminiController.text.trim();
    final backupGroq = _backupGroqController.text.trim();

    setState(() => _isSaving = true);

    await AppConfig.setPrimaryGeminiApiKey(primary);
    await AppConfig.setBackupGeminiApiKey(backupGemini);
    await AppConfig.setBackupGroqApiKey(backupGroq);
    await AppConfig.loadConfig();

    setState(() => _isSaving = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✓ এআই সেটিংস সফলভাবে সংরক্ষিত হয়েছে!"),
        backgroundColor: AppColors.success,
      ),
    );

    if (widget.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeControlScreen()),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _skipForNow() async {
    await AppConfig.setKeySetupSkipped(true);
    if (!mounted) return;
    if (widget.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeControlScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "এআই কী (API Key) সেটআপ",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.isFirstLaunch)
            TextButton(
              onPressed: _skipForNow,
              child: const Text(
                "পরে করব",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
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
                          child: const Icon(Icons.key_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "আপনার নিজস্ব ফ্রি এআই কী",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Talk2Type সরাসরি আপনার গুগল জেমিনাই (Gemini) কী ব্যবহার করে দ্রুত ও নির্ভুলভাবে কথা থেকে লেখা রূপান্তর করে। এটি ১০০% ফ্রি ও নিরাপদ।",
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Step-by-step numbered guide
              const Text(
                "কিভাবে ফ্রি API Key পাবেন?",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _buildStepCard(
                stepNum: "১",
                title: "aistudio.google.com খুলুন",
                subtitle: "গুগলের অফিসিয়াল ফ্রি এআই স্টুডিওতে যান।",
                action: ElevatedButton.icon(
                  onPressed: () => NativeBridge.openBrowserUrl("https://aistudio.google.com/app/apikey"),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text("গুগল এআই স্টুডিও খুলুন"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _buildStepCard(
                stepNum: "২",
                title: "Google দিয়ে লগইন করুন",
                subtitle: "আপনার ব্যক্তিগত জিমেইল (Gmail) অ্যাকাউন্ট দিয়ে সাইন ইন করুন।",
              ),

              const SizedBox(height: 10),

              _buildStepCard(
                stepNum: "৩",
                title: "'Create API key' তৈরি করুন",
                subtitle: "'Get API key' বোতামে চাপ দিয়ে নতুন একটি ফ্রি কী তৈরি করুন।",
              ),

              const SizedBox(height: 10),

              _buildStepCard(
                stepNum: "৪",
                title: "কপি করে নিচে পেস্ট করুন",
                subtitle: "প্রাপ্ত কী টি কপি করে নিচের ঘরে পেস্ট করে সংরক্ষণ করুন।",
              ),

              const SizedBox(height: 24),

              // Primary Gemini Key Input Card
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.looks_one_rounded, color: AppColors.primaryLight, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Primary Gemini Key *",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isPrimaryEditing && AppConfig.isValidKey(_primaryController.text))
                          TextButton.icon(
                            onPressed: () => setState(() => _isPrimaryEditing = true),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: const Text("এডিট"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryLight,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "প্রধান এআই ইঞ্জিন (gemini-2.5-flash / 1.5-flash)",
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    if (!_isPrimaryEditing && AppConfig.isValidKey(_primaryController.text))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppConfig.maskKey(_primaryController.text),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _primaryController,
                              obscureText: true,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "AIzaSy...",
                                prefixIcon: Icon(Icons.key_rounded, size: 18),
                              ),
                              onChanged: (_) => setState(() => _testStatus = null),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _pasteTo(_primaryController),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("পেস্ট", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Advanced section expander (Backup Gemini Key & Groq Key)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _isAdvancedExpanded,
                    onExpansionChanged: (val) => setState(() => _isAdvancedExpanded = val),
                    leading: const Icon(Icons.alt_route_rounded, color: AppColors.textSecondary, size: 20),
                    title: const Text(
                      "উন্নত সেটিংস (অ্যাডভান্সড ব্যাকআপ কী)",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      const Text(
                        "প্রাইমারি কীতে ৫০৩ বা কোটা শেষ হলে স্বয়ংক্রিয়ভাবে নিচের ব্যাকআপ কীতে সুইচ হবে।",
                        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),

                      // Backup Gemini
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Tier 2: Backup Gemini Key",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                          ),
                          if (!_isBackupGeminiEditing && AppConfig.isValidKey(_backupGeminiController.text))
                            TextButton(
                              onPressed: () => setState(() => _isBackupGeminiEditing = true),
                              child: const Text("এডিট", style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (!_isBackupGeminiEditing && AppConfig.isValidKey(_backupGeminiController.text))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppConfig.maskKey(_backupGeminiController.text),
                            style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _backupGeminiController,
                                obscureText: true,
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "AIzaSy... (ঐচ্ছিক ব্যাকআপ কী)",
                                  prefixIcon: Icon(Icons.key_rounded, size: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _pasteTo(_backupGeminiController),
                              child: const Text("পেস্ট"),
                            ),
                          ],
                        ),

                      const SizedBox(height: 14),

                      // Backup Groq
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Tier 3: Backup Groq Key (Whisper + LLaMA)",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                          ),
                          if (!_isBackupGroqEditing && AppConfig.isValidKey(_backupGroqController.text))
                            TextButton(
                              onPressed: () => setState(() => _isBackupGroqEditing = true),
                              child: const Text("এডিট", style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (!_isBackupGroqEditing && AppConfig.isValidKey(_backupGroqController.text))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppConfig.maskKey(_backupGroqController.text),
                            style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _backupGroqController,
                                obscureText: true,
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "gsk_... (ঐচ্ছিক Groq কী)",
                                  prefixIcon: Icon(Icons.key_rounded, size: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _pasteTo(_backupGroqController),
                              child: const Text("পেস্ট"),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Test Result Display Card
              if (_testStatus != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _testSuccess
                          ? AppColors.success.withValues(alpha: 0.4)
                          : AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _testStatus!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _testSuccess ? AppColors.success : const Color(0xFFFCA5A5),
                    ),
                  ),
                ),

              if (_testStatus != null) const SizedBox(height: 14),

              // Action Buttons: Test Key & Save Key
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testKeys,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(
                        _isTesting ? "যাচাই হচ্ছে..." : "Key পরীক্ষা করুন",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAndProceed,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        widget.isFirstLaunch ? "সংরক্ষণ ও প্রবেশ" : "সংরক্ষণ করুন",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (widget.isFirstLaunch)
                Center(
                  child: TextButton(
                    onPressed: _skipForNow,
                    child: const Text(
                      "এখন কী নেই — পরে সেট করব",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNum,
    required String title,
    required String subtitle,
    Widget? action,
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
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNum,
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
