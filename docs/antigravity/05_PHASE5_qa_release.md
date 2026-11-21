# [Antigravity — Talk2Type] Phase 5: QA, polish & release prep

Read `00_MASTER_PLAN.md` first. Requires Phase 4 approved.

1. Full pass over the Regression Checklist F1–F19 + R1–R4 + every Phase 2–4 feature. Produce `docs/antigravity/reports/phase-5-test-matrix.md` (rows = features, columns = Android 10 / 12 / 14 emulator results, notes). Items that need a real phone (WhatsApp/Messenger injection, OEM battery killers on Xiaomi/Samsung) → list exact manual steps for the owner.
2. Fix bugs found (small commits). Do not add new features.
3. `flutter analyze` 0 errors, 0 warnings if reasonably possible; `flutter test` passes; add unit tests for: mode key normalization, plan limits/daily counter reset, license verify state machine (valid / revoked / offline 30 days), snippet matching, voice command parsing.
4. Release build: `flutter build apk --release` succeeds; confirm R3 dev tools are absent; confirm no API key or token is logged; check APK size and report it.
5. Bump version in `pubspec.yaml` to `2.0.0+<next>` (CI overrides build-name with run number — check `.github/workflows/build-release.yml` and make the CI produce `2.0.<run>` for this major release; keep the rest of the workflow unchanged). The in-app updater compares versions — make sure 1.0.x installs see 2.0.x as newer.
6. Write `CHANGELOG.md` (Bangla, customer-friendly) and update README.
7. Commit. STOP. The owner will review, merge `commercial-v2` into `main` and push himself.
