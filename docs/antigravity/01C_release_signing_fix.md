# [Antigravity — Talk2Type] Phase 1.2: Fix in-app update failure (APK signing)

Same Hard rules (branch `commercial-v2`, commit only, never push). Do this right after Phase 1.1, before Phase 2.

## Root cause (supervisor finding)
`android/app/build.gradle.kts` release buildType uses `signingConfig = signingConfigs.getByName("debug")`. On GitHub Actions every run creates a NEW random debug keystore, so every released APK has a different signature. Android refuses to install an update whose signature differs from the installed app ("অ্যাপ ইনস্টল করা হয়নি / package conflicts"). That is why the update dialog shows, downloads, but the update never installs.

## Tasks
1. **Release keystore (owner's PC, one time)** — guide the owner and run with him:
   `keytool -genkeypair -v -keystore E:\keys\talk2type-release.jks -alias talk2type -keyalg RSA -keysize 2048 -validity 10000`
   Keystore must live OUTSIDE the repo (e.g. `E:\keys\`). Tell the owner clearly: back it up (Google Drive + USB). If it is lost, no future update can ever install over the app.
2. **Gradle**: add a `release` signingConfig that reads from `android/key.properties` (storeFile, storePassword, keyAlias, keyPassword) when present, otherwise from env vars `T2T_KEYSTORE_PATH`, `T2T_KEYSTORE_PASSWORD`, `T2T_KEY_ALIAS`, `T2T_KEY_PASSWORD`. If neither exists, fall back to debug signing **with a loud Gradle warning** (so local dev still works). Add `android/key.properties`, `*.jks`, `*.keystore` to `.gitignore`. Never commit the keystore or passwords.
3. **CI** (`.github/workflows/build-release.yml`): before the build step, decode secret `T2T_KEYSTORE_BASE64` to a temp file and export the env vars from secrets `T2T_KEYSTORE_PASSWORD`, `T2T_KEY_ALIAS`, `T2T_KEY_PASSWORD`. If the secret is missing, FAIL the job (never publish a debug-signed release again). Keep everything else in the workflow unchanged.
   Give the owner exact steps to add the 4 secrets in GitHub → repo → Settings → Secrets and variables → Actions (incl. PowerShell command to base64 the .jks: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("E:\keys\talk2type-release.jks")) | Set-Clipboard`).
4. **Updater safety** (`app_update_service.dart` + `MainActivity.kt`): before launching the installer, compare the downloaded APK's signing certificate with the installed app's (`PackageManager.getPackageArchiveInfo(path, GET_SIGNING_CERTIFICATES)` on API 28+, `GET_SIGNATURES` below). If they differ, do NOT open the installer; show a Bangla dialog: "এই আপডেটটি নতুন নিরাপত্তা সাইনসহ এসেছে। একবার পুরোনো অ্যাপ আনইনস্টল করে নতুন অ্যাপ ইনস্টল করুন। (আপনার লাইসেন্স কী আবার দিতে হবে)" with buttons "ডাউনলোড পেজ খুলুন" (download URL in browser) and "বাতিল".
   Also: if the "Install unknown apps" permission for Talk2Type is not granted (`packageManager.canRequestPackageInstalls()` false on API 26+), first send the user to `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` for this package with a Bangla explanation, then continue.
5. Report: append "Phase 1.2" to `reports/phase-1.md` incl. the owner's step list. Commit `fix(release): proper release signing + update signature check`. Then continue to Phase 2.

Note for owner (write in report): users on v1.0.x must uninstall/reinstall ONCE (signature change is unavoidable). From then on all updates install normally.
