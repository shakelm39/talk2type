# [Antigravity — Talk2Type] Phase 1.1: Review fix-ups (do BEFORE Phase 2)

Supervisor review of commit 80a55a5: approved with these fixes. Same Hard rules (branch `commercial-v2`, commit only, never push).

## A. Kotlin text prompts must be TEXT prompts, not audio prompts
In `FloatingOverlayService.callGeminiTextTransform()` the input is already-recognized TEXT, but the new built-in prompts for `bangla` and `english` were copied from the Dart AUDIO prompts ("Transcribe…", "Listen to the spoken Bengali…").
- `bangla`: restore the original text prompt from `main` (see `git show main:android/app/src/main/kotlin/com/voiceflow/ai/voiceflow_ai/services/FloatingOverlayService.kt`, the `"bangla", "guchiye", "sundor" ->` line: "Format the given spoken Bengali text with precise, natural punctuation… Never omit or cut off any spoken words…"). That wording was part of the earlier speech cut-off fix.
- `english`: "Translate the given Bengali text into natural, fluent, grammatical English. Output ONLY the English text."
- `formal`/`support`/`casual`: reword to "the given Bengali text" (not "spoken"/"listen").
- Custom prompts: the prompt a user edits in settings is shared by both paths. Prepend a fixed line in Kotlin when using a custom prompt: "The input below is Bengali text that was transcribed from speech." so audio-worded custom prompts still work on text.

## B. Mode chosen on the orb is not persisted
Today Dart saves `vf_active_mode` and pushes it to Kotlin, but when the user changes mode on the orb (pill or badge dot) Kotlin keeps it only in memory → after the service restarts (reboot, OS kill, toggle) the orb falls back to `bangla` and the app home shows a different mode.
- Kotlin: whenever the mode changes from the orb, write `flutter.vf_active_mode` to `FlutterSharedPreferences`; in `onCreate`/service start read it (normalize) before building the strip.
- Dart: `VoiceFlowProvider` re-reads `vf_active_mode` on app resume (`didChangeAppLifecycleState` resumed — the home screen already observes lifecycle) so home screen and orb always agree.

## C. Race in the formal/support/casual thread
In `finishContinuousVoiceTyping`, capture `val modeAtFinish = currentMode` (and the base text) **before** starting the Thread and use only those copies inside the thread and in `notifyTranscriptionCompleted`. Switching mode while processing must not change the result's mode.

## Done =
`flutter analyze` 0 issues, `flutter build apk --debug` OK, append a "Phase 1.1" section to `reports/phase-1.md` (what changed + manual test: change mode on orb → force-stop app → reopen → mode kept on both orb and home). Commit `fix(phase-1): text prompts, persist orb mode, thread race`. Then continue directly with Phase 2 (`02_PHASE2_byok_ai_engine.md`).
