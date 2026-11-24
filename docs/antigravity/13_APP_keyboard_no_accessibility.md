# [Antigravity — Talk2Type] Phase 13 (v2.1): Talk2Type Keyboard — remove Accessibility so Play Protect never blocks install

Commit only, NEVER push, debug builds only, never touch keystore/key.properties, never print API keys/tokens.
Branch: `keyboard` from `main`. If branches `price-fix` and/or `install-ping` exist and their reports say they are complete, merge them into `keyboard` first (`git merge --no-ff`), resolving conflicts carefully; note this in the report.

## Why (owner decision)
Google Play Protect "enhanced fraud protection" hard-blocks ("App blocked to protect your device", no install-anyway) any APK installed from a browser / messaging app / file manager that declares one of: ACCESSIBILITY service, NOTIFICATION_LISTENER, RECEIVE_SMS, READ_SMS. Talk2Type declares an AccessibilityService → every customer install is blocked.
**Goal: the released APK must declare NONE of those**, and text must still go into any app (WhatsApp, Messenger, Chrome, Gmail…) — via our own keyboard (InputMethodService), which is not on Play Protect's list.

## 1. Remove Accessibility completely (allowed to delete these files)
- Delete `AutoTypeAccessibilityService.kt`, `res/xml/accessibility_service_config.xml`, its `<service>` in AndroidManifest, every reference (26+ call sites), the accessibility permission UI, the Android-13 "restricted settings" card, accessibility checks in permission/setup screens and in NativeBridge/MainActivity.
- Never add NOTIFICATION_LISTENER, SMS permissions or `BIND_NOTIFICATION_LISTENER_SERVICE`.
- After building, PROVE it: run `aapt2 dump xmltree --file AndroidManifest.xml app-debug.apk` (or apkanalyzer manifest print) and paste in the report that the merged manifest contains no `BIND_ACCESSIBILITY_SERVICE`, `accessibilityservice`, `NOTIFICATION_LISTENER`, `RECEIVE_SMS`, `READ_SMS` — including from plugins/dependencies.

## 2. Shared voice pipeline (refactor, no behaviour change)
Move the recognition + text-processing logic out of `FloatingOverlayService.kt` into a reusable Kotlin class (e.g. `services/VoicePipeline.kt`): SpeechRecognizer live session (bn-BD, partials), AI engine recording (AudioRecorderHelper → Gemini audio, using the same keys and `flutter.vf_gemini_models` order + 404 skip as Dart), 5 tone modes + custom prompts, bangla polish / translation fallbacks, voice commands, snippets, Free/Pro gating + daily counter (`flutter.vf_is_pro`, `vf_daily_*`), history notification to Flutter. Output goes to a callback (`onPartial(text)`, `onFinal(text)`, `onError(msg)`) instead of directly to accessibility.

