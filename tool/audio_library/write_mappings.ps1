$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Tool = Join-Path $Root 'tool\audio_library'

function From-Hex {
    param([string]$Hex)
    $pts = $Hex -split ' '
    $chars = for ($k = 0; $k -lt $pts.Count; $k++) { [char][int]('0x' + $pts[$k]) }
    return [string]::new($chars)
}

function Hex-Of {
    param([string]$Text)
    return (($Text.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ')
}

# Records: Hx = codepoints of the on-disk file name (without extension),
# Key  = ASCII object key file name, Id = pinned id suffix, New = new flag.
$arabiSpec = @(
    @{ Hx = '0627 062E 06CC 0020 0633 0648 0641 0020 062A 0628 06A9 06CC 0020 0639 0644 06CC 06A9 0020 0627 0644 0639 06CC 0648 0646'; Key = '18-akhi-sawfa-taki-al-ayn.opus';     Id = 18; New = $true }
    @{ Hx = '0637 0627 0644 0628 0020 0627 0644 0639 0644 0645';               Key = '19-talib-al-elm.opus';               Id = 19; New = $true }
    @{ Hx = '0627 0628 0648 0628 06A9 0631 0020 0627 0644 0635 062F 06CC 0642'; Key = '01-abou-bakr-siddiq.opus';          Id = 1 }
    @{ Hx = '0627 0628 0648 062D 0020 0628 0634 0648 0642';                    Key = '02-abouh-bishooq.opus';             Id = 2 }
    @{ Hx = '0627 0644 0020 0628 06CC 062A';                                  Key = '03-al-bayt.opus';                   Id = 3 }
    @{ Hx = '0627 0644 06CC 06A9 0020 0648 0020 0627 0644 0627';              Key = '04-aleika-wal-lyya.opus';           Id = 4 }
    @{ Hx = '0627 0646 06CC 0020 0630 06A9 0631 062A 06A9';                   Key = '05-inni-dhkur-tak.opus';            Id = 5 }
    @{ Hx = '0631 0628 0020 0628 0627 0644 0633 0628 0639 0020 0627 0644 0645 062B 0627 0646 06CC'; Key = '06-rabbi-bi-sab-al-mathani.opus'; Id = 6 }
    @{ Hx = '0639 062B 0645 0627 0646';                                       Key = '07-othman.opus';                    Id = 7 }
    @{ Hx = '064A 0627 0020 062E 064A 0631 0020 0627 0644 062E 0644 0642';    Key = '08-ya-khayr-al-khalq.opus';         Id = 8 }
    @{ Hx = '06CC 0645 0647 0020 06CC 0627 0020 0646 0628 0639 0020 0627 0644 062D 0646 0627 0646'; Key = '09-yamha-ya-nab-al-hanan.opus'; Id = 9 }
)

$farsiSpec = @(
    @{ Hx = '062C 0648 0627 0646 0020 062A 0627 0020 06A9 06CC 0020 0686 0646 06CC 0646'; Key = '20-javan-ta-key-cheynin.opus';                 Id = 20; New = $true }
    @{ Hx = '0639 0637 0631 0020 0642 0631 0622 0646 0020 0639 0637 0631 0020 0627 06CC 0645 0627 0646'; Key = '21-atre-quran-atre-iman.opus';            Id = 21; New = $true }
    @{ Hx = '063A 0631 06CC 0628 06CC 005F 063A 0631 0628 062A 005F 0634 0627 0645 005F 0648 005F 06CC 0645 0646 005F 0646 06CC 0633 062A'; Key = '22-ghorbati-qorbat-sham-va-yemen-nist.opus'; Id = 22; New = $true }
    @{ Hx = '06AF 0641 062A 0645 0020 0645 0646 0645 0020 0627 0647 0644 0020 062E 0637 0627'; Key = '23-goftam-manham-ehle-khata.opus';          Id = 23; New = $true }
    @{ Hx = '0645 0648 0645 0646 06CC 0646 0020 0628 067E 0627 0020 062E 06CC 0632 06CC 062F'; Key = '10-momenin-bepa-khizid.opus';               Id = 10 }
    @{ Hx = '0686 0631 0627 0020 0627 06CC 0020 0628 0646 062F 0647 0020 06CC 0020 0639 0627 0635 06CC'; Key = '11-chera-ey-bandeye-asi.opus';           Id = 11 }
    @{ Hx = '062F 0644 0020 063A 0627 0641 0644 0020 0628 06A9 0646 0020 062A 0648 0628 0647'; Key = '12-del-e-ghafel-bokon-tobbe.opus';          Id = 12 }
    @{ Hx = '0633 0631 0648 062F 0020 0632 06CC 0628 0627 06CC 0020 0642 0631 0622 0646 0020 062F 0631 0645 0627 0646 0020 062F 0644 0647 0627 0020'; Key = '13-sorud-ziba-ye-quran-darman-e-delha.opus'; Id = 13 }
    @{ Hx = '0633 0631 0648 062F 0020 00AB 0642 0631 0622 0646 061B 0020 0647 0648 06CC 062A 0020 0645 0633 0644 0645 0627 0646 00BB 0020 0020 0636 06CC 0627 0621 0627 0644 0631 062D 0645 0646 0020 0635 062D 062A'; Key = '14-sorud-quran-hoviyat-mosalaman.opus'; Id = 14 }
    @{ Hx = '0645 0631 0627 0020 0628 0627 0020 062E 0648 062F 062A 0020 062A 0627 0020 062B 0631 06CC 0627 0020 0628 0628 0631'; Key = '16-mara-ba-khodat-ta-soraya-bebar.opus'; Id = 16 }
    @{ Hx = '0648 0020 0645 0646 0020 0645 06AF 0631 0020 0686 06CC 0633 062A 0645 0020 0627 06CC 0020 062E 062F 0627 061F 0020'; Key = '17-va-man-magar-chistam-ey-khoda.opus'; Id = 17 }
)

$miscSpec = @(
    @{ Hx = '062E 062F 0627 005F 0628 0646 062F 0647 200C 0647 0627 06CC 005F 062E 0648 0628 005F 062E 0648 062F 0634 005F 0631 0627 005F 0627 0645 062A 062D 0627 0646 005F 0645 06CC 200C 06A9 0646 062F 0021 2764 FE0F 005F 0645 0648 0644 0627 0646 0627 005F 0628 0647 0632 0627 062F 005F 0641 0642 0647 06CC'; Key = '01-tawheed-molana-behzad-faghi.opus'; Id = 1; New = $true }
)

function Write-Csv {
    param(
        [string]$OutFile,
        [string[]]$PathSegments,
        [array]$Spec
    )
    $dir = Get-Item -LiteralPath (Join-Path $PathSegments[0] $PathSegments[1])
    $files = Get-ChildItem -LiteralPath $dir.FullName -File | Where-Object { $_.Extension -eq '.opus' }
    $rows = @()
    foreach ($rec in $Spec) {
        $name = From-Hex $rec.Hx
        $fname = "$name.opus"
        $match = $files | Where-Object { $_.BaseName -eq $name }
        if (-not $match) {
            throw "MISSING on disk: $fname (codepoints: $($rec.Hx))"
        }
        $title = $name.Replace('_', ' ').TrimEnd(' ')
        $suffix = if ($rec.New) { ';N' } else { '' }
        $rows += "$fname;$($rec.Key);$title;$($rec.Id)$suffix"
    }
    [System.IO.File]::WriteAllLines(
        $OutFile,
        $rows,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "Wrote $(@($rows).Count) rows -> $OutFile"
}

$NasheedRoot = Join-Path $Root 'TAWHEED-EWAZ\nasheed'
$Ar = ([string][char]0x0639) + ([string][char]0x0631) + ([string][char]0x0628) + ([string][char]0x06CC)
$Fa = ([string][char]0x0641) + ([string][char]0x0627) + ([string][char]0x0631) + ([string][char]0x0633) + ([string][char]0x06CC)

Write-Csv -OutFile (Join-Path $Tool 'nasheed_arabi_mapping.csv') `
    -Spec $arabiSpec -PathSegments @($NasheedRoot, $Ar)
Write-Csv -OutFile (Join-Path $Tool 'nasheed_farsi_mapping.csv') `
    -Spec $farsiSpec -PathSegments @($NasheedRoot, $Fa)
Write-Csv -OutFile (Join-Path $Tool 'sokhanrani_mapping.csv') `
    -Spec $miscSpec -PathSegments @((Join-Path $Root 'TAWHEED-EWAZ'), 'sokhanrani')