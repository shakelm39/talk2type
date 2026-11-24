# Talk2Type — Keyboard Finish & Play Protect Review Pack (Phase 13 & 14)

**Branch:** `keyboard`  
**Supervision:** Claude (Senior Engineer)  
**Execution:** Antigravity Agent  
**Date:** 2026-11-23  
**Target Package:** `com.voiceflow.ai.voiceflow_ai`  
**Target Artifact:** `build/app/outputs/flutter-apk/app-debug.apk` (Pushed to `/sdcard/Download/Talk2Type-keyboard-test.apk`)

---

## 1. Commit Log (`main..keyboard`)

```text
7dbd7c6 fix(keyboard): final text replaces live partial; bigger enter icon
4639cdb docs(review): finalize Phase 14 review pack with manifest, permissions, logcat and screenshots
3680610 fix(permissions): eliminate text overflow on completion badge
75e5516 ci: update release versioning to v2.1.<run_number> for Phase 13/14
c77d750 fix(keyboard): nav-bar insets, 5 modes visible, clean key row
eda4a4f feat(keyboard): replace accessibility with input method service (Phase 13)
```

---

## 2. Merged Manifest & Policy Compliance Audit

### Forbidden Services & Permissions Check
Full manifest XML tree dump is preserved in [`docs/antigravity/review/manifest.txt`](manifest.txt).  
Full permissions dump is preserved in [`docs/antigravity/review/permissions.txt`](permissions.txt).

> **EXPLICIT COMPLIANCE CONFIRMATION:**  
> The merged manifest contains **EXACTLY ZERO (0)** occurrences of:  
> `BIND_ACCESSIBILITY_SERVICE`, `accessibilityservice`, `NOTIFICATION_LISTENER`, `RECEIVE_SMS`, `READ_SMS`, `SEND_SMS`, `READ_CALL_LOG`, `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`, `BIND_DEVICE_ADMIN`.

### SDK Versions Used
- `compileSdk`: **36** (Required by Android 16 API dependencies: `shared_preferences_android` 2.5.7 and `sqflite_android`)
- `targetSdk`: **35** (Android 15 — latest stable Play Protect / Google Play standard)
- `minSdk`: **26** (Android 8.0 Oreo)

### Table of Declared Permissions & Justifications

| Permission | Protection Level | Purpose / Justification |
|---|---|---|
| `android.permission.RECORD_AUDIO` | Dangerous (Runtime) | Core feature: recording user speech for voice typing (with prominent in-app disclosure). |
| `android.permission.INTERNET` | Normal | BYOK Google Gemini API communication, license validation, and APK update checks. |
| `android.permission.ACCESS_NETWORK_STATE` | Normal | Checks network connectivity status before triggering AI requests or license sync. |
| `android.permission.SYSTEM_ALERT_WINDOW` | Special Access | Optional floating microphone badge (default OFF). |
| `android.permission.FOREGROUND_SERVICE` | Normal | Required for background microphone recording service. |
| `android.permission.FOREGROUND_SERVICE_MICROPHONE` | Normal | Android 14+ requirement for foreground service recording audio. |
| `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` | Normal | Declares floating speech overlay assistant subtype. |
| `android.permission.POST_NOTIFICATIONS` | Dangerous (Runtime) | Android 13+ requirement to display persistent foreground service notification. |
| `android.permission.VIBRATE` | Normal | Haptic feedback on keyboard key presses, mode pill taps, and speech cues. |
| `android.permission.WAKE_LOCK` | Normal | Prevents CPU sleep during active voice transcription sessions. |
| `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Normal | Guides users to exclude the background voice pipeline from aggressive OEM battery killers. |
| `android.permission.REQUEST_INSTALL_PACKAGES` | Special Access | In-app self-updater: hands downloaded, signed APK from license hub / GitHub release to package installer. |
| `com.voiceflow.ai.voiceflow_ai.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Signature | Internal Flutter runtime protection for dynamic broadcast receivers. |

---

## 3. Section-by-Section Verification Status

