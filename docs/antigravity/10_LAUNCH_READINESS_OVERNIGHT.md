# [Antigravity — Talk2Type] Phase 10: LAUNCH READINESS — overnight, bug-fix only

The owner is asleep. Never ask questions; pick the safest option and log it under "DECISIONS MADE".
**Owner decision: NO new features (except the model fix above), NO changes to the licensing/business model, NO free-for-all mode, NO UI redesign.** The app as released in v2.0.6 is the product. Tonight = find and fix real launch blockers only.

## Rules
- Never `git push`. Never commit to `main` directly. Never touch keystore / key.properties (debug builds only). Do not modify the license hub repo.
- Do not delete files you did not create.

## Step 0 — Branch
The voice-engine work (phase 7) is already committed on `main` (0564de6, 5c89a03, ec415c0) — keep it, it is part of this release. Ignore CRLF-only diffs (`git diff --ignore-cr-at-eol`). `git checkout -b launch-fixes` from `main`.

## Step 0.5 — LAUNCH BLOCKER: outdated Gemini model names (fix first)
Code uses `gemini-2.5-flash`, `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-flash-8b` (Dart `direct_gemini_voice_repository.dart` ~lines 119-153 and Kotlin `FloatingOverlayService.kt` ~lines 1122 and 2415). Per Google's deprecations page: 1.5 and 2.0 models are shut down; 2.5 is restricted for new projects; Google says new projects should use **3.5 Flash-Lite or 3.8 Flash**. New customers create new keys → every AI feature would silently fail.
Fix (Dart + Kotlin, ONE shared preference order, no hard dependency on any single name):
1. Preferred order: `gemini-3.5-flash-lite`, `gemini-3.8-flash`, `gemini-3.6-flash`, `gemini-3.1-flash-lite`, `gemini-flash-lite-latest`, `gemini-flash-latest`, `gemini-2.5-flash` (last). Remove all 1.5 / 2.0 names.
2. Model discovery: on key save/test and at most once per 24 h, call `GET https://generativelanguage.googleapis.com/v1beta/models` (header `x-goog-api-key`), keep only models whose `supportedGenerationMethods` contains `generateContent`, intersect with the preferred order, cache the result as `vf_gemini_models` (JSON list). Dart writes it, Kotlin reads `flutter.vf_gemini_models`. If discovery fails, use the preferred order as-is.
3. On HTTP 404 / "model not found" for a model, skip it and mark it unavailable for 24 h (don't count it as a key failure). On 429/quota, move to the next key (existing behaviour).
4. The "Key পরীক্ষা করুন" button must show which model answered.
5. Unit tests: discovery filtering, ordering, 404-skip.
6. Verify with my real key on the phone (key is already saved in the app — never print it): native path bangla polish, a tone mode, English mode, AI engine, voice-note transcription. Note in the report which model answered.

Also check the phase-7 "comparison test" (native SpeechRecognizer + MediaRecorder at the same time): many phones give one of them silence. If the native side returns empty on my phone, run the two captures sequentially (record once to file, then feed? — if not possible, run native first, then AI on a second take) and label it clearly. Small fix only.

## Step 1 — Baseline
`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. Record results.

## Step 2 — Launch audit (read the code, fix only real bugs; one small commit per fix)
Check and report OK / FIXED / NEEDS-OWNER for each:
1. **Crashes / ANR**: null-safety, `!` on nullable, unhandled exceptions in Kotlin services, network or disk work on the main/UI thread, MethodChannel calls when engine is detached, service start on Android 8–15 (foreground service types), receivers registered/unregistered correctly.
2. **License flows** (do NOT change the business rules): activate (valid key / wrong key / other device + v1 legacy retry / no internet), periodic verify (active / revoked / device_mismatch / not_found / unavailable / 429 / offline), clear license, existing v1 users after reinstall. Messages in clear Bangla.
3. **Free vs Pro gating consistency** between Dart and Kotlin (`vf_is_pro`, daily counter, locked modes) — fix only inconsistencies/bugs, do not change limits.
4. **Update flow**: version compare (v-prefix, 2.0.10 > 2.0.9), snooze/skip, signature-mismatch dialog, `releaseNotes` multi-line text fits the dialog (make the dialog content scrollable if it can overflow).
5. **Permissions**: mic, overlay, accessibility (incl. Android 13+ restricted-settings card), notifications (Android 13+ POST_NOTIFICATIONS), battery optimization; re-check on resume.
6. **Orb**: show/hide on focus, strip width at 360/411 dp, right-edge snap, Recent apps screen, screen off, rotation, keyboard open.
7. **Text injection**: WhatsApp, Messenger, Chrome address bar, Gmail compose — SET_TEXT / PASTE / clipboard fallback; never lose spoken text.
8. **Privacy/security**: no API key, license key or token in logs (release), no secrets in repo, Gemini key sent in header.
9. **Bangla copy**: typos, mixed English jargon on customer-facing screens, consistent mode names.
10. **Layout**: no overflow on any screen at 360dp and Android font size "Large".

## Step 3 — Device test (only if a phone is connected via `adb devices`)
Install the debug build, open every screen, save screenshots to `docs/antigravity/screens/launch/NN_name.png` (`adb exec-out screencap -p`), and `adb logcat -d` filtered for FATAL/AndroidRuntime/talk2type/voiceflow to `docs/antigravity/screens/launch/logcat.txt`. If no phone: skip, note it.

## Step 4 — Report
Write `docs/antigravity/reports/LAUNCH_READINESS.md`:
- ✅ / ⚠️ / ❌ table for the 10 audit areas, commit hash per fix
- "NEEDS-OWNER" list (things only the owner can do: real-phone voice tests, test purchase, prices/links, privacy policy page)
- A 15-minute manual test script for the owner (numbered, Bangla)
`flutter analyze` 0 issues, `flutter test` pass, debug build OK on `launch-fixes`. Commit the report. STOP.
