# [Antigravity — Talk2Type] Phase 14: Finish the keyboard (design fixes + phase 13) and produce the review pack

Branch `keyboard` (continue on it). Commit only, NEVER push, debug builds only, never touch keystore/key.properties, never print API keys/tokens. Do not checkout other branches (the owner releases 2.0.8 from commit 01a9899 without touching your working tree).

## A. Keyboard design fixes (Talk2TypeKeyboardService)
Test with BOTH gesture navigation and 3-button navigation, 360dp and 411dp widths, font size Default and Large.
1. INSETS (most important): the bottom row is drawn under the system navigation bar. Apply the navigation-bar inset as bottom padding of the keyboard root (ViewCompat.setOnApplyWindowInsetsListener + WindowInsetsCompat.Type.navigationBars(); handle Android 15 edge-to-edge for IMEs). Nothing may overlap the nav bar.
2. LAYOUT (dark, ≈236dp + nav inset, background #0F172A, 8dp side padding):
   - Row A (44dp): HorizontalScrollView with 5 chips বাংলা · অফিস · সাপোর্ট · আড্ডা · EN — height 34dp, 14dp horizontal padding, radius 17dp, 15sp; inactive bg #1E293B text #E2E8F0; active bg #DC2626 white; Pro-locked: small 🔒 + 60% text alpha. ✨ is NOT in the scroll: fixed 40dp circle (bg #312E81) pinned right.
   - Row B (22dp): centred status 13sp #94A3B8 ("বলতে মাইকে চাপুন" / "শুনছি…" / "গুছিয়ে দিচ্ছি…").
   - Row C (96dp): centred 76dp red mic (gradient #EF4444→#B91C1C, white vector mic, pulsing ring while listening); left 44dp round 📋 পেস্ট; right 44dp round ⚙ (opens app). Both bg #1E293B.
   - Row D (52dp): keys 46dp tall, 6dp gaps, radius 10dp, bg #1E293B, pressed #334155, glyphs #F1F5F9 20sp:
     🌐 (44dp, Material "language" vector) | , (40) | । (40) | ? (40) | স্পেস (flex, label 14sp #94A3B8) | ⌫ (52dp, Material "backspace" vector, hold-to-repeat) | action (64dp, bg #DC2626, label from imeOptions: পাঠান / খুঁজুন / যান / পরের ঘর / ✓ / ↵).
   - Remove the "±" key and every unicode/emoji used as a key icon; use vector drawables.
3. Touch targets ≥ 40dp, haptic + pressed state, Bangla contentDescription on every key.
4. Cap font scale at 1.15× inside the keyboard; no clipping.
Commit: "fix(keyboard): nav-bar insets, 5 modes visible, clean key row".

## B. Finish everything still open in `13_APP_keyboard_no_accessibility.md` (sections 1–8)
Check each section; complete what is missing (accessibility fully removed incl. manifest/xml/references, shared VoicePipeline, ✨ rewrite + undo, voice commands, password-field guard, optional floating mic in copy/IME-bridge mode, setup checklist with keyboard enable/select, Bangla disclosures, privacy-policy link constant, CI version 2.1.<run>, Play policy checklist). One commit per logical part.

## C. Verification
1. `flutter analyze` → 0 issues; `flutter test` → all pass; `flutter build apk --debug` OK.
2. Manifest proof: run `aapt2 dump xmltree --file AndroidManifest.xml build\app\outputs\flutter-apk\app-debug.apk` (or `apkanalyzer manifest print`) and save the FULL output to `docs/antigravity/review/manifest.txt`. Also save `aapt2 dump permissions` (or apkanalyzer permissions) to `docs/antigravity/review/permissions.txt`.
3. On my phone via adb (gesture + 3-button nav): enable & select the keyboard, dictate in WhatsApp in বাংলা, one tone mode and EN, ✨ rewrite + undo, a voice command, a password field, 🌐 switch back, Free lock on a Pro mode. Save screenshots `docs/antigravity/review/screens/NN_name.png` (`adb exec-out screencap -p`), at least: keyboard idle, listening, result in WhatsApp, ✨ menu, setup checklist, permission disclosure dialog, 3-button-nav keyboard.
4. `adb logcat -d` filtered for FATAL|AndroidRuntime|talk2type|voiceflow → `docs/antigravity/review/logcat.txt`.
5. `adb push build\app\outputs\flutter-apk\app-debug.apk /sdcard/Download/Talk2Type-keyboard-test.apk`.

## D. Review pack for the supervisor (Claude) — write `docs/antigravity/review/REVIEW_PACK.md`
- Commit list `main..keyboard` (hash + message).
- Table of every permission in the merged manifest with its justification; explicit line confirming NO BIND_ACCESSIBILITY_SERVICE / accessibilityservice / NOTIFICATION_LISTENER / RECEIVE_SMS / READ_SMS / SEND_SMS / READ_CALL_LOG / QUERY_ALL_PACKAGES / MANAGE_EXTERNAL_STORAGE, and the targetSdk/compileSdk values actually used.
- Section-by-section status of 13 (§1–§8) and 14 (A–C): ✅ / ⚠️ / ❌ with notes.
- Test results (counts), analyze result, APK size.
- DECISIONS MADE, KNOWN ISSUES, and an OWNER TODO list that includes: "Uninstall Talk2Type, install /Download/Talk2Type-keyboard-test.apk from the Files app, confirm Play Protect does not block".
Commit everything under docs/antigravity/review/ (screenshots too). Then STOP.
