param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$DestDir,
    [string]$MappingFile
)

# Copies the "yaqeen" lesson files into $DestDir with ASCII (English) names and
# writes an "original;new" mapping used by build_manifest.ps1 to keep Persian
# display titles while uploading English object keys (the Supabase gateway
# rejects non-ASCII file names in the upload path).
#
#   .\rename_yaqeen.ps1 -SourceDir "...\TAWHEED-EWAZ\yaqeen" `
#       -DestDir "$env:TEMP\opencode\yaqeen_upload" `
#       -MappingFile ".\yaqeen_mapping.csv"

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "Source folder not found: $SourceDir"
}

# Lesson number -> English slug (kept ASCII on purpose).
$slugs = @{
    1  = 'marefat-shenasi'
    2  = 'esbat-vojude-khoda-emkan-vojub'
    3  = 'esbat-vojude-khoda-borhan-nazm'
    4  = 'naghd-borhan-shar'
    5  = 'peydayesh-adyan-naghd-nadarost'
    6  = 'karkardhaye-din-dar-jamee'
    7  = 'esbat-sedaqat-rasoul'
    8  = 'esbat-nobovvat-rasoul'
    9  = 'defa-az-sahat-peyambar'
    10 = 'esbat-elahi-boodan-quran-mansha'
    11 = 'quran-aejaz-elmi'
    12 = 'quran-tahaddi'
    13 = 'quran-va-elm'
    14 = 'eddeaye-tanaghoz-dar-quran'
    15 = 'din-va-elm'
    16 = 'eslam-va-hoghoogh-bashar'
    17 = 'eslam-paziri-iranian'
    18 = 'eslam-va-melliyat'
    19 = 'eslam-va-khoshonat'
    20 = 'jabr-va-ekhtiar'
    21 = 'hoghoogh-zan-dar-eslam'
    22 = 'ashnaee-ba-moghalatat'
    23 = 'chegonegi-bahs-ba-mokhalefan'
}

# Lesson order from the leading number of each file name.
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

if (-not (Test-Path -LiteralPath $DestDir)) {
    New-Item -ItemType Directory -Path $DestDir | Out-Null
}

$mapping = @()
foreach ($f in $files) {
    $num = if ($f.BaseName -match '^\s*(\d+)') { [int]$Matches[1] } else { 0 }
    $slug = $slugs[$num]
    if (-not $slug) {
        throw "No English slug for lesson number $num ($($f.Name))"
    }
    $newName = '{0:d2}-{1}.opus' -f $num, $slug
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $DestDir $newName) -Force
    $mapping += "$($f.Name);$newName"
    Write-Output "  $($f.Name)  ->  $newName"
}

if ($MappingFile) {
    [System.IO.File]::WriteAllLines($MappingFile, $mapping,
        (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "Mapping written: $MappingFile ($($mapping.Count) entries)"
}

Write-Output "Copied $($files.Count) files to $DestDir"