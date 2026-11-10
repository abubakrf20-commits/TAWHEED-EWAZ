<#
.SYNOPSIS
  ساخت APK نسخهٔ release با فعال‌سازیِ گزارش خطا (Sentry).

.DESCRIPTION
  دستور سادهٔ «flutter build apk --release» هیچ SENTRY_DSN را پاس نمی‌دهد،
  بنابراین Sentry در نسخهٔ منتشرشده بی‌صدا خاموش می‌ماند. از این اسکریپت
  استفاده کنید تا خطاهای کاربران گزارش شوند:

    1) در Sentry یک پروژهٔ Flutter/Android بسازید و DSN را بردارید.
    2) DSN را در همین نشست تنظیم کنید:
         $env:SENTRY_DSN = 'https://<key>@o0.ingest.sentry.io/<project>'
    3) اجرا کنید:
         pwsh -File tool/build_release.ps1

  برای بیلد عمداً بدون گزارش (فقط تست محلی) از -NoSentry استفاده کنید.
  راهنمای کامل: docs/ERROR_TRACKING.md
#>
[CmdletBinding()]
param(
  [switch]$NoSentry,
  [string]$AppRevision = $env:APP_REVISION,
  [switch]$SplitPerAbi
)

$ErrorActionPreference = 'Stop'

$flutterArgs = @('build', 'apk', '--release')

if ($NoSentry) {
  Write-Warning 'Building WITHOUT Sentry error reporting (-NoSentry).'
}
elseif ([string]::IsNullOrWhiteSpace($env:SENTRY_DSN)) {
  throw 'SENTRY_DSN is not set. Set $env:SENTRY_DSN=<dsn> or pass -NoSentry. See docs/ERROR_TRACKING.md.'
}
else {
  $flutterArgs += "--dart-define=SENTRY_DSN=$($env:SENTRY_DSN)"
  Write-Host 'Sentry error reporting: ENABLED'
}

if (-not [string]::IsNullOrWhiteSpace($AppRevision)) {
  $flutterArgs += "--dart-define=APP_REVISION=$AppRevision"
}

if ($SplitPerAbi) {
  $flutterArgs += '--split-per-abi'
}

Write-Host "flutter $($flutterArgs -join ' ')"
& flutter @flutterArgs
exit $LASTEXITCODE
