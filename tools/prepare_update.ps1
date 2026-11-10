# prepare_update.ps1 — build a self-hosted release APK and stage the in-app update
# manifest for the content repo (the same GitHub repo that serves app/update.json).
#
# The phone's "بررسی بروزرسانی" (About screen) reads {contentBase}/app/update.json
# and downloads + installs the APK inside the app (self-hosted builds only).
#
# IMPORTANT — versioning is frozen in android/app/build.gradle.kts:
#   FROZEN_VERSION_CODE is the ONE number that ever moves. It is bumped by
#   1..10 only right before a publish, and stays put through the whole
#   development cycle. pubspec's `+code` / `--build-number` take no part.
#   The universal APK carries it verbatim; ABI-split APKs carry it
#   +1000 (armeabi-v7a) / +2000 (arm64-v8a). This script publishes all three
#   and lists the splits under `apkVariants`, so a phone that already runs a
#   split downloads that same ~31 MB artifact instead of the ~47 MB universal
#   one. Fat installs and older clients fall back to the universal `apkUrl`.
#   The in-app `revision` is derived from the same frozen number so baked
#   (APP_REVISION) and unbaked builds rank updates correctly.
#
# Usage:
#   .\tools\prepare_update.ps1 -Repo "C:\repos\TAWHEED-EWAZ" [-Notes "متن تغییرات"] [-SkipBuild]
#
# After it runs: cd $Repo ; git add app; git commit; git push — and the new
# APK + manifest go live on GitHub raw immediately.
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    [string]$Notes = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# ── 1. Frozen versionCode / revision / version name ────────────────────
$vMatch = [regex]::Match((Get-Content "pubspec.yaml" -Raw), '^version:\s*([0-9.]+)\+(\d+)')
if (-not $vMatch.Success) { throw "pubspec version line not found" }
$VersionName = $vMatch.Groups[1].Value

$fMatch = [regex]::Match((Get-Content "android\app\build.gradle.kts" -Raw), 'val FROZEN_VERSION_CODE\s*=\s*([\d_]+)')
if (-not $fMatch.Success) { throw "FROZEN_VERSION_CODE not found in android/app/build.gradle.kts" }
$FrozenCode = [int64]($fMatch.Groups[1].Value -replace '_', '')

# Revision aligns with the OS versionCode of the universal (= base) build so
# old, unbaked installs (runningRevision = OS code) and fresh baked builds agree.
$Revision = $FrozenCode

$manifestPath = Join-Path $Repo "app\update.json"
$apkDir = Join-Path $Repo "app\apk"

if (Test-Path $manifestPath) {
    $current = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ([int64]$current.revision -ge $Revision) {
        Write-Warning "Existing manifest revision ($($current.revision)) is >= frozen code ($Revision). Bump FROZEN_VERSION_CODE by 1..10 in android/app/build.gradle.kts (and the expectation in test/android/version_code_scheme_test.dart) and retry."
        exit 1
    }
}

$baseUrl = Get-Content "assets\env\quran_api.env" -ErrorAction SilentlyContinue |
    Select-String -Pattern '^QF_CONTENT_BASE\s*=\s*(.+)$' |
    Select-Object -First 1
if ($baseUrl) {
    $contentBase = $baseUrl.Matches.Groups[1].Value.Trim('"')
} else {
    $contentBase = "https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/main"
}
$apkFileName = "tawheeed-$VersionName.apk"
$apkUrl = "$contentBase/app/apk/$apkFileName"
$playUrl = "https://play.google.com/store/apps/details?id=com.islamic.tawheeed"

Write-Host "Version     : $VersionName"
Write-Host "FROZEN code : $FrozenCode  (build.gradle.kts; universal APK)"
Write-Host "In-app rev  : $Revision"
Write-Host "APK URL     : $apkUrl"

# ── 2. Build the release APKs (universal + per-ABI) ─────────────────────
$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$sourceArm64 = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
$sourceArmv7 = "build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk"
if (-not $SkipBuild) {
    flutter build apk --release --dart-define=APP_REVISION=$Revision
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed ($LASTEXITCODE)" }
    # --split-per-abi exits 1 on this toolchain although both splits are
    # produced and valid; the file checks below are the real verdict.
    flutter build apk --release --split-per-abi --dart-define=APP_REVISION=$Revision
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "split build exited $LASTEXITCODE (expected on this toolchain); checking the outputs instead"
    }
}
if (-not (Test-Path $sourceApk)) { throw "No APK at $sourceApk (run without -SkipBuild)" }

# ── 3. Stage APK + manifest into the content repo ───────────────────────
New-Item -ItemType Directory -Force -Path $apkDir | Out-Null
Copy-Item $sourceApk (Join-Path $apkDir $apkFileName) -Force
$universalSha = (Get-FileHash $sourceApk -Algorithm SHA256).Hash.ToLowerInvariant()

$variants = @()
$arm64Name = "tawheeed-$VersionName-arm64-v8a.apk"
$armv7Name = "tawheeed-$VersionName-armeabi-v7a.apk"
if (Test-Path $sourceArm64) {
    Copy-Item $sourceArm64 (Join-Path $apkDir $arm64Name) -Force
    $variants += [ordered]@{
        abi         = "arm64-v8a"
        # AGP derives the split codes itself: base + 2000 (arm64), + 1000 (v7a).
        versionCode = $FrozenCode + 2000
        url         = "$contentBase/app/apk/$arm64Name"
        sha256      = (Get-FileHash $sourceArm64 -Algorithm SHA256).Hash.ToLowerInvariant()
    }
} else {
    Write-Warning "No arm64 split at $sourceArm64; the manifest will serve the universal APK on arm64"
}
if (Test-Path $sourceArmv7) {
    Copy-Item $sourceArmv7 (Join-Path $apkDir $armv7Name) -Force
    $variants += [ordered]@{
        abi         = "armeabi-v7a"
        versionCode = $FrozenCode + 1000
        url         = "$contentBase/app/apk/$armv7Name"
        sha256      = (Get-FileHash $sourceArmv7 -Algorithm SHA256).Hash.ToLowerInvariant()
    }
} else {
    Write-Warning "No armeabi-v7a split at $sourceArmv7; the manifest will serve the universal APK on 32-bit"
}

$manifest = [ordered]@{
    revision    = $Revision
    versionCode = $Revision
    versionName = $VersionName
    notes       = $Notes
    apkUrl      = $apkUrl
    apkSha256   = $universalSha
    apkVariants = $variants
    playUrl     = $playUrl
    mandatory   = $false
}
$json = $manifest | ConvertTo-Json -Depth 4
# No BOM: the checker jsonDecode()s the raw response body, and a leading
# U+FEFF throws a FormatException.
[System.IO.File]::WriteAllText($manifestPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "Staged:"
Write-Host "  $manifestPath"
Write-Host "  $(Join-Path $apkDir $apkFileName)  (universal)"
foreach ($v in $variants) {
    Write-Host "  $($v.url.Split('/')[-1])  ($($v.abi), code $($v.versionCode))"
}
Write-Host ""
Write-Host "Now publish (in $Repo):"
Write-Host "  git add app"
Write-Host "  git commit -m \"update: tawheeed $VersionName (rev $Revision)\""
Write-Host "  git push"
Write-Host ""
Write-Host "Phones running 'درباره برنامه → بررسی بروزرسانی' will then see the new version."
Write-Host "TIP: the arm64 split (same code as the phone's) installs directly for testing:"
Write-Host "  adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"