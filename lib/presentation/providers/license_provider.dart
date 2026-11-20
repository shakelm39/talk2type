import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/services/license_service.dart';

class LicenseProvider extends ChangeNotifier {
  bool _isChecking = true;
  bool _isActivated = false;
  String? _licenseToken;
  String? _savedLicenseKey;
  String? _planName;
  String? _expiresAt;
  String _deviceId = '';
  String? _errorMessage;

  bool get isChecking => _isChecking;
  bool get isActivated => _isActivated;
  String? get licenseToken => _licenseToken;
  String? get savedLicenseKey => _savedLicenseKey;
  String? get planName => _planName;
  String? get expiresAt => _expiresAt;
  String get deviceId => _deviceId;
  String? get errorMessage => _errorMessage;

  LicenseProvider() {
    initLicenseState();
  }

  Future<void> initLicenseState() async {
    _isChecking = true;
    notifyListeners();

    try {
      _deviceId = await LicenseService.instance.getDeviceId();
      final prefs = await SharedPreferences.getInstance();
      _licenseToken = prefs.getString(AppConfig.keyLicenseToken);
      _savedLicenseKey = prefs.getString(AppConfig.keyLicenseKey);
      _planName = prefs.getString(AppConfig.keyPlanName);
      _expiresAt = prefs.getString(AppConfig.keyExpiresAt);

      _isActivated = await LicenseService.instance.isLicenseValid();
    } catch (e) {
      _errorMessage = "Failed to initialize license: $e";
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<bool> activateLicense(String licenseKey, {String? customAppId}) async {
    final cleanKey = licenseKey.trim();
    if (cleanKey.isEmpty) {
      _errorMessage = "অনুগ্রহ করে লাইসেন্স কী দিন।";
      notifyListeners();
      return false;
    }

    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await LicenseService.instance.activateLicense(cleanKey, customAppId: customAppId);

      if (result.success && result.token != null) {
        _licenseToken = result.token;
        _savedLicenseKey = cleanKey;
        _planName = result.planName;
        _expiresAt = result.expiresAt;
        _isActivated = true;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message ?? "লাইসেন্স অ্যাক্টিভেশন ব্যর্থ হয়েছে।";
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "সক্রিয়করণ ত্রুটি: $e";
      notifyListeners();
      return false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> logoutLicense() async {
    await LicenseService.instance.clearLicense();
    _licenseToken = null;
    _savedLicenseKey = null;
    _planName = null;
    _expiresAt = null;
    _isActivated = !AppConfig.enableLicenseCheck;
    notifyListeners();
  }
}
