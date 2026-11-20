# VoiceFlow AI 🎙️ (Talk2Type)
> **Production-Ready Hybrid Android Application for Floating Bengali & English AI Voice-to-Text AutoType**

VoiceFlow AI is a high-performance hybrid mobile application combining a modern Flutter (Material 3) user interface with native Android background services (Kotlin). It provides a persistent, draggable floating orb button that stays active on top of any other application (such as WhatsApp, Messenger, Word, Notes, Browser, Slack, or SMS). When tapped, it records high-clarity voice audio in `.m4a` format, streams it to an AI voice transcription engine (Google Gemini 2.5 Flash or a custom backend hub), formats punctuation and tone according to the selected mode, and uses Android's `AccessibilityService` to directly inject and type the text into whatever input field is currently active.

---

## 🏗️ Architecture & Technology Stack

### 1. Flutter Layer (UI & Orchestration)
- **Framework:** Flutter (Material 3, Dart 3)
- **State Management:** Provider (`MultiProvider` for reactive, decoupled business logic)
- **Local Storage:**
  - `shared_preferences` for license tokens, active tone modes, custom prompts, and Gemini API keys.
  - `sqflite` (SQLite) for storing local transcription history, timestamps, success status, and injection state.
- **Networking:** `dio` with custom interceptors and modular repository interfaces.
- **Native Bridge:** `MethodChannel` on `com.voiceflow.ai/native_bridge` with bidirectional event dispatching.

### 2. Native Android Layer (Kotlin)
- **`FloatingOverlayService` (`WindowManager` & Foreground Service):**
  - Uses `TYPE_APPLICATION_OVERLAY` with `FLAG_NOT_FOCUSABLE`.
  - Draggable circular Orb with pulse rings and visual feedback states (`idle`, `recording`, `processing`, `success`, `error`).
  - Expandable mini-menu on tap or long-press for instant tone switching and service shutdown.
  - Runs with a foreground service notification to avoid Android OS battery killer terminations.
- **`AudioRecorderHelper` (`MediaRecorder`):**
  - Captures microphone audio using MPEG-4 / AAC encoder at 44.1 kHz, 128 kbps to `.m4a` files in the application cache.
- **`AutoTypeAccessibilityService` (`AccessibilityService`):**
  - Monitors `TYPE_VIEW_FOCUSED` and `TYPE_WINDOW_CONTENT_CHANGED` across all window layers.
  - Automatically identifies the active editable `AccessibilityNodeInfo` (`isEditable == true`).
  - Injects formatted text using `ACTION_SET_TEXT` (appending to existing content if present) and positions the text selection cursor at the end.
  - **Clipboard Fallback:** If direct accessibility injection is unavailable or blocked by target app security, it safely copies to `ClipboardManager` and displays a user Toast.
- **`MainActivity.kt` (`MethodChannel` Bridge):**
  - Mediates between Flutter and native services.
  - Forwards `onAudioRecorded` events from background service to Flutter.
  - Exposes permission checking and intent launch methods.

---

## 🎨 Supported Tone Modes

VoiceFlow AI includes 5 specialized tone modes with mode-specific Bengali/English AI instructions:

1. **Clean Bangla (`clean_bangla` - পরিষ্কার বাংলা):**
   - Transcribes natural, standard Bengali (প্রমিত বাংলা).
   - Eliminates filler words (উম, মানে, এ্যাঁ) and inserts proper Bengali punctuation marks (`|`, `,`, `?`).
2. **Office Formal (`office_formal` - অফিসিয়াল ও কর্পোরেট):**
   - Polished corporate vocabulary for emails, Slack messages, and official documentation.
3. **Customer Support (`customer_support` - কাস্টমার সার্ভিস):**
   - Courteous, empathetic, and professional language with polite greetings and resolutions.
4. **Friend Casual (`friend_casual` - বন্ধুসুলভ আড্ডা):**
   - Warm, conversational colloquial Bengali preserving informal nuance and casual expressions.
5. **Bangla to English (`bangla_to_english` - বাংলা থেকে ইংরেজি):**
   - Real-time speech translation: speak in Bengali and have it typed directly in fluent, natural English.

---

