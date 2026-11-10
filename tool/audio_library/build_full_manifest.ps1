param(
    [Parameter(Mandatory = $true)][string]$YaqeenSourceDir,
    [Parameter(Mandatory = $true)][string]$YaqeenMappingFile,
    [Parameter(Mandatory = $true)][string]$NasheedSourceDir,
    [Parameter(Mandatory = $true)][string]$NasheedMappingFile,
    [string]$NasheedFarsiSourceDir = '',
    [string]$NasheedFarsiMappingFile = '',
    [string]$NasheedArabiTitleFile = '',
    [string]$NasheedFarsiTitleFile = '',
    [Parameter(Mandatory = $true)][string]$ZiaeiSourceDir,
    [Parameter(Mandatory = $true)][string]$ZiaeiMappingFile,
    [string]$ZiaeiSpeakerId = 'ziaei',
    [string]$ZiaeiSpeakerTitleFile = '',
    [string]$MiscSourceDir = '',
    [string]$MiscMappingFile = '',
    [string]$MiscSpeakerTitleFile = '',
    [string]$OutFile = 'index.json'
)

# Builds the FULL audio-library manifest (index.json) with all three categories
# in display order: yaqeen, anasheed, lectures.
#
# Category display titles are resolved in the app (AudioCategory.displayTitle),
# so the manifest and object keys stay pure ASCII. Track order, Persian titles
# and ASCII object keys come from the mapping CSVs (in row order - the single
# source of truth shared with rename_new_categories.ps1 / upload_supabase.ps1).
#
# The lectures category is speaker-grouped: when -ZiaeiSpeakerTitleFile points
# to a UTF-8 text file containing the speaker's Persian title (e.g. a file with
# the single line «شیخ ضیایی»), the category also carries a `speakers` array so
# the app can split the category per speaker without extra data. Track object
# keys stay flat under `lectures/` (the app flattens speakers for playback).
#
# The anasheed category is language-grouped the same way: when a farsi mapping
# is supplied the Arabic source/mapping become the first group and the Persian
# files the second, both surfaced as `speakers` entries.
#
#   .\build_full_manifest.ps1 `
#       -YaqeenSourceDir "...\TAWHEED-EWAZ\yaqeen" -YaqeenMappingFile ".\yaqeen_mapping.csv" `
#       -NasheedSourceDir "...\TAWHEED-EWAZ\nasheed\arabic" -NasheedMappingFile ".\nasheed_arabi_mapping.csv" `
#       -NasheedFarsiSourceDir "...\TAWHEED-EWAZ\nasheed\persian" -NasheedFarsiMappingFile ".\nasheed_farsi_mapping.csv" `
#       -NasheedArabiTitleFile ".\nasheed_arabi_title.txt" -NasheedFarsiTitleFile ".\nasheed_farsi_title.txt" `
#       -ZiaeiSourceDir "...\TAWHEED-EWAZ\ziaei" -ZiaeiMappingFile ".\ziaei_mapping.csv" `
#       -ZiaeiSpeakerTitleFile ".\ziaei_speaker_title.txt" `
#       -OutFile "..\..\index.json"

$ErrorActionPreference = 'Stop'

function Get-Tracks {
    param(
        [string]$SourceDir,
        [string]$MappingFile,
        [string]$CategoryId,
        [int]$IdOffset = 0
    )
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Source folder not found: $SourceDir"
    }
    if (-not (Test-Path -LiteralPath $MappingFile)) {
        throw "Mapping file not found: $MappingFile"
    }
    $allFiles = Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Filter '*.opus'

    $tracks = @()
    $i = $IdOffset
    foreach ($line in [System.IO.File]::ReadAllLines($MappingFile)) {
        $line = $line.Trim()
        if (-not $line) { continue }
        $c = $line -split ';'
        if ($c.Count -lt 2) { continue }
        $orig = $c[0].Trim()
        $new = $c[1].Trim()
        $override = if ($c.Count -ge 3) { $c[2] } else { '' }
        $explicit = $null
        if ($c.Count -ge 4 -and $c[3].Trim()) {
            try { $explicit = [int]($c[3].Trim()) } catch {
                throw "Bad id in mapping row: $line"
            }
        }
        $isNew = ($c.Count -ge 5 -and $c[4].Trim() -eq 'N')
        $match = @($allFiles | Where-Object { $_.Name -eq $orig })
        if ($match.Count -ne 1) {
            throw "Expected exactly one '$orig' under $SourceDir, found $($match.Count)"
        }
        # Third column overrides the display title (used to strip trailing
        # dots/ellipses from source file names); fourth pins the track id so
        # groups keep stable ids when new files are added anywhere in the
        # mapping; fifth (`N`) marks the track as newly added.
        $title = if ($override) {
            $override
        } else {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($orig)
            [regex]::Replace($base, '^\s*[0-9]+\s*[._\-]?\s*', '')
        }
        $id = if ($null -ne $explicit) {
            '{0}-{1:d2}' -f $CategoryId, $explicit
        } else {
            '{0}-{1:d2}' -f $CategoryId, $i
        }
        if ($null -eq $explicit) { $i++ }
        $track = [ordered]@{
            id        = $id
            title     = $title
            file      = ('{0}/{1}' -f $CategoryId, $new)
            sizeBytes = $match[0].Length
        }
        if ($isNew) { $track.new = $true }
        $tracks += $track
    }
    if ($tracks.Count -eq 0) {
        throw "No tracks produced for category $CategoryId"
    }
    return , $tracks
}

