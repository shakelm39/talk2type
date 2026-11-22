# [Antigravity — ayyzan-license-hub] Phase 3C: Supervisor review fix-ups for talk2type-verify

Workspace: `E:\XAMPP\htdocs\ayyzan-license-hub`, branch `talk2type-verify`. Commit only, never push. Review of commit 7688058: good, backward-compatible design. Fix these before deploy:

## 1. HIGH — server-side problems must NOT look like a revoked license
Talk2Type clears the customer's license when verify returns `valid:false` with status `revoked`, `device_mismatch` or `not_found`. Today these server/config problems also return those statuses:
- app not found / app `status != active` → `not_found`
- app public key invalid/misconfigured → `device_mismatch`
- empty `appId` → `not_found`
One admin mistake (e.g. setting the app inactive for a minute) would wipe every customer's Pro.
Fix: return a new status **`unavailable`** (HTTP 200, `success:false`, `valid:false`, Bangla message "সার্ভারে সাময়িক সমস্যা, পরে আবার চেষ্টা হবে।") for: missing appId, app missing/inactive, public key misconfigured, any caught exception. Keep `not_found` ONLY for "this key does not exist for this app", `device_mismatch` ONLY for real device/token mismatch, `revoked` ONLY for revoked/expired licenses. Update tests + README.

## 2. MEDIUM — rate limit bucket for verify
Check that `/v1/verify` (new path) does not consume or get blocked by the activation failure counters in a way that can lock out legit customers behind shared mobile-operator IPs (CGNAT is common in Bangladesh). Successful verifies must never count. If needed, give verify its own, more lenient per-IP bucket. 429 responses must not contain `status` revoked/not_found/device_mismatch.

## 3. Seeder must never be needed in production
`scripts/seed-talk2type.php` hard-codes a public key, price `৳৫৯৯` and URL `https://ayyzan.com/talk2type` — these are guesses. Talk2Type already exists in production. Add a guard at the top: refuse to run unless `APP_ENV` is local/dev (or a `--force-local` flag), print a warning. Price and purchase URL are set by the owner in admin → Apps.

## 4. Deploy note
Write in `docs/reports/talk2type-3a.md` a "Production deploy order" section: (1) backup DB, (2) run migration 012 on production BEFORE the code is pushed (the new `getAppInfo` selects `purchase_url`/`price_text`; code without the columns breaks `/v1/apps/*/info` for ALL apps), (3) push, (4) set price/purchase URL in admin, (5) curl checks.

## Done =
All test suites pass, report updated, commit `fix(verify): unavailable status for server issues, seeder guard`. STOP.