## 📁 Project Directory Structure

```
Talk2Type/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml                        # Permissions & Service declarations
│       ├── kotlin/com/voiceflow/ai/voiceflow_ai/
│       │   ├── MainActivity.kt                        # MethodChannel implementation
│       │   └── services/
│       │       ├── AudioRecorderHelper.kt             # MediaRecorder (.m4a AAC) helper
│       │       ├── AutoTypeAccessibilityService.kt    # ACTION_SET_TEXT injection & clipboard fallback
│       │       └── FloatingOverlayService.kt          # WindowManager draggable orb & mini-menu
│       └── res/
│           ├── values/strings.xml                     # App & notification channel strings
│           └── xml/accessibility_service_config.xml   # Accessibility service capabilities
├── lib/
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart                        # Central license & API endpoint configs
│   │   ├── constants/
│   │   │   ├── app_colors.dart                        # Dark theme palette & gradients
│   │   │   └── tone_modes.dart                        # 5 tone modes & default system prompts
│   │   ├── database/
│   │   │   └── history_database.dart                  # SQLite transcription storage
│   │   ├── native/
│   │   │   └── native_bridge.dart                     # Flutter <-> Android Native communication
│   │   ├── network/
│   │   │   └── dio_client.dart                        # Dio HTTP client configuration
│   │   └── theme/
│   │       └── app_theme.dart                         # Material 3 Dark UI theme
│   ├── data/
│   │   ├── models/
│   │   │   ├── license_activation_response.dart       # License validation model
│   │   │   └── transcription_item.dart                # History item model
│   │   └── repositories/
│   │       ├── ai_voice_repository.dart               # Modular repository interface
│   │       ├── backend_api_voice_repository.dart      # Multipart HTTP POST repository
│   │       └── direct_gemini_voice_repository.dart    # Direct Gemini 2.5 Flash API repository
│   ├── presentation/
│   │   ├── providers/
│   │   │   ├── history_provider.dart                  # History state provider
│   │   │   ├── license_provider.dart                  # License gate & device ID provider
│   │   │   ├── permission_provider.dart               # Real-time permission checker
│   │   │   └── voiceflow_provider.dart                # Floating orb, mode & AI pipeline controller
│   │   └── screens/
│   │       ├── history_screen.dart                    # History list with copy & auto-type
│   │       ├── home_control_screen.dart               # Orb toggle switch & tone selector
│   │       ├── license_activation_screen.dart         # License key activation screen
│   │       ├── permission_dashboard_screen.dart       # Real-time permission checklist cards
│   │       ├── splash_gate_screen.dart                # Splash animation & navigation gate
│   │       └── test_ai_dialog.dart                    # In-app Gemini/Endpoint tester & injection demo
│   └── main.dart                                      # Application root entry point
└── pubspec.yaml                                       # Project dependencies
```

---

## ⚙️ Configuration & Testing

Edit `lib/core/config/app_config.dart` or open the in-app **AI Config & Test** dialog (top right slider icon):

```dart
class AppConfig {
  // Set to false for instant local testing without backend authentication
  static const bool enableLicenseCheck = false;

  // Custom backend endpoints (if enableLicenseCheck is true)
  static String licenseApiEndpoint = "https://your-license-hub.com";
  static String aiProcessEndpoint = "https://your-license-hub.com";

  // Optional direct Google Gemini 2.5 Flash API key for instant testing
  static String directGeminiApiKey = "";
}
```

### In-App AI Testing
Tap the **AI Config & Test** icon (`tune`) on the top right of the Home screen:
1. Enter your **Google Gemini API Key** or custom backend endpoint.
2. View and customize the active mode's **System Prompt**.
3. Use the **Live AutoType Injection Test** to click into an input field and witness the Accessibility Service automatically inject Bengali text.

---

## 🚀 Building & Running

### Prerequisites
- Flutter SDK (v3.13.7+)
- Android SDK (API 26+)
- Physical Android device or Emulator with Google Play Services

### Commands
```bash
# Get dependencies
flutter pub get

# Run static analysis (0 warnings / 0 errors)
flutter analyze

# Run unit tests
flutter test

# Run on connected Android device
flutter run
```
