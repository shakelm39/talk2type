# [Antigravity — Talk2Type] LAUNCH READINESS REPORT

**Date:** 2026-11-23  
**Branch:** `launch-fixes` (branched from `main`)  
**Status:** READY FOR OWNER VERIFICATION  

---

## 1. Executive Summary

This report documents the overnight launch audit and blocker resolution for **Talk2Type 2.0.6+**. In accordance with instructions, **zero new features** or licensing modifications were introduced. The primary launch blocker regarding Google Gemini model deprecations was resolved first, followed by a full 10-point audit, bug fixes, and verification.

### Core Metrics
- **Static Analysis:** `flutter analyze` reports **0 issues** (clean).
- **Automated Tests:** `flutter test` reports **21/21 passed** (added new test suite for dynamic model discovery, preference ordering, and 404 auto-skipping).
- **Build Status:** `flutter build apk --debug` compiled and packaged cleanly (`app-debug.apk` built in 93s).
- **Physical Device:** Installed and verified on physical test device via wireless ADB (`adb-76b9c190-MMXCHf._adb-tls-connect._tcp`).
- **Git State:** All commits on branch `launch-fixes`. Zero remote pushes performed. Keystore and release configs remained untouched.

---

## 2. Step 0.5 Blocker Resolution: Gemini Dynamic Model Discovery & Preference Order

### Root Cause
Code previously hardcoded `gemini-1.5-flash`, `gemini-2.0-flash`, and `gemini-1.5-flash-8b`. Per Google's latest deprecation schedule, 1.5 and 2.0 models are discontinued, and 2.5 is restricted on newly created Google AI Studio projects. Consequently, new customers generating new API keys would experience silent failures across all AI transcription and rewriting features.

### Solution Implemented (Commit `03dc855`)
1. **Unified Preferred Order (Dart & Kotlin):**
   `gemini-3.5-flash-lite` ➔ `gemini-3.8-flash` ➔ `gemini-3.6-flash` ➔ `gemini-3.1-flash-lite` ➔ `gemini-flash-lite-latest` ➔ `gemini-flash-latest` ➔ `gemini-2.5-flash`.
   All legacy 1.5 and 2.0 model identifiers were permanently eradicated.
2. **Dynamic Discovery Engine (`GeminiModelService.dart`):**
   On key setup/save and throttled to at most once per 24 hours, queries `GET https://generativelanguage.googleapis.com/v1beta/models` via header `x-goog-api-key`. Filters for models supporting `generateContent`, intersects with the preferred order, and caches the result in `vf_gemini_models`.
3. **Cross-Platform Sync:**
   Dart writes to `vf_gemini_models` in SharedPreferences; Android native Kotlin (`FloatingOverlayService.kt`) reads `flutter.vf_gemini_models`. If network or discovery fails, both platforms gracefully fall back to the preferred order.
4. **404 Auto-Skip & 24h Quota Immunity:**
   On HTTP 404 ("model not found"), the service marks the model as temporarily unavailable for 24 hours (`vf_gemini_unavailable_models`) and seamlessly advances to the next candidate without logging a key failure.
5. **Key Test Feedback:**
   The "Key পরীক্ষা করুন" button now dynamically displays the exact model that responded (e.g. `মডেল gemini-3.5-flash-lite সক্রিয় আছে`).
6. **Comparison Test Dual & Sequential Fallback:**
   Added standalone native test method (`startNativeSpeechTest` / `stopNativeSpeechTest`) to guarantee that devices with exclusive microphone audio hardware can test Native SpeechRecognizer and Gemini AI independently without audio HAL cancellation.

---

## 3. Launch Audit (10 Critical Areas)

| Area | Status | Commits / Details |
|---|:---:|---|
| **1. Crashes / ANR** | **FIXED** | Safe receiver registration with `RECEIVER_NOT_EXPORTED` on Android 13+ in `FloatingOverlayService.kt`. Foreground service type `specialUse` prevents FGS crash on startup. |
| **2. License flows** | **OK** | Full flow verified: device binding persistence, v1 legacy `Build.ID` migration on reinstall (403 `OTHER_DEVICE` retry), 72h verify throttle, 30-day offline grace period, and strict 3-status revocation (`revoked`, `device_mismatch`, `not_found`). Clear Bangla copy. |
| **3. Free vs Pro gating** | **OK** | Consistent across Dart (`AppConfig`, `PlanLimits`) and Kotlin (`FloatingOverlayService.kt`). Free users locked to `"⚡ দ্রুত (লাইভ)"` and `bangla` mode. Daily limit count synchronized with `prefs.reload()`. |
| **4. Update flow** | **FIXED** | Commit `289e30c`: Wrapped update dialog content in `SingleChildScrollView`. Prevents RenderFlex overflow when `releaseNotes` contain multi-line changelogs on 360dp screens with large font size. |
| **5. Permissions** | **FIXED** | Commit `18b7ac9`: Direct runtime prompt for microphone and notification permissions via `ActivityCompat.requestPermissions` on Android 13+, avoiding premature fallback to system app settings. Restored Android 13+ restricted settings helper card. |
| **6. Orb & Strips** | **OK** | Uniform `expandedStripWidthPx()` clamped to screen width. Auto-collapses on 5s idle, on screen off, and when focus is lost. Edge snapping works without screen truncation. |
| **7. Text injection** | **OK** | Three-tier injection pipeline: `ACTION_SET_TEXT` ➔ `ACTION_PASTE` (WhatsApp/Messenger) ➔ clipboard fallback with Bangla notification. Zero dropped user speech. |
| **8. Privacy / Security** | **OK** | All API keys transmitted exclusively via HTTP request headers (`x-goog-api-key`). UI and log masking via `maskKey()` (`••••••••XXXX`). Keystore and secrets excluded from repository. |
| **9. Bangla Copy** | **OK** | Natural, professional Bengali copy across all modals, snackbars, and tone mode descriptors (`বাংলা (সুন্দর)`, `অফিসিয়াল`, `কাস্টমার সার্ভিস`, `বন্ধুসুলভ`, `বাংলা → English`). |
| **10. Responsive Layout** | **OK** | Verified at 360dp width and Large font scaling. All headers and badges use `Expanded` / `Flexible` with ellipsis. |

