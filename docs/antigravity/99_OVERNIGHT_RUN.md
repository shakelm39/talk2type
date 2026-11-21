# [Antigravity — Talk2Type] OVERNIGHT RUN — do all remaining phases unattended

The owner is asleep. Nobody will answer questions until morning. The supervisor (Claude) reviews everything in the morning.

## Order (one commit per step minimum, more is fine)
1. `01B_PHASE1_fixups.md` (A, B, C)
2. `01C_release_signing_fix.md` — **code parts only** (Gradle signing config with key.properties/env/debug-fallback, CI secret decoding + fail-if-missing, updater signature check, unknown-sources permission). Do NOT create a keystore and do NOT touch GitHub secrets — put the owner's exact morning steps in the report under "OWNER TODO".
3. `02_PHASE2_byok_ai_engine.md`
4. `03B_PHASE3_license_free_pro.md` — the hub work (3A) is done by a different agent tonight. Look for its report at `E:\XAMPP\htdocs\ayyzan-license-hub\docs\reports\talk2type-3a.md`. If it is not there or you cannot read it, implement against the contract in `03A_HUB_license_verify.md` (POST `/api/v1/verify`, fields `valid`, `status`, `message`; info fields `purchase_url`, `price_text`), make the endpoint path a constant in AppConfig, and note "verify contract unconfirmed" in the report.
5. `04_PHASE4_pro_features.md`
6. `05_PHASE5_qa_release.md` — but do NOT bump to 2.0.0 or edit CI versioning yet; prepare it as a separate final commit `chore(release): prepare 2.0.0` so the supervisor can review it on its own.

## Overrides of the Hard rules for tonight
- Ignore "STOP after each phase": after a phase passes its Done checks (analyze + debug build), write its report and continue to the next phase.
- Never ask the owner a question tonight. When a decision is needed, pick the safest reasonable option, implement it, and list it under "DECISIONS MADE" in that phase's report.
- Anything that needs a real phone, the owner's passwords, GitHub settings or the hub server → do not block; write it under "OWNER TODO".

## Still absolutely forbidden
- `git push` (any branch), committing to `main`, merging into `main`, force operations (`reset --hard` on shared history, `push -f`, branch deletion).
- Deleting files you did not create. Touching any folder outside `E:\XAMPP\htdocs\Talk2Type` (reading the hub report is the only exception).
- Committing secrets, keystores, API keys.

## If stuck
If a phase cannot reach 0 analyze errors + successful debug build after 3 serious attempts: `git stash` or revert only that phase's uncommitted changes, write `reports/BLOCKED.md` (what failed, full error, what you tried), and STOP the whole run. Do not continue with a broken build.

## Morning summary
When finished (or stopped), write `docs/antigravity/reports/OVERNIGHT_SUMMARY.md`: per phase ✅/❌, commit hashes, DECISIONS MADE, OWNER TODO (merged list), known issues. Commit it.
