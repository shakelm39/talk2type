# [Antigravity — ayyzan-license-hub] Phase 3A: License verify + app info for Talk2Type

**Workspace: `E:\XAMPP\htdocs\ayyzan-license-hub` (repo shakelm39/ayyzan-license-hub). NOT the Talk2Type repo.**
This hub is live at license.ayyzan.com and auto-deploys from GitHub when the owner pushes. Other apps (Sarah OT Khata, Sarah Motion Studio) already depend on it — **do not change existing request/response formats**; only add.

## Rules
- Commit only, never push (owner pushes → auto-deploy). Work on branch `talk2type-verify`.
- Do NOT touch the app.ayyzan.com Laravel codebase.
- No breaking change to `/api/v1/activate` or `/v1/apps/{appId}/info` (Talk2Type v1.0.x in customers' phones uses them right now).
- Licenses are lifetime only.

## Tasks
1. **Investigate first** and write findings at the top of your report: framework/structure, existing routes, how `/api/v1/activate` works (token format, device binding, max devices), whether a verify/validate/check endpoint already exists (Sarah OT Khata may use one), how app `info` (version, download URL) is stored.
2. **Verify endpoint** — if an equivalent already exists, reuse it and just document it. Otherwise add `POST /api/v1/verify`:
   - request JSON: `{ "appId": "talk2type", "key": "...", "deviceId": "...", "token": "..." }`
   - response 200: `{ "success": true, "valid": true|false, "status": "active|revoked|device_mismatch|not_found", "planName": "...", "message": "<Bangla message>" }`
   - must check: license exists for that appId, not revoked/blocked, deviceId is bound to that license, token matches what activate issued (if tokens are stored). Rate-limit per IP/device sensibly. Never return other customers' data.
3. **App info**: make sure `/v1/apps/talk2type/info` can also return `purchase_url` (where to buy) and optional `price_text` (e.g. "৳৯৯৯ লাইফটাইম") configurable from the hub admin for each app. Add the fields to the app settings form if missing; keep old fields unchanged.
4. Make sure an app with id `talk2type` exists (or document exactly how the owner adds it in the admin).
5. Add a short API doc section (README or docs file) for activate / verify / info with example curl.

## Done =
Report `docs/reports/talk2type-3a.md` inside the hub repo (create folder) with findings, endpoints, example requests/responses, and confirmation that Sarah OT Khata / Sarah Motion Studio flows are untouched. Commit on `talk2type-verify`. STOP.