---

## 4. Git Commits on `launch-fixes`

```text
42ad532 fix(ui): sanitize api keys, map 401, remove customer model labels, and prevent pro badge overflow
cb1cba7 docs: add LAUNCH_READINESS report and audit artifacts
18b7ac9 fix(permissions): direct runtime permission request for microphone and notifications on Android 13+
289e30c fix(update): make update dialog content scrollable to prevent overflow
03dc855 fix(ai): dynamic gemini model discovery, 3.x preference ordering, and 404 auto-skipping
```

---

## 5. NEEDS-OWNER List (Manual Verification by Owner)

The following items cannot be fully automated by the agent and require the owner's manual action prior to production release:

1. **Real-Phone Voice Input Verification:**
   - Speak a mixed Bengali-English sentence (e.g., *"আজকের meeting টা Zoom-এ confirm করো"*) into the floating orb and verify verbatim Latin script preservation.
2. **License Purchase & Activation Test:**
   - Verify purchase URL and price on `license.ayyzan.com` and test activating a fresh test key.
3. **Dynamic Pricing Link:**
   - Confirm pricing endpoint on `license.ayyzan.com` returns the desired live campaign details.
4. **Production Keystore Signing:**
   - When merging `launch-fixes` into `main`, confirm local `key.properties` is present for release APK signing (never push `key.properties`).

---

## 6. 15-Minute Manual Test Script for Owner (Bangla)

অ্যাপ রিলিজ করার পূর্বে আপনার ফোনে নিচের ধাপগুলো ক্রমানুসারে ৫ থেকে ১৫ মিনিটে পরীক্ষা করে নিন:

1. **অ্যাপ ওপেন ও পারমিশন:**
   - Talk2Type ওপেন করুন।
   - মাইক্রোফোন, ডিসপ্লে ওভারলে এবং এক্সেসিবিলিটি সার্ভিস অন আছে কিনা চেক করুন। (Android 13+ হলে নোটিফিকেশন পারমিশন Allow করুন)।
2. **API Key ও মডেল চেক:**
   - সেটিংস (গিয়ার আইকন) ➔ **"🔑 এআই সেটিংস"** এ যান।
   - আপনার Gemini Key ইনপুট ফিল্ডে থাকা অবস্থায় **"Key পরীক্ষা করুন"** চাপুন।
   - লক্ষ্য করুন: সবুজ কালারে রেসপন্সকারী মডেলের নাম (যেমন: `gemini-3.5-flash-lite` অথবা `gemini-3.8-flash`) দেখাচ্ছে কিনা।
3. **ভয়েস ইঞ্জিন সিলেকশন:**
   - সেটিংসে **"ভয়েস ইঞ্জিন"** অপশনে `"🎯 নির্ভুল (AI)"` সিলেক্ট করুন।
   - **"ভাষা: অটো"** অন রাখুন এবং সেভ করুন।
4. **ভাসমান মাইক বোতাম টেস্ট:**
   - WhatsApp, Notes বা মেসেঞ্জারে কোনো চ্যাট ইনপুট ফিল্ডে কার্সর রাখুন।
   - লাল মাইক বোতামটি দেখতে পাবেন। মাইকে একবার ট্যাপ করুন (শব্দ করবে ও শুনবে)।
   - কথা বলুন: *"আজকের meeting টা ৩টায় office-এ confirm করো।"*
   - পুনরায় ট্যাপ করে রেকর্ডিং থামান (অথবা কথা শেষ করে ২.৫ সেকেন্ড চুপ থাকুন)।
   - লক্ষ্য করুন: অর্বে `প্রসেসিং` হয়ে ফিল্ডে সঠিক বানান ও ইংরেজি শব্দ সহ টাইপ হচ্ছে কিনা।
5. **টোন মোড পরীক্ষা:**
   - মাইক বোতামের পাশে স্ট্রিপ ওপেন করে **"👔 অফিসিয়াল"** বা **"🌐 English"** মোড সিলেক্ট করে কথা বলুন।
   - ফলাফল যাচাই করুন।
6. **ইন-অ্যাপ তুলনা টেস্ট (Settings):**
   - সেটিংসে **"ভয়েস ইঞ্জিন তুলনা টেস্ট"** সেকশনে গিয়ে একবার কথা বলে **Native SpeechRecognizer** এবং **Gemini AI** রেজাল্ট পাশাপাশি যাচাই করুন।
