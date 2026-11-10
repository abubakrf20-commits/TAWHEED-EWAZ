param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$CategoryId,
    [string]$OutFile = 'index.json',
    [string]$MappingFile
)

# Builds the audio-library manifest (index.json) from a folder of .opus files.
#
#   .\build_manifest.ps1 -SourceDir "...\TAWHEED-EWAZ\yaqeen" -CategoryId yaqeen
#
# The manifest is pure ASCII (Persian titles are escaped by ConvertTo-Json), so
# it is always written as UTF-8 and is safe to upload to Supabase. Track titles
# are derived from the file names with the leading "N." / "N_" ordering prefix
# stripped; a stable ASCII id (category-trackN) points at the object key
# "<category>/<file name>".
#
# Category display titles are resolved on the app side (see
# AudioLibraryCategory.persianTitle in code), so this script stays ASCII.

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "Source folder not found: $SourceDir"
}

# Sort by the leading lesson number ("2.", "10_", …) so tracks appear in
# lesson order (1, 2, 3, … 23), not lexicographic folder order (1, 10, 11…).
$files = @(
    Get-ChildItem -LiteralPath $SourceDir -File -Filter '*.opus' |
        ForEach-Object {
            $num = if ($_.BaseName -match '^\s*(\d+)') {
                [int]$Matches[1]
            } else {
                [int]::MaxValue
            }
            [pscustomobject]@{ File = $_; Num = $num }
        } |
        Sort-Object Num |
        ForEach-Object { $_.File }
)

if ($files.Count -eq 0) {
    throw "No .opus files in $SourceDir"
}

# Optional "original;new" mapping produced by rename_yaqeen.ps1. When a source
# file was renamed to an ASCII key for upload, the manifest references the new
# key while keeping the Persian title from the original file name.
$renameMap = @{}
if ($MappingFile) {
    if (-not (Test-Path -LiteralPath $MappingFile)) {
        throw "Mapping file not found: $MappingFile"
    }
    foreach ($line in [System.IO.File]::ReadAllLines($MappingFile)) {
        if ($line -notmatch '^(.+);(.+)$') { continue }
        $renameMap[$Matches[1]] = $Matches[2]
    }
}

$tracks = @()
$i = 0
foreach ($f in $files) {
    $i++
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    # Strip the ordering prefix ("3. ", "10_", "4-", "1." etc.) from the title.
    $title = [regex]::Replace($base, '^\s*[0-9]+\s*[._\-]?\s*', '')
    $fileName = if ($renameMap.ContainsKey($f.Name)) { $renameMap[$f.Name] } else { $f.Name }
    $tracks += [ordered]@{
        id        = ('{0}-{1:d2}' -f $CategoryId, $i)
        title     = $title
        file      = ('{0}/{1}' -f $CategoryId, $fileName)
        sizeBytes = $f.Length
    }
}

$manifest = [ordered]@{
    version    = 1
    categories = @(
        [ordered]@{
            id     = $CategoryId
            tracks = $tracks
        }
    )
}

$json = $manifest | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText(
    $OutFile,
    $json,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Output "Wrote $($tracks.Count) tracks to $OutFile ($((Get-Item -LiteralPath $OutFile).Length) bytes)"