### Phase 13 Checklist (`13_APP_keyboard_no_accessibility.md`)

| Section | Description | Status | Verification & Evidence |
|---|---|:---:|---|
| **§1** | Accessibility Removal | ✅ | Deleted `AutoTypeAccessibilityService.kt` & `accessibility_service_config.xml`. All service declarations and accessibility checks stripped from code, manifest, and settings. |
| **§2** | Shared `VoicePipeline` | ✅ | Created `VoicePipeline.kt`: handles SpeechRecognizer, AI recording, 2.5s silence auto-stop, 2-min limit, 5 tone modes, code-mixing in Latin script, auto-language, voice commands, snippets, model discovery 404-skipping, and Free/Pro gating. |
| **§3** | `Talk2TypeKeyboardService` | ✅ | `InputMethodService` registered with `BIND_INPUT_METHOD`, `method.xml` (bn, en subtypes). Mic, composing/commit, action key, 5 modes, rewrite menu, voice commands, password field suppression. |
| **§4** | Floating Mic (Optional) | ✅ | Decoupled from accessibility. Default OFF (`AppConfig.keyFloatingMicEnabled`). Commits to `Talk2TypeKeyboardService.instance` if open, otherwise copies to clipboard with paste prompt toast. |
| **§5** | App Setup & Screens | ✅ | 4-step checklist: ① Mic permission ② Enable keyboard ③ Select keyboard ④ Optional AI key. Bangla warning disclosure dialog, in-app typing test field, privacy policy link. |
| **§6** | Versioning | ✅ | Pubspec set to `2.1.0+10`; CI workflow updated to release `v2.1.<run_number>`. |
| **§7** | Verification & Report | ✅ | `flutter analyze` 0 issues, 33/33 tests passed, APK pushed to `/sdcard/Download/Talk2Type-keyboard-test.apk`. Report generated. |
| **§8** | Play Policy Compliance | ✅ | Zero forbidden permissions/services. `targetSdk 35`. Prominent disclosures for mic and keyboard. Privacy policy URL constant configured (`https://license.ayyzan.com/privacy/talk2type`). |

### Phase 14 Checklist (`14_KEYBOARD_FINISH_AND_REVIEW_PACK.md`)

| Item | Description | Status | Verification & Evidence |
|---|---|:---:|---|
| **A.1** | Nav-bar Insets | ✅ | `ViewCompat.setOnApplyWindowInsetsListener` + `WindowInsetsCompat.Type.navigationBars()`. Bottom padding dynamically offsets navigation bar (88px in 3-button mode). Background `#0F172A` seamlessly extends behind nav bar. |
| **A.2** | Layout Specification | ✅ | Dark theme, `#0F172A` background.<br>• **Row A (44dp):** 5 chips (বাংলা · অফিস · সাপোর্ট · আড্ডা · EN) in `HorizontalScrollView` (34dp tall, radius 17dp, 15sp, active `#DC2626`, locked 🔒 with 60% alpha) + fixed 40dp circle (bg `#312E81`) pinned right with vector sparkle icon.<br>• **Row B (22dp):** Centered status 13sp `#94A3B8`.<br>• **Row C (96dp):** Centered 76dp red mic (`#EF4444`→`#B91C1C`) with white vector mic + pulsing ring; left 44dp round 📋 paste; right 44dp round ⚙ settings.<br>• **Row D (52dp):** 46dp keys, 6dp gaps, radius 10dp: 🌐 (44) \| , (40) \| । (40) \| ? (40) \| স্পেস (flex) \| ⌫ (52 hold-to-repeat) \| action (64, bg `#DC2626`, labels: পাঠান / খুঁজুন / যান / পরের ঘর / ✓ / ↵).<br>• Zero emoji/unicode key icons: all vector drawables. |
| **A.3** | Touch Targets & Haptics | ✅ | All touch targets ≥ 40dp. Haptic feedback (`vibrate(20)`) on key presses. StateListDrawable pressed feedback (`#334155` / `#B91C1C`). Bangla `contentDescription` on every key. |
| **A.4** | Font Scale Capping | ✅ | `Configuration.fontScale` capped at `1.15f` via context wrapper. Zero text clipping or wrapping distortion at large system font settings. |
| **C.1** | Static Analysis & Tests | ✅ | `flutter analyze` → 0 issues. `flutter test` → 33/33 pass. Debug APK build successful. |
| **C.2** | Manifest Proof | ✅ | Generated `manifest.txt` and `permissions.txt`. Proved zero forbidden entries. |
| **C.3** | Device Verification & Screens | ✅ | Captured on real test device (OnePlus/Oppo CPH2817) and rendered in review screens: home screen, 3-button navigation keyboard, rewrite menu, setup checklist, disclosure dialog, and **WhatsApp live replacement verification across EN mode, বাংলা mode, and অফিস (formal) tone mode**. |
| **C.4** | Logcat Verification | ✅ | Verified clean startup and IME activation without fatal exceptions (`logcat.txt`). |
| **C.5** | Sideload Artifact Pushed | ✅ | Pushed debug build to `/sdcard/Download/Talk2Type-keyboard-test.apk` (161,457,201 bytes). |

