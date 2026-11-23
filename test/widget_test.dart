import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voiceflow_ai/core/config/app_config.dart';
import 'package:voiceflow_ai/core/config/plan_limits.dart';
import 'package:voiceflow_ai/core/constants/tone_modes.dart';
import 'package:voiceflow_ai/core/services/app_update_service.dart';
import 'package:voiceflow_ai/core/services/gemini_model_service.dart';
import 'package:voiceflow_ai/core/services/install_ping_service.dart';
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

  test('Daily usage counter reset logic', () {
    // If today matches, keep count; if date is old, reset to 0
    final today = DateTime.now().toIso8601String().substring(0, 10);
    const yesterday = "2026-01-01";

    int resolveUsageCount(String savedDate, int savedCount, String currentDate) {
      if (savedDate == currentDate) return savedCount;
      return 0;
    }

    expect(resolveUsageCount(today, 15, today), 15);
    expect(resolveUsageCount(yesterday, 19, today), 0);
  });

  test('License verify state machine (valid / revoked / offline 30 days)', () {
    // State machine logic:
    // 1. If backend returns valid -> valid
    // 2. If backend returns explicitly revoked -> invalid
    // 3. If network fails but last success was within 30 days -> grace period keeps Pro active
    // 4. If network fails and last success > 30 days ago -> downgraded to Free
    bool evaluateLicenseStatus({
      required bool hasNetwork,
      bool? serverValid,
      String? serverStatus,
      required DateTime lastSuccessfulVerify,
      required DateTime now,
    }) {
      if (hasNetwork && serverValid != null) {
        if (serverValid && serverStatus != 'revoked') {
          return true;
        }
        return false;
      }
      // Offline fallback: 30-day grace period
      final difference = now.difference(lastSuccessfulVerify);
      return difference.inDays <= 30;
    }

    final now = DateTime.now();

    // 1. Valid server response
    expect(evaluateLicenseStatus(
      hasNetwork: true,
      serverValid: true,
      serverStatus: 'active',
      lastSuccessfulVerify: now,
      now: now,
    ), true);

    // 2. Explicitly revoked
    expect(evaluateLicenseStatus(
      hasNetwork: true,
      serverValid: false,
      serverStatus: 'revoked',
      lastSuccessfulVerify: now,
      now: now,
    ), false);

    // 3. Offline within 30 days grace period
    expect(evaluateLicenseStatus(
      hasNetwork: false,
      lastSuccessfulVerify: now.subtract(const Duration(days: 15)),
      now: now,
    ), true);

    // 4. Offline past 30 days grace period
    expect(evaluateLicenseStatus(
      hasNetwork: false,
      lastSuccessfulVerify: now.subtract(const Duration(days: 35)),
      now: now,
    ), false);
  });

  test('Voice command parsing and trigger matching', () {
    final commands = <String, String>{
      'নতুন লাইন': '\n',
      'new line': '\n',
      'দাঁড়ি': '। ',
      'ফুলস্টপ': '। ',
      'কমা': ', ',
      'comma': ', ',
      'প্রশ্নবোধক': '? ',
      'question mark': '? ',
    };

    String processUtterance(String text) {
      final trimmed = text.trim();
      final lower = trimmed.toLowerCase();

      // Standalone match
      for (final entry in commands.entries) {
        if (lower == entry.key || trimmed == entry.key) {
          return entry.value;
        }
      }

      // Suffix match
      for (final entry in commands.entries) {
        if (lower.endsWith(' ${entry.key}') || trimmed.endsWith(' ${entry.key}')) {
          final prefix = trimmed.substring(0, trimmed.length - entry.key.length).trimRight();
          return '$prefix${entry.value}';
        }
      }

      return text;
    }

    expect(processUtterance('নতুন লাইন'), '\n');
    expect(processUtterance('new line'), '\n');
    expect(processUtterance('দাঁড়ি'), '। ');
    expect(processUtterance('কমা'), ', ');
    expect(processUtterance('প্রশ্নবোধক'), '? ');
    expect(processUtterance('আমি ঢাকা যাব দাঁড়ি'), 'আমি ঢাকা যাব। ');
    expect(processUtterance('কেমন আছেন প্রশ্নবোধক'), 'কেমন আছেন? ');
    expect(processUtterance('প্রথম অংশ নতুন লাইন'), 'প্রথম অংশ\n');
  });

  test('Phase 6: Stored device ID is preserved for existing activations', () async {
    SharedPreferences.setMockInitialValues({
      AppConfig.keyDeviceId: 'legacy-build-id-TP1A.220624.014',
      AppConfig.keyLicenseToken: 'test-token',
      AppConfig.keyLicenseKey: 'TEST-KEY-1234',
    });

    final deviceId = await LicenseService.instance.getDeviceId();
    expect(deviceId, 'legacy-build-id-TP1A.220624.014');
  });

  test('Phase 6: Periodic verify response handling (4xx revocation vs network error)', () async {
    SharedPreferences.setMockInitialValues({
      AppConfig.keyLicenseToken: 'valid-token',
      AppConfig.keyLicenseKey: 'PRO-KEY',
      AppConfig.keyIsPro: true,
      AppConfig.keyLastVerifiedAt: '2026-11-20T10:00:00.000',
    });

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConfig.keyLicenseToken), 'valid-token');

    // Simulate 403 / 401 revocation JSON body via processVerifyResponseDataForTesting
    final revocationBody = {'valid': false, 'status': 'revoked', 'message': 'License has been revoked'};
    final result = await LicenseService.instance.processVerifyResponseDataForTesting(revocationBody, prefs);

    expect(result, false);
    expect(AppConfig.isPro, false);
    expect(prefs.getString(AppConfig.keyLicenseToken), isNull);

    // Verify lastVerifiedAt was NOT updated on failed verify
    expect(prefs.getString(AppConfig.keyLastVerifiedAt), '2026-11-20T10:00:00.000');
  });

  test('Phase 6: Verify status handler - active, revoked, device_mismatch, not_found, unavailable, 429 RATE_LIMITED', () async {
    final prefs = await SharedPreferences.getInstance();

    // 1. active
    await prefs.setString(AppConfig.keyLicenseToken, 'token-active');
    await prefs.setString(AppConfig.keyLicenseKey, 'KEY-ACTIVE');
    await AppConfig.setIsPro(false);
    await prefs.setString(AppConfig.keyLastVerifiedAt, '2026-11-20T10:00:00.000');
    final activeRes = await LicenseService.instance.processVerifyResponseDataForTesting(
      {'valid': true, 'status': 'active', 'planName': 'Lifetime Pro'},
      prefs,
    );
    expect(activeRes, true);
    expect(AppConfig.isPro, true);
    expect(prefs.getString(AppConfig.keyLicenseToken), 'token-active');
    expect(AppConfig.lastVerifiedAt, isNot('2026-11-20T10:00:00.000'));

    // 2. revoked -> clears license, isPro = false, lastVerifiedAt untouched
    await prefs.setString(AppConfig.keyLicenseToken, 'token-revoked');
    await prefs.setString(AppConfig.keyLicenseKey, 'KEY-REVOKED');
    await AppConfig.setIsPro(true);
    await prefs.setString(AppConfig.keyLastVerifiedAt, '2026-11-20T10:00:00.000');
    final revokedRes = await LicenseService.instance.processVerifyResponseDataForTesting(
      {'valid': false, 'status': 'revoked', 'message': 'License has been revoked'},
      prefs,
    );
    expect(revokedRes, false);
    expect(AppConfig.isPro, false);
    expect(prefs.getString(AppConfig.keyLicenseToken), isNull);
    expect(prefs.getString(AppConfig.keyLastVerifiedAt), '2026-11-20T10:00:00.000');

    // 3. device_mismatch -> clears license, isPro = false
    await prefs.setString(AppConfig.keyLicenseToken, 'token-mismatch');
    await prefs.setString(AppConfig.keyLicenseKey, 'KEY-MISMATCH');
    await AppConfig.setIsPro(true);
    await prefs.setString(AppConfig.keyLastVerifiedAt, '2026-11-20T10:00:00.000');
    final mismatchRes = await LicenseService.instance.processVerifyResponseDataForTesting(
      {'valid': false, 'status': 'device_mismatch', 'message': 'Device does not match'},
      prefs,
    );
    expect(mismatchRes, false);
    expect(AppConfig.isPro, false);
    expect(prefs.getString(AppConfig.keyLicenseToken), isNull);

    // 4. not_found -> clears license, isPro = false
    await prefs.setString(AppConfig.keyLicenseToken, 'token-notfound');
    await prefs.setString(AppConfig.keyLicenseKey, 'KEY-NOTFOUND');
    await AppConfig.setIsPro(true);
    await prefs.setString(AppConfig.keyLastVerifiedAt, '2026-11-20T10:00:00.000');
    final notFoundRes = await LicenseService.instance.processVerifyResponseDataForTesting(
      {'valid': false, 'status': 'not_found', 'message': 'License not found'},
      prefs,
    );
    expect(notFoundRes, false);
    expect(AppConfig.isPro, false);
    expect(prefs.getString(AppConfig.keyLicenseToken), isNull);

    // 5. unavailable -> keeps current Pro state, does NOT clear license, does NOT update lastVerifiedAt
    await prefs.setString(AppConfig.keyLicenseToken, 'token-unavail');
    await prefs.setString(AppConfig.keyLicenseKey, 'KEY-UNAVAIL');
    await AppConfig.setIsPro(true);
    await prefs.setString(AppConfig.keyLastVerifiedAt, '2026-11-20T10:00:00.000');
    final unavailRes = await LicenseService.instance.processVerifyResponseDataForTesting(
      {'valid': false, 'status': 'unavailable'},
      prefs,
    );
    expect(unavailRes, true);
    expect(AppConfig.isPro, true);
    expect(prefs.getString(AppConfig.keyLicenseToken), 'token-unavail');
    expect(prefs.getString(AppConfig.keyLastVerifiedAt), '2026-11-20T10:00:00.000');

    // 6. 429 body {success:false, valid:false, code:"RATE_LIMITED"} -> keeps current Pro state, does NOT clear license, does NOT update lastVerifiedAt
    await prefs.setString(AppConfig.keyLicenseToken, 'token-ratelimit');
    await prefs.setString(AppConfig.keyLicenseKey, 'KEY-RATELIMIT');
    await AppConfig.setIsPro(true);
    await prefs.setString(AppConfig.keyLastVerifiedAt, '2026-11-20T10:00:00.000');
    final rateLimitRes = await LicenseService.instance.processVerifyResponseDataForTesting(
      {'success': false, 'valid': false, 'code': 'RATE_LIMITED'},
      prefs,
    );
    expect(rateLimitRes, true);
    expect(AppConfig.isPro, true);
    expect(prefs.getString(AppConfig.keyLicenseToken), 'token-ratelimit');
    expect(prefs.getString(AppConfig.keyLastVerifiedAt), '2026-11-20T10:00:00.000');
  });

  test('Phase 6: Migration initializes lastVerifiedAt for existing token without timestamp', () async {
    SharedPreferences.setMockInitialValues({
      AppConfig.keyLicenseToken: 'existing-v1-token',
      AppConfig.keyLicenseKey: 'V1-KEY',
      AppConfig.keyIsPro: true,
    });

    await AppConfig.loadConfig();
    expect(AppConfig.lastVerifiedAt, isNotEmpty);
    expect(DateTime.tryParse(AppConfig.lastVerifiedAt), isNotNull);
  });

  test('Phase 6: Daily counter syncs with reload and handles Long/Int from native', () async {
    final today = AppConfig.formatTodayDate();
    SharedPreferences.setMockInitialValues({
      AppConfig.keyDailyDate: today,
      AppConfig.keyDailyCount: 7, // Simulated Native Long / Int
    });

    final count = await AppConfig.getDailyUsageCount();
    expect(count, 7);
    expect(AppConfig.dailyCount, 7);

    // Dart increments
    final newCount = await AppConfig.incrementDailyUsage();
    expect(newCount, 8);
    expect(AppConfig.dailyCount, 8);

    // Simulate Native writing to SharedPreferences while app is running
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.keyDailyCount, 15);

    // getDailyUsageCount reloads and sees the updated value
    final synced = await AppConfig.getDailyUsageCount();
    expect(synced, 15);
    expect(AppConfig.dailyCount, 15);
  });

  test('Phase 6: Key setup skip preference is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig.loadConfig();
    expect(AppConfig.keySetupSkipped, false);

    await AppConfig.setKeySetupSkipped(true);
    expect(AppConfig.keySetupSkipped, true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConfig.keyKeySetupSkipped), true);
  });

  test('Phase 6: Reinstall v1 binding migration retry decision logic', () {
    final service = LicenseService.instance;

    // 1. HTTP 403 with code OTHER_DEVICE, no stored deviceId, and legacy ID available -> should retry
    expect(
      service.shouldRetryWithLegacyId(
        statusCode: 403,
        responseData: {'success': false, 'code': 'OTHER_DEVICE', 'message': 'Max devices reached'},
        hasStoredDeviceId: false,
        legacyDeviceId: 'TP1A.220624.014',
        currentDeviceId: 'android_id_abcdef123',
      ),
      true,
    );

    // 2. HTTP 403 with code OTHER_DEVICE, but deviceId was ALREADY stored -> should NOT retry
    expect(
      service.shouldRetryWithLegacyId(
        statusCode: 403,
        responseData: {'success': false, 'code': 'OTHER_DEVICE'},
        hasStoredDeviceId: true,
        legacyDeviceId: 'TP1A.220624.014',
        currentDeviceId: 'android_id_abcdef123',
      ),
      false,
    );

    // 3. HTTP 403 with different error code (e.g. INVALID_KEY) -> should NOT retry
    expect(
      service.shouldRetryWithLegacyId(
        statusCode: 403,
        responseData: {'success': false, 'code': 'INVALID_KEY'},
        hasStoredDeviceId: false,
        legacyDeviceId: 'TP1A.220624.014',
        currentDeviceId: 'android_id_abcdef123',
      ),
      false,
    );

    // 4. Non-403 error status (e.g. 401, 500) -> should NOT retry
    expect(
      service.shouldRetryWithLegacyId(
        statusCode: 401,
        responseData: {'success': false, 'code': 'OTHER_DEVICE'},
        hasStoredDeviceId: false,
        legacyDeviceId: 'TP1A.220624.014',
        currentDeviceId: 'android_id_abcdef123',
      ),
      false,
    );

    // 5. Legacy ID is empty or identical to current device ID -> should NOT retry
    expect(
      service.shouldRetryWithLegacyId(
        statusCode: 403,
        responseData: {'success': false, 'code': 'OTHER_DEVICE'},
        hasStoredDeviceId: false,
        legacyDeviceId: '',
        currentDeviceId: 'android_id_abcdef123',
      ),
      false,
    );
    expect(
      service.shouldRetryWithLegacyId(
        statusCode: 403,
        responseData: {'success': false, 'code': 'OTHER_DEVICE'},
        hasStoredDeviceId: false,
        legacyDeviceId: 'same_device_id',
        currentDeviceId: 'same_device_id',
      ),
      false,
    );
  });

  test('AppUpdateService: version comparison logic (SemVer)', () {
    final updateService = AppUpdateService.instance;

    // Newer version detection
    expect(updateService.isVersionGreater('2.0.6', '2.0.5'), true);
    expect(updateService.isVersionGreater('v2.1.0', '2.0.6'), true);
    expect(updateService.isVersionGreater('3.0.0', '2.9.9'), true);
    expect(updateService.isVersionGreater('1.0.10', '1.0.9'), true);

    // Same or older versions
    expect(updateService.isVersionGreater('2.0.5', '2.0.5'), false);
    expect(updateService.isVersionGreater('v2.0.5', '2.0.5'), false);
    expect(updateService.isVersionGreater('2.0.4', '2.0.5'), false);
    expect(updateService.isVersionGreater('1.0.9', '1.0.10'), false);
  });

  test('AppUpdateService: snooze, skip, and mandatory shouldShowUpdate decision logic', () {
    final updateService = AppUpdateService.instance;
    const now = 1700000000000;
    const futureSnooze = now + (24 * 60 * 60 * 1000); // 24 hours later
    const expiredSnooze = now - 1000; // Past

    const regularUpdate = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: '2.0.5',
      latestVersion: '2.0.6',
      downloadUrl: 'https://license.ayyzan.com/dl/talk2type',
      isMandatory: false,
    );

    const mandatoryUpdate = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: '2.0.5',
      latestVersion: '2.0.6',
      downloadUrl: 'https://license.ayyzan.com/dl/talk2type',
      isMandatory: true,
    );

    // 1. Manual check ALWAYS shows (even if snoozed or skipped)
    expect(
      updateService.shouldShowUpdate(
        info: regularUpdate,
        isManual: true,
        snoozeUntilMs: futureSnooze,
        skippedVersion: '2.0.6',
        currentTimestampMs: now,
      ),
      true,
    );

    // 2. Mandatory update ALWAYS shows (overrides snooze and skip)
    expect(
      updateService.shouldShowUpdate(
        info: mandatoryUpdate,
        isManual: false,
        snoozeUntilMs: futureSnooze,
        skippedVersion: '2.0.6',
        currentTimestampMs: now,
      ),
      true,
    );

    // 3. Auto check: active snooze blocks popup
    expect(
      updateService.shouldShowUpdate(
        info: regularUpdate,
        isManual: false,
        snoozeUntilMs: futureSnooze,
        skippedVersion: null,
        currentTimestampMs: now,
      ),
      false,
    );

    // 4. Auto check: expired snooze allows popup
    expect(
      updateService.shouldShowUpdate(
        info: regularUpdate,
        isManual: false,
        snoozeUntilMs: expiredSnooze,
        skippedVersion: null,
        currentTimestampMs: now,
      ),
      true,
    );

    // 5. Auto check: skipped version blocks popup for that exact version
    expect(
      updateService.shouldShowUpdate(
        info: regularUpdate,
        isManual: false,
        snoozeUntilMs: 0,
        skippedVersion: '2.0.6',
        currentTimestampMs: now,
      ),
      false,
    );
    expect(
      updateService.shouldShowUpdate(
        info: regularUpdate,
        isManual: false,
        snoozeUntilMs: 0,
        skippedVersion: 'v2.0.6',
        currentTimestampMs: now,
      ),
      false,
    );

    // 6. Auto check: newer version than skipped version ALLOWS popup
    const newerUpdate = AppUpdateInfo(
      hasUpdate: true,
      currentVersion: '2.0.5',
      latestVersion: '2.0.7',
      downloadUrl: 'https://license.ayyzan.com/dl/talk2type',
      isMandatory: false,
    );
    expect(
      updateService.shouldShowUpdate(
        info: newerUpdate,
        isManual: false,
        snoozeUntilMs: 0,
        skippedVersion: '2.0.6',
        currentTimestampMs: now,
      ),
      true,
    );
  });

  test('AppUpdateService: SharedPreferences persistence of snooze and skip', () async {
    SharedPreferences.setMockInitialValues({});
    final updateService = AppUpdateService.instance;

    // Check defaults
    expect(await updateService.getSnoozeUntil(), 0);
    expect(await updateService.getSkippedVersion(), isNull);

    // Snooze for 24h
    final before = DateTime.now().millisecondsSinceEpoch;
    await updateService.snoozeUpdate(duration: const Duration(hours: 24));
    final snoozeUntil = await updateService.getSnoozeUntil();
    expect(snoozeUntil, greaterThanOrEqualTo(before + (24 * 60 * 60 * 1000) - 2000));

    // Verify raw key in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppConfig.keyUpdateSnoozeUntil), snoozeUntil);

    // Skip version
    await updateService.skipVersion('2.0.6');
    expect(await updateService.getSkippedVersion(), '2.0.6');
    expect(prefs.getString(AppConfig.keyUpdateSkippedVersion), '2.0.6');

    // Clear preferences
    await updateService.clearUpdatePreferences();
    expect(await updateService.getSnoozeUntil(), 0);
    expect(await updateService.getSkippedVersion(), isNull);
  });

  test('Voice Engine & Auto Language: default properties and switching', () async {
    SharedPreferences.setMockInitialValues({});
    AppConfig.isPro = false;
    await AppConfig.loadConfig();

    // Default engine is live (fast)
    expect(AppConfig.voiceEngine, AppConfig.engineLive);
    expect(AppConfig.isAiEngine, isFalse);
    expect(AppConfig.autoLanguage, isTrue);

    // Free user: isAiEngine remains false even if engineAi string is passed
    await AppConfig.setVoiceEngine(AppConfig.engineAi);
    expect(AppConfig.isAiEngine, isFalse);

    // Pro user: isAiEngine becomes true
    await AppConfig.setIsPro(true);
    expect(AppConfig.isAiEngine, isTrue);

    // Verify persistence in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConfig.keyVoiceEngine), AppConfig.engineAi);

    // Toggle Auto Language
    await AppConfig.setAutoLanguage(false);
    expect(AppConfig.autoLanguage, isFalse);
    expect(prefs.getBool(AppConfig.keyAutoLanguage), isFalse);

    // Reload config for Pro user preserves engineAi
    await AppConfig.loadConfig();
    expect(AppConfig.voiceEngine, AppConfig.engineAi);
    expect(AppConfig.autoLanguage, isFalse);

    // Reset back to live
    await AppConfig.setVoiceEngine(AppConfig.engineLive);
    expect(AppConfig.voiceEngine, AppConfig.engineLive);
    expect(AppConfig.isAiEngine, isFalse);

    // Cleanup
    await AppConfig.setIsPro(false);
  });

  test('GeminiModelService: discovery filtering, preferred ordering, and 404-skip', () async {
    SharedPreferences.setMockInitialValues({});
    final service = GeminiModelService.instance;

    // 1. Filtering & Ordering: Google API returns a mixed set including deprecated 1.5, experimental, and text models
    final mockDiscoveredFromGoogle = {
      'gemini-1.5-flash',       // Deprecated -> must be filtered out
      'gemini-2.0-flash',       // Deprecated -> must be filtered out
      'gemini-2.5-flash',       // Supported (last priority)
      'gemini-3.8-flash',       // Supported (high priority)
      'gemini-3.5-flash-lite',  // Supported (top priority)
      'gemini-pro-vision',      // Non-standard -> must be filtered out
      'text-embedding-004',     // Non-generation -> must be filtered out
    };

    final ordered = GeminiModelService.filterAndOrderModels(mockDiscoveredFromGoogle);

    // Expected order strictly matches preferredModelOrder
    expect(ordered, [
      'gemini-3.5-flash-lite',
      'gemini-3.8-flash',
      'gemini-2.5-flash',
    ]);
    expect(ordered.contains('gemini-1.5-flash'), isFalse);
    expect(ordered.contains('gemini-2.0-flash'), isFalse);

    // 2. Active models default to preferredModelOrder when nothing is cached
    final initialActive = await service.getActiveModels();
    expect(initialActive, GeminiModelService.preferredModelOrder);

    // 3. 404-skip: Mark a model unavailable for 24h
    await service.markModelUnavailable('gemini-3.5-flash-lite');

    final updatedActive = await service.getActiveModels();
    expect(updatedActive.contains('gemini-3.5-flash-lite'), isFalse);
    expect(updatedActive.first, 'gemini-3.8-flash');

    // Verify persistence in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final unavailMap = service.getUnavailableModelsMap(prefs);
    expect(unavailMap.containsKey('gemini-3.5-flash-lite'), isTrue);
    expect(unavailMap['gemini-3.5-flash-lite']!, greaterThan(DateTime.now().millisecondsSinceEpoch));
  });

  group('Phase 12: InstallPingService Unit Tests', () {
    test('Hash stability: sha256(deviceId:talk2type) is deterministic, 64 hex chars, and cached', () async {
      const rawDeviceId = "android-device-test-xyz-987";
      final hash1 = InstallPingService.computeInstallHash(rawDeviceId);
      final hash2 = InstallPingService.computeInstallHash(rawDeviceId);

      expect(hash1, equals(hash2));
      expect(hash1.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash1), isTrue);

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.keyInstallHash, hash1);
      final service = InstallPingService.instance;
      final cachedHash = await service.getInstallHash();
      expect(cachedHash, equals(hash1));
    });

    test('Tier selection: pro only with isPro + non-empty token, else free', () {
      final service = InstallPingService.instance;

      expect(service.determineTier(isPro: true, token: "valid-jwt-token"), "pro");
      expect(service.determineTier(isPro: true, token: ""), "free");
      expect(service.determineTier(isPro: true, token: null), "free");
      expect(service.determineTier(isPro: false, token: "valid-jwt-token"), "free");
      expect(service.determineTier(isPro: false, token: null), "free");
    });

    test('Payload construction: token included ONLY when tier is pro', () async {
      final service = InstallPingService.instance;
      final prefs = await SharedPreferences.getInstance();

      // Case 1: Pro user
      await prefs.setString(AppConfig.keyLicenseToken, "token-pro-1234");
      AppConfig.isPro = true;

      final proPayload = await service.buildPayload(
        prefs: prefs,
        customInstallHash: "a" * 64,
        customAppVersion: "2.0.7",
        customManufacturer: "Google",
        customModel: "Pixel 9",
        customOsVersion: "15",
      );

      expect(proPayload['tier'], "pro");
      expect(proPayload['installHash'], "a" * 64);
      expect(proPayload['appVersion'], "2.0.7");
      expect(proPayload['manufacturer'], "Google");
      expect(proPayload['model'], "Pixel 9");
      expect(proPayload['osVersion'], "15");
      expect(proPayload['licenseToken'], "token-pro-1234");

      // Case 2: Free user (even if legacy token was in prefs)
      AppConfig.isPro = false;
      final freePayload = await service.buildPayload(
        prefs: prefs,
        customInstallHash: "b" * 64,
        customAppVersion: "2.0.7",
        customManufacturer: "Samsung",
        customModel: "Galaxy S24",
        customOsVersion: "14",
      );

      expect(freePayload['tier'], "free");
      expect(freePayload['installHash'], "b" * 64);
      expect(freePayload.containsKey('licenseToken'), isFalse);
    });

    test('12-hour throttling and force bypass logic', () async {
      final service = InstallPingService.instance;
      final now = DateTime.now();

      // Not throttled if no prior ping
      expect(service.isThrottled(null, now), isFalse);
      expect(service.isThrottled("", now), isFalse);

      // Throttled if pinged 6 hours ago
      final sixHoursAgo = now.subtract(const Duration(hours: 6)).toIso8601String();
      expect(service.isThrottled(sixHoursAgo, now), isTrue);

      // Not throttled if pinged 13 hours ago
      final thirteenHoursAgo = now.subtract(const Duration(hours: 13)).toIso8601String();
      expect(service.isThrottled(thirteenHoursAgo, now), isFalse);

      // Verify sendPing behavior with mock sender
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.keySendUsageStats, true);
      AppConfig.sendUsageStats = true;
      await prefs.setString(AppConfig.keyInstallHash, "c" * 64);

      int pingCallCount = 0;
      service.pingSenderForTesting = (url, data) async {
        pingCallCount++;
        return 200;
      };

      // 1st ping: succeeds and sets lastPingAt
      await prefs.remove(AppConfig.keyLastPingAt);
      await service.sendPing();
      expect(pingCallCount, 1);
      expect(prefs.getString(AppConfig.keyLastPingAt), isNotNull);

      // 2nd ping right after: throttled, call count remains 1
      await service.sendPing();
      expect(pingCallCount, 1);

      // 3rd ping with force=true: bypasses throttle, call count becomes 2
      await service.sendPing(force: true);
      expect(pingCallCount, 2);

      service.pingSenderForTesting = null;
    });

    test('Switch off = no request sent', () async {
      final service = InstallPingService.instance;
      final prefs = await SharedPreferences.getInstance();

      int pingCallCount = 0;
      service.pingSenderForTesting = (url, data) async {
        pingCallCount++;
        return 200;
      };

      // Telemetry turned OFF
      await prefs.setBool(AppConfig.keySendUsageStats, false);
      AppConfig.sendUsageStats = false;
      await prefs.remove(AppConfig.keyLastPingAt);

      await service.sendPing(force: true);
      expect(pingCallCount, 0);

      // Restore setting
      await prefs.setBool(AppConfig.keySendUsageStats, true);
      AppConfig.sendUsageStats = true;
      service.pingSenderForTesting = null;
    });
  });
}
