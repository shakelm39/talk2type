# [Antigravity — Talk2Type] Phase 2: BYOK AI engine (customer's own API key)

Read `00_MASTER_PLAN.md` (Hard rules + Regression Checklist) first. Phase 1 must be approved before starting.

## Background
Business model is BYOK: customers bring their own free Gemini key. We will NOT run an AI proxy. Current code problems found in review:
1. **Bug**: `voiceflow_provider.dart::_resolveRepository()` — when `AppConfig.enableLicenseCheck == true` (true in production) it always uses `BackendApiVoiceRepository` → `https://license.ayyzan.com/api/process-voice`, an endpoint that does not exist for this model. So the recording fallback path (F6) is broken for licensed users.
2. `AppConfig.directGeminiApiKey = "YOUR_TEST_GEMINI_KEY"` placeholder is treated as a real key in places.
3. Customers have no guided way to get/enter/test a key.
4. Free online engines (`text.pollinations.ai`, unofficial `translate.googleapis.com ... client=gtx`) send user text to third parties silently.

## Tasks
### 2.1 AI routing (Dart)
- `_resolveRepository()`: always use `DirectGeminiVoiceRepository` with the user's saved keys (primary Gemini → backup Gemini → Groq, F10 unchanged), regardless of license state. Keep `BackendApiVoiceRepository` class in code (unused, for future) but do not route to it, except via the debug-only dev switch from Phase 1.
- If no key at all: do not call any network AI for audio; show the orb error "এআই ব্যবহারের জন্য সেটিংসে আপনার Gemini API key দিন" and save the failed item to history (existing behaviour).
- Treat empty strings and the placeholder `YOUR_TEST_GEMINI_KEY` as "no key". Remove the placeholder from `AppConfig` (default `""`).

### 2.2 Native pipeline order (Kotlin, FloatingOverlayService.kt)
For `bangla` and `english` modes the order becomes:
1. User's Gemini key (if set) → `callGeminiTextTransform` (primary key, then backup key `flutter.vf_backup_gemini_api_key` if primary fails),
2. **Free online engine** (pollinations / gtx) — ONLY if the new setting `flutter.vf_free_online_engine` is true,
3. Rule-based `formatBengaliPunctuation` (bangla) / return original Bangla text with a toast "অনুবাদের জন্য API key দিন" (english).
Default of `vf_free_online_engine`: **true** for users with no key, but it must be shown as a clearly labelled toggle (see 2.4) with a one-line privacy note. Add short timeouts so the orb never hangs > 6 s total; on any failure the user's spoken text must still be typed (F8 guarantee).

### 2.3 Key onboarding wizard (new screen `api_key_setup_screen.dart`)
- Reachable from: first launch after permissions (skippable: "পরে করব"), settings dialog, and from the orb error toast tap (open app).
- Steps in Bangla with numbered cards: ১) aistudio.google.com খুলুন (button opens URL in browser) ২) Google দিয়ে লগইন ৩) "Get API key" → "Create API key" ৪) কপি করে এখানে পেস্ট করুন.
- Fields: Primary Gemini key (required), Backup Gemini key (optional, collapsed "অ্যাডভান্সড"), Groq key (optional, collapsed). Paste button for each.
- "Key পরীক্ষা করুন" button: send a tiny text request to Gemini (reuse the repository's model list; first model that answers wins), show ✅ with model name or ❌ with a Bangla reason (invalid key / quota / no internet). For Groq: call its models list endpoint.
- Keys stored where they are today (SharedPreferences keys `vf_primary_gemini_api_key`, `vf_gemini_api_key`, `vf_backup_gemini_api_key`, `vf_backup_groq_api_key`) so the Kotlin side keeps reading them. Never display a full saved key — show `••••••••abcd` with an edit button.
- Home screen: small status chip "AI: সক্রিয় (নিজস্ব key)" / "AI: key নেই" that opens the wizard.

### 2.4 Settings
In the settings dialog add a toggle "ফ্রি অনলাইন ইঞ্জিন (key ছাড়া)" with note: "key না থাকলে বাক্য সাজাতে/অনুবাদে তৃতীয় পক্ষের ফ্রি সার্ভিস ব্যবহার হবে। ব্যক্তিগত তথ্যের জন্য বন্ধ রাখুন।" Saved as `vf_free_online_engine` (bool).

### 2.5 Hygiene
- Mask keys & tokens in every `debugPrint`/`Log` (last 4 chars only). grep the whole repo for logging of `apiKey`, `key=`, `token`.
- Gemini requests: send the key in the `x-goog-api-key` header instead of the `?key=` URL query where possible (Dart and Kotlin).

## Done =
Recording path works for licensed users with their key; native path works with key / with free engine / with neither; wizard tested with a valid key, an invalid key, and airplane mode (describe results); Regression checklist re-verified; report `reports/phase-2.md`; commit; STOP.
