# Stage the new (N-flagged) rows of the nasheed + misc mapping CSVs into an
# upload-ready folder tree. ASCII-only; Persian folder names are assembled
# from their Unicode code points (see build_full_manifest.ps1).

param(
    [string]$Root = '',
    [string]$UploadDir = ''
)

$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

function Join-PathPersian {
    param([string]$BaseDir, [int[]]$CodePoints)
    $name = -join ($CodePoints | ForEach-Object { [char]$_ })
    return Join-Path $BaseDir $name
}

$dirArabi  = Join-PathPersian (Join-Path $Root 'TAWHEED-EWAZ\nasheed') @(0x0639, 0x0631, 0x0628, 0x06CC)
$dirFarsi  = Join-PathPersian (Join-Path $Root 'TAWHEED-EWAZ\nasheed') @(0x0641, 0x0627, 0x0631, 0x0633, 0x06CC)
$dirSokh   = Join-Path $Root 'TAWHEED-EWAZ\sokhanrani'

if (-not $UploadDir) {
    $UploadDir = Join-Path $env:TEMP 'opencode\nasheed_upload'
}

$rows = @(
    @{ Csv = 'nasheed_arabi_mapping.csv'; Source = $dirArabi; Prefix = 'anasheed' },
    @{ Csv = 'nasheed_farsi_mapping.csv'; Source = $dirFarsi; Prefix = 'anasheed' },
    @{ Csv = 'sokhanrani_mapping.csv';    Source = $dirSokh;  Prefix = 'misc' }
)

$copied = 0
foreach ($r in $rows) {
    $csvPath = Join-Path $PSScriptRoot $r.Csv
    $lines = [System.IO.File]::ReadAllLines($csvPath)
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $cols = $line -split ';'
        if ($cols.Count -lt 5 -or $cols[4] -ne 'N') { continue }
        $src = Join-Path $r.Source $cols[0]
        if (-not (Test-Path -LiteralPath $src)) {
            throw "Missing source: $($r.Csv) -> $($cols[0])"
        }
        $destDir = Join-Path $UploadDir $r.Prefix
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        $dest = Join-Path $destDir $cols[1]
        Copy-Item -LiteralPath $src -Destination $dest -Force
        Write-Output ("{0}  {1}" -f (Get-Item -LiteralPath $dest).Length, $cols[1])
        $copied++
    }
}
Write-Output "Staged $copied new files under $UploadDir"