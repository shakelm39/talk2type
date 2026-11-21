import 'package:shared_preferences/shared_preferences.dart';

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
  static const String keyAiEndpoint = "vf_ai_endpoint";
  static const String keyLicenseEndpoint = "vf_license_endpoint";
  static const String keyLicenseAppId = "vf_license_app_id";
  static const String keyCustomPromptPrefix = "vf_custom_prompt_";
  static const String keyCustomVocabulary = "vf_custom_vocabulary";
  static const String keyOrbSize = "vf_orb_size";
  static const String keyOrbOpacity = "vf_orb_opacity";

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
