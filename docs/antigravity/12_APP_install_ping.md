# [Antigravity — Talk2Type] Phase 12: Anonymous install/usage ping to the hub

Branch `install-ping` from `main`. Commit only, NEVER push, debug builds only, never touch keystore/key.properties. No other behaviour changes. Contract: see `11_HUB_install_stats.md` (hub endpoint `POST https://license.ayyzan.com/api/v1/apps/talk2type/ping`).

1. `InstallPingService` (Dart):
   - `installHash` = sha256( ANDROID_ID (NativeBridge.getDeviceId) + ":talk2type" ), hex. Compute once, store as `vf_install_hash`. Never send the raw id.
   - `tier` = "pro" if a valid license is active (AppConfig.isPro with a token), else "free".
   - Body: installHash, tier, appVersion, manufacturer, model, osVersion (device_info_plus), and `licenseToken` ONLY when pro.
   - Send on app start and on resume, at most once per 12 h (`vf_last_ping_at`), plus immediately after a successful license activation and after the license is cleared. Fire-and-forget: 5 s timeout, never block UI, never show errors, swallow all failures (offline, 404 before hub deploy, 429).
2. Settings → অ্যাডভান্সড: a switch "ব্যবহারের পরিসংখ্যান পাঠান (নাম-পরিচয় ছাড়া)" default ON; when OFF, no pings. One-line explanation under it.
3. Unit tests: hash stability, 12 h throttle, tier selection, token only when pro, switch off = no request.
4. `flutter analyze` 0, `flutter test` pass, debug build installed on my phone; confirm with adb logcat that one ping is sent (log only status code, never the token). Report `docs/antigravity/reports/phase-12.md`. STOP.
