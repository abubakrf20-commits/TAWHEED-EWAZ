$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$NasheedRoot = Join-Path $Root 'TAWHEED-EWAZ\nasheed'

$ArabicName = ([string][char]0x0639) + ([string][char]0x0631) + `
    ([string][char]0x0628) + ([string][char]0x06CC)
$FarsiName = ([string][char]0x0641) + ([string][char]0x0627) + `
    ([string][char]0x0631) + ([string][char]0x0633) + ([string][char]0x06CC)

$ArabicDir = Join-Path $NasheedRoot $ArabicName
$FarsiDir = Join-Path $NasheedRoot $FarsiName

& (Join-Path $PSScriptRoot 'build_full_manifest.ps1') `
    -YaqeenSourceDir (Join-Path $Root 'TAWHEED-EWAZ\yaqeen') `
    -YaqeenMappingFile (Join-Path $Root 'tool\audio_library\yaqeen_mapping.csv') `
    -NasheedSourceDir $ArabicDir `
    -NasheedMappingFile (Join-Path $Root 'tool\audio_library\nasheed_arabi_mapping.csv') `
    -NasheedFarsiSourceDir $FarsiDir `
    -NasheedFarsiMappingFile (Join-Path $Root 'tool\audio_library\nasheed_farsi_mapping.csv') `
    -NasheedArabiTitleFile (Join-Path $Root 'tool\audio_library\nasheed_arabi_title.txt') `
    -NasheedFarsiTitleFile (Join-Path $Root 'tool\audio_library\nasheed_farsi_title.txt') `
    -ZiaeiSourceDir (Join-Path $Root 'TAWHEED-EWAZ\sokhanrani\ziaei') `
    -ZiaeiMappingFile (Join-Path $Root 'tool\audio_library\ziaei_mapping.csv') `
    -ZiaeiSpeakerTitleFile (Join-Path $Root 'tool\audio_library\ziaei_speaker_title.txt') `
    -MiscSourceDir (Join-Path $Root 'TAWHEED-EWAZ\sokhanrani') `
    -MiscMappingFile (Join-Path $Root 'tool\audio_library\sokhanrani_mapping.csv') `
    -MiscSpeakerTitleFile (Join-Path $Root 'tool\audio_library\misc_speaker_title.txt') `
    -OutFile (Join-Path $Root 'index.json')

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Manifest built:"
(Get-Item (Join-Path $Root 'index.json')).Length