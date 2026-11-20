abstract class AiVoiceRepository {
  /// Processes recorded voice audio file and returns formatted transcription text.
  Future<String> processVoiceAudio({
    required String audioFilePath,
    required String mode,
    required String deviceId,
    String? customPrompt,
  });
}
