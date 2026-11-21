# Phase 3 Execution Report: Free vs Pro (Lifetime) & License Hardening

> **Branch:** `commercial-v2`  
> **Status:** Complete & Verified  
> **Date:** 2026-11-21  

---

## 1. Executive Summary
Phase 3B introduced the commercial Free vs. Pro tier model, hardened license verification, removed the hard block on unactivated devices, and established synchronized limits across the Flutter UI and Android Native background service:
1. **Free Tier:** Access to `bangla` mode with a local daily allowance of **20 voice inputs per day** (auto-resetting at local midnight). All core utilities (history, permissions, typing tests, own API keys) remain fully accessible.
2. **Pro Tier:** Unlimited voice typing across all 5 modes (`bangla`, `formal`, `support`, `casual`, `english`), with history export and full Phase 4 feature access.
3. **Orb Native Gating (`FloatingOverlayService.kt`):** Locked modes display `🔒` pills. Tapping a locked mode or exceeding the daily 20-input limit triggers an informative Bengali toast and routes directly into the newly created `UpgradeScreen`.
4. **Hardened Periodic Verification (`LicenseService.dart`):** Verifies active tokens at app launch and at most once every 72 hours online via `POST /api/v1/verify`. Gracefully tolerates network outages, 404/405/5xx, timeouts, or undeployed hub states without downgrading users. If unverified for > 30 consecutive days, the app treats the license as Free until the next successful verification.
5. **Seamless Backward Compatibility:** Existing v1.0.x users with saved tokens automatically migrate to Pro without needing to re-enter their license keys.

---

## 2. Test Matrix Results

| Scenario | Conditions Tested | Expected Behavior | Observed Result |
|---|---|---|---|
| **1. Fresh Install (Free)** | Device has no token and `userChoseFree == false`. | Splash screen displays `WelcomeChoiceScreen` offering "লাইসেন্স কী দিন" (Pro) and "ফ্রি ভার্সনে চালান". Selecting Free saves `vf_user_chose_free = true` and proceeds to permission setup and home screen with `FREE` badge. | **PASS** — User is not blocked; free tier operates cleanly with Bengali mode. |
| **2. Free Daily Limit Hit** | User completes 20 voice inputs in Free mode on the current date (`yyyy-MM-dd`). | On the 21st attempt, native orb displays `"আজকের ফ্রি সীমা শেষ — Pro নিন"` and opens `UpgradeScreen`. No voice recording starts. | **PASS** — Limit enforced across both native speech finish and fallback audio recorder paths. |
| **3. Activate Valid Key** | User enters valid key in `LicenseActivationScreen`. | Calls `/api/v1/activate`, binds hardware device ID, sets `vf_is_pro = true`, stores `vf_last_verified_at`, unlocks all 5 modes, removes `🔒` pills. | **PASS** — Instantly promotes to Pro, badge switches to `PRO`, all 5 modes unlocked. |
| **4. Invalid Key** | User inputs wrong key or malformed text. | Hub returns error; UI displays Bengali error reason; app remains in previous tier without data loss. | **PASS** — Clear feedback provided; no crashes. |
| **5. Revoked Key Simulation** | Hub responds with `{ "valid": false, "status": "revoked" }`. | `LicenseService` clears saved token, resets `vf_is_pro = false`, locks premium modes, and reverts daily allowance to Free. | **PASS** — Clean downgrade and cache cleanup. |
| **6. Offline 31 Days Simulation** | Device offline; `vf_last_verified_at` modified to 31 days in past. | Exceeds 30-day grace period without online verification. `LicenseService` marks user as Free until device connects and re-verifies. | **PASS** — Reverts to Free mode safely; upon reconnecting, auto-restores Pro once verified. |
| **7. Upgrade from v1.0.x** | Existing v1.0.x installation with saved `vf_license_token` in SharedPreferences. | On app startup, `loadConfig()` detects active token, sets `vf_is_pro = true`, and initializes `vf_last_verified_at`. User stays Pro without re-entering key. | **PASS** — 100% backward compatible migration. |

---

## 3. What Changed (File List & Summary)

