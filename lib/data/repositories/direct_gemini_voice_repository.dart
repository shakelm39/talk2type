import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/tone_modes.dart';
import '../../core/network/dio_client.dart';
import 'ai_voice_repository.dart';

class DirectGeminiVoiceRepository implements AiVoiceRepository {
  final String apiKey;
  final Dio dio;

  /// Holds the identifier of the engine that successfully processed the last request
  static String lastUsedEngine = "Primary AI (Gemini 1.5 Flash)";

  DirectGeminiVoiceRepository({
    required this.apiKey,
    Dio? dioClient,
  }) : dio = dioClient ?? DioClient.createDio();

  @override
  Future<String> processVoiceAudio({
    required String audioFilePath,
    required String mode,
    required String deviceId,
    String? customPrompt,
  }) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception("Audio file not found at: $audioFilePath");
    }

    final audioBytes = await file.readAsBytes();
    if (audioBytes.isEmpty) {
      throw Exception("Audio recording is empty (0 bytes). Please speak louder into the microphone.");
    }

    final base64Audio = base64Encode(audioBytes);

    // Prepare mode system prompt and custom vocabulary
    final modeInfo = ToneModes.getByKey(mode);
    final vocabInstruction = AppConfig.customVocabulary.isNotEmpty
        ? "\nPay special attention to accurately recognize and preserve these specific terms/brand names if spoken: ${AppConfig.customVocabulary.join(', ')}."
        : "";

    final systemPrompt = ((customPrompt != null && customPrompt.isNotEmpty)
            ? customPrompt
            : modeInfo.defaultSystemPrompt) +
        vocabInstruction;

    final ext = audioFilePath.split('.').last.toLowerCase();
    final mimeType = (ext == 'm4a' || ext == 'mp4') ? 'audio/mp4' : 'audio/aac';

    final requestBody = {
      "systemInstruction": {
        "parts": [
          {"text": systemPrompt}
        ]
      },
      "contents": [
        {
          "parts": [
            {
              "inlineData": {
                "mimeType": mimeType,
                "data": base64Audio,
              }
            },
            {
              "text": "Transcribe the audio speech accurately according to your instructions. Output ONLY the transcription text without commentary."
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.2,
        "maxOutputTokens": 2048,
      }
    };

    final effectivePrimaryKey = AppConfig.isValidKey(AppConfig.primaryGeminiApiKey)
        ? AppConfig.primaryGeminiApiKey.trim()
        : (AppConfig.isValidKey(apiKey) ? apiKey.trim() : "");

    final effectiveBackupKey = AppConfig.isValidKey(AppConfig.backupGeminiApiKey)
        ? AppConfig.backupGeminiApiKey.trim()
        : "";

    final groqKey = AppConfig.isValidKey(AppConfig.backupGroqApiKey)
        ? AppConfig.backupGroqApiKey.trim()
        : "";

    // Check if any key is available
    if (effectivePrimaryKey.isEmpty && effectiveBackupKey.isEmpty && groqKey.isEmpty) {
      throw Exception(
        "এআই ব্যবহারের জন্য সেটিংসে আপনার Gemini API key দিন",
      );
    }

    String? lastError;

    // =========================================================================
    // TIER 1: Model 1 (Primary Google Gemini: 2.5 Flash / 1.5 Flash / 2.0 Flash)
    // =========================================================================
    if (effectivePrimaryKey.isNotEmpty) {
      final tier1Models = [
        'gemini-2.5-flash',
        'gemini-1.5-flash',
        'gemini-2.0-flash',
        'gemini-1.5-flash-8b',
      ];

      for (final model in tier1Models) {
        try {
          final result = await _callGeminiModel(
            model: model,
            apiKey: effectivePrimaryKey,
            requestBody: requestBody,
          );
          if (result != null && result.isNotEmpty) {
            lastUsedEngine = "Primary AI ($model)";
            debugPrint("[Fallback Pipeline] Successfully processed via $lastUsedEngine");
            return result;
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint("[Fallback Pipeline] Model 1 ($model) failed: $e. Checking next fallback...");
          continue;
        }
      }
    }

    // =========================================================================
    // TIER 2: Model 2 (Backup Gemini Key or Fast 8B Model)
    // =========================================================================
    debugPrint("[Fallback Pipeline] Switching to Backup AI Model (Tier 2: Gemini Lite)...");

    if (effectiveBackupKey.isNotEmpty && effectiveBackupKey != effectivePrimaryKey) {
      final tier2Models = [
        'gemini-1.5-flash-8b',
        'gemini-1.5-flash',
      ];

      for (final model in tier2Models) {
        try {
          final result = await _callGeminiModel(
            model: model,
            apiKey: effectiveBackupKey,
            requestBody: requestBody,
          );
          if (result != null && result.isNotEmpty) {
            lastUsedEngine = "Backup AI ($model - Auto-Switched)";
            debugPrint("[Fallback Pipeline] Successfully processed via $lastUsedEngine");
            return result;
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint("[Fallback Pipeline] Model 2 ($model) failed: $e. Checking Tier 3...");
          continue;
        }
      }
    }

    // =========================================================================
    // TIER 3: Model 3 (Groq Whisper-large-v3-turbo + LLaMA-3.3-70b-versatile)
    // =========================================================================
    if (groqKey.isNotEmpty) {
      debugPrint("[Fallback Pipeline] Switching to Tier 3 Backup (Groq Whisper + LLaMA)...");
      try {
        final groqResult = await _callGroqWhisperAndLlama(
          audioFile: file,
          groqApiKey: groqKey,
          mode: mode,
          systemPrompt: systemPrompt,
        );
        if (groqResult.isNotEmpty) {
          lastUsedEngine = "Groq Turbo (Whisper + LLaMA - Auto-Switched)";
          debugPrint("[Fallback Pipeline] Successfully processed via $lastUsedEngine");
          return groqResult;
        }
      } catch (e) {
        lastError = "Groq Fallback Error: $e";
        debugPrint("[Fallback Pipeline] Tier 3 Groq failed: $e");
      }
    }

    throw Exception(
      "All AI Engines in the fallback chain were exhausted. Last error: ${lastError ?? 'Unknown error'}",
    );
  }

  /// Helper to call a specific Google Gemini model with fast timeout
  Future<String?> _callGeminiModel({
    required String model,
    required String apiKey,
    required Map<String, dynamic> requestBody,
  }) async {
    final url =
        "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent";

    final response = await dio.post(
      url,
      data: requestBody,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              return text.trim();
            }
          }
        }
      }
    }

    throw Exception("HTTP ${response.statusCode}: ${response.statusMessage}");
  }

  /// Helper for Tier 3: Groq Whisper-large-v3-turbo + LLaMA-3.3-70b-versatile
  Future<String> _callGroqWhisperAndLlama({
    required File audioFile,
    required String groqApiKey,
    required String mode,
    required String systemPrompt,
  }) async {
    // Step 1: Transcribe using Groq Whisper-large-v3-turbo
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFile.path,
        filename: 'speech.m4a',
      ),
      'model': 'whisper-large-v3-turbo',
      'response_format': 'json',
      'language': (mode == ToneModes.english) ? 'bn' : 'bn',
    });

    final whisperResponse = await dio.post(
      'https://api.groq.com/openai/v1/audio/transcriptions',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $groqApiKey',
        },
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    String rawTranscript = "";
    if (whisperResponse.statusCode == 200 && whisperResponse.data != null) {
      rawTranscript = (whisperResponse.data['text'] as String?)?.trim() ?? "";
    }

    if (rawTranscript.isEmpty) {
      throw Exception("Groq Whisper produced an empty transcription.");
    }

    // Step 2: Post-process and refine using LLaMA-3.3-70b-versatile
    final llamaResponse = await dio.post(
      'https://api.groq.com/openai/v1/chat/completions',
      data: {
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content':
                'Refine and format this raw transcribed text strictly according to your system prompt:\n\n"$rawTranscript"',
          }
        ],
        'temperature': 0.2,
        'max_tokens': 1024,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    if (llamaResponse.statusCode == 200 && llamaResponse.data != null) {
      final choices = llamaResponse.data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'];
        final content = message?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          return content.trim();
        }
      }
    }

    return rawTranscript;
  }
}
