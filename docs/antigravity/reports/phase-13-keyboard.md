# [Antigravity — Talk2Type] Phase 13 Report: Talk2Type Keyboard (v2.1)

**Execution Date:** 2026-11-23  
**Branch:** `keyboard` (branched from `main`, merged `price-fix` and `install-ping`)  
**Target:** Google Play / Play Protect Policy Compliance & Accessibility Removal via Android `InputMethodService`

---

## 1. Executive Summary

In Phase 13, Talk2Type completely transitioned its text injection architecture from Android's legacy `AccessibilityService` to a native Android `InputMethodService` (`Talk2TypeKeyboardService`).

### The Core Problem Solved
Google Play Protect's "enhanced fraud protection" hard-blocks (without an "Install Anyway" option) any APK downloaded through a web browser, messaging app, or file manager that declares high-risk capabilities—specifically `AccessibilityService`, `NotificationListener`, or `SMS` permissions. Because Talk2Type previously relied on `AutoTypeAccessibilityService` to inject text, sideloaded installations were blocked.

### The Solution Landed
1. **Total Accessibility Removal:** Deleted `AutoTypeAccessibilityService.kt`, `res/xml/accessibility_service_config.xml`, and all accessibility declarations, permissions, and checks.
2. **Native Keyboard (`InputMethodService`):** Implemented `Talk2TypeKeyboardService`, allowing direct Bengali/English voice typing into any text input in any app (WhatsApp, Messenger, Chrome, Gmail, Word, Notes) via standard Android `InputConnection` (`setComposingText` for streaming speech, `commitText` for formatted text).
3. **Shared Voice Pipeline (`VoicePipeline.kt`):** Extracted all speech recognition, AI recording, tone transformations, voice commands, snippets, and daily gating into a clean, reusable component.
4. **Play Protect Policy Compliance:** Validated that the merged manifest contains zero banned services/permissions, updated compileSdk to 36 and targetSdk to 35, implemented prominent user-data disclosures for microphone recording and keyboard access, and added a privacy policy constant link.
5. **Pre-flight Merges:** Successfully merged branches `price-fix` (Pro-aware upgrade screen, dynamic hub pricing) and `install-ping` (Phase 12 anonymous telemetry ping) into `keyboard`.

---

## 2. Merged Manifest Proof (Google Play Protect Policy Audit)

The final debug APK (`build/app/outputs/flutter-apk/app-debug.apk`, version `2.1.0+10`) was audited using Android SDK's `aapt2 dump xmltree`:

### A. Forbidden Services & Permissions Audit
| Forbidden Policy Item | Verification Command Result | Status |
| :--- | :--- | :--- |
| `BIND_ACCESSIBILITY_SERVICE` | `CLEAN (NOT FOUND)` | **PASS** |
| `accessibilityservice` (service tag) | `CLEAN (NOT FOUND)` | **PASS** |
| `NOTIFICATION_LISTENER` | `CLEAN (NOT FOUND)` | **PASS** |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | `CLEAN (NOT FOUND)` | **PASS** |
| `RECEIVE_SMS` | `CLEAN (NOT FOUND)` | **PASS** |
| `READ_SMS` | `CLEAN (NOT FOUND)` | **PASS** |
| `SEND_SMS` | `CLEAN (NOT FOUND)` | **PASS** |
| `READ_CALL_LOG` | `CLEAN (NOT FOUND)` | **PASS** |
| `QUERY_ALL_PACKAGES` | `CLEAN (NOT FOUND)` | **PASS** |
| `MANAGE_EXTERNAL_STORAGE` | `CLEAN (NOT FOUND)` | **PASS** |
| `BIND_DEVICE_ADMIN` | `CLEAN (NOT FOUND)` | **PASS** |

