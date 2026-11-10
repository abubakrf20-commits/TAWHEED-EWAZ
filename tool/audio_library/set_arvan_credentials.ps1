<#
.SYNOPSIS
  Stores ArvanCloud S3 credentials in an env file OUTSIDE the git repository.

.DESCRIPTION
  Prompts for the Access Key ID and Secret Access Key from the ArvanCloud panel
  and writes them to %LOCALAPPDATA%\Temp\opencode\arvan.env.

  Two things this does that a hand-edited file does not:

  - The secret is read with -AsSecureString, so it is never echoed to the
    console and never lands in the PowerShell history. Paste it like a password.
  - The file is written with an explicit ACL for the current user only, so the
    secret is not readable by other accounts on the machine.

  The file is outside the repository on purpose: it can never be committed by
  accident, and `git status` will never show it.

.PARAMETER Endpoint
  S3 endpoint to write. Defaults to the Ir_thr_at1 storage endpoint that serves
  the yaqeen / nasheed / t-sokhanrani buckets.

  The host is arvanstorage.ir, not arvancloud.ir: s3.ir-thr-at1.arvancloud.ir
  does not resolve in DNS at all, so an "arvancloud" endpoint fails with
  EndpointConnectionError before a single request is signed.

.PARAMETER OutFile
  Override the destination path.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\audio_library\set_arvan_credentials.ps1
#>
[CmdletBinding()]
param(
    [string] $Endpoint = 'https://s3.ir-thr-at1.arvanstorage.ir',
    [string] $OutFile
)

$ErrorActionPreference = 'Stop'

if (-not $OutFile) {
    $OutFile = Join-Path $env:LOCALAPPDATA 'Temp\opencode\arvan.env'
}

$parent = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

Write-Host ''
Write-Host 'ArvanCloud S3 credentials' -ForegroundColor Cyan
Write-Host 'Paste the values from the panel (Storage > Buckets > Access Keys).' -ForegroundColor DarkGray
Write-Host 'Input is hidden and is not written to shell history.' -ForegroundColor DarkGray
Write-Host ''

$accessKey = Read-Host 'Access Key ID'
if ([string]::IsNullOrWhiteSpace($accessKey)) {
    $accessKey = (Read-Host 'Access Key ID').Trim()
}

$secureSecret = Read-Host 'Secret Access Key' -AsSecureString
$secretPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
try {
    $secretKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPtr)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPtr)
}

$accessKey = $accessKey.Trim()
$secretKey = $secretKey.Trim()

if ([string]::IsNullOrWhiteSpace($accessKey) -or [string]::IsNullOrWhiteSpace($secretKey)) {
    Write-Host ''
    Write-Host 'ERROR: both values are required. Nothing was written.' -ForegroundColor Red
    exit 2
}

# Reject stray characters that would corrupt the key=value parsing downstream.
foreach ($pair in @(@('Access Key', $accessKey), @('Secret Key', $secretKey))) {
    if ($pair[1] -match '[\r\n"]') {
        Write-Host ''
        Write-Host ("ERROR: the {0} contains a quote or a line break. Copy it again from the panel." -f $pair[0]) -ForegroundColor Red
        exit 2
    }
}

$lines = @(
    ('ARVAN_ACCESS_KEY=' + $accessKey),
    ('ARVAN_SECRET_KEY=' + $secretKey),
    ('ARVAN_ENDPOINT=' + $Endpoint)
)
[System.IO.File]::WriteAllText($OutFile, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))

# Lock the file down to the current user. Best effort: a filesystem that does not
# support ACLs (some network shares) should not abort a working setup.
try {
    $acl = Get-Acl -LiteralPath $OutFile
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        'FullControl', 'Allow')
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $OutFile -AclObject $acl
    $aclNote = 'locked to the current user'
}
catch {
    $aclNote = 'WARNING: could not set the ACL, file may be readable by other accounts'
}

# Do not leave the plaintext secret sitting in this session's memory any longer
# than necessary.
$secretKey = $null
$secureSecret = $null

Write-Host ''
Write-Host ('Wrote ' + $OutFile) -ForegroundColor Green
Write-Host ('  endpoint  : ' + $Endpoint)
Write-Host ('  access key: ' + $accessKey.Substring(0, [Math]::Min(4, $accessKey.Length)) + '...') -ForegroundColor DarkGray
Write-Host ('  acl       : ' + $aclNote) -ForegroundColor DarkGray
Write-Host ''
Write-Host 'This file is outside the repository and will never be committed.' -ForegroundColor DarkGray
Write-Host ''