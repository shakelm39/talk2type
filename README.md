# Talk2Type 🎙️
> **Production-Ready Floating Bengali & English AI Voice-to-Text AutoType for Android**

Talk2Type is a high-performance hybrid mobile application combining a modern Flutter (Material 3) interface with native Android background services (Kotlin). It provides a persistent, draggable floating orb button that stays active on top of any application (WhatsApp, Messenger, Word, Notes, Browser, SMS, etc.).

When an input field is focused, the orb automatically appears. Speaking in Bengali streams live partial text directly into the field, followed by AI-powered punctuation, grammar formatting, and tone adaptation according to the selected mode.

---

## 🚀 Key Features

- **Floating Assistant Orb:** Draggable circular orb with ambient glow, size/opacity settings, and snap-to-edge animation.
- **Smart Focus Visibility:** Automatically shows when an input field is focused and hides when the keyboard/field closes.
- **Continuous Native Speech Engine:** Uses Android `SpeechRecognizer` (`bn-BD`) for instant, continuous recognition with live partial text injection.
- **Multi-Tier AI Fallback:**
  1. *Native continuous speech with AI polish:* Free AI punctuation → Google Gemini → rule-based formatter.
  2. *Audio recording fallback:* If native speech recognition is unavailable, records `.m4a` AAC and processes via Gemini (Tier 1: primary key, Tier 2: backup key) or Groq Whisper + LLaMA (Tier 3).
- **AutoType Accessibility Injection:** Uses Android `AccessibilityService` (`ACTION_SET_TEXT` with `ACTION_PASTE` fallback and clipboard copy) for universal app compatibility.
- **5 Supported Tone Modes:**
  1. **বাংলা (`bangla`):** Clean standard Bengali with natural punctuation (দাঁড়ি, কমা, প্রশ্নবোধক) and removal of filler words.
  2. **অফিসিয়াল (`formal`):** Polite corporate/office Bengali suitable for professional emails and workplace communications.
  3. **কাস্টমার সার্ভিস (`support`):** Courteous, helpful replies for online sellers and support teams without hallucinated facts.
  4. **বন্ধুসুলভ (`casual`):** Warm, colloquial Bengali for friendly chats while preserving informal conversational nuances.
  5. **English (`english`):** Speak in Bengali, type instantly in fluent, grammatically correct English.
- **Customizable System Prompts:** Edit and test per-mode AI prompts directly from the settings dialog.
- **Custom Vocabulary:** Add personal/brand names (বিকাশ, নগদ, রকেট, পাঠাও, চালডাল) to ensure accurate transcription.
- **Local History (SQLite):** View past transcriptions, copy text, or re-type directly into active input fields.
- **Lifetime License Verification:** Integrated with Ayyzan License Hub (`license.ayyzan.com`, appId `talk2type`) with hardware device binding.
- **In-App Updater:** Automated and manual update checking, background APK download, and system installation prompt.
- **CI/CD Automation:** Automated GitHub Actions release pipeline (`.github/workflows/build-release.yml`).

---

## 🏗️ Architecture & Technology Stack

### 1. Flutter Layer (Dart 3 / Material 3)
- **State Management:** Provider (`VoiceFlowProvider`, `PermissionProvider`, `LicenseProvider`, `HistoryProvider`).
- **Storage:** `shared_preferences` (settings, mode, keys, custom prompts) and `sqflite` (history).
- **Networking:** `dio` with robust timeouts and retry logic.
- **Bridge:** Bidirectional `MethodChannel` communication with native Android services.

### 2. Native Android Layer (Kotlin)
- **`FloatingOverlayService`:** `WindowManager` overlay (`TYPE_APPLICATION_OVERLAY`, `FLAG_NOT_FOCUSABLE`), expandable 5-mode pill strip, continuous speech loop, and state animations.
- **`AutoTypeAccessibilityService`:** Inspects focused nodes (`isEditable`), streams live text, and falls back to clipboard when needed.
- **`AudioRecorderHelper`:** High-clarity MPEG-4 / AAC recording at 44.1 kHz, 128 kbps.
- **`MainActivity`:** Handles bridge method calls, update APK installations, and permission checks.

---

## 🎨 Tone Modes Reference

| Key | Title | Short Label | Accent Color | Description |
|---|---|---|---|---|
| `bangla` | বাংলা | বাংলা | `#C81E2E` | Clean standard Bengali with proper punctuation |
| `formal` | অফিসিয়াল | অফিস | `#8B5CF6` | Formal corporate Bengali for email & work |
| `support` | কাস্টমার সার্ভিস | সাপোর্ট | `#10B981` | Courteous customer service replies |
| `casual` | বন্ধুসুলভ | আড্ডা | `#F59E0B` | Warm colloquial Bengali for friendly chats |
| `english` | English | EN | `#3B82F6` | Direct Bengali to English translation |

---

## 🛠️ Build & Verification

```bash
# Get dependencies
flutter pub get

# Static code analysis
flutter analyze

# Run test suite
flutter test

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```
