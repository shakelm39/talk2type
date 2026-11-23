# [Antigravity — ayyzan-license-hub] Phase 11: Install & usage statistics (free + pro, per app)

Workspace `E:\XAMPP\htdocs\ayyzan-license-hub`. New branch `install-stats` from `main`. Commit only, NEVER push. Do not touch app.ayyzan.com. Do not modify AI gateway files (`src/Ai*`, `admin/ai_*`). Next free migration number (currently 015). Only ADD — every existing endpoint, page and app (Sarah OT Khata, video-dubber, Talk2Type) must keep working unchanged.

## Goal (owner)
"See how many people installed each app, how many use it free, how many are Pro."
Statistics only — NO blocking, NO remote control, NO change to licensing.

## 1. Table `app_installs` (migration 015)
`id BIGINT PK, app_id VARCHAR(64) FK→apps, install_hash CHAR(64)` (sha256 sent by the app; never a raw device id), `tier ENUM('free','pro')`, `license_id INT NULL FK→licenses ON DELETE SET NULL` (only when a valid license key last4+token is sent, see below), `app_version VARCHAR(50)`, `manufacturer VARCHAR(100)`, `model VARCHAR(100)`, `os_version VARCHAR(50)`, `district/division/country VARCHAR(100) NULL` (via existing GeoIPService), `first_seen DATETIME`, `last_seen DATETIME`, `ping_count INT DEFAULT 1`. UNIQUE(app_id, install_hash). Indexes on (app_id,last_seen), (app_id,tier), first_seen.
Also `app_install_daily` (app_id, day DATE, new_installs, active, active_pro, active_free; PK app_id+day) updated on each ping (upsert) so charts stay fast.

## 2. Public endpoint `POST /v1/apps/{appId}/ping`
Request JSON: `{ installHash, tier: "free"|"pro", appVersion, manufacturer, model, osVersion, licenseToken? }`
- Validate: appId exists & active, installHash = 64 hex chars, tier in the enum, strings trimmed/length-limited. Unknown app → 404 `{ok:false}`.
- If `licenseToken` is sent: verify it with the app's Ed25519 public key (existing Crypto); if valid, set `license_id` from the token's keyHash and force `tier='pro'`; if invalid, store as `free` (never trust a client-claimed "pro" without a valid token).
- Upsert `app_installs` (first_seen kept, last_seen=now, ping_count+1, geo from IP — do not store the raw IP), upsert today's row in `app_install_daily` (count a device as active once per day).
- Rate-limit: max 1 counted ping per install per hour (extra pings return ok without counting); per-IP limit generous (CGNAT, e.g. 1000/hour).
- Response `{ ok: true, serverTime }`. Never errors to the app except 400/404/429.

## 3. Admin page `admin/installs.php` (nav: "ইনস্টল ও ব্যবহার")
Per-app selector (default: all apps) and date range (7/30/90 days, all time).
- Top tiles per app: মোট ইনস্টল · গত ৭ দিনে সক্রিয় · গত ৩০ দিনে সক্রিয় · ফ্রি ইউজার · Pro ইউজার · Free→Pro রূপান্তর হার.
- Charts (inline SVG or a pinned CDN lib already used in admin, if any): daily new installs, daily active (free vs pro stacked).
- Breakdown tables: app version, phone brand/model, district (top 10 each).
- Device list (paginated, searchable): brand/model, version, tier pill (FREE/PRO), license last4 + link to the license page when pro, district, first seen, last seen ("x দিন আগে"), ping count. CSV export button.
- A row on the existing dashboard (admin/index.php) showing per-app installs / active 7 d / free / pro.
- Inactive = no ping for 30 days (show greyed, keep in totals as "মোট ইনস্টল").

## 4. Tests & report
`tests/InstallStatsTest.php`: new install, repeat ping (no double count), free→pro upgrade with valid token, fake "pro" without token stays free, invalid hash 400, unknown app 404, rate limit, daily table correctness. Run ALL existing test suites. README API section. Report `docs/reports/install-stats.md` with production deploy order: backup DB → run migration 015 → push. Make the endpoint return `{ok:true}` silently (and log) if the tables are missing, so apps never break if deployed before the migration. STOP.
