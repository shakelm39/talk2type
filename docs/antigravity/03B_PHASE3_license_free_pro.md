# [Antigravity — Talk2Type] Phase 3B: Free vs Pro (lifetime) + license hardening

Read `00_MASTER_PLAN.md` first. Requires Phase 2 approved AND Phase 3A (hub) done — read the hub report for the exact verify endpoint and info fields; ask the owner to paste it if you cannot see it.

## Product rules
- **Free (no license)**: only `bangla` mode, max **20 voice inputs per day** (local counter, resets at local midnight; count both native-speech finishes and recording-path finishes). History, permissions, typing test, own API key: allowed.
- **Pro (lifetime license)**: all 5 modes, unlimited use, all Phase 4 features, history export.
- Put both numbers/lists in one place (`lib/core/config/plan_limits.dart`) so they are easy to change.

## Tasks
1. **Splash gate** (`splash_gate_screen.dart`): app must no longer be blocked without a license. No valid license → a choice screen: "লাইসেন্স অ্যাক্টিভেট করুন" / "ফ্রি ভার্সনে চালান". Remember the choice; licensed users go straight in (current flow).
2. **Pro flag shared with Kotlin**: store `vf_is_pro` (bool) in SharedPreferences whenever license state changes; Kotlin reads `flutter.vf_is_pro`. Also store the daily counter as `vf_daily_count` + `vf_daily_date` so both sides read/write the same values (write from Kotlin via the same FlutterSharedPreferences file).
3. **Gating in the orb (Kotlin)**:
   - Locked modes show a 🔒 on their pill; tapping a locked mode → toast "এটি Pro ফিচার" + opens the app's upgrade screen (intent extra).
   - When the daily limit is reached: orb shows a short message "আজকের ফ্রি সীমা শেষ — Pro নিন" and opens upgrade screen on tap; no recording starts.
4. **Upgrade screen** (new): Pro benefits list (Bangla), `price_text` and "কিনুন" button opening `purchase_url` from hub app info (fallback constants in AppConfig if the hub doesn't return them), and "আমার লাইসেন্স কী আছে" → activation screen.
5. **Periodic verification** (`license_service.dart`): call the hub verify endpoint on app start and at most every 72 h when online. `valid:false` with status revoked/device_mismatch/not_found → clear license, `vf_is_pro=false`, show the hub's Bangla message once. Network errors — and also HTTP 404/405/5xx or an unparseable response (e.g. the verify endpoint is not deployed yet) — never downgrade, but if no successful verify for **30 days** → treat as Free until the next successful verify. Store `vf_last_verified_at`. Lifetime keys may have `expiresAt == null` → that is valid forever (keep existing expiry handling for non-null values).
6. **License info screen** (or section): plan name, masked key (last 4), device ID (copyable, for support), last verified time, "লাইসেন্স সরান" (existing clearLicense).
7. Existing activated users after updating must stay Pro without re-entering the key (migrate: existing token present → `vf_is_pro=true`, schedule a verify).

## Done =
Test matrix in the report: fresh install free; free limit hit; activate valid key; invalid key; revoked key (ask owner to revoke a test key in hub, or simulate response); offline 31 days (simulate by editing `vf_last_verified_at` in debug); upgrade from v1.0.x with existing license. Regression checklist re-verified. Commit. STOP.
