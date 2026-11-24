# [Antigravity — ayyzan-license-hub] Phase 8: Remote control of apps (license mode, device block, home announcement)

Workspace: `E:\XAMPP\htdocs\ayyzan-license-hub`. Branch `remote-control` from `main`. Commit only, NEVER push. Do not touch app.ayyzan.com. Another agent works on the AI gateway (`src/Ai*`, `admin/ai_*`) — do not modify those files. Use the next free migration number (check `migrations/`).
Existing apps (Sarah OT Khata, Sarah Motion Studio/video-dubber, Talk2Type v1/v2) must keep working unchanged — only ADD.

## Goal (owner's words)
"From the license hub I want to control the app: make it free for everyone (no license asked), later switch the license system on so everyone falls under it, block any user, re-activate any user, and control the home screen."

## 1. Per-app license mode (apps table, new columns)
- `license_mode` ENUM('open','freemium','license_only') DEFAULT 'freemium'
  - `open` = everyone gets ALL features, app never asks for a license
  - `freemium` = current Talk2Type behaviour (Free tier limits, Pro with license)
  - `license_only` = app unusable without a valid license (shows activation screen)
- `free_daily_limit` INT NULL (override for freemium; NULL = app default)
- Announcement / home banner: `announce_active` TINYINT, `announce_text` VARCHAR(500), `announce_link` VARCHAR(255) NULL, `announce_button` VARCHAR(50) NULL, `announce_style` ENUM('info','success','warning','danger') DEFAULT 'info', `announce_dismissible` TINYINT DEFAULT 1, `announce_id` INT (bump on every edit so apps re-show it)

## 2. Device registry (new table `app_devices`)
`id, app_id, device_id_hash (sha256 like activations), model, manufacturer, os_version, app_version, license_key_last4 NULL, first_seen, last_seen, last_ip, status ENUM('active','blocked') DEFAULT 'active', block_reason VARCHAR(255) NULL, note VARCHAR(255) NULL`, UNIQUE(app_id, device_id_hash), FK app_id → apps.
Store only the hash of deviceId (never the raw id).

## 3. Public endpoint `POST /v1/apps/{appId}/config`
Request: `{ deviceId, appVersion, model, manufacturer, osVersion, licenseKeyLast4? }`
- Upsert `app_devices` (update last_seen etc.). Rate-limit per IP generously (CGNAT: e.g. 600/hour/IP) and per device (e.g. 30/hour); on limit return 429 without a config body.
Response 200:
```json
{ "success": true, "appId": "talk2type", "serverTime": 1795370791,
  "licenseMode": "open|freemium|license_only",
  "freeDailyLimit": 20,
  "device": { "status": "active|blocked", "message": "<Bangla, only when blocked>" },
  "announcement": { "id": 7, "text": "...", "link": "...", "button": "...", "style": "info", "dismissible": true } ,
  "minVersion": null, "ttlSeconds": 21600 }
```
- `announcement` is `null` when inactive. Blocked message default: "আপনার ডিভাইসটি সাময়িকভাবে বন্ধ করা হয়েছে। সহায়তার জন্য WhatsApp করুন: <support number>."
- App not found/inactive or any exception → `{ success:false, code:"UNAVAILABLE" }` (HTTP 200). Clients keep their cached config on this.

## 4. Admin
- Apps → app card: "লাইসেন্স মোড" radio (৩টা অপশন, Bangla help text per option, a confirmation dialog when switching open → freemium/license_only: "এখন যারা ফ্রিতে ব্যবহার করছে তাদের লাইসেন্স লাগবে। আগে ঘোষণা দিয়েছেন?"), free daily limit field, announcement editor with live preview.
- New page "ডিভাইস" (admin/devices.php, linked in the nav): filter by app, search by model / key last4 / note, sort by last_seen, columns: model, version, license last4, first/last seen, district if available, status; buttons Block (asks reason) / Unblock, note edit. Show counts: total, active in last 7 days, blocked. Pagination. Audit-log every block/unblock/mode change.
- Also allow Block/Unblock from a license's detail view for all devices of that license.

## 5. Tests & docs
Add `tests/AppConfigTest.php` (mode values, blocked device, announcement id, unknown app → UNAVAILABLE, rate limit, Sarah OT Khata /info untouched). Run all existing suites. README API section. Report `docs/reports/remote-control.md` with production deploy order (migration BEFORE push is not required if code tolerates missing columns — make `config` return `licenseMode:"freemium"` + no announcement when columns/table are missing, like getAppInfo does). STOP.
