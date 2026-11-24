# [Antigravity — Talk2Type] Phase 9 (v2.1): Simpler UX + remote control from the hub

Branch `v2.1` from `main`. Commit only (one commit per part), NEVER push, never touch keystore/key.properties (debug builds only). Regression checklist F1–F19 and all v2.0.x features must keep working. All UI text in simple Bangla — no technical words for customers (no "dp", "API endpoint", model names, "SpeechRecognizer"). Test on my phone via wireless adb at 360dp width and large font.

Product principle: **a non-technical customer must be typing by voice in WhatsApp within 2 minutes of opening the app, WITHOUT an API key.** (Native speech works without a key — that is our big advantage over competitors that block everything until an API key is added.)

## Part A — Remote config from the hub (`POST /v1/apps/talk2type/config`, see hub doc 08)
1. New `RemoteConfigService`: call on app start and when the app returns to foreground if older than `ttlSeconds` (default 6 h). Send deviceId (stored `vf_device_id`, else ANDROID_ID — same id the license uses), appVersion, model, manufacturer, osVersion, license key last4 if any.
2. Cache the last good config in SharedPreferences (`vf_remote_config` JSON + `vf_remote_config_at`). Use the cache when offline / `UNAVAILABLE` / 429 / timeout (5 s). Never block app start waiting for it.
3. `licenseMode`:
   - `open` → treat everyone as Pro (all modes, unlimited, all Pro features), never show welcome-choice / upgrade / lock icons. Keep an existing real license as is.
   - `freemium` → current behaviour (Free limits from `freeDailyLimit` if given, Pro with license).
   - `license_only` → no free usage: without a valid license show only the activation screen (+ buy button + WhatsApp).
   - No config ever received (fresh install, offline) → `freemium`.
   - Expose ONE source of truth `Entitlement.isPro` used by Dart AND Kotlin (write `flutter.vf_effective_pro` + `flutter.vf_license_mode`), replacing direct `vf_is_pro` reads for gating. `vf_is_pro` stays = "has a valid paid license".
4. Device blocked → full-screen block page (hub message, WhatsApp button), floating orb stops and hides, keyboard/accessibility injection disabled. Cache the blocked status so it also applies offline; unblock takes effect on the next successful config fetch.
5. Announcement → banner card at the top of Home (style colour, optional button opening `link`, ✕ if dismissible; remember dismissed `announcement.id`; a new id shows again).
6. `minVersion` → if installed version is lower, show the existing mandatory-update dialog.
7. Unit tests: mode switching, offline cache, blocked persistence, dismissed announcement, missing fields.

## Part B — Simple home screen (good idea from a competitor, done better)
1. Home top: one status line + **a single setup banner** when anything is missing, listing only what is missing in plain words (e.g. "সেটআপ বাকি: ভাসমান মাইক অনুমতি") with one "সেটআপ করুন ›" button. Hide the banner when everything is done.
2. Home middle: **big round mic button inside the app** + text box with কপি / শেয়ার / মুছুন, so the app is useful even without other apps. Uses the selected mode and engine. Results also go to History.
3. Mode chips (5 modes) right under the mic; locked chips only in freemium/license_only for non-Pro.
4. Bottom: one big primary button "ভাসমান মাইক চালু করুন" / "ভাসমান মাইক বন্ধ করুন".
5. Move everything else (history, shortcuts, voice-note, settings, update, license) into a simple bottom navigation or a ⚙️ page. Remove technical lines from Home (AI engine names, "48dp", etc.).

## Part C — One guided setup (max 3 steps, auto-detect, big buttons)
Single `SetupScreen` replacing the scattered permission dashboard + key wizard entry points (keep old screens reachable from settings for support):
1. **মাইক অনুমতি** — one button, ✓ when granted.
2. **ভাসমান মাইক** — overlay + accessibility in one card, step-by-step, with the Android 13+ "Allow restricted settings" help inline (existing card), auto-✓ when both granted (re-check on resume).
3. **আরও নির্ভুল লেখা (ঐচ্ছিক)** — Gemini key. Clearly optional: "Key ছাড়াও অ্যাপ চলবে। Key দিলে বাংলা-ইংরেজি মেশানো কথা আরও ভালো লিখবে।" Opens the existing key wizard.
Each card shows a green "✓ দেওয়া আছে" pill when done. Progress "২/৩ সম্পন্ন".

## Part D — API keys like a pro (better than competitor)
1. Replace Primary/Backup/Groq fields with a list: "+ আরেকটা Key যোগ করুন" (unlimited Gemini keys), each with ✓/✗ test status and delete. Rotate automatically to the next key on quota/429/invalid; remember which key failed and retry it after 1 h. Tip text: "আলাদা Gmail থেকে ২-৩টা key রাখলে ফ্রি লিমিট শেষ হওয়ার চিন্তা থাকে না।"
2. Groq key moves to "অ্যাডভান্সড" (collapsed).
3. Migration: existing primary/backup keys become the first list items; Kotlin must read the same list (store as JSON `flutter.vf_gemini_keys` and keep writing the old single-key prefs for backward compatibility until removed).

## Part E — Simple settings
Only these visible by default: লেখার ধরন (mode), ভয়েস ইঞ্জিন (⚡ দ্রুত / 🎯 নির্ভুল — from phase 7 if merged), "বলার সময়েই লেখা দেখাও" (live preview on/off), "লেখা সাথে সাথে বসিয়ে দাও" (on = inject immediately; off = show result in orb bubble with ✓ বসাও / ✗ বাতিল), ভাসমান মাইকের আকার. Everything else (custom prompts, vocabulary, free online engine, model choice "অটো") inside "অ্যাডভান্সড".

## Part F — Not now (write a short design note only, do not build)
"Talk2Type কিবোর্ড" (own IME with a mic): works without Accessibility/restricted settings and is Play-Store friendly. Write `docs/antigravity/notes/ime-keyboard-design.md` (scope, effort estimate, what to reuse). Do not implement in v2.1.

## Done =
flutter analyze 0 issues, flutter test pass, debug build installed on my phone, screenshots of every changed screen saved to `docs/antigravity/screens/v2.1/` (adb exec-out screencap), report `docs/antigravity/reports/phase-9.md` incl. a 2-minute first-run walkthrough. STOP.
