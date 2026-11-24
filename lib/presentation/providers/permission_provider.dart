import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/native/native_bridge.dart';

class PermissionProvider extends ChangeNotifier {
  bool _microphoneGranted = false;
  bool _keyboardEnabled = false;
  bool _keyboardSelected = false;
  bool _overlayGranted = false;
  bool _batteryOptimizationIgnored = false;
  bool _isLoading = false;

  bool get microphoneGranted => _microphoneGranted;
  bool get keyboardEnabled => _keyboardEnabled;
  bool get keyboardSelected => _keyboardSelected;
  bool get keyboardReady => _keyboardEnabled && _keyboardSelected;
  bool get overlayGranted => _overlayGranted;
  bool get batteryOptimizationIgnored => _batteryOptimizationIgnored;
  bool get isLoading => _isLoading;

  /// Main readiness check: Mic permission granted & Talk2Type keyboard enabled
  bool get allGranted => _microphoneGranted && _keyboardEnabled;

  /// Fully configured: Mic + Keyboard Enabled + Keyboard Selected as Default
  bool get isFullyReady => _microphoneGranted && _keyboardEnabled && _keyboardSelected;

  /// Deprecated compatibility getter (accessibility is replaced by keyboard in Phase 13)
  bool get accessibilityGranted => _keyboardEnabled;

  PermissionProvider() {
    checkAllPermissions();
  }

  Future<void> checkAllPermissions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final micStatus = await Permission.microphone.status;
      final nativeMicGranted = await NativeBridge.checkMicrophonePermission();
      _microphoneGranted = micStatus.isGranted || nativeMicGranted;

      _keyboardEnabled = await NativeBridge.checkKeyboardEnabled();
      _keyboardSelected = await NativeBridge.checkKeyboardSelected();
      _overlayGranted = await NativeBridge.checkOverlayPermission();
      _batteryOptimizationIgnored = await NativeBridge.checkBatteryOptimization();
    } catch (e) {
      debugPrint("Error checking permissions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestMicrophone() async {
    try {
      final status = await Permission.microphone.request();
      _microphoneGranted = status.isGranted;
      if (status.isPermanentlyDenied || !_microphoneGranted) {
        await NativeBridge.requestMicrophonePermission();
      }
    } catch (_) {
      await NativeBridge.requestMicrophonePermission();
    }
    await checkAllPermissions();
  }

  Future<void> enableKeyboard() async {
    try {
      await NativeBridge.openKeyboardSettings();
    } catch (e) {
      debugPrint("Error opening keyboard settings: $e");
    }
    await checkAllPermissions();
  }

  Future<void> selectKeyboard() async {
    try {
      await NativeBridge.showInputMethodPicker();
    } catch (e) {
      debugPrint("Error showing input method picker: $e");
    }
    await checkAllPermissions();
  }

  Future<void> requestOverlay() async {
    try {
      await NativeBridge.requestOverlayPermission();
    } catch (e) {
      debugPrint("Error requesting overlay: $e");
    }
    await checkAllPermissions();
  }

  /// Deprecated no-op: Talk2Type Phase 13 uses InputMethodService
  Future<void> requestAccessibility() async {
    await enableKeyboard();
  }

  Future<void> requestBatteryOptimization() async {
    try {
      await NativeBridge.requestBatteryOptimization();
    } catch (e) {
      debugPrint("Error requesting battery optimization: $e");
    }
    await checkAllPermissions();
  }

  Future<void> openAppSettingsFallback() async {
    try {
      await NativeBridge.openAppDetailsSettings();
    } catch (_) {
      await openAppSettings();
    }
    await checkAllPermissions();
  }
}
