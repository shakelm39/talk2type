# Phase 12 Report: Anonymous Install/Usage Ping to Hub

**Branch:** `install-ping` (branched from `main`)  
**Commit Target:** `feat(telemetry): anonymous install & usage ping to hub`  
**Date:** 2026-11-23  

---

## 1. Overview & Goal
Implemented anonymous install and usage telemetry for Talk2Type. The application transmits non-personally identifiable hardware specifications (manufacturer, model, OS version), app version, and license tier (`free` vs `pro`) to the Ayyzan License Hub (`POST /v1/apps/talk2type/ping` or `/api/v1/apps/talk2type/ping`).

### Privacy & Security Guarantees:
- **No Raw Device ID Sent**: `installHash` is a one-way deterministic SHA-256 digest: `sha256(rawDeviceId + ":talk2type")` (64 lowercase hex characters).
- **Token Protection**: `licenseToken` is included in payload **ONLY** when `isPro == true` and a valid token exists. Free users never send any token.
- **Opt-Out Control**: Users can disable telemetry at any time via Settings → অ্যাডভান্সড → "ব্যবহারের পরিসংখ্যান পাঠান (নাম-পরিচয় ছাড়া)". When disabled, zero network requests are made.
- **Fail-Safe & Silent**: 5-second timeout, fire-and-forget, non-blocking UI. Swallows network errors, offline states, 404s (pre-hub deployment), and 429 rate limits.
- **Safe Logging**: Logs only HTTP status codes (e.g. `[InstallPingService] Ping response status: 404`). Never logs tokens, raw device IDs, or keys.

---

## 2. Modified & Created Files

| File | Status | Description |
|---|---|---|
| `lib/core/services/install_ping_service.dart` | **Created** | Core telemetry service computing `installHash`, building payload, handling 12h throttling and force pings. |
| `lib/core/config/app_config.dart` | **Modified** | Added keys `vf_install_hash`, `vf_last_ping_at`, `vf_send_usage_stats`, and `sendUsageStats` property & setter. |
| `lib/presentation/screens/test_ai_dialog.dart` | **Modified** | Added "উন্নত সেটিংস (অ্যাডভান্সড)" section with opt-out switch and explanatory subtitle. |
| `lib/presentation/screens/splash_gate_screen.dart` | **Modified** | Triggers `InstallPingService.instance.sendPing()` on app cold start. |
| `lib/presentation/screens/home_control_screen.dart` | **Modified** | Triggers `InstallPingService.instance.sendPing()` on app resume (`AppLifecycleState.resumed`). |
| `lib/core/services/license_service.dart` | **Modified** | Triggers immediate ping (`force: true`) upon successful activation and when license is cleared. |
| `pubspec.yaml` & `pubspec.lock` | **Modified** | Added direct dependency `crypto: ^3.0.3` and bumped version to `2.0.7+9`. |
| `test/widget_test.dart` | **Modified** | Added 5 unit tests covering hash stability, tier selection, payload construction, 12h throttling, and opt-out. |

---

## 3. Verification Details

### A. Unit Tests (`flutter test`)
Ran `flutter test test/widget_test.dart`. **All 26 tests passed (100%)**:
1. `Hash stability: sha256(deviceId:talk2type) is deterministic, 64 hex chars, and cached` -> **PASSED**
2. `Tier selection: pro only with isPro + non-empty token, else free` -> **PASSED**
3. `Payload construction: token included ONLY when tier is pro` -> **PASSED**
4. `12-hour throttling and force bypass logic` -> **PASSED**
5. `Switch off = no request sent` -> **PASSED**

### B. Static Analysis (`flutter analyze`)
Ran `flutter analyze`:
```
Analyzing Talk2Type...
No issues found! (ran in 91.4s)
```
**0 errors, 0 warnings, 0 issues.**

### C. Build Verification (`flutter build apk --debug`)
`assembleDebug` completed successfully (`build/app/outputs/flutter-apk/app-debug.apk`).

### D. Physical Device Verification (CPH2817 via Wireless ADB)
- Installed debug APK to device `192.168.0.110:42331` (`Performing Streamed Install -> Success`).
- Cleared logcat and launched `com.voiceflow.ai.voiceflow_ai/.MainActivity`.
- Logcat confirmed ping dispatch and logged only the HTTP status:
  ```
  11-23 13:49:28.521 29586 29586 I flutter : [InstallPingService] Ping response status: 404
  ```
- Checked device `FlutterSharedPreferences.xml`:
  - `vf_install_hash` was computed and stored: `2c1d1598d2d10ea98cee17e51b66c646fc1e3738a15f118d858aae5bf4673695` (64 hex characters).
  - `vf_last_ping_at` was recorded: `2026-11-23T13:49:28.507932`.
- Subsequent launch within 12 hours correctly throttles without spamming the hub.

---

## 4. Known Issues & Upstream Dependencies
- The live endpoint `https://license.ayyzan.com/api/v1/apps/talk2type/ping` currently returns HTTP 404 because Phase 11 on `ayyzan-license-hub` is pending deployment. The app handles this completely silently as expected per the specification.
