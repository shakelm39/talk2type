import 'package:shared_preferences/shared_preferences.dart';
import '../native/native_bridge.dart';

class AppConfig {
  /// License check toggle.
  /// Connected with Ayyzan License Hub (license.ayyzan.com)
  static bool enableLicenseCheck = true;

  /// Default API endpoints
  static String licenseApiEndpoint = "https://license.ayyzan.com";
  static String licenseAppId = "talk2type";
  static String aiProcessEndpoint = "https://license.ayyzan.com";

  /// Direct Gemini API Key (Default / Fallback)
  static String directGeminiApiKey = "";

  /// Multi-Model Fallback Chain API Keys
  static String primaryGeminiApiKey = "";
  static String backupGeminiApiKey = "";
  static String backupGroqApiKey = "";

  /// Free Online Engine Toggle (for users without key: pollinations / gtx)
  static bool freeOnlineEngine = true;

  /// Custom Vocabulary for specialized brand names, local words & jargon
  static List<String> customVocabulary = ["বিকাশ", "নগদ", "রকেট", "পাঠাও", "চালডাল"];

  /// Floating Orb Appearance Settings
  static int orbSize = 58; // 46 (Small), 58 (Medium), 68 (Large)
  static double orbOpacity = 1.0; // 0.4 to 1.0

  /// Pro Tier vs Free Tier state
  static bool isPro = false;
  static int dailyCount = 0;
  static String dailyDate = "";
  static String lastVerifiedAt = "";
  static bool userChoseFree = false;
  static bool keySetupSkipped = false;
  static String purchaseUrl = "https://license.ayyzan.com";
  static String priceText = "৳৩৯৯ লাইফটাইম";
  static String supportWhatsapp = "01829110203";

  // Voice Engine settings
  static const String engineLive = "live";
  static const String engineAi = "ai";
  static String voiceEngine = engineLive;
  static bool autoLanguage = true;

  // Privacy Policy URL (Hub constant)
  static const String privacyPolicyUrl = "https://license.ayyzan.com/privacy/talk2type";

  // Telemetry & Usage Statistics
  static bool sendUsageStats = true;

  // Floating Mic (Optional, default OFF)
  static bool floatingMicEnabled = false;

  // Keys for SharedPreferences
  static const String keyLicenseToken = "vf_license_token";
  static const String keyLicenseKey = "vf_license_key";
  static const String keyDeviceId = "vf_device_id";
  static const String keyPlanName = "vf_plan_name";
  static const String keyExpiresAt = "vf_expires_at";
  static const String keyActiveMode = "vf_active_mode";
  static const String keyGeminiApiKey = "vf_gemini_api_key";
  static const String keyPrimaryGeminiApiKey = "vf_primary_gemini_api_key";
  static const String keyBackupGeminiApiKey = "vf_backup_gemini_api_key";
  static const String keyBackupGroqApiKey = "vf_backup_groq_api_key";
  static const String keyFreeOnlineEngine = "vf_free_online_engine";
  static const String keyIsPro = "vf_is_pro";
  static const String keyDailyCount = "vf_daily_count";
  static const String keyDailyDate = "vf_daily_date";
  static const String keyLastVerifiedAt = "vf_last_verified_at";
  static const String keyUserChoseFree = "vf_user_chose_free";
  static const String keyKeySetupSkipped = "vf_key_setup_skipped";
  static const String keyPurchaseUrl = "vf_purchase_url";
  static const String keyPriceText = "vf_price_text";
  static const String keySupportWhatsapp = "vf_support_whatsapp";
  static const String keyAiEndpoint = "vf_ai_endpoint";
  static const String keyLicenseEndpoint = "vf_license_endpoint";
  static const String keyLicenseAppId = "vf_license_app_id";
  static const String keyCustomPromptPrefix = "vf_custom_prompt_";
  static const String keyCustomVocabulary = "vf_custom_vocabulary";
  static const String keyOrbSize = "vf_orb_size";
  static const String keyOrbOpacity = "vf_orb_opacity";
  static const String keyUpdateSnoozeUntil = "vf_update_snooze_until";
  static const String keyUpdateSkippedVersion = "vf_update_skipped_version";
  static const String keyVoiceEngine = "vf_voice_engine";
  static const String keyAutoLanguage = "vf_auto_language";
  static const String keyInstallHash = "vf_install_hash";
  static const String keyLastPingAt = "vf_last_ping_at";
  static const String keySendUsageStats = "vf_send_usage_stats";
  static const String keyFloatingMicEnabled = "vf_floating_mic_enabled";

