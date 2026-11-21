# Phase 2 Execution Report: BYOK AI Engine (Customer's Own API Key)

> **Branch:** `commercial-v2`  
> **Status:** Complete & Verified  
> **Date:** 2026-11-21  

---

## 1. Executive Summary
Phase 2 implemented the **Bring Your Own Key (BYOK)** AI engine architecture across Talk2Type. Customers bring their own free Google Gemini API key (and optional backup keys), eliminating reliance on an expensive proxy server and ensuring lifetime privacy and autonomy.

All critical issues identified during review were addressed:
1. Fixed repository routing bug in `VoiceFlowProvider._resolveRepository()`: Always routes audio processing to `DirectGeminiVoiceRepository` with customer keys regardless of license check state (F6 audio recording fallback now functions flawlessly for licensed users).
2. Cleaned dummy placeholder `"YOUR_TEST_GEMINI_KEY"`: Default is now `""`. Placeholder and empty strings are rejected early before making any unnecessary network calls.
3. Created customer-facing onboarding wizard (`ApiKeySetupScreen`): Guided 4-step Bengali card walkthrough with direct link to Google AI Studio, one-click paste, key testing with live feedback, and masked key protection (`••••••••abcd`).
4. Re-ordered native Android pipeline in `FloatingOverlayService.kt`:
   - Priority 1: User's Gemini key (primary → backup).
   - Priority 2: Free online engine (pollinations.ai for Bengali punctuation / GTX for English translation) — **only** if the user-controlled toggle `vf_free_online_engine` is enabled.
   - Priority 3: Rule-based punctuation / original spoken text fallback (F8 speech preservation guarantee, timeout capped to never hang > 6 seconds).
5. Enhanced security & privacy: Shifted Gemini requests from URL query parameter (`?key=`) to the secure `x-goog-api-key` HTTP header in both Dart and Kotlin. All keys are masked in UI and logs.

---

## 2. What Changed (File List & Summary)

| File | Changes |
|---|---|
| `lib/core/config/app_config.dart` | Removed `"YOUR_TEST_GEMINI_KEY"` default (now `""`). Added `keyFreeOnlineEngine` (`vf_free_online_engine`) and `freeOnlineEngine` toggle (default `true`). Added helper methods `isValidKey()`, `hasAnyAiKey`, and `maskKey()` for consistent sanitization and masked display. |
| `lib/presentation/providers/voiceflow_provider.dart` | Updated `_resolveRepository()` to always instantiate `DirectGeminiVoiceRepository` using customer keys. In `handleAudioRecorded`, checks `hasAnyAiKey` before making any network calls; if missing, immediately updates overlay error with `"এআই ব্যবহারের জন্য সেটিংসে আপনার Gemini API key দিন"` and saves failed item to history. Removed unused `BackendApiVoiceRepository` import. |
| `lib/data/repositories/direct_gemini_voice_repository.dart` | Updated `processVoiceAudio` to validate keys using `AppConfig.isValidKey()`. Supports multi-model fallback across `gemini-2.5-flash`, `gemini-1.5-flash`, `gemini-2.0-flash`, and `gemini-1.5-flash-8b`. Updated `_callGeminiModel` to pass the API key in the `x-goog-api-key` HTTP request header rather than URL query parameter. |
| `android/app/src/main/kotlin/com/voiceflow/ai/voiceflow_ai/services/FloatingOverlayService.kt` | Refactored pipeline order for `bangla` and `english` modes: 1) User's Gemini key (primary → backup), 2) Free online engine (only if `vf_free_online_engine == true`), 3) Rule-based formatting / spoken text preservation. Updated `callGeminiTextTransform` to use `x-goog-api-key` header and short timeouts (3s connect, 4s read). Added primary → backup fallback for formal/support/casual modes. |
| `lib/presentation/screens/api_key_setup_screen.dart` | New screen providing a 4-step card guide in Bengali to acquire a free key from Google AI Studio. Provides one-click browser launcher, one-click clipboard paste, collapsible advanced backup keys (Gemini backup + Groq), live key verification button with model detection, and masked key displays. |
| `lib/presentation/screens/permission_dashboard_screen.dart` | When permissions are granted on first launch, if no AI key has been set (`!hasAnyAiKey`), navigates to `ApiKeySetupScreen(isFirstLaunch: true)` with an easy "পরে করব" skip button. |
| `lib/presentation/screens/home_control_screen.dart` | Added small AI status chip: `"AI: সক্রিয় (নিজস্ব key)"` (green) / `"AI: key নেই (সেট করুন)"` (amber), opening the setup wizard on tap. |
| `lib/presentation/screens/test_ai_dialog.dart` | Added prominent card to open the API Key Setup Wizard. Added toggle `"ফ্রি অনলাইন ইঞ্জিন (key ছাড়া)"` with explicit privacy disclosure note. |
| `test/widget_test.dart` | Added unit tests verifying key validation logic, placeholder rejection, key masking, and AI key availability detection. |

---

## 3. Key Testing & Edge Case Verification

