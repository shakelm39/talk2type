# [Antigravity — Talk2Type] Phase 1: Restore dropped features (no new business logic)

Read `docs/antigravity/00_MASTER_PLAN.md` first and follow its Hard rules.

## 0. Setup
- Make sure the working tree is clean, then `git checkout -b commercial-v2` from `main` (or switch to it if it exists). Never push. The new untracked `docs/antigravity/` folder is expected — commit it as the first commit on `commercial-v2` (`docs: add commercial v2 plan`).
- Run `flutter pub get`, `flutter analyze`, `flutter build apk --debug` once BEFORE changing anything and note the baseline result in the report.

## 1. R1 — Restore 5 tone modes (Flutter + native Kotlin, kept in sync)
Mode keys (final, lowercase):
| key | Bangla title (UI) | Short pill label (orb strip) | Purpose |
|---|---|---|---|
| `bangla` | বাংলা | বাংলা | Clean standard Bangla, remove filler words (উম, মানে, এ্যাঁ), correct punctuation । , ? — keep meaning, numbers, names exactly. (current default — unchanged) |
| `formal` | অফিসিয়াল | অফিস | Polite formal/corporate Bangla for email, office messages |
| `support` | কাস্টমার সার্ভিস | সাপোর্ট | Courteous, empathetic customer-reply Bangla (F-commerce sellers): greeting + clear answer, no invented facts/prices |
| `casual` | বন্ধুসুলভ | আড্ডা | Warm colloquial Bangla, keep informal words |
| `english` | English | EN | Speak Bangla → fluent natural English (current, unchanged) |

Tasks:
1. `lib/core/constants/tone_modes.dart`: add the 3 modes with good system prompts (style of the existing two: "Output ONLY the final text, no quotes/explanations, never drop spoken details/numbers"). Fix `getByKey` normalization: `formal`/`office_formal` → `formal`; `support`/`customer_support` → `support`; `casual`/`friend_casual` → `casual`; `bangla`/`guchiye`/`sundor`/`clean_bangla`/`hubohu` → `bangla`; `english`/`bangla_to_english`/`english_translate` → `english`; unknown → `bangla`. Remove the old alias constants that wrongly point `formal`/`officeFormal` to `bangla` (update every usage).
2. Home screen mode selector must show all 5 (check it isn't hard-coded to 2).
3. `FloatingOverlayService.kt`:
   - `buildModeStrip()`: 5 pills using the short labels; wrap in a `HorizontalScrollView` if it would overflow on small screens (test at 360dp width). Keep hidden-by-default / expand / auto-collapse behaviour (F3).
   - `getModeColor()`: a distinct color per mode (keep existing two colors).
   - Mode badge dot click (F4): cycle through the 5 modes in order instead of toggling 2; toast shows the Bangla title.
   - `setToneMode()`: same normalization table as Dart.
   - Processing after native speech: `bangla` → existing `polishGuchiyeBangla` pipeline (unchanged, F8). `english` → existing translate pipeline (unchanged, F9). `formal`/`support`/`casual` → `callGeminiTextTransform(text, mode, key)` with the matching prompt. If no Gemini key is saved → fall back to the `bangla` pipeline and show a toast once per session: "এই মোডের জন্য Gemini API key দরকার — সেটিংসে key দিন". Never lose the spoken text.
   - Custom prompts (F18): if `flutter.vf_custom_prompt_<mode>` exists in `FlutterSharedPreferences`, the Kotlin side must use it instead of its built-in prompt (today only Flutter uses custom prompts). Verify the exact stored key name in Dart before coding.
4. `direct_gemini_voice_repository.dart` (recording fallback path F6): confirm it uses the prompt for the selected mode for all 5 modes.
5. History screen: show the Bangla mode title for each item (old items with old keys must map correctly via `getByKey`).

## 2. R2 — Restore Live AutoType injection test
In the settings dialog (`test_ai_dialog.dart`, title "Talk2Type - এআই সেটিংস") add back a section "🎯 টাইপিং টেস্ট": a TextField + button "স্বয়ংক্রিয় টাইপ পরীক্ষা করুন" calling `NativeBridge.testTextInjection(...)`, with the same status messages as the old code (see `git show 4bcc97e -- lib/presentation/screens/test_ai_dialog.dart`). Available in release builds — it is useful for customers to check accessibility works.

## 3. R3 — Developer tools (debug builds ONLY)
Restore from commit 4bcc97e, wrapped in `if (kDebugMode)`:
- License Hub gate switch, Backend AI endpoint field (settings dialog),
- "টেস্ট মোডে প্রবেশ করুন (Skip for Testing)" button + "Hub: <endpoint>" text (license activation screen).
Verify with `flutter build apk --release` that none of these appear (search the release build behaviour, explain how you verified in the report).

## 4. R4 — README
Rewrite README.md to match the real code after this phase (name Talk2Type, 5 modes, native speech + AI pipeline, license hub, in-app updater, CI). Keep it concise. Bangla or English is fine.

## 5. Housekeeping (no code behaviour change)
- Add to `.gitignore` if not already ignored: `replay_pid*.log`, `android/hs_err_pid*.log`, `current_phone_screen.png` (already covered by *.png — confirm), `*.apk`.
- Do NOT delete the APK/log files from disk.

## Done = 
Regression checklist F1–F19 all still work (explain per item how verified; for things needing a phone, list exact manual test steps for the owner), all 5 modes work in both the native path and the recording path, report written, committed on `commercial-v2`, STOP.