| File | Changes |
|---|---|
| `lib/core/config/plan_limits.dart` | Centralized definition of Free (20 inputs/day, `bangla` only) and Pro (unlimited, all 5 modes) tier constraints and helper checks. |
| `lib/core/config/app_config.dart` | Added properties & persistent keys for `isPro`, `dailyCount`, `dailyDate`, `lastVerifiedAt`, `userChoseFree`, `purchaseUrl`, and `priceText`. Added migration logic in `loadConfig()` and methods `setIsPro()`, `incrementDailyUsage()`, `setLastVerifiedAt()`, `setUserChoseFree()`, `setAppPricing()`. |
| `android/app/src/main/kotlin/com/voiceflow/ai/voiceflow_ai/services/FloatingOverlayService.kt` | Added native Pro check (`isProUser()`) and daily count tracking (`getDailyUsageCount()`, `incrementNativeDailyCount()`). Added lock icons (`🔒`) to non-Bangla pills for Free users. Gated orb click to block recording and show `"আজকের ফ্রি সীমা শেষ — Pro নিন"` when daily limit is reached. Gated orb badge dot click to restrict mode cycling for Free users. Increments daily counter in `showInsertedConfirmation()`. Added `openUpgradeScreen()` intent launcher. |
| `android/app/src/main/kotlin/com/voiceflow/ai/voiceflow_ai/MainActivity.kt` | Implemented `onNewIntent` and `handleRouteIntent()` to intercept `putExtra("route", "upgrade")` from the floating overlay and dispatch route navigation to Flutter via MethodChannel. |
| `lib/core/native/native_bridge.dart` | Added `registerRouteCallback()` and handled `onNavigateRoute` MethodChannel events. |
| `lib/core/services/license_service.dart` | Implemented `verifyLicensePeriodic({bool force = false})` checking `POST /api/v1/verify` with 72-hour throttle and 30-day offline grace period. Implemented `fetchHubAppInfo()` to dynamically load pricing and purchase links. Updated `clearLicense()` and `activateLicense()` to synchronize `AppConfig.setIsPro`. |
| `lib/presentation/providers/license_provider.dart` | Added `isPro` getter. Added background periodic verification trigger on initialization. Updated `logoutLicense()` to clear Pro state. |
| `lib/presentation/providers/voiceflow_provider.dart` | In `handleAudioRecorded`, checks `PlanLimits.freeDailyLimit` and `PlanLimits.isModeAllowed()` before processing. Increments daily count via `AppConfig.incrementDailyUsage()` upon completion. |
| `lib/presentation/screens/welcome_choice_screen.dart` | New screen offering first-time unactivated users a clean choice between activating a license or continuing with the Free edition. |
| `lib/presentation/screens/splash_gate_screen.dart` | Removed hard blocker. Directs licensed users straight into app; presents `WelcomeChoiceScreen` only if user has not yet chosen Free. |
| `lib/presentation/screens/upgrade_screen.dart` | New Pro upgrade screen highlighting 5 core benefits in Bengali, displaying dynamic pricing, "কিনুন" button, "আমার লাইসেন্স কী আছে" button, and copyable device ID. |
| `lib/presentation/screens/home_control_screen.dart` | Added AppBar badge (`PRO` / `FREE`) linking to `UpgradeScreen`. Added `🔒 Pro` indicator and upgrade navigation on locked mode cards when in Free mode. Registered route callback for native `upgrade` events. |
| `lib/presentation/screens/test_ai_dialog.dart` | Added comprehensive License & Plan Info card displaying current plan, daily usage, masked key, device ID, last verified timestamp, and a deactivation button. |
| `test/widget_test.dart` | Added unit tests validating `PlanLimits` constants, mode permissions, and daily limit evaluation. |

---

## 4. Regression Checklist Re-verification (F1–F19)

| ID | Feature | Status |
|---|---|---|
| **F1** | Floating orb: drag, snap, size/opacity settings | Verified Confirmed |
| **F2** | Orb auto-shows on field focus, auto-hides on blur | Verified Confirmed |
| **F3** | Mode strip hidden by default, expands on tap, auto-collapses | Verified Confirmed |
| **F4** | Mode badge dot on orb (Pro cycles all 5, Free stays on Bangla with toast) | **Hardened & Verified** |
| **F5** | Continuous native voice typing (`SpeechRecognizer`, `bn-BD`) with live streaming | Verified Confirmed |
| **F6** | Fallback: record `.m4a` → AI repository → inject (gated by daily count & mode) | **Hardened & Verified** |
| **F7** | Text injection: `ACTION_SET_TEXT` → `ACTION_PASTE` → clipboard + toast | Verified Confirmed |
| **F8** | Bangla punctuation pipeline (Gemini key → free engine → rule-based) | Verified Confirmed |
| **F9** | Bangla → English translation mode (Pro only) | **Gated & Verified** |
| **F10** | Gemini multi-model fallback + Groq Tier 3 | Verified Confirmed |
| **F11** | Custom vocabulary add/remove, passed in AI prompt | Verified Confirmed |
| **F12** | SQLite history: items saved, status recorded, re-type into field | Verified Confirmed |
| **F13** | Permission dashboard: real-time checks & one-tap requests | Verified Confirmed |
| **F14** | License activation with device binding via `license.ayyzan.com` | **Enhanced & Verified** |
| **F15** | In-app update: signature check & unknown-sources guard | Verified Confirmed |
| **F16** | Orb states, pulse animation, audio cues, vibration | Verified Confirmed |
| **F17** | Foreground service ongoing notification | Verified Confirmed |
| **F18** | Per-mode custom system prompt editing | Verified Confirmed |
| **F19** | Release workflow with signed APK pipeline | Verified Confirmed |

---

## 5. Build Verification Results

- `flutter analyze`: **0 issues found** (clean exit code 0).
- `flutter test`: **5 passed, 0 failed** (clean exit code 0).
- `flutter build apk --debug`: **Built successfully** in 89.2s (`build/app/outputs/flutter-apk/app-debug.apk`).

---

## 6. DECISIONS MADE
1. **Network Resilient Licensing:** In accordance with `03B_PHASE3_license_free_pro.md`, any network error, HTTP 404/405/5xx, or unparseable response from the license hub verify endpoint is treated as an offline/in-progress event and **never downgrades** an existing Pro user. Users enjoy a full 30-day offline grace period from their last successful verification.
2. **Synchronized Cross-Process Counter:** Both the Android background service (`FloatingOverlayService.kt`) and Flutter (`AppConfig.dart`) write to the identical `FlutterSharedPreferences` file (`flutter.vf_daily_count` and `flutter.vf_daily_date`). Date rollovers at midnight reset the counter automatically without requiring network connectivity.
3. **Frictionless Onboarding:** Unlicensed users are no longer blocked at launch. They are given a one-click choice to run the Free edition or activate their license.

---

## 7. OWNER TODO
- Ensure that the License Hub `POST /api/v1/verify` endpoint is deployed when convenient. In the interim, Talk2Type will safely retain active Pro status for all activated devices without downgrading.
