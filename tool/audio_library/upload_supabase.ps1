param(
    [string]$BaseUrl = 'https://qjrhxnmxmqtnusifpngd.supabase.co',
    [Parameter(Mandatory = $true)][string]$Bucket,
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [string]$FolderPrefix = '',
    [string]$ManifestFile = 'index.json',
    [int]$MaxAttempts = 3
)

# Uploads the audio-library tracks + manifest to a Supabase storage bucket.
#
#   $env:SUPABASE_SERVICE_ROLE = '<secret>'   # set ONCE, never committed
#   .\upload_supabase.ps1 -Bucket tawheed -SourceDir "...\upload" -FolderPrefix yaqeen
#
# Resumable: objects that already exist with the correct size are skipped, so
# rerunning after a dropped connection just continues. Every upload is retried
# up to $MaxAttempts times. File keys are expected to be ASCII (see
# rename_yaqeen.ps1 / build_manifest.ps1); Persian titles live in the manifest.

$ErrorActionPreference = 'Stop'

# Large binary uploads sometimes get mangled by an HTTP(S) proxy; bypass it.
$env:HTTP_PROXY = ''
$env:HTTPS_PROXY = ''
$env:NO_PROXY = '*'

if (-not $env:SUPABASE_SERVICE_ROLE) {
    throw 'Set $env:SUPABASE_SERVICE_ROLE to the Supabase storage secret first.'
}
if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "Source folder not found: $SourceDir"
}

function Encode-Key {
    param([string]$Key)
    return ($Key -split '/' | ForEach-Object {
        if ($_ -eq '') { return '' }
        return [uri]::EscapeDataString($_)
    }) -join '/'
}

function Get-ObjectSize {
    param([string]$ObjectKey)
    $enc = Encode-Key $ObjectKey
    $url = "$BaseUrl/storage/v1/object/info/public/$Bucket/$enc"
    $json = & curl.exe -s -m 60 -H "apikey: $env:SUPABASE_SERVICE_ROLE" $url
    if (-not $json) { return $null }
    try {
        $obj = $json | ConvertFrom-Json
        return $obj.size
    } catch {
        return $null
    }
}

function Upload-Object {
    param(
        [string]$FullName,
        [string]$ObjectKey,
        [string]$ContentType
    )
    $tmpBody = Join-Path $env:TEMP 'supabase_upload_body.txt'
    $encoded = Encode-Key $ObjectKey
    $url = "$BaseUrl/storage/v1/object/$Bucket/$encoded"
    $code = & curl.exe -s -o "$tmpBody" -w "%{http_code}" -m 900 -X POST `
        -H "apikey: $env:SUPABASE_SERVICE_ROLE" -H "x-upsert: true" `
        -H "Content-Type: $ContentType" --data-binary "@$FullName" $url
    return [int]$code
}

function Sync-Object {
    param(
        [string]$FullName,
        [string]$ObjectKey,
        [string]$ContentType
    )
    $localSize = [long](Get-Item -LiteralPath $FullName).Length
    $serverSize = Get-ObjectSize $ObjectKey
    if ($serverSize -ne $null -and [long]$serverSize -eq $localSize) {
        return 'SKIP'
    }
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $code = Upload-Object $FullName $ObjectKey $ContentType
        if ($code -eq 200) {
            $serverSize = Get-ObjectSize $ObjectKey
            if ($serverSize -ne $null -and [long]$serverSize -eq $localSize) {
                return 'OK'
            }
        }
        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Seconds 3
        }
    }
    return 'FAIL'
}

$files = Get-ChildItem -LiteralPath $SourceDir -File -Filter '*.opus' |
    Sort-Object Name

$ok = 0
$skip = 0
$fail = 0
foreach ($f in $files) {
    $key = if ($FolderPrefix) { "$FolderPrefix/$($f.Name)" } else { $f.Name }
    $result = Sync-Object $f.FullName $key 'audio/ogg'
    switch ($result) {
        'OK'   { $ok++ }
        'SKIP' { $skip++ }
        default { $fail++ }
    }
    Write-Output ("{0,-4} {1,10:N0} B  {2}" -f $result, $f.Length, $key)
}

if ($ManifestFile -and (Test-Path -LiteralPath $ManifestFile)) {
    $manifestKey = Split-Path -Leaf $ManifestFile
    $result = Sync-Object (Resolve-Path -LiteralPath $ManifestFile) `
        "$manifestKey" 'application/json'
    switch ($result) {
        'OK'   { $ok++ }
        'SKIP' { $skip++ }
        default { $fail++ }
    }
    Write-Output ("{0,-4} manifest  {1}" -f $result, $manifestKey)
}

Write-Output "Done: ok=$ok skip=$skip fail=$fail / total=$($files.Count + ([int]($ManifestFile -and (Test-Path -LiteralPath $ManifestFile))))"
if ($fail -gt 0) { exit 1 }
exit 0