# Anasheed category: Arabic group from the primary source/mapping, plus an
# optional Persian group. When the Persian files exist the category is
# language-grouped (both groups surfaced as `speakers`).
$arabicTracks = Get-Tracks -SourceDir $NasheedSourceDir `
    -MappingFile $NasheedMappingFile -CategoryId 'anasheed'
$nasheedEntry = [ordered]@{
    id     = 'anasheed'
    tracks = $arabicTracks
}
if ($NasheedFarsiMappingFile -and $NasheedFarsiSourceDir) {
    $farsiTracks = Get-Tracks -SourceDir $NasheedFarsiSourceDir `
        -MappingFile $NasheedFarsiMappingFile -CategoryId 'anasheed' `
        -IdOffset $arabicTracks.Count
    $nasheedEntry.tracks = @($arabicTracks + $farsiTracks)
    $arabicTitle = ''
    if ($NasheedArabiTitleFile -and (Test-Path -LiteralPath $NasheedArabiTitleFile)) {
        $arabicTitle = ([System.IO.File]::ReadAllText(
            $NasheedArabiTitleFile)).Trim()
    }
    $farsiTitle = ''
    if ($NasheedFarsiTitleFile -and (Test-Path -LiteralPath $NasheedFarsiTitleFile)) {
        $farsiTitle = ([System.IO.File]::ReadAllText(
            $NasheedFarsiTitleFile)).Trim()
    }
    $nasheedEntry.speakers = @(
        [ordered]@{
            id     = 'arabi'
            title  = $arabicTitle
            tracks = $arabicTracks
        }
        [ordered]@{
            id     = 'farsi'
            title  = $farsiTitle
            tracks = $farsiTracks
        }
    )
}

$categories = @(
    [ordered]@{
        id     = 'yaqeen'
        tracks = Get-Tracks -SourceDir $YaqeenSourceDir `
            -MappingFile $YaqeenMappingFile -CategoryId 'yaqeen'
    }
    $nasheedEntry
    [ordered]@{}
)

# Lectures category: flat tracks + optional speaker groups read from UTF-8
# sidecar files (keeps the .ps1 itself pure ASCII). The ziaei lectures form
# the first group; any misc files (e.g. a one-off speech) form a second group
# listed right below it.
$speakerTitle = ''
if ($ZiaeiSpeakerTitleFile -and (Test-Path -LiteralPath $ZiaeiSpeakerTitleFile)) {
    $speakerTitle = ([System.IO.File]::ReadAllText(
        $ZiaeiSpeakerTitleFile)).Trim()
}
$lectureTracks = Get-Tracks -SourceDir $ZiaeiSourceDir `
    -MappingFile $ZiaeiMappingFile -CategoryId 'lectures'
$lecturesEntry = [ordered]@{
    id     = 'lectures'
    tracks = $lectureTracks
}
$lectureSpeakers = @()
if ($speakerTitle) {
    $lectureSpeakers += [ordered]@{
        id     = $ZiaeiSpeakerId
        title  = $speakerTitle
        tracks = $lectureTracks
    }
}
if ($MiscSourceDir -and $MiscMappingFile) {
    $miscTracks = Get-Tracks -SourceDir $MiscSourceDir `
        -MappingFile $MiscMappingFile -CategoryId 'misc'
    $lecturesEntry.tracks = @($lectureTracks + $miscTracks)
    $miscSpeakerTitle = ''
    if ($MiscSpeakerTitleFile -and (Test-Path -LiteralPath $MiscSpeakerTitleFile)) {
        $miscSpeakerTitle = ([System.IO.File]::ReadAllText(
            $MiscSpeakerTitleFile)).Trim()
    }
    $lectureSpeakers += [ordered]@{
        id     = 'misc'
        title  = $miscSpeakerTitle
        tracks = $miscTracks
    }
}
if ($lectureSpeakers.Count -gt 0) {
    $lecturesEntry.speakers = $lectureSpeakers
}
$categories[2] = $lecturesEntry

$manifest = [ordered]@{
    version    = 1
    categories = $categories
}

$json = $manifest | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText(
    $OutFile,
    $json,
    (New-Object System.Text.UTF8Encoding($false))
)

$total = ($categories | ForEach-Object { $_.tracks.Count } | Measure-Object -Sum).Sum
Write-Output "Wrote $total tracks to $OutFile ($((Get-Item -LiteralPath $OutFile).Length) bytes)"