import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/history_database.dart';
import '../../core/native/native_bridge.dart';
import '../../core/services/gemini_model_service.dart';
import '../../data/models/transcription_item.dart';
import 'api_key_setup_screen.dart';
import 'upgrade_screen.dart';

class VoiceNoteTranscribeScreen extends StatefulWidget {
  final String audioPath;

  const VoiceNoteTranscribeScreen({
    super.key,
    required this.audioPath,
  });

  @override
  State<VoiceNoteTranscribeScreen> createState() => _VoiceNoteTranscribeScreenState();
}

class _VoiceNoteTranscribeScreenState extends State<VoiceNoteTranscribeScreen> {
  final TextEditingController _resultController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedMode = 'bangla'; // 'bangla' or 'english'
  bool _hasSavedToHistory = false;
  int _fileSizeBytes = 0;
  String _fileName = '';

  @override
  void initState() {
    super.initState();
    _inspectFile();
    if (AppConfig.isPro && AppConfig.hasAnyAiKey && _fileSizeBytes <= 20 * 1024 * 1024) {
      _startTranscription();
    }
  }

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  void _inspectFile() {
    try {
      final file = File(widget.audioPath);
      if (file.existsSync()) {
        _fileSizeBytes = file.lengthSync();
        _fileName = file.uri.pathSegments.last;
      } else {
        _errorMessage = "অডিও ফাইলটি খুঁজে পাওয়া যায়নি";
      }
    } catch (e) {
      _errorMessage = "ফাইল পড়তে সমস্যা হয়েছে: $e";
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.opus')) return 'audio/opus';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mp3';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/m4a';
    return 'audio/ogg';
  }

  Future<void> _startTranscription() async {
    if (!AppConfig.isPro) {
      setState(() {
        _errorMessage = "ভয়েস নোট ট্রান্সক্রিপশন একটি Pro ফিচার। অনুগ্রহ করে Pro আনলক করুন।";
      });
      return;
    }

    if (!AppConfig.hasAnyAiKey) {
      setState(() {
        _errorMessage = "Gemini API key নেই। অনুগ্রহ করে এআই কি সেট করুন।";
      });
      return;
    }

    final file = File(widget.audioPath);
    if (!file.existsSync()) {
      setState(() {
        _errorMessage = "অডিও ফাইল পাওয়া যায়নি";
      });
      return;
    }

    if (file.lengthSync() > 20 * 1024 * 1024) {
      setState(() {
        _errorMessage = "ফাইলের আকার অনেক বড় (সর্বোচ্চ ১৫ মেগাবাইট পর্যন্ত অনুমোদিত)।";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);
      final mimeType = _getMimeType(widget.audioPath);

      final prompt = _selectedMode == 'english'
          ? "Listen to this audio recording carefully and translate the speech accurately into natural, fluent English. Output ONLY the English translation without quotes, greetings, or extra commentary."
          : "Listen to this audio recording carefully and transcribe the speech into clean, grammatically correct Bengali text. Include proper Bengali punctuation (দাঁড়ি, কমা, প্রশ্নবোধক চিহ্ন, ইত্যাদি)। Output ONLY the Bengali transcription without quotes, greetings, or extra commentary.";

      final keysToTry = <String>[];
      final primary = AppConfig.primaryGeminiApiKey.isNotEmpty
          ? AppConfig.primaryGeminiApiKey
          : AppConfig.directGeminiApiKey;
      if (AppConfig.isValidKey(primary)) keysToTry.add(primary);
      if (AppConfig.isValidKey(AppConfig.backupGeminiApiKey) &&
          AppConfig.backupGeminiApiKey != primary) {
        keysToTry.add(AppConfig.backupGeminiApiKey);
      }

      String? transcribedText;
      final models = await GeminiModelService.instance.getActiveModels();
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 40),
      ));

      for (final key in keysToTry) {
        for (final model in models) {
          try {
            final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
            final body = {
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                    {
                      'inlineData': {
                        'mimeType': mimeType,
                        'data': base64Audio,
                      }
                    }
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.2,
                'maxOutputTokens': 2048,
              }
            };

            final response = await dio.post(
              url,
              data: body,
              options: Options(headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': key.trim(),
              }),
            );

            if (response.statusCode == 200 && response.data != null) {
              final candidates = response.data['candidates'] as List?;
              if (candidates != null && candidates.isNotEmpty) {
                final content = candidates[0]['content'];
                final parts = content?['parts'] as List?;
                if (parts != null && parts.isNotEmpty) {
                  final text = parts[0]['text']?.toString().trim();
                  if (text != null && text.isNotEmpty) {
                    transcribedText = text;
                    break;
                  }
                }
              }
            }
          } on DioException catch (e) {
            if (e.response?.statusCode == 404) {
              await GeminiModelService.instance.markModelUnavailable(model);
            }
            // Try next model or next key
          } catch (_) {
            // Try next model or next key
          }
        }
        if (transcribedText != null) break;
      }

      if (transcribedText != null && transcribedText.isNotEmpty) {
        _resultController.text = transcribedText;
        _saveToHistory(transcribedText);
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "অডিও ট্রান্সক্রাইব করা সম্ভব হয়নি। ইন্টারনেট সংযোগ বা API Key পরীক্ষা করুন।";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "ভুল হয়েছে: $e";
      });
    }
  }

  Future<void> _saveToHistory(String text) async {
    try {
      await HistoryDatabase.instance.insertItem(
        TranscriptionItem(
          text: text,
          audioPath: widget.audioPath,
          mode: 'voice_note',
          timestamp: DateTime.now(),
          isSuccess: true,
          isDirectTyped: false,
        ),
      );
      if (mounted) {
        setState(() => _hasSavedToHistory = true);
      }
    } catch (_) {}
  }

  void _copyResult() {
    if (_resultController.text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: _resultController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ক্লিপবোর্ডে কপি করা হয়েছে!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareResult() {
    if (_resultController.text.trim().isEmpty) return;
    NativeBridge.shareText(_resultController.text);
  }

  @override
  Widget build(BuildContext context) {
    final isPro = AppConfig.isPro;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "ভয়েস নোট ট্রান্সক্রিপশন",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Audio File Metadata Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.audiotrack_rounded, color: Color(0xFF818CF8), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName.isNotEmpty ? _fileName : "শেয়ার করা ভয়েস রেকর্ড",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "সাইজ: ${_formatFileSize(_fileSizeBytes)} • হোয়াটসঅ্যাপ / মেসেঞ্জার নোট",
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Pro Feature Locked Banner (if not pro)
            if (!isPro) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Color(0xFFF43F5E), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "ভয়েস নোট ট্রান্সক্রিপশন শুধুমাত্র Pro ফিচারে উপলব্ধ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "যেকোনো অ্যাপ থেকে পাঠানো অডিও বা ভয়েস নোট মুহূর্তেই বাংলায় বা ইংরেজিতে টেক্সট রূপান্তর করতে Pro আনলক করুন।",
                      style: TextStyle(fontSize: 12, color: Color(0xFFFDA4AF)),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                        );
                      },
                      icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                      label: const Text("লাইফটাইম Pro আনলক করুন"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. API Key Missing Banner
            if (isPro && !AppConfig.hasAnyAiKey) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: AppColors.warning),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Gemini API key প্রয়োজন",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ApiKeySetupScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text("Key দিন"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Mode Selection (বাংলা vs English অনুবাদ)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() => _selectedMode = 'bangla');
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedMode == 'bangla'
                            ? const Color(0xFFC81E2E).withValues(alpha: 0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedMode == 'bangla'
                              ? const Color(0xFFC81E2E)
                              : AppColors.surfaceLight,
                          width: _selectedMode == 'bangla' ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "বাংলা টেক্সট 🇧🇩",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _selectedMode == 'bangla' ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() => _selectedMode = 'english');
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedMode == 'english'
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedMode == 'english'
                              ? const Color(0xFF3B82F6)
                              : AppColors.surfaceLight,
                          width: _selectedMode == 'english' ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "English অনুবাদ 🌐",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _selectedMode == 'english' ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 5. Loading Progress or Error Message
            if (_isLoading) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      "Gemini AI দিয়ে ভয়েস নোট রূপান্তর করা হচ্ছে...",
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "অডিও সাইজের ওপর ভিত্তি করে কয়েক সেকেন্ড সময় লাগতে পারে।",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFFCA5A5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 6. Result Text Area
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "ট্রান্সক্রাইবকৃত টেক্সট",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_hasSavedToHistory)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, color: AppColors.success, size: 12),
                              SizedBox(width: 4),
                              Text(
                                "হিস্টোরিতে সংরক্ষিত",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _resultController,
                    maxLines: 8,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: "অডিও ট্রান্সক্রিপশন এখানে দেখা যাবে...",
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 7. Action Buttons (কপি / শেয়ার / পুনঃচেষ্টা)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyResult,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text("কপি"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareResult,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text("শেয়ার"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!_isLoading && isPro && AppConfig.hasAnyAiKey)
              OutlinedButton.icon(
                onPressed: _startTranscription,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("আবার ট্রান্সক্রাইব করুন"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.surfaceLight),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
