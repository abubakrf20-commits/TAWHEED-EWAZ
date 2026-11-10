# Builds the release artifacts for distribution:
#   1. appbundle  -> Play Store upload (android/app/outputs/bundle/release/)
#   2. split APKs  -> direct download (android/app/outputs/apk/release/)
#      (arm64-v8a + armeabi-v7a per-ABI splits, plus a universal APK)
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools/build_release.ps1
# Requires: Flutter SDK on PATH, key.properties + keystore configured.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Show-Sizes([string]$label, [string[]]$paths) {
  Write-Host ""
  Write-Host "=== $label ===" -ForegroundColor Cyan
  foreach ($p in $paths) {
    if (Test-Path $p) {
      $size = (Get-Item $p).Length / 1MB
      Write-Host ("  {0,-60} {1,8:N2} MB" -f (Split-Path $p -Leaf), $size)
    }
  }
}

Write-Host "==> flutter build appbundle --release" -ForegroundColor Green
flutter build appbundle --release --target-platform android-arm,android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> flutter build apk --release (splits + universal)" -ForegroundColor Green
flutter build apk --release --target-platform android-arm,android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$bundleDir = "build\app\outputs\bundle\release"
$apkDir = "build\app\outputs\flutter-apk"

Show-Sizes "APP BUNDLE (Play Store)" @(
  "$bundleDir\app-release.aab"
)

Show-Sizes "SPLIT APKs (direct download)" @(
  "$apkDir\app-arm64-v8a-release.apk",
  "$apkDir\app-armeabi-v7a-release.apk",
  "$apkDir\app-universal-release.apk"
)

Write-Host ""
Write-Host "Done." -ForegroundColor Green