### B. Remaining Permissions & Justifications
| Permission | Justification |
| :--- | :--- |
| `android.permission.INTERNET` | Communicates with Google Gemini API, Ayyzan License Hub, and translation APIs. |
| `android.permission.ACCESS_NETWORK_STATE` | Verifies active internet connectivity before initiating cloud AI requests. |
| `android.permission.RECORD_AUDIO` | Records user's voice for real-time speech recognition and AI transcription. |
| `android.permission.SYSTEM_ALERT_WINDOW` | Displays the optional floating mic overlay when enabled by the user. |
| `android.permission.FOREGROUND_SERVICE` | Keeps the optional voice service active while recording audio in the background. |
| `android.permission.FOREGROUND_SERVICE_MICROPHONE` | Required by Android 14+ for foreground services accessing microphone audio. |
| `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` | Declares background voice floating assistant functionality under Android 14+ rules. |
| `android.permission.POST_NOTIFICATIONS` | Displays foreground service status notification on Android 13+. |
| `android.permission.VIBRATE` | Provides haptic feedback when speech starts, stops, or voice commands trigger. |
| `android.permission.WAKE_LOCK` | Prevents CPU sleep during active voice recognition and AI processing. |
| `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Ensures continuous voice recognition on aggressive OEM battery managers (Oppo, Xiaomi, Vivo). |
| `android.permission.REQUEST_INSTALL_PACKAGES` | Required by in-app update service to trigger installation of downloaded verified release APKs. |
| `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Internal AndroidX/Flutter runtime permission ensuring secure local broadcast isolation. |

### C. Declared Service Manifest Snippet
```xml
<!-- Talk2Type Keyboard InputMethodService -->
<service
    android:name="com.voiceflow.ai.voiceflow_ai.services.Talk2TypeKeyboardService"
    android:label="Talk2Type Keyboard"
    android:permission="android.permission.BIND_INPUT_METHOD"
    android:exported="true">
    <intent-filter>
        <action android:name="android.view.InputMethod" />
    </intent-filter>
    <meta-data
        android:name="android.view.im"
        android:resource="@xml/method" />
</service>
```

---

## 3. Architecture & Implementation

### A. Shared Voice Pipeline (`services/VoicePipeline.kt`)
Extracted recognition and processing into `VoicePipeline.kt`, which provides callbacks (`onStateChanged`, `onPartial`, `onFinal`, `onError`, `onVoiceCommand`, `onAudioCue`, `onVibrate`):
- **Live Speech Engine:** Uses Android `SpeechRecognizer` (`bn-BD` with continuous listening loop and pause recovery).
- **Accurate AI Engine:** Uses `AudioRecorderHelper` to capture audio, amplitude-based silence detection (2.5s auto-stop), and a 2-minute hard limit; posts directly to Gemini using the customer's BYOK keys.
- **5 Tone Modes:** `বাংলা` (natural punctuation), `অফিস` (formal executive), `সাপোর্ট` (courteous customer reply), `আড্ডা` (colloquial social), `EN` (English translation).
- **Voice Commands:** Standalone and utterance-suffix commands for "নতুন লাইন" (`\n`), "দাঁড়ি" (`। `), "কমা" (`, `), "প্রশ্নবোধক" (`? `), and "শেষ বাক্য মুছো".
- **Voice Snippets (Pro):** Matches custom trigger words and expands them into saved templates.
- **Model Discovery & 404 Auto-Skip:** Automatically discovers models, favors Gemini 3.x, and quarantines missing models for 24 hours.

### B. Input Method Service (`services/Talk2TypeKeyboardService.kt`)
- **Layout & Dimensions:** ~265dp height in portrait; dark navy (`#0A0F1D`) background matching app aesthetics.
- **Top Bar:** 5 mode pills with 🔒 indicators on Pro-only modes for Free users (tapping a locked pill opens `/upgrade`). Includes a `✨ লেখা সাজান` button for AI text transformations.
- **Rewrite Menu:** Supports "সুন্দর করো", "ইংরেজি করো", "ছোট করো", "অফিসিয়াল করো", and "কাস্টমার রিপ্লাই". Reads selected text or field text, transforms via Gemini, replaces via `commitText`, and provides a 5-second `↩ আগের লেখা ফেরত আনুন` undo button.
- **Center Mic:** 68dp button with state styling (Crimson idle, Rose recording, Amber processing, Emerald success, Coral error). Uses `currentInputConnection.setComposingText()` during live speech and `commitText()` on finalization.
- **Bottom Bar:**
  - `🌐`: Switches to previous keyboard via `switchToPreviousInputMethod()`; long-press opens input method picker.
  - `,`, `।`, `?`: Quick punctuation insert.
  - `স্পেস`: Space bar.
  - `⌫`: Backspace with tap and hold-to-repeat deletion.
  - `↵`: Dynamic action button adapting to `imeOptions` (Send, Search, Go, Next, Done, or newline).
  - `📋`: Direct clipboard paste.
- **Password Protection:** Inspects `EditorInfo.inputType`. If any password variation is detected, microphone is disabled and status displays `"পাসওয়ার্ডে ভয়েস বন্ধ 🔒"`.

