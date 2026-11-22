# [Antigravity — Talk2Type] Phase 6: Supervisor review fix-ups for 2.0.0 (do before any merge)

Supervisor review of `commercial-v2` (80a55a5..7f221e1): good work overall. The items below MUST be fixed before release. Hard rules unchanged: branch `commercial-v2`, commit only, never push, never touch `main`.

## 1. CRITICAL — device ID is not unique (license binding)
`LicenseService.getDeviceId()` returns `DeviceInfoPlugin().androidInfo.id`. That is **`Build.ID`** (firmware build label like `TP1A.220624.014`), NOT a device identifier: thousands of phones share it, and it CHANGES after every OS update. With the new periodic verify, an OS update ⇒ hub says `device_mismatch` ⇒ the app clears a paying customer's license.
Fix:
- New activations: use `NativeBridge.getDeviceId()` (Settings.Secure.ANDROID_ID — already implemented in MainActivity `getAppDeviceId`). Remove the `androidInfo.id` path.
- Existing activations: if `vf_device_id` is stored, ALWAYS send that stored value in verify (and in re-activation on the same install). Never recompute the ID for an already-activated install.
- Verify request must use the stored `vf_device_id`, not a fresh lookup.
- Unit test: activated install with stored legacy id → verify payload carries the stored id.

## 2. HIGH — revocation responses are swallowed
Dio throws `DioException` for HTTP 4xx. If the hub answers an invalid/revoked license with 401/403/404 + JSON body (`{"valid":false,"status":"revoked",...}`), the current code treats it as a network error and keeps Pro forever.
Fix: in the `DioException` handler, if `e.response?.data` is a Map containing `valid`/`status`, process it exactly like a 200 response (revoked / device_mismatch / not_found ⇒ clear). Only true network errors, timeouts, 5xx, 404/405 WITHOUT such a JSON body, or unparseable bodies count as "keep state".
Also: do not write `vf_last_verified_at` on a failed verify. Instead set it once at activation (already done) and once in the v1→v2 migration (existing token, no timestamp ⇒ set now). The 30-day grace must count from the last REAL success.

## 3. MEDIUM — free daily counter can be reset by stale Dart cache
`AppConfig.incrementDailyUsage()` increments the in-memory `dailyCount` loaded at startup and writes it back, overwriting increments made by Kotlin meanwhile. Fix: `await prefs.reload()` then read `vf_daily_date`/`vf_daily_count` from prefs, increment, write. Same for any Dart read of the count (home screen display). Note Kotlin stores it as Long — keep compatible.

## 4. LOW — key setup screen on every launch
Splash routes to `ApiKeySetupScreen(isFirstLaunch: true)` on EVERY launch while no key exists. After the user taps "পরে করব" once, remember it (`vf_key_setup_skipped=true`) and go to Home next time; Home already shows the "AI: key নেই" chip.

## 5. Docs
In `OVERNIGHT_SUMMARY.md` / phase reports: the keystore command must place the file OUTSIDE the repo: `E:\keys\talk2type-release.jks`. Remove the "merge and push to main" instructions — the supervisor will give release steps after the hub phase and phone test.

## Done =
`flutter analyze` 0 issues, `flutter test` all pass (add tests for 1, 2, 3), `flutter build apk --debug` OK. Report `reports/phase-6.md`. Commit `fix(license): stable device id, revocation via 4xx, counter sync`. STOP.