## 3. New `Talk2TypeKeyboardService : InputMethodService` (the main way to type)
Register with `android.permission.BIND_INPUT_METHOD`, `res/xml/method.xml` (Bangla + English subtypes, settingsActivity → MainActivity). Dark UI matching the app (navy, crimson mic). Layout (portrait, ~260dp tall):
- Top row: 5 mode pills (বাংলা · অফিস · সাপোর্ট · আড্ডা · EN; 🔒 on Pro-only for Free users → tapping opens the app's upgrade screen) and a ✨ button.
- Centre: big mic button. Tap = start, tap = stop (also auto-stop on silence like the AI engine). While speaking: live partial text via `currentInputConnection.setComposingText()`; final text via `commitText()` (replaces the composing text). States + vibration + sound like the orb. Short status line ("শুনছি…", "গুছিয়ে দিচ্ছি…").
- Bottom row: 🌐 (switch back to previous keyboard: `switchToPreviousInputMethod()`; long-press → `showInputMethodPicker`), `,` `।` `?`, long space bar, ⌫ (hold to repeat), ↵ (respect `imeOptions` action: send/search/go/next/newline), 📋 paste.
- ✨ rewrite menu: "সুন্দর করো / ইংরেজি করো / ছোট করো / অফিসিয়াল করো / কাস্টমার রিপ্লাই" — read selected text (`getSelectedText`) or whole field (`getExtractedText`/`getTextBeforeCursor`+`After`), transform with Gemini (Pro + key), replace via `setSelection`+`commitText`; keep a 5-second "ফেরত আনুন" (undo).
- Voice commands ("নতুন লাইন", "দাঁড়ি", "কমা", "প্রশ্নবোধক", "শেষ বাক্য মুছো", "সব মুছো" with confirm) operate through InputConnection.
- RECORD_AUDIO: if not granted, show "মাইক অনুমতি দিন" in the keyboard that opens the app's permission screen (an IME cannot request it itself).
- Password fields (`TYPE_TEXT_VARIATION_PASSWORD` etc.): mic disabled, show "পাসওয়ার্ডে ভয়েস বন্ধ".
- No basic letter typing in this version — the 🌐 key returns to the user's normal keyboard. (Write a short note for a later full phonetic layout.)

## 4. Floating mic (optional, simplified)
Keep the overlay orb as an OPTIONAL extra, default OFF, setting "ভাসমান মাইক": tap → speak → if Talk2Type keyboard is the current input method, send the final text to the keyboard service to commit; otherwise copy to clipboard and toast "কপি হয়েছে — লেখার ঘরে চেপে ধরে পেস্ট করুন". No focus auto-show (that needed accessibility): the orb stays visible while enabled; drag to a "✕" zone to turn off. If this adds risk, keep it but simple.

## 5. App setup & screens
- Setup checklist becomes: ① মাইক অনুমতি ② Talk2Type কিবোর্ড চালু করুন (open `Settings.ACTION_INPUT_METHOD_SETTINGS`; detect enabled via `InputMethodManager.enabledInputMethodList`) ③ কিবোর্ড বেছে নিন (`showInputMethodPicker`; detect current via `Settings.Secure.DEFAULT_INPUT_METHOD`) ④ (ঐচ্ছিক) AI Key. Re-check on resume, green ✓ pills.
- Explain Android's standard warning in Bangla: "Android সব কিবোর্ডের ক্ষেত্রেই বলে 'সব লেখা সংগ্রহ করতে পারে'। Talk2Type শুধু আপনার বলা কথা লেখায় রূপান্তর করে, কিছু সংরক্ষণ বা পাঠায় না।"
- Home: replace orb-centric texts with keyboard-centric ones; keep history, snippets, voice-note share, settings, update, license.
- In-app "টাইপিং টেস্ট": a TextField where the user can open the Talk2Type keyboard and try.

## 6. Versioning
Change CI to `2.1.<run_number>` (VERSION_NAME and tag `v2.1.<run>`), so it is newer than 2.0.x. Existing 2.0.x users update in-app normally (same signature).

## 7. Verify & report
- `flutter analyze` 0, `flutter test` pass (add tests for gating/commands logic that moved), debug build OK.
- On my phone via adb: enable + select the keyboard, dictate in WhatsApp (bangla + a tone mode + EN), ✨ rewrite, voice commands, password field, 🌐 switch back, Free lock behaviour. Screenshots to `docs/antigravity/screens/keyboard/`.
- Push the debug APK to the phone's Download folder (`adb push app-debug.apk /sdcard/Download/Talk2Type-keyboard-test.apk`) and write in the report: "Owner: uninstall Talk2Type, then install this file from the Files app (that is an internet-sideload path) and confirm Play Protect does NOT block it."
- Report `docs/antigravity/reports/phase-13-keyboard.md` incl. the manifest proof and DECISIONS MADE. STOP.

## 8. Google Play / Play Protect policy checklist (must all pass — owner asked for full policy compliance)
1. Merged manifest has NO Accessibility service, NotificationListener, RECEIVE_SMS/READ_SMS/SEND_SMS, READ_CALL_LOG, QUERY_ALL_PACKAGES, MANAGE_EXTERNAL_STORAGE, BIND_DEVICE_ADMIN. List every remaining permission in the report with a one-line justification.
2. `targetSdk` = the latest stable API level supported by the current Flutter/AGP (no lower than 35); `compileSdk` the same. Avoids Play Protect's "built for an older version of Android" warning. Fix any runtime-permission / foreground-service-type issues this causes.
3. Prominent disclosure (Play User Data policy): before the first microphone permission request, show a Bangla in-app dialog explaining exactly what is recorded, that audio/text goes to Google speech / the user's own Gemini key for conversion, and that nothing is stored on our servers; buttons "রাজি আছি" / "না". Before sending the anonymous usage ping the first time, same style disclosure (or reuse the settings switch with a first-run notice).
4. Keyboard: before opening the input-method settings, a Bangla screen explaining Android's standard "may collect all text you type" warning and what Talk2Type actually does (only converts the user's speech; never logs typed text; password fields disabled).
5. Privacy policy: add a "প্রাইভেসি পলিসি" link in Settings and on the setup screen pointing to `https://license.ayyzan.com/privacy/talk2type` (hub page to be created separately — make the URL a constant).
6. No dynamic code loading, no hidden features, no executing downloaded code. The in-app updater only downloads our own signed APK from license.ayyzan.com/GitHub release and hands it to the system installer (keep `REQUEST_INSTALL_PACKAGES`, justify it in the report).
7. Release APK will be signed by CI with the owner's release key (unchanged). Remind the owner in the report: register the app (package name + signing certificate SHA-256) in Google's Android Developer Console developer verification, because unverified sideloaded apps will stop installing on certified devices (rolling out by country 2026–2027).
