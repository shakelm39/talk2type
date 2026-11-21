import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/tone_modes.dart';
import '../../core/database/history_database.dart';
import '../../core/native/native_bridge.dart';
import '../../data/models/transcription_item.dart';
import '../../data/repositories/ai_voice_repository.dart';
import '../../data/repositories/backend_api_voice_repository.dart';
import '../../data/repositories/direct_gemini_voice_repository.dart';

class VoiceFlowProvider extends ChangeNotifier {
  String _activeMode = ToneModes.bangla;
  bool _isServiceRunning = false;
  bool _isProcessing = false;
  String? _lastTranscribedText;
  String? _lastError;
  String _deviceId = '';
  String _lastUsedEngine = "Primary AI";

  String get activeMode => _activeMode;
  bool get isServiceRunning => _isServiceRunning;
  bool get isProcessing => _isProcessing;
  String? get lastTranscribedText => _lastTranscribedText;
  String? get lastError => _lastError;
  String get deviceId => _deviceId;
  String get lastUsedEngine => _lastUsedEngine;

  VoiceFlowProvider() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(AppConfig.keyActiveMode);
    if (savedMode != null && savedMode.isNotEmpty) {
      _activeMode = savedMode;
    }

    _deviceId = await NativeBridge.getDeviceId();
    _isServiceRunning = await NativeBridge.isFloatingServiceRunning();

    // Register audio recorded callback from Android Native overlay
    NativeBridge.registerAudioCallback(handleAudioRecorded);
    NativeBridge.registerTranscriptionCallback(handleTranscriptionCompleted);

    // Sync active mode to native
    await NativeBridge.updateToneMode(_activeMode);

    notifyListeners();
  }

  Future<void> setToneMode(String modeKey) async {
    _activeMode = modeKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.keyActiveMode, modeKey);
    await NativeBridge.updateToneMode(modeKey);
    notifyListeners();
  }

  Future<bool> toggleFloatingService() async {
    if (_isServiceRunning) {
      await NativeBridge.stopFloatingService();
      _isServiceRunning = false;
      notifyListeners();
      return false;
    } else {
      final success = await NativeBridge.startFloatingService();
      _isServiceRunning = success;
      if (success) {
        await NativeBridge.updateToneMode(_activeMode);
      }
      notifyListeners();
      return success;
    }
  }

  Future<void> checkServiceStatus() async {
    _isServiceRunning = await NativeBridge.isFloatingServiceRunning();
    notifyListeners();
  }

  Future<void> handleTranscriptionCompleted(String text, String mode) async {
    _lastTranscribedText = text;
    _lastUsedEngine = "Android Native Speech / Gemini";
    final effectiveMode = mode.isNotEmpty ? mode : _activeMode;
    final item = TranscriptionItem(
      text: text,
      audioPath: '',
      mode: effectiveMode,
      timestamp: DateTime.now(),
      isSuccess: true,
      isDirectTyped: true,
    );
    await HistoryDatabase.instance.insertItem(item);
    notifyListeners();
  }

  /// Called when native Android FloatingOverlay finishes recording an audio file
  Future<void> handleAudioRecorded(String audioPath, String mode) async {
    _isProcessing = true;
    _lastError = null;
    notifyListeners();

    await NativeBridge.setOverlayState('processing');

    try {
      final repository = await _resolveRepository();
      final effectiveMode = mode.isNotEmpty ? mode : _activeMode;
      final customPrompt = await AppConfig.getCustomPrompt(effectiveMode);

      final transcribedText = await repository.processVoiceAudio(
        audioFilePath: audioPath,
        mode: effectiveMode,
        deviceId: _deviceId,
        customPrompt: customPrompt,
      );

      _lastTranscribedText = transcribedText;
      _lastUsedEngine = DirectGeminiVoiceRepository.lastUsedEngine;
      await NativeBridge.setOverlayEngineStatus(_lastUsedEngine);

      // 1. Inject formatted text via AutoTypeAccessibilityService
      final injected = await NativeBridge.injectText(transcribedText);

      // 2. Save entry to history database
      final historyItem = TranscriptionItem(
        text: transcribedText,
        audioPath: audioPath,
        mode: effectiveMode,
        timestamp: DateTime.now(),
        isSuccess: true,
        isDirectTyped: injected,
      );
      await HistoryDatabase.instance.insertItem(historyItem);

      // 3. Mark overlay as success
      await NativeBridge.setOverlayState('success');
    } catch (e) {
      _lastError = e.toString();
      debugPrint("Voice processing error: $e");
      String userMessage = e.toString().replaceAll("Exception: ", "").trim();
      if (userMessage.isEmpty) {
        userMessage = "এআই প্রসেসিং ব্যর্থ হয়েছে। অনুগ্রহ করে ইন্টারনেট ও এআই কি চেক করুন।";
      }
      await NativeBridge.setOverlayError(userMessage);

      // Still save failed event to DB for user review if desired
      final failedItem = TranscriptionItem(
        text: "[Transcription Failed] ${e.toString()}",
        audioPath: audioPath,
        mode: mode,
        timestamp: DateTime.now(),
        isSuccess: false,
        isDirectTyped: false,
      );
      await HistoryDatabase.instance.insertItem(failedItem);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Resolve appropriate repository based on app config & keys
  Future<AiVoiceRepository> _resolveRepository() async {
    final prefs = await SharedPreferences.getInstance();

    if (AppConfig.enableLicenseCheck) {
      final token = prefs.getString(AppConfig.keyLicenseToken) ?? '';
      return BackendApiVoiceRepository(
        endpoint: AppConfig.aiProcessEndpoint,
        authToken: token,
      );
    } else {
      final geminiKey = AppConfig.directGeminiApiKey.isNotEmpty
          ? AppConfig.directGeminiApiKey
          : (prefs.getString(AppConfig.keyGeminiApiKey) ?? '');

      if (geminiKey.isNotEmpty) {
        return DirectGeminiVoiceRepository(apiKey: geminiKey);
      } else {
        // Fallback to Backend repository if direct Gemini key is not configured
        return BackendApiVoiceRepository(
          endpoint: AppConfig.aiProcessEndpoint,
        );
      }
    }
  }

  /// Direct test trigger from within app UI
  Future<String> testTranscription({
    required String audioPath,
    required String mode,
    String? customPrompt,
  }) async {
    _isProcessing = true;
    _lastError = null;
    notifyListeners();

    try {
      final repository = await _resolveRepository();
      final text = await repository.processVoiceAudio(
        audioFilePath: audioPath,
        mode: mode,
        deviceId: _deviceId,
        customPrompt: customPrompt,
      );
      _lastTranscribedText = text;
      _lastUsedEngine = DirectGeminiVoiceRepository.lastUsedEngine;

      // Save to history
      await HistoryDatabase.instance.insertItem(
        TranscriptionItem(
          text: text,
          audioPath: audioPath,
          mode: mode,
          timestamp: DateTime.now(),
          isSuccess: true,
          isDirectTyped: false,
        ),
      );

      return text;
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }
}