  /// Helper to check if a key string is valid (non-empty and not dummy placeholder)
  static bool isValidKey(String? k) {
    if (k == null) return false;
    final trimmed = k.trim();
    return trimmed.isNotEmpty && trimmed != "YOUR_TEST_GEMINI_KEY";
  }

  /// Whether user has configured any valid AI key
  static bool get hasAnyAiKey =>
      isValidKey(primaryGeminiApiKey) ||
      isValidKey(directGeminiApiKey) ||
      isValidKey(backupGeminiApiKey) ||
      isValidKey(backupGroqApiKey);

  /// Whether user has configured any valid Gemini API key
  static bool get hasGeminiKey =>
      isValidKey(primaryGeminiApiKey) ||
      isValidKey(directGeminiApiKey) ||
      isValidKey(backupGeminiApiKey);

  /// Whether current voice engine is set to AI (Pro only)
  static bool get isAiEngine => isPro && voiceEngine == engineAi;

  /// Helper to safely mask keys for UI or logging (shows last 4 characters only)
  static String maskKey(String? key) {
    if (key == null || key.trim().isEmpty) return "";
    final trimmed = key.trim();
    if (trimmed.length <= 4) return "••••";
    return "••••••••${trimmed.substring(trimmed.length - 4)}";
  }

  /// Initialize and load saved runtime configurations
  static Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    final savedGeminiKey = prefs.getString(keyGeminiApiKey);
    if (isValidKey(savedGeminiKey)) {
      directGeminiApiKey = savedGeminiKey!;
      primaryGeminiApiKey = savedGeminiKey;
    } else {
      directGeminiApiKey = "";
    }

    final savedPrimary = prefs.getString(keyPrimaryGeminiApiKey);
    if (isValidKey(savedPrimary)) {
      primaryGeminiApiKey = savedPrimary!;
      directGeminiApiKey = savedPrimary;
    } else if (isValidKey(directGeminiApiKey)) {
      primaryGeminiApiKey = directGeminiApiKey;
    } else {
      primaryGeminiApiKey = "";
    }

    final savedBackupGemini = prefs.getString(keyBackupGeminiApiKey);
    if (isValidKey(savedBackupGemini)) {
      backupGeminiApiKey = savedBackupGemini!;
    } else {
      backupGeminiApiKey = "";
    }

    final savedGroq = prefs.getString(keyBackupGroqApiKey);
    if (isValidKey(savedGroq)) {
      backupGroqApiKey = savedGroq!;
    } else {
      backupGroqApiKey = "";
    }

    freeOnlineEngine = prefs.getBool(keyFreeOnlineEngine) ?? true;

    final token = prefs.getString(keyLicenseToken);
    final hasActiveToken = token != null && token.trim().isNotEmpty;
    // Migration: if token exists but keyIsPro wasn't saved, mark as Pro
    if (hasActiveToken && !prefs.containsKey(keyIsPro)) {
      await prefs.setBool(keyIsPro, true);
      isPro = true;
    } else {
      isPro = prefs.getBool(keyIsPro) ?? hasActiveToken;
    }

    dailyDate = prefs.getString(keyDailyDate) ?? "";
    final rawCount = prefs.get(keyDailyCount);
    if (rawCount is int) {
      dailyCount = rawCount;
    } else if (rawCount is num) {
      dailyCount = rawCount.toInt();
    } else {
      dailyCount = 0;
    }

    lastVerifiedAt = prefs.getString(keyLastVerifiedAt) ?? "";
    // Migration: existing active token without lastVerifiedAt timestamp -> set now
    if (hasActiveToken && lastVerifiedAt.trim().isEmpty) {
      final nowStr = DateTime.now().toIso8601String();
      await prefs.setString(keyLastVerifiedAt, nowStr);
      lastVerifiedAt = nowStr;
    }

