param(
    [Parameter(Mandatory = $true)][string]$NasheedSourceDir,
    [Parameter(Mandatory = $true)][string]$NasheedDestDir,
    [Parameter(Mandatory = $true)][string]$NasheedMappingFile,
    [Parameter(Mandatory = $true)][string]$ZiaeiSourceDir,
    [Parameter(Mandatory = $true)][string]$ZiaeiDestDir,
    [Parameter(Mandatory = $true)][string]$ZiaeiMappingFile
)

# Copies the "nasheed" (two subfolders arabi/farsi) and "ziaei" source folders
# into flat ASCII-named upload dirs, following the mapping CSVs that
# build_full_manifest.ps1 consumes too - one source of truth for both the
# object keys and the manifest order/titles.
#
#   .\rename_new_categories.ps1 `
#       -NasheedSourceDir "...\TAWHEED-EWAZ\nasheed" `
#       -NasheedDestDir "$env:TEMP\opencode\nasheed_upload" `
#       -NasheedMappingFile ".\nasheed_mapping.csv" `
#       -ZiaeiSourceDir "...\TAWHEED-EWAZ\ziaei" `
#       -ZiaeiDestDir "$env:TEMP\opencode\ziaei_upload" `
#       -ZiaeiMappingFile ".\ziaei_mapping.csv"

$ErrorActionPreference = 'Stop'

function Copy-Mapped {
    param(
        [string]$SourceDir,
        [string]$DestDir,
        [string]$MappingFile
    )
    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Source folder not found: $SourceDir"
    }
    if (-not (Test-Path -LiteralPath $MappingFile)) {
        throw "Mapping file not found: $MappingFile"
    }
    if (-not (Test-Path -LiteralPath $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir | Out-Null
    }

    $allFiles = Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Filter '*.opus'
    $count = 0
    foreach ($line in [System.IO.File]::ReadAllLines($MappingFile)) {
        if ($line -notmatch '^([^;]+);([^;]+)(;(.*))?$') { continue }
        $orig = $Matches[1]
        $new = $Matches[2]
        $match = @($allFiles | Where-Object { $_.Name -eq $orig })
        if ($match.Count -eq 0) {
            throw "No file named '$orig' under $SourceDir"
        }
        if ($match.Count -gt 1) {
            throw "Multiple files named '$orig' under $SourceDir - ambiguous"
        }
        Copy-Item -LiteralPath $match[0].FullName `
            -Destination (Join-Path $DestDir $new) -Force
        $rel = $match[0].FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        Write-Output "  $rel  ->  $new"
        $count++
    }
    Write-Output "Copied $count files to $DestDir"
}

Copy-Mapped -SourceDir $NasheedSourceDir -DestDir $NasheedDestDir `
    -MappingFile $NasheedMappingFile
Copy-Mapped -SourceDir $ZiaeiSourceDir -DestDir $ZiaeiDestDir `
    -MappingFile $ZiaeiMappingFile