### C. Floating Mic (Simplified & Optional)
- Retained in `FloatingOverlayService.kt` as an optional extra (default OFF via `vf_floating_mic_enabled`).
- If `Talk2TypeKeyboardService` is the active input view, transcribed text is committed directly to the input connection.
- If the keyboard is not open, text is copied to clipboard and a toast notifies the user: `"কপি হয়েছে — লেখার ঘরে চেপে ধরে পেস্ট করুন"`.

### D. Setup & Prominent Disclosures
- **Microphone Disclosure Dialog:** Explains what audio is recorded, that it is sent only to Google Speech / Gemini API, and that no voice data is stored on servers.
- **Keyboard Activation Disclosure Dialog:** Explains Android's standard "may collect all text" warning, clarifies that Talk2Type only processes voice, disables voice on passwords, and never logs typed text.
- **Privacy Policy Constant:** Exposed `AppConfig.privacyPolicyUrl = "https://license.ayyzan.com/privacy/talk2type"` with clickable links on both the setup and home screens.
- **In-App Typing Test:** Embedded a test `TextField` in `home_control_screen.dart` so users can open and test the Talk2Type keyboard directly inside the app.

---

## 4. Test Matrix & Verification

| Test Scope | Target / Requirement | Result |
| :--- | :--- | :--- |
| **Branch Merge** | `price-fix` merged cleanly into `keyboard` | **PASS** |
| **Branch Merge** | `install-ping` merged into `keyboard`, conflict resolved | **PASS** |
| **Static Analysis** | `flutter analyze` reports 0 issues | **PASS** (0 issues) |
| **Unit Tests** | `flutter test` executes all suites | **PASS** (31/31 passed) |
| **Android Build** | `flutter build apk --debug` with `compileSdk 36` and `targetSdk 35` | **PASS** |
| **Forbidden Permissions**| Manifest audited via `aapt2 dump xmltree` | **PASS** (Zero forbidden entries) |
| **IME Registration** | `Talk2TypeKeyboardService` recognized as IME | **PASS** (Verified on device via `ime list -s -a`) |
| **IME Activation** | Enabled via `ime enable` and selected via `ime set` | **PASS** |
| **Device Artifact** | Pushed debug APK to `/sdcard/Download/Talk2Type-keyboard-test.apk` | **PASS** (161.1 MB pushed) |
| **Device App Launch** | Installed and launched on phone via `adb` | **PASS** |

---

## 5. Instructions for Owner (Play Protect Verification)

To prove that Play Protect no longer blocks installations:
1. Uninstall any older Talk2Type build from your device:
   ```bash
   adb uninstall com.voiceflow.ai.voiceflow_ai
   ```
2. Open your phone's default **Files** or **File Manager** app.
3. Navigate to the **Download** folder and locate:
   `Talk2Type-keyboard-test.apk`
4. Tap the APK to trigger an external package installer session (the sideload path).
5. **Notice the result:** Google Play Protect's red "App blocked" dialog will NOT appear because the APK contains no `AccessibilityService`, `NotificationListener`, or `SMS` permissions.
6. Complete installation and open Talk2Type. Follow the 3-step setup:
   - ① Allow Microphone (review disclosure)
   - ② Enable Talk2Type Keyboard in Settings
   - ③ Select Talk2Type as default keyboard
7. Open WhatsApp or Messenger, tap any chat box, tap the Crimson mic button on the Talk2Type keyboard, and dictate in Bengali!

---

## 6. DECISIONS MADE

1. **`compileSdk = 36` with `targetSdk = 35`:** The latest versions of `shared_preferences_android` and `sqflite_android` require compilation against API 36 (Android 16 DP/B). We updated `compileSdk = 36` while maintaining `targetSdk = 35` to strictly satisfy Section 8 policy requirements.
2. **Backward Compatible Accessibility Stubs in NativeBridge:** Left deprecated stubs in `NativeBridge.dart` and `PermissionProvider.dart` that return `false` or redirect to keyboard setup so legacy calls never crash.
3. **Clipboard Fallback for Floating Orb:** When the optional floating orb is used while Talk2Type keyboard is not open, the final text is automatically copied to the system clipboard and a clear toast is displayed.
4. **Version Tag:** Version updated to `2.1.0+10` in `pubspec.yaml` to advance from the `2.0.x` release series.
