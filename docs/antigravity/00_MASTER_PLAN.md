# Talk2Type — Commercial v2 Master Plan (for Antigravity)

> Supervisor: Claude (senior engineer). Executor: Antigravity agent.
> Repo: `E:\XAMPP\htdocs\Talk2Type` (GitHub `shakelm39/talk2type`)
> Read this whole file before starting ANY phase. Re-read the "Hard rules" before every commit.

## Business model (decided by owner — do not change)
- **Lifetime license only** (sold via Ayyzan sites, key delivered by email, activated against `license.ayyzan.com`, appId `talk2type`). No subscriptions, no expiry-based plans.
- **BYOK AI**: the customer uses **their own** Google Gemini API key (free tier from aistudio.google.com) and optionally their own Groq key. We run **no AI proxy server**. Our server only does license + update info.
- **Free tier** (no license): basic Bangla voice typing with limits. **Pro (lifetime license)**: everything.

## Hard rules (apply to every phase)
1. Work ONLY on branch `commercial-v2` (create it from `main` in Phase 1 if it does not exist). **Never commit to `main`. Never `git push`.** The owner pushes himself. (Pushing `main` triggers the GitHub Actions release + in-app update to real customers.)
2. Commit at the end of each phase (you may make smaller commits inside a phase). Conventional commit messages, e.g. `feat(modes): restore 5 tone modes`.
3. **Do not remove or break any feature in the Regression Checklist below.** If a change touches one, re-test it. If something must change behaviour, write it in the phase report.
4. Never hard-code API keys or secrets. Never log full API keys or license tokens (mask to last 4 chars).
5. Keep all user-facing text in Bangla (English only where it is a brand/technical term). Keep the current dark theme & colors.
6. Keep backward compatibility of saved data: SharedPreferences keys (`vf_*`, and the `flutter.`-prefixed ones the Kotlin side reads) and the SQLite history DB must keep working after update — no data loss for existing users.
7. Do NOT touch the `app.ayyzan.com` Laravel codebase under any circumstance.
8. Do not delete files you did not create unless the phase says so.
9. At the end of every phase you MUST:
   - run `flutter analyze` → 0 errors (warnings listed in report),
   - run `flutter build apk --debug` → must succeed,
   - write `docs/antigravity/reports/phase-N.md` with: what changed (file list), how each checklist item was verified, known issues, screenshots/notes if any,
   - then commit, then STOP and wait. Do not start the next phase on your own.

## Regression Checklist — features that exist today and MUST keep working
| ID | Feature | Where |
|---|---|---|
| F1 | Floating orb over all apps: drag, snap to edge, size & opacity settings | FloatingOverlayService.kt, AppConfig |
| F2 | Orb auto-shows when an input field is focused, auto-hides when keyboard/field closes | AutoTypeAccessibilityService.kt + overlay |
| F3 | Mode strip hidden by default, expands on tap, auto-collapses after done | FloatingOverlayService.kt |
| F4 | Mode badge dot on the orb (tap to switch mode) | FloatingOverlayService.kt |
| F5 | Continuous native voice typing (Android SpeechRecognizer, bn-BD) with live partial text in the field | FloatingOverlayService.kt |
| F6 | Fallback: if SpeechRecognizer is unavailable → record .m4a → AI repository → inject | AudioRecorderHelper.kt, voiceflow_provider.dart |
| F7 | Text injection: ACTION_SET_TEXT → ACTION_PASTE fallback (WhatsApp/Messenger) → clipboard + toast; streaming partial replace | AutoTypeAccessibilityService.kt |
| F8 | Bangla punctuation pipeline: free online AI → Gemini → rule-based formatter | FloatingOverlayService.kt |
| F9 | Bangla → English translation mode | FloatingOverlayService.kt, direct_gemini_voice_repository.dart |
| F10 | Gemini multi-model fallback (primary key → backup key) + Groq Whisper/LLaMA tier 3 | direct_gemini_voice_repository.dart |
| F11 | Custom vocabulary (বিকাশ, নগদ …) add/remove, used in AI prompt | AppConfig, settings dialog |
| F12 | History (SQLite): list, copy, re-type into field, failed items shown | history_screen.dart, history_database.dart |
| F13 | Permission dashboard: mic, overlay, accessibility, battery optimization, app settings | permission_dashboard_screen.dart |
| F14 | License activation with device binding via license.ayyzan.com `/api/v1/activate` | license_service.dart |
| F15 | In-app update: auto + manual check, download & install APK | app_update_service.dart, MainActivity.kt |
| F16 | Orb states idle/recording/processing/success/error, pulse animation, audio cue, vibration | FloatingOverlayService.kt |
| F17 | Foreground service notification (keeps service alive) | FloatingOverlayService.kt |
| F18 | Per-mode custom system prompt editing | test_ai_dialog.dart |
| F19 | GitHub Actions release workflow | .github/workflows/build-release.yml |

## Features that were dropped and must be RESTORED
| ID | Feature | Evidence |
|---|---|---|
| R1 | 5 tone modes: বাংলা (clean), অফিসিয়াল, কাস্টমার সার্ভিস, বন্ধুসুলভ, বাংলা→English | README "Supported Tone Modes"; code now has only 2 |
| R2 | Live AutoType injection test (focus a field, press button, accessibility types) | removed in commit 4bcc97e from test_ai_dialog.dart |
| R3 | Developer tools: license-gate switch, backend endpoint field, "Skip for testing" | removed in 4bcc97e — restore **only in debug builds** (`kDebugMode`), never in release |
| R4 | README accuracy | README describes features the code no longer has |

## Phases
| Phase | File | Agent / repo |
|---|---|---|
| 1 | `01_PHASE1_restore_features.md` | Antigravity — **Talk2Type** |
| 1.1 | `01B_PHASE1_fixups.md` (review fixes) | Antigravity — **Talk2Type** |
| 1.2 | `01C_release_signing_fix.md` (update fix) | Antigravity — **Talk2Type** |
| 2 | `02_PHASE2_byok_ai_engine.md` | Antigravity — **Talk2Type** |
| 3A | `03A_HUB_license_verify.md` | Antigravity — **ayyzan-license-hub** (separate workspace) |
| 3B | `03B_PHASE3_license_free_pro.md` | Antigravity — **Talk2Type** (after 3A) |
| 4 | `04_PHASE4_pro_features.md` | Antigravity — **Talk2Type** |
| 5 | `05_PHASE5_qa_release.md` | Antigravity — **Talk2Type** |

After each phase the owner tells Claude; Claude reviews the diff and the report, and either approves or sends a fix-up prompt.