    userChoseFree = prefs.getBool(keyUserChoseFree) ?? false;
    keySetupSkipped = prefs.getBool(keyKeySetupSkipped) ?? false;
    final savedUrl = prefs.getString(keyPurchaseUrl);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      purchaseUrl = savedUrl.trim();
    } else {
      purchaseUrl = "https://license.ayyzan.com";
    }

    final savedPrice = prefs.getString(keyPriceText);
    if (savedPrice == null || savedPrice == "৳৯৯৯ লাইফটাইম") {
      priceText = "৳৩৯৯ লাইফটাইম";
      await prefs.setString(keyPriceText, priceText);
    } else {
      priceText = savedPrice;
    }

    final savedWhatsapp = prefs.getString(keySupportWhatsapp);
    if (savedWhatsapp != null && savedWhatsapp.trim().isNotEmpty) {
      supportWhatsapp = savedWhatsapp.trim();
    }

    // Auto-reset daily count if date has rolled over
    final todayStr = formatTodayDate();
    if (dailyDate != todayStr) {
      dailyDate = todayStr;
      dailyCount = 0;
      await prefs.setString(keyDailyDate, todayStr);
      await prefs.setInt(keyDailyCount, 0);
    }

    final savedAiEndpoint = prefs.getString(keyAiEndpoint);
    if (savedAiEndpoint != null && savedAiEndpoint.isNotEmpty) {
      aiProcessEndpoint = savedAiEndpoint;
    }

    final savedLicenseEndpoint = prefs.getString(keyLicenseEndpoint);
    if (savedLicenseEndpoint != null && savedLicenseEndpoint.isNotEmpty) {
      licenseApiEndpoint = savedLicenseEndpoint;
    }

    final savedAppId = prefs.getString(keyLicenseAppId);
    if (savedAppId != null && savedAppId.isNotEmpty) {
      licenseAppId = savedAppId;
    }

    final savedVocab = prefs.getStringList(keyCustomVocabulary);
    if (savedVocab != null && savedVocab.isNotEmpty) {
      customVocabulary = savedVocab;
    }

    orbSize = prefs.getInt(keyOrbSize) ?? 58;
    orbOpacity = prefs.getDouble(keyOrbOpacity) ?? 1.0;

    final savedEngine = prefs.getString(keyVoiceEngine) ?? engineLive;
    voiceEngine = (isPro && savedEngine == engineAi) ? engineAi : engineLive;
    autoLanguage = prefs.getBool(keyAutoLanguage) ?? true;
    sendUsageStats = prefs.getBool(keySendUsageStats) ?? true;
    floatingMicEnabled = prefs.getBool(keyFloatingMicEnabled) ?? false;
  }

  /// Save floating mic enabled setting (optional extra, default false)
  static Future<void> setFloatingMicEnabled(bool enabled) async {
    floatingMicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFloatingMicEnabled, enabled);
    if (enabled) {
      await NativeBridge.startFloatingService();
    } else {
      await NativeBridge.stopFloatingService();
    }
  }

  /// Save anonymous usage statistics telemetry setting
  static Future<void> setSendUsageStats(bool enabled) async {
    sendUsageStats = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySendUsageStats, enabled);
  }

  /// Save Voice Engine setting ('live' or 'ai')
  static Future<void> setVoiceEngine(String engine) async {
    voiceEngine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyVoiceEngine, engine);
  }

  /// Save Auto Language setting (bool)
  static Future<void> setAutoLanguage(bool enabled) async {
    autoLanguage = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoLanguage, enabled);
  }

  /// Add word to custom vocabulary
  static Future<void> addVocabularyWord(String word) async {
    final clean = word.trim();
    if (clean.isNotEmpty && !customVocabulary.contains(clean)) {
      customVocabulary.add(clean);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyCustomVocabulary, customVocabulary);
    }
  }

  /// Remove word from custom vocabulary
  static Future<void> removeVocabularyWord(String word) async {
    customVocabulary.remove(word);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyCustomVocabulary, customVocabulary);
  }

  /// Save Orb Appearance
  static Future<void> saveOrbAppearance({int? size, double? opacity}) async {
    final prefs = await SharedPreferences.getInstance();
    if (size != null) {
      orbSize = size;
      await prefs.setInt(keyOrbSize, size);
    }
    if (opacity != null) {
      orbOpacity = opacity;
      await prefs.setDouble(keyOrbOpacity, opacity);
    }
  }

  /// Save primary Gemini API Key
  static Future<void> setPrimaryGeminiApiKey(String apiKey) async {
    primaryGeminiApiKey = apiKey;
    directGeminiApiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrimaryGeminiApiKey, apiKey);
    await prefs.setString(keyGeminiApiKey, apiKey);
  }

  /// Save backup Gemini API Key
  static Future<void> setBackupGeminiApiKey(String apiKey) async {
    backupGeminiApiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBackupGeminiApiKey, apiKey);
  }

  /// Save free online engine toggle
  static Future<void> setFreeOnlineEngine(bool enabled) async {
    freeOnlineEngine = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFreeOnlineEngine, enabled);
  }

  /// Save backup Groq API Key
  static Future<void> setBackupGroqApiKey(String apiKey) async {
    backupGroqApiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBackupGroqApiKey, apiKey);
  }

  /// Legacy helper for setting Gemini API Key
  static Future<void> setGeminiApiKey(String apiKey) async {
    await setPrimaryGeminiApiKey(apiKey);
  }

  /// Save custom AI Endpoint
  static Future<void> setAiProcessEndpoint(String endpoint) async {
    aiProcessEndpoint = endpoint;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAiEndpoint, endpoint);
  }

  /// Format current local date string (yyyy-MM-dd)
  static String formatTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /// Update Pro license status and sync to native
  static Future<void> setIsPro(bool value) async {
    isPro = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsPro, value);
    await NativeBridge.updateProStatus(value);
  }

  /// Read current synchronized daily usage count from disk after reload
  static Future<int> getDailyUsageCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final todayStr = formatTodayDate();
    final savedDate = prefs.getString(keyDailyDate) ?? "";
    if (savedDate != todayStr) {
      dailyDate = todayStr;
      dailyCount = 0;
      await prefs.setString(keyDailyDate, todayStr);
      await prefs.setInt(keyDailyCount, 0);
      return 0;
    }
    final rawCount = prefs.get(keyDailyCount);
    int current = 0;
    if (rawCount is int) {
      current = rawCount;
    } else if (rawCount is num) {
      current = rawCount.toInt();
    }
    dailyDate = savedDate;
    dailyCount = current;
    return dailyCount;
  }

  /// Increment daily voice usage counter and persist with reload
  static Future<int> incrementDailyUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final todayStr = formatTodayDate();
    final savedDate = prefs.getString(keyDailyDate) ?? "";
    int current = 0;
    if (savedDate == todayStr) {
      final rawCount = prefs.get(keyDailyCount);
      if (rawCount is int) {
        current = rawCount;
      } else if (rawCount is num) {
        current = rawCount.toInt();
      }
    }
    current += 1;
    dailyDate = todayStr;
    dailyCount = current;
    await prefs.setString(keyDailyDate, todayStr);
    await prefs.setInt(keyDailyCount, current);
    return current;
  }

  /// Record last successful verification timestamp
  static Future<void> setLastVerifiedAt(String timestamp) async {
    lastVerifiedAt = timestamp;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastVerifiedAt, timestamp);
  }

  /// Save user choice for free version
  static Future<void> setUserChoseFree(bool value) async {
    userChoseFree = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyUserChoseFree, value);
  }

  /// Save user choice to skip initial API key setup wizard
  static Future<void> setKeySetupSkipped(bool value) async {
    keySetupSkipped = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyKeySetupSkipped, value);
  }

  /// Save dynamic app pricing & purchase link
  static Future<void> setAppPricing({String? url, String? price, String? whatsapp}) async {
    final prefs = await SharedPreferences.getInstance();
    if (url != null && url.isNotEmpty) {
      purchaseUrl = url;
      await prefs.setString(keyPurchaseUrl, url);
    }
    if (price != null && price.isNotEmpty) {
      priceText = price;
      await prefs.setString(keyPriceText, price);
    }
    if (whatsapp != null && whatsapp.isNotEmpty) {
      supportWhatsapp = whatsapp;
      await prefs.setString(keySupportWhatsapp, whatsapp);
    }
  }

  /// Get custom system prompt for a mode if defined
  static Future<String?> getCustomPrompt(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    final prompt = prefs.getString("$keyCustomPromptPrefix$mode");
    return (prompt != null && prompt.trim().isNotEmpty) ? prompt.trim() : null;
  }

  /// Set or reset custom system prompt for a mode
  static Future<void> setCustomPrompt(String mode, String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    if (prompt.trim().isEmpty) {
      await prefs.remove("$keyCustomPromptPrefix$mode");
    } else {
      await prefs.setString("$keyCustomPromptPrefix$mode", prompt.trim());
    }
  }
}
