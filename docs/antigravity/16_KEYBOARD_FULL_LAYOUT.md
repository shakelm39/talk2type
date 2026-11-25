# [Antigravity — Talk2Type repo: E:\XAMPP\htdocs\Talk2Type]
# TASK 16: Full typing keyboard (Ridmik-style) + phonetic Bangla + faster voice commit

Supervisor: Claude. Owner tests on his OPPO (wireless debugging).

## Hard rules
- Branch: `test/keyboard-layout` from current `main` (39cbe4d or later). Commit only, never push.
  (Pushing is the owner's job. When he pushes this branch, GitHub workflow "Test build" makes a
  release-signed APK artifact automatically - so NO local release build and NO password is needed.)
- Never ask for / read / extract any password, token or credential (keystore, git, GitHub, browser).
- Do NOT uninstall the app on the phone (active Pro license). Install only with `adb install -r`.
- Do NOT commit screenshots or logcat (gitignored - keep it that way).
- Everything that works today must keep working: voice (first-tap reliability from 825f2bc - do not
  touch VoicePipeline's recognizer lifecycle), 5 modes + Pro locks, Free 20/day limit, voice commands,
  snippets, ✨ rewrite menu, paste, settings, password-field protection, enter/action key labels,
  nav-bar inset fix, EN-mode final-text replace fix. Regression list: docs/antigravity/00_MASTER_PLAN.md.
- No Accessibility, no new dangerous permissions (Play Protect safety from Task 13 stays).

## 1. New layout (replaces Row C big mic area; Row A stays)
Top → bottom, dark theme unchanged (#0F172A bg, keys #1E293B, pressed #334155, text #F1F5F9):

1. **Mode row (40dp)** - existing 5 chips বাংলা · অফিস · সাপোর্ট · আড্ডা · EN + fixed ✨ (unchanged
   behaviour, Pro locks, selected = red).
2. **Status strip (26dp)** - left 📋 paste (32dp), centre status text (existing texts: "এক মুহূর্ত…",
   "বলুন… শুনছি", live partial text while listening, "গুছিয়ে দিচ্ছি…", "✓ সম্পন্ন"), right ⚙ settings.
   When idle and typing Bangla phonetic, the centre shows the current phonetic preview (e.g. "ami → আমি").
3. **Number row (42dp)** - 1 2 3 4 5 6 7 8 9 0. In বাং typing language show ১ ২ ৩ … ০ (long-press gives the
   other digit set).
4. **Letter rows (46dp each)** QWERTY:
   - q w e r t y u i o p
   - a s d f g h j k l   (half-key indent)
   - ⇧ z x c v b n m ⌫   (⇧ and ⌫ 1.5 width; ⌫ long-press = repeat, reuse existing backspaceRunnable)
   Long-press on letters: show the symbol/Bangla alternative (optional, nice-to-have).
5. **Bottom row (48dp)**: `?123` | `বাং/EN` (typing-language toggle; long-press = system keyboard picker,
   replaces the old 🌐) | `,` | **🎤 mic key** (red gradient, 1.6 width, same pulsing ring while listening)
   | `space` (flex; shows "বাংলা" or "English" faintly) | `.`/`।` (। in বাং) | action key (existing labels:
   পাঠান / খুঁজুন / যান / ✓ / পরের ঘর / ↵).
- Mic key = exactly the old big mic: same handler `onMicButtonClicked()`, same states/colours.
- Total height must fit a 6.1" phone without covering the chat: target ≤ 300dp + nav inset.
  Compact screens (≤375dp width) - keys 42dp, gaps 4dp.
- Key press: small popup preview above the key, 10ms haptic (respect existing vibrate setting).

## 2. Layers
- `?123` layer: 1-0 row stays; rows: @ # ৳ _ & - + ( ) /  |  * " ' : ; ! ? ।  |  =\< ⌫  ; bottom `ABC`.
  `=\<` opens a second symbol page (~ ` | • √ π ÷ × { } [ ] % ^ © ®).
- Shift: tap = next letter capital, double-tap = caps lock (⇧ highlighted), auto-capital at sentence
  start in English only.

## 3. Phonetic Bangla typing (Avro-style)
- `বাং/EN` toggle selects typing language; remember it in prefs `flutter.vf_kb_typing_lang`
  ("en" default for new installs? → use "bn" default, owner's market is Bangla).
- In বাং: letters build a Latin buffer shown as composing text in Bangla script (setComposingText),
  converted on every keystroke; space / punctuation / enter commits the word (commitText) + the char.
  Backspace removes the last Latin char of the buffer and re-converts (when buffer empty, normal delete).
- Converter: new file `services/PhoneticBangla.kt`, pure Kotlin, rule table (longest-match first),
  Avro-compatible conventions. Must pass these unit tests (add `android/app/src/test/.../PhoneticBanglaTest.kt`):
    ami→আমি, tumi→তুমি, bangla→বাংলা, kemon→কেমন, achhi→আছি, bhalo→ভালো, ki→কি, korchho→করছো,
    dhonyobad→ধন্যবাদ, sokal→সকাল, rat→রাত, Taka→টাকা, kSh→ক্ষ, bidyaloy→বিদ্যালয়, amar→আমার,
    tOmar→তোমার (O = ো), ii→ঈ, kii→কী. Digits are NOT converted by phonetic (they come from the number row).
  Use only an implementation you write yourself or MIT/Apache-licensed rules; record the source and
  licence in a comment at the top of the file. No GPL/MPL code copied.
- Optional (only if time allows, separate commit): 3-word suggestion strip in the status strip from a
  small bundled word list. Not required for this task.
- Password fields: force English, no phonetic, no suggestions, no history; mic stays disabled (existing).
- Typing letters never counts toward the Free 20/day limit and is never locked for Free users.
- Before starting voice: `finishComposingText()` so a half-typed phonetic word is kept, not replaced.

## 4. Faster voice → text (owner request: "আরেকটু ফাস্ট")
In `VoicePipeline.finishContinuousSpeechSession()` for Bangla mode ("sundor"/"bangla"):
- Commit the recognizer text IMMEDIATELY (callback.onFinal(raw)), state "success".
- Then polish with AI in background (existing polishBanglaText with the 3.5 s budget). If the result
  differs AND the text before the cursor still ends with exactly the raw text we committed, replace it:
  deleteSurroundingText(raw.length, 0) + commitText(polished). Otherwise leave raw (user already edited).
  Implement the replacement via a new callback `onReplaceLastCommit(old: String, new: String)` in the
  keyboard service (check getTextBeforeCursor(old.length + 2) first).
- AI modes (অফিস/সাপোর্ট/আড্ডা/EN) unchanged (they must wait for AI).
- `FINAL_RESULT_WAIT_MS` 1200 → 800.

## 5. Settings screen (Flutter)
Add a "কিবোর্ড" section: typing language default (বাংলা ফোনেটিক / English), key sound on/off,
vibration on/off, "ভয়েসের পর AI দিয়ে গুছিয়ে দাও" (default on; off = raw text only, fastest).
Store in FlutterSharedPreferences with `flutter.` prefix; keyboard reads them in onStartInputView.

## 6. Verify on the phone (report a table)
- Typing: English sentence with capitals, numbers, symbols; Bangla phonetic "ami bhalo achhi"
  → "আমি ভালো আছি"; backspace inside a phonetic word; switch বাং/EN mid-sentence.
- Voice after typing and typing after voice in the same message (WhatsApp, Messenger, Facebook comment,
  Chrome address bar, a password field).
- Voice first-tap reliability still 10/10 (WhatsApp).
- Bangla voice: time from end of speech → text committed (log timestamps), before vs after.
- All F1–F19 / R1–R4 regression items.
- Screenshots of: letters (EN), letters (বাং), ?123, listening state - show them to the owner, do NOT commit.

## 7. Commits (small, in order)
1. feat(keyboard): full QWERTY layout + number row + symbol layers
2. feat(keyboard): phonetic Bangla typing (+ unit tests)
3. perf(voice): instant Bangla commit, AI polish replaces in background
4. feat(settings): keyboard section
Report: what changed, test table, unit test output, commit hashes, anything you could not do.
