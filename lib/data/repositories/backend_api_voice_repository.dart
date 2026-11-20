import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import 'ai_voice_repository.dart';

class BackendApiVoiceRepository implements AiVoiceRepository {
  final String endpoint;
  final String? authToken;
  final Dio dio;

  BackendApiVoiceRepository({
    required this.endpoint,
    this.authToken,
    Dio? dioClient,
  }) : dio = dioClient ?? DioClient.createDio(authToken: authToken);

  @override
  Future<String> processVoiceAudio({
    required String audioFilePath,
    required String mode,
    required String deviceId,
    String? customPrompt,
  }) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception("Audio recording file not found on disk at: $audioFilePath");
    }

    final fileName = file.path.split('/').last.split('\\').last;

    // Send audio_file, mode ('sundor', 'formal', 'hubohu', 'english'), and device_id
    final formData = FormData.fromMap({
      'audio_file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
      'mode': mode,
      'device_id': deviceId,
      if (customPrompt != null && customPrompt.isNotEmpty) 'custom_prompt': customPrompt,
    });

    // Synchronize to Laravel backend POST /api/process-voice route
    final String targetUrl;
    final cleanEndpoint = endpoint.trim();
    if (cleanEndpoint.contains('/api/process-voice')) {
      targetUrl = cleanEndpoint;
    } else if (cleanEndpoint.endsWith('/')) {
      targetUrl = '${cleanEndpoint}api/process-voice';
    } else {
      targetUrl = '$cleanEndpoint/api/process-voice';
    }

    try {
      final response = await dio.post(
        targetUrl,
        data: formData,
        options: Options(
          headers: {
            if (authToken != null && authToken!.isNotEmpty) 'Authorization': 'Bearer $authToken',
            'Content-Type': 'multipart/form-data',
          },
          sendTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 40),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('text') && data['text'] != null) {
            return data['text'].toString().trim();
          } else if (data.containsKey('transcription') && data['transcription'] != null) {
            return data['transcription'].toString().trim();
          } else if (data['data'] is Map && data['data']['text'] != null) {
            return data['data']['text'].toString().trim();
          } else if (data['data'] is String) {
            return data['data'].toString().trim();
          }
        }
        return data.toString().trim();
      } else {
        throw Exception("Server returned HTTP ${response.statusCode}: ${response.statusMessage}");
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? "Unknown network error";
      throw Exception("Backend Voice API Error: $message");
    } catch (e) {
      throw Exception("Failed to process voice on backend: $e");
    }
  }
}
