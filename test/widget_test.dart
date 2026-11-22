import 'package:flutter_test/flutter_test.dart';
import 'package:voiceflow_ai/core/config/app_config.dart';
import 'package:voiceflow_ai/core/config/plan_limits.dart';
import 'package:voiceflow_ai/core/constants/tone_modes.dart';
import 'package:voiceflow_ai/core/services/license_service.dart';
import 'package:voiceflow_ai/core/services/snippet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppConfig default properties', () {
    expect(AppConfig.enableLicenseCheck, true);
    expect(AppConfig.licenseApiEndpoint, isNotEmpty);
    expect(AppConfig.aiProcessEndpoint, isNotEmpty);
  });

  test('ToneModes 5-mode configuration and normalization check', () {
    expect(ToneModes.allModes.length, 5);
    expect(ToneModes.getByKey(ToneModes.bangla).key, ToneModes.bangla);
    expect(ToneModes.getByKey(ToneModes.formal).key, ToneModes.formal);
    expect(ToneModes.getByKey(ToneModes.support).key, ToneModes.support);
    expect(ToneModes.getByKey(ToneModes.casual).key, ToneModes.casual);
    expect(ToneModes.getByKey(ToneModes.english).key, ToneModes.english);

    // Normalization & backward compatibility checks
    expect(ToneModes.getByKey("clean_bangla").key, ToneModes.bangla);
    expect(ToneModes.getByKey("guchiye").key, ToneModes.bangla);
    expect(ToneModes.getByKey("sundor").key, ToneModes.bangla);
    expect(ToneModes.getByKey("hubohu").key, ToneModes.bangla);
    expect(ToneModes.getByKey("office_formal").key, ToneModes.formal);
    expect(ToneModes.getByKey("customer_support").key, ToneModes.support);
    expect(ToneModes.getByKey("friend_casual").key, ToneModes.casual);
    expect(ToneModes.getByKey("bangla_to_english").key, ToneModes.english);
    expect(ToneModes.getByKey("english_translate").key, ToneModes.english);
    expect(ToneModes.getByKey("unknown_mode").key, ToneModes.bangla);
  });

  test('LicenseService check with enableLicenseCheck=false bypass', () async {
    AppConfig.enableLicenseCheck = false;
    final isValid = await LicenseService.instance.isLicenseValid();
    expect(isValid, true);
  });

  test('BYOK AppConfig key validation and masking checks', () {
    expect(AppConfig.isValidKey(null), false);
    expect(AppConfig.isValidKey(""), false);
    expect(AppConfig.isValidKey("   "), false);
    expect(AppConfig.isValidKey("YOUR_TEST_GEMINI_KEY"), false);
    expect(AppConfig.isValidKey("AIzaSyValidKey12345"), true);

    expect(AppConfig.maskKey(null), "");
    expect(AppConfig.maskKey(""), "");
    expect(AppConfig.maskKey("123"), "••••");
    expect(AppConfig.maskKey("AIzaSyABCD1234"), "••••••••1234");

    AppConfig.primaryGeminiApiKey = "";
    AppConfig.directGeminiApiKey = "";
    AppConfig.backupGeminiApiKey = "";
    AppConfig.backupGroqApiKey = "";
    expect(AppConfig.hasAnyAiKey, false);

    AppConfig.primaryGeminiApiKey = "AIzaSyTestKey123";
    expect(AppConfig.hasAnyAiKey, true);
    AppConfig.primaryGeminiApiKey = "";
  });

  test('Phase 3B Free vs Pro PlanLimits and Gating Rules', () {
    expect(PlanLimits.freeDailyLimit, 20);
    expect(PlanLimits.proDailyLimit, -1);

    // Mode gating
    expect(PlanLimits.isModeAllowed(ToneModes.bangla, isPro: false), true);
    expect(PlanLimits.isModeAllowed(ToneModes.formal, isPro: false), false);
    expect(PlanLimits.isModeAllowed(ToneModes.support, isPro: false), false);
    expect(PlanLimits.isModeAllowed(ToneModes.casual, isPro: false), false);
    expect(PlanLimits.isModeAllowed(ToneModes.english, isPro: false), false);

    // Pro has all modes allowed
    for (final mode in ToneModes.allModes) {
      expect(PlanLimits.isModeAllowed(mode.key, isPro: true), true);
    }

    // Daily limit checks
    expect(PlanLimits.isDailyLimitReached(0, isPro: false), false);
    expect(PlanLimits.isDailyLimitReached(19, isPro: false), false);
    expect(PlanLimits.isDailyLimitReached(20, isPro: false), true);
    expect(PlanLimits.isDailyLimitReached(25, isPro: false), true);

    // Pro is never limit reached
    expect(PlanLimits.isDailyLimitReached(20, isPro: true), false);
    expect(PlanLimits.isDailyLimitReached(9999, isPro: true), false);
  });

  test('Voice Snippet trigger normalization and matching', () {
    expect(SnippetService.normalizeUtterance('আমার ঠিকানা।'), 'আমার ঠিকানা');
    expect(SnippetService.normalizeUtterance('আমার ঠিকানা?'), 'আমার ঠিকানা');
    expect(SnippetService.normalizeUtterance('  ডেলিভারি চার্জ  \n'), 'ডেলিভারি চার্জ');
    expect(SnippetService.normalizeUtterance('NEW LINE!'), 'new line');
  });
}
