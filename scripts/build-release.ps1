# Talk2Type - signed release APK build (local)
# Usage (PowerShell):  E:\XAMPP\htdocs\Talk2Type\scripts\build-release.ps1
# Asks the keystore password once. Nothing is saved to disk.
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$ks = "E:\keys\talk2type-release.jks"
if (-not (Test-Path $ks)) { Write-Host "Keystore not found: $ks" -ForegroundColor Red; exit 1 }

$sec = Read-Host "Keystore password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try {
    $env:T2T_KEYSTORE_PATH = $ks
    $env:T2T_KEY_ALIAS = "talk2type"
    $env:T2T_KEYSTORE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    $env:T2T_KEY_PASSWORD = $env:T2T_KEYSTORE_PASSWORD
    flutter build apk --release
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    Remove-Item Env:T2T_KEYSTORE_PASSWORD, Env:T2T_KEY_PASSWORD -ErrorAction SilentlyContinue
}
$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
    Copy-Item $apk "$env:USERPROFILE\Desktop\Talk2Type-test.apk" -Force
    Write-Host "`nDone: Desktop\Talk2Type-test.apk" -ForegroundColor Green
}
