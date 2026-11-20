import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/native/native_bridge.dart';

class PermissionProvider extends ChangeNotifier {
  bool _microphoneGranted = false;
  bool _overlayGranted = false;
  bool _accessibilityGranted = false;
  bool _batteryOptimizationIgnored = false;
  bool _isLoading = false;

  bool get microphoneGranted => _microphoneGranted;
  bool get overlayGranted => _overlayGranted;
  bool get accessibilityGranted => _accessibilityGranted;
  bool get batteryOptimizationIgnored => _batteryOptimizationIgnored;
  bool get isLoading => _isLoading;

  bool get allGranted => _microphoneGranted && _overlayGranted && _accessibilityGranted;

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

      _overlayGranted = await NativeBridge.checkOverlayPermission();
      _accessibilityGranted = await NativeBridge.checkAccessibilityPermission();
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

  Future<void> requestOverlay() async {
    try {
      await NativeBridge.requestOverlayPermission();
    } catch (e) {
      debugPrint("Error requesting overlay: $e");
    }
    await checkAllPermissions();
  }

  Future<void> requestAccessibility() async {
    try {
      await NativeBridge.requestAccessibilityPermission();
    } catch (e) {
      debugPrint("Error requesting accessibility: $e");
    }
    await checkAllPermissions();
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
