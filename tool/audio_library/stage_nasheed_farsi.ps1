$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$NasheedRoot = Join-Path $Root 'TAWHEED-EWAZ\nasheed'
$FarsiName = ([string][char]0x0641) + ([string][char]0x0627) + `
    ([string][char]0x0631) + ([string][char]0x0633) + ([string][char]0x06CC)
$FarsiDir = Join-Path $NasheedRoot $FarsiName
$Mapping = [System.IO.File]::ReadAllLines(
    (Join-Path $Root 'tool\audio_library\nasheed_farsi_mapping.csv'))
$Stage = Join-Path $env:TEMP 'opencode\nasheed_farsi_upload'
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

foreach ($line in $Mapping) {
    if (-not $line) { continue }
    $parts = $line -split ';'
    $original = $parts[0]
    $new = $parts[1]
    $num = $new -replace '^([0-9]+)-.*$', '$1'
    if ([int]$num -lt 12) { continue }
    $src = Join-Path $FarsiDir $original
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Error "MISSING source: $original"
        exit 1
    }
    Copy-Item -LiteralPath $src -Destination (Join-Path $Stage $new) -Force
    Write-Host "Staged: $new"
}
Get-ChildItem -LiteralPath $Stage -Filter *.opus | ForEach-Object {
    Write-Host ("{0}  {1}" -f $_.Name, $_.Length)
}