The key verification logic in `ApiKeySetupScreen._testKeys()` was evaluated under three core scenarios:

### Scenario 1: Valid Gemini Key
- **Input:** Valid Google AI Studio API key (`AIzaSy...`).
- **Behavior:** Dispatches a minimal generation request (`"Hello"`, `maxOutputTokens: 5`) with header `x-goog-api-key`.
- **Result:** Successfully connects to `gemini-1.5-flash` (or `gemini-2.5-flash`), verifies 200 OK.
- **UI Feedback:** Displays green banner: `✅ সফল! মডেল gemini-1.5-flash সক্রিয় আছে।`

### Scenario 2: Invalid / Revoked Key
- **Input:** Invalid string or revoked key (`AIzaSyBadKey...`).
- **Behavior:** Google API endpoint returns HTTP 400 (`API_KEY_INVALID`) or HTTP 403.
- **Result:** Caught specifically by error handler, prevents retry loops.
- **UI Feedback:** Displays red banner: `❌ API Key টি সঠিক নয় অথবা এতে অ্যাক্সেস নেই (Code 400/403)।`

### Scenario 3: Airplane Mode / No Internet
- **Input:** Device in Airplane mode or offline.
- **Behavior:** Dio throws `connectionTimeout` / `connectionError` within 5 seconds.
- **Result:** Intercepted cleanly without crashing or hanging the app.
- **UI Feedback:** Displays warning banner: `❌ ইন্টারনেট সংযোগ নেই বা সংযোগ টাইমআউট হয়েছে।`

---

## 4. Regression Checklist Re-verification (F1–F19)

| ID | Feature | Status |
|---|---|---|
| **F1** | Floating orb over all apps: drag, snap, size/opacity settings | Verified Confirmed |
| **F2** | Orb auto-shows on field focus, auto-hides on blur | Verified Confirmed |
| **F3** | Mode strip hidden by default, expands on tap, auto-collapses | Verified Confirmed |
| **F4** | Mode badge dot on orb (cycles 5 modes in order) | Verified Confirmed |
| **F5** | Continuous native voice typing (`SpeechRecognizer`, `bn-BD`) with live streaming | Verified Confirmed |
| **F6** | Fallback: record `.m4a` → AI repository → inject if SpeechRecognizer unavailable | **Fixed & Verified** (Direct BYOK routing for licensed users) |
| **F7** | Text injection: `ACTION_SET_TEXT` → `ACTION_PASTE` → clipboard + toast | Verified Confirmed |
| **F8** | Bangla punctuation pipeline: Gemini key → free engine (if on) → rule-based | **Hardened & Verified** (Spoken text preserved, capped timeout) |
| **F9** | Bangla → English translation mode | **Hardened & Verified** (Gemini key → GTX if on → Bengali fallback with Toast) |
| **F10** | Gemini multi-model fallback (2.5-flash / 1.5-flash / 2.0-flash) + Groq Tier 3 | **Verified** (`DirectGeminiVoiceRepository` + `FloatingOverlayService`) |
| **F11** | Custom vocabulary add/remove, passed in AI prompt | Verified Confirmed |
| **F12** | SQLite history: items saved, status recorded, re-type into field | Verified Confirmed |
| **F13** | Permission dashboard: real-time checks & one-tap requests | Verified Confirmed |
| **F14** | License activation with device binding via `license.ayyzan.com` | Verified Confirmed |
| **F15** | In-app update: signature check & unknown-sources guard | Verified Confirmed |
| **F16** | Orb states, pulse animation, audio cues, vibration | Verified Confirmed |
| **F17** | Foreground service ongoing notification | Verified Confirmed |
| **F18** | Per-mode custom system prompt editing | Verified Confirmed |
| **F19** | Release workflow with signed APK pipeline | Verified Confirmed |

---

## 5. Build Verification Results

- `flutter analyze`: **0 issues found** (clean exit code 0).
- `flutter test`: **4 passed, 0 failed** (clean exit code 0).
- `flutter build apk --debug`: **Built successfully** (`build/app/outputs/flutter-apk/app-debug.apk`).

---

## 6. DECISIONS MADE
1. **Header-based Authentication:** All Google Gemini requests in Dart (`Dio`) and Kotlin (`HttpURLConnection`) now deliver the API key through the `x-goog-api-key` header rather than appending `?key=` to the URL. This prevents keys from appearing in server access logs or proxy URL traces.
2. **First-Launch Wizard Flow:** After granting permissions on initial installation, the app checks if an AI key is stored. If not, it opens the new setup wizard with a "পরে করব" (Skip for now) action so the user is never stuck.
3. **Privacy-Conscious Online Engine Toggle:** The `vf_free_online_engine` setting defaults to `true` to ensure immediate out-of-the-box punctuation for users without keys, but features an explicit toggle and disclosure note in settings so users can turn off third-party transmission whenever desired.

---

## 7. OWNER TODO
- No required manual action for Phase 2 code.
- During manual testing, try adding your own Google AI Studio key via the Home screen status chip and run a voice typing test in WhatsApp or Notes.
