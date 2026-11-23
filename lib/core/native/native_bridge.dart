import 'package:flutter/services.dart';

typedef OnAudioRecordedCallback = Future<void> Function(String audioPath, String mode);
typedef OnTranscriptionCompletedCallback = Future<void> Function(String text, String mode);
typedef OnNavigateRouteCallback = void Function(String route);
typedef OnAudioSharedCallback = void Function(String audioPath);

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.voiceflow.ai/native_bridge');

  static OnAudioRecordedCallback? _audioRecordedCallback;
  static OnTranscriptionCompletedCallback? _transcriptionCompletedCallback;
  static OnNavigateRouteCallback? _navigateRouteCallback;
  static OnAudioSharedCallback? _audioSharedCallback;

  /// Initialize listener for native events
  static void initialize({
    OnAudioRecordedCallback? onAudioRecorded,
    OnTranscriptionCompletedCallback? onTranscriptionCompleted,
    OnNavigateRouteCallback? onNavigateRoute,
  }) {
    _audioRecordedCallback = onAudioRecorded;
    _transcriptionCompletedCallback = onTranscriptionCompleted;
    _navigateRouteCallback = onNavigateRoute;
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static void registerAudioCallback(OnAudioRecordedCallback callback) {
    _audioRecordedCallback = callback;
  }

  static void registerTranscriptionCallback(OnTranscriptionCompletedCallback callback) {
    _transcriptionCompletedCallback = callback;
  }

  static void registerRouteCallback(OnNavigateRouteCallback callback) {
    _navigateRouteCallback = callback;
  }

  static void registerAudioSharedCallback(OnAudioSharedCallback callback) {
    _audioSharedCallback = callback;
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioRecorded':
        final String? path = call.arguments['path'] as String?;
        final String mode = (call.arguments['mode'] as String?) ?? 'sundor';
        if (path != null && _audioRecordedCallback != null) {
          await _audioRecordedCallback!(path, mode);
        }
        return true;
      case 'onTranscriptionCompleted':
        final String? text = call.arguments['text'] as String?;
        final String mode = (call.arguments['mode'] as String?) ?? 'sundor';
        if (text != null && _transcriptionCompletedCallback != null) {
          await _transcriptionCompletedCallback!(text, mode);
        }
        return true;
      case 'onNavigateRoute':
        final String? route = call.arguments['route'] as String?;
        if (route != null && _navigateRouteCallback != null) {
          _navigateRouteCallback!(route);
        }
        return true;
      case 'onAudioShared':
        final String? path = call.arguments['path'] as String?;
        if (path != null && _audioSharedCallback != null) {
          _audioSharedCallback!(path);
        }
        return true;
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  /// Retrieve initial shared audio path (cold start from share target)
  static Future<String?> getInitialSharedAudio() async {
    try {
      final String? path = await _channel.invokeMethod<String>('getInitialSharedAudio');
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Open system share sheet for text
  static Future<void> shareText(String text) async {
    try {
      await _channel.invokeMethod('shareText', {'text': text});
    } catch (_) {}
  }

  /// Open system share sheet for a file via FileProvider
  static Future<bool> shareFile(String path, {String mimeType = 'text/plain'}) async {
    try {
      final res = await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check whether microphone permission is granted via native bridge
  static Future<bool> checkMicrophonePermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkMicrophonePermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request microphone permission / open app settings via native bridge
  static Future<void> requestMicrophonePermission() async {
    try {
      await _channel.invokeMethod('requestMicrophonePermission');
    } catch (_) {}
  }

  /// Check whether overlay permission (Settings.canDrawOverlays) is granted
  static Future<bool> checkOverlayPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android Overlay Permission settings intent
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// Check whether AutoTypeAccessibilityService is enabled
  static Future<bool> checkAccessibilityPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkAccessibilityPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android Accessibility Settings intent
  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (_) {}
  }

  /// Start in-app voice recording via native AudioRecorderHelper
  static Future<String?> startInlineRecording() async {
    try {
      return await _channel.invokeMethod<String>('startInlineRecording');
    } catch (_) {
      return null;
    }
  }

  /// Stop in-app voice recording and return saved .m4a audio file path
  static Future<String?> stopInlineRecording() async {
    try {
      return await _channel.invokeMethod<String>('stopInlineRecording');
    } catch (_) {
      return null;
    }
  }

  /// Start in-app single recording comparison session (Native SpeechRecognizer + AudioRecorder)
  static Future<String?> startComparisonRecording() async {
    try {
      return await _channel.invokeMethod<String>('startComparisonRecording');
    } catch (_) {
      return null;
    }
  }

  /// Stop comparison session and retrieve audio file path and native SpeechRecognizer text
  static Future<Map<String, String>?> stopComparisonRecording() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('stopComparisonRecording');
      if (res != null) {
        return {
          'audioPath': (res['audioPath'] as String?) ?? '',
          'nativeText': (res['nativeText'] as String?) ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  /// Start standalone Native SpeechRecognizer test (for sequential capture)
  static Future<bool> startNativeSpeechTest() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('startNativeSpeechTest');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stop standalone Native SpeechRecognizer test and return recognized text
  static Future<String?> stopNativeSpeechTest() async {
    try {
      return await _channel.invokeMethod<String>('stopNativeSpeechTest');
    } catch (_) {
      return null;
    }
  }

  /// Start the Floating Overlay background service
  static Future<bool> startOverlayService() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('startOverlayService');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startFloatingService() => startOverlayService();

  /// Stop the Floating Overlay service
  static Future<void> stopOverlayService() async {
    try {
      await _channel.invokeMethod('stopOverlayService');
    } catch (_) {}
  }

  static Future<void> stopFloatingService() => stopOverlayService();

  /// Check if the Floating Overlay service is currently running
  static Future<bool> isFloatingServiceRunning() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isFloatingServiceRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Inject formatted text directly into the focused field via AccessibilityService
  static Future<bool> injectText(String text) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('injectText', {'text': text});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Test text injection into active input field (alias for testing from Flutter)
  static Future<bool> testTextInjection(String text) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('testTextInjection', {'text': text});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Set active tone mode on native floating overlay
  static Future<void> setActiveMode(String mode) async {
    try {
      await _channel.invokeMethod('setActiveMode', {'mode': mode});
    } catch (_) {}
  }

  static Future<void> updateToneMode(String mode) => setActiveMode(mode);

  /// Update native overlay state: "idle", "recording", "processing", "success", "error"
  static Future<void> setOverlayState(String state) async {
    try {
      await _channel.invokeMethod('setOverlayState', {'state': state});
    } catch (_) {}
  }

  /// Inform native floating overlay about the active AI engine (e.g. Primary vs Auto-Switched)
  static Future<void> setOverlayEngineStatus(String engineName) async {
    try {
      await _channel.invokeMethod('setOverlayEngineStatus', {'engine': engineName});
    } catch (_) {}
  }

  /// Show an error toast from the native overlay and reset its state
  static Future<void> setOverlayError(String message) async {
    try {
      await _channel.invokeMethod('setOverlayError', {'message': message});
    } catch (_) {}
  }

  /// Check whether battery optimization is ignored for this app (background stability)
  static Future<bool> checkBatteryOptimization() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkBatteryOptimization');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Request user to whitelist app from battery saver
  static Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimization');
    } catch (_) {}
  }

  /// Open App Details Settings screen (Oppo/Vivo/Xiaomi deep-link fallback)
  static Future<void> openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod('openAppDetailsSettings');
    } catch (_) {}
  }

  /// Update floating orb size and transparency dynamically
  static Future<void> updateOrbAppearance({int sizeDp = 58, double opacity = 1.0}) async {
    try {
      await _channel.invokeMethod('updateOrbAppearance', {
        'sizeDp': sizeDp,
        'opacity': opacity,
      });
    } catch (_) {}
  }

  /// Get unique Android device hardware identifier
  static Future<String> getDeviceId() async {
    try {
      final String? id = await _channel.invokeMethod<String>('getDeviceId');
      return id ?? 'DEVICE_UNKNOWN';
    } catch (_) {
      return 'DEVICE_FALLBACK';
    }
  }

  /// Get current running Android App Version (versionName)
  static Future<String> getAppVersion() async {
    try {
      final String? version = await _channel.invokeMethod<String>('getAppVersion');
      return version ?? '1.0.1';
    } catch (_) {
      return '1.0.1';
    }
  }

  /// Install downloaded APK using Android Package Installer via FileProvider
  static Future<bool> installApk(String filePath) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Verify whether the downloaded APK signature matches the installed application
  static Future<bool> verifyApkSignature(String filePath) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('verifyApkSignature', {'filePath': filePath});
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Check whether app has permission to install unknown apps (API 26+)
  static Future<bool> canInstallUnknownApps() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('canInstallUnknownApps');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Open Android Settings for unknown app sources
  static Future<void> openUnknownAppSourcesSettings() async {
    try {
      await _channel.invokeMethod('openUnknownAppSourcesSettings');
    } catch (_) {}
  }

  /// Notify native overlay about Pro status change
  static Future<void> updateProStatus(bool isPro) async {
    try {
      await _channel.invokeMethod('updateProStatus', {'isPro': isPro});
    } catch (_) {}
  }

  /// Open external URL in system web browser
  static Future<bool> openBrowserUrl(String url) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openBrowserUrl', {'url': url});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