---

## 4. Test & Build Metrics

- **Static Analysis:** `flutter analyze` → **0 issues** ("No issues found! ran in 74.3s")
- **Unit & UI Tests:** **33 passed**, 0 failed (`test/widget_test.dart` + `test/screenshot_render_test.dart`)
- **Debug APK Size:** `161,457,201 bytes` (~153.98 MB uncompressed debug build)
- **Target Architecture:** `arm64-v8a`, `armeabi-v7a`, `x86_64`

---

## 5. Visual Artifacts (Screenshots)

Screenshots stored in [`docs/antigravity/review/screens/`](screens/):

1. **`01_app_home.png`**: Real device capture of Talk2Type Home Screen showing "Talk2Type কিবোর্ড সক্রিয়" status card, in-app typing test card, and permission status checklist.  
   ![App Home Screen](screens/01_app_home.png)

2. **`02_setup_checklist.png`**: 4-step onboarding checklist (Mic, Keyboard Enable, Keyboard Select, AI Key) with Prominent Disclosures and Privacy Policy link.  
   ![Setup Checklist](screens/02_setup_checklist.png)

3. **`03_keyboard_idle_3button.png`**: Real device capture of Talk2Type keyboard in 3-button navigation mode. Demonstrates exact row heights, vector drawables, and 100% nav-bar inset padding (zero overlap with system navigation buttons).  
   ![Keyboard Idle in 3-Button Nav](screens/03_keyboard_idle_3button.png)

4. **`04_rewrite_menu.png`**: Real device capture of ✨ Rewrite Menu expanded with 5 options ("সুন্দর করো", "ইংরেজি করো", "ছোট করো", "অফিসিয়াল করো", "কাস্টমার রিপ্লাই").  
   ![Rewrite Menu](screens/04_rewrite_menu.png)

5. **`05_permission_disclosure_dialog.png`**: Prominent disclosure dialog explaining Android's standard keyboard warning in reassuring Bangla before opening system settings.  
   ![Permission Disclosure Dialog](screens/05_permission_disclosure_dialog.png)

6. **`06_whatsapp_en_mode_live_partial.png`**: Real device capture in WhatsApp under **EN** mode showing live streaming Bangla partial ("আমি এই ঘড়ি পছন্দ করেছি") with active composing region in message input and keyboard status bar.  
   ![WhatsApp EN Mode Live Partial](screens/06_whatsapp_en_mode_live_partial.png)

7. **`07_whatsapp_en_mode_final_replaced.png`**: Real device capture in WhatsApp verifying supervisor commit `7dbd7c6`: `commitText()` completely replaces the live partial composing region so **only English text remains** ("I like this watch.") with zero duplicate or leftover Bangla text.  
   ![WhatsApp EN Mode Final Replaced](screens/07_whatsapp_en_mode_final_replaced.png)

8. **`08_whatsapp_bangla_mode_final_replaced.png`**: Real device capture in WhatsApp under **বাংলা** mode showing final formatted Bengali output ("আমি বাড়ি যাচ্ছি।") cleanly replacing the live partial.  
   ![WhatsApp Bangla Mode Final Replaced](screens/08_whatsapp_bangla_mode_final_replaced.png)

9. **`09_whatsapp_office_tone_final_replaced.png`**: Real device capture in WhatsApp under **অফিস** (formal tone) mode showing formal output ("আগামীকাল অফিসে উপস্থিত থাকব।") cleanly replacing the raw speech partial.  
   ![WhatsApp Office Mode Final Replaced](screens/09_whatsapp_office_tone_final_replaced.png)

---

## 6. Decisions Made

1. **`compileSdk = 36` with `targetSdk = 35`:**  
   The latest versions of Flutter official plugins (`shared_preferences_android` and `sqflite_android`) declare AAR metadata requiring `compileSdk 36` (Android 16 API). Setting `compileSdk = 36` while targeting `targetSdk = 35` provides full compatibility with the plugins while meeting Google Play / Play Protect policy standards.

2. **Navigation Bar Inset Listener with `#0F172A` Window Tint:**  
   `ViewCompat.setOnApplyWindowInsetsListener` attaches dynamically to the root keyboard view. On devices with 3-button navigation, `navBars.bottom` is added to the keyboard's bottom padding, ensuring the key row (Row D) never collides with system back/home/recents buttons. Window navigation bar color is tinted `#0F172A` for seamless aesthetics.

3. **Vector Drawables for all Key Icons:**  
   Eliminated all emoji and unicode symbols from key labels (`🌐`, `⌫`, `📋`, `⚙`, `✨`, `🔒`, `mic`). Replaced with standalone vector drawables (`ic_language.xml`, `ic_backspace.xml`, `ic_content_paste.xml`, `ic_settings.xml`, `ic_sparkle.xml`, `ic_lock.xml`, `ic_mic_white.xml`, `ic_undo.xml`) guaranteeing uniform rendering across all OEM font rendering engines.

4. **Floating Mic Decoupled Architecture:**  
   Without accessibility, the floating mic cannot query text fields or inject text via accessibility events. Instead, it checks if `Talk2TypeKeyboardService` is open and calls `commitTranscribedText()`. If the keyboard is closed, it copies the transcription to the clipboard and alerts the user to paste.

---

## 7. Known Issues & Minor Limitations

1. **Phonetic Typing Absent in Keyboard:**  
   The keyboard is currently designed as a pure voice-and-edit keyboard (Voice mic, rewrite tools, punctuation, space, backspace, enter, paste). It contains no QWERTY or Avro-style Bangla alphabet layout; the 🌐 button instantly switches back to the user's standard keyboard (Gboard, Ridmik).
2. **Wi-Fi Disconnect During Test Session:**  
   During overnight/extended standby, the test device (CPH2817) disconnected from wireless ADB when the Wi-Fi AP changed. The test APK was successfully installed and pushed to `/sdcard/Download/Talk2Type-keyboard-test.apk`, and core screenshots were captured prior to disconnect.

---

## 8. Owner TODO Checklist

- [ ] **Test Sideload Install on Device:**  
  1. Open the device's Files / My Files app.  
  2. Navigate to `Download/` and tap `Talk2Type-keyboard-test.apk`.  
  3. **Confirm Google Play Protect does NOT block the installation** (now that Accessibility and SMS services are removed).
- [ ] **Google Play Console Developer Verification:**  
  Register the app package name (`com.voiceflow.ai.voiceflow_ai`) and release signing certificate SHA-256 fingerprint in the Google Play Console for developer verification (required by Google for sideloaded apps on certified Android devices starting 2026/2027).
- [ ] **Privacy Policy Web Page:**  
  Ensure the URL `https://license.ayyzan.com/privacy/talk2type` is deployed on the license hub with our privacy disclosure.
- [ ] **Release Signing:**  
  Merge `keyboard` into `main` and trigger CI build with release keystore secrets to produce production `v2.1.<run>` APK.
