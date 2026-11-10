param(
    [Parameter(Mandatory = $true)][string]$BaseUrl,
    [string]$ManifestFile = 'index.json',
    [int]$SampleSize = 5,
    [int]$ProbeBytes = 1024
)

# Checks whether an object-storage host can serve the audio library to the app,
# BEFORE anything is uploaded to it.
#
#   .\verify_host.ps1 -BaseUrl 'https://<bucket-url>/tawheed'
#
# Reports every requirement listed in docs/AUDIO_LIBRARY_HOSTING.md as a
# pass/fail row and exits non-zero when a hard requirement fails, so it can gate
# a migration. Range support is the one that matters most: the player streams
# through UrlSource, so a host that answers 200 to a ranged GET looks fine in a
# browser and only fails when a user drags the seek bar.
#
# NOTE: keep this file ASCII-only. PowerShell 5.1 reads BOM-less .ps1 files as
# ANSI, so a stray non-ASCII byte (em dash, Persian text) corrupts the parse.

$ErrorActionPreference = 'Stop'

# Proxies rewrite Range requests and silently degrade them to 200.
$env:HTTP_PROXY = ''
$env:HTTPS_PROXY = ''
$env:NO_PROXY = '*'

[System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.SecurityProtocolType]::Tls12

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Check, [string]$State, [string]$Detail, [bool]$Hard = $true)
    $results.Add([pscustomobject]@{
        Check  = $Check
        State  = $State
        Hard   = $Hard
        Detail = $Detail
    })
}

function Encode-Key {
    param([string]$Key)
    return ($Key -split '/' | ForEach-Object {
        if ($_ -eq '') { return '' }
        return [uri]::EscapeDataString($_)
    }) -join '/'
}

# Returns status, headers and body for a GET. HttpWebRequest is used directly
# because Invoke-WebRequest turns every non-2xx into an exception and hides the
# status code we need to tell "bucket is private" from "quota cap".
function Invoke-Probe {
    param([string]$Url, [long]$From = -1, [long]$To = -1)
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = 'GET'
    $req.Timeout = 30000
    $req.ReadWriteTimeout = 30000
    $req.UserAgent = 'tawheed-host-verifier'
    if ($From -ge 0) { $req.AddRange([long]$From, [long]$To) }
    $res = $req.GetResponse()
    try {
        $stream = $res.GetResponseStream()
        $ms = New-Object System.IO.MemoryStream
        $stream.CopyTo($ms)
        $body = $ms.ToArray()
        return [pscustomobject]@{
            Status       = [int]$res.StatusCode
            Headers      = $res.Headers
            Body         = $body
            ContentRange = $res.Headers['Content-Range']
            Length       = $res.ContentLength
        }
    } finally { $res.Close() }
}

function Get-ProbeFailure {
    param($ErrorRecord)
    $ex = $ErrorRecord.Exception
    while ($ex -and -not ($ex -is [System.Net.WebException])) { $ex = $ex.InnerException }
    if ($ex -is [System.Net.WebException] -and $ex.Response) {
        return [int]$ex.Response.StatusCode
    }
    return 0
}

# -- 1. Scheme ---------------------------------------------------------------
$base = $BaseUrl.TrimEnd('/')
if ($base -match '^https://') {
    Add-Result 'HTTPS' 'PASS' $base
} else {
    Add-Result 'HTTPS' 'FAIL' 'not https:// - Android blocks cleartext by default' $false
}

# -- 2. Manifest -------------------------------------------------------------
$manifestUrl = "$base/$ManifestFile"
$tracks = @()
try {
    $m = Invoke-Probe -Url $manifestUrl
    if ($m.Status -ne 200) {
        Add-Result 'index.json' 'FAIL' "HTTP $($m.Status)" $true
    } else {
        Add-Result 'index.json' 'PASS' "$($m.Length) bytes"
        try {
            $json = [System.Text.Encoding]::UTF8.GetString($m.Body) | ConvertFrom-Json
            $version = if ($json.PSObject.Properties.Name -contains 'version') { $json.version } else { '(none)' }
            foreach ($cat in @($json.categories)) { $tracks += @($cat.tracks) }
            Add-Result 'manifest JSON' 'PASS' ("version=$version categories=$(@($json.categories).Count) tracks=$($tracks.Count)")
            if ($tracks.Count -eq 0) {
                Add-Result 'track list' 'FAIL' 'manifest lists zero tracks' $true
            }
        } catch {
            Add-Result 'manifest JSON' 'FAIL' "unparseable: $($_.Exception.Message)" $true
        }
    }
} catch {
    $code = Get-ProbeFailure $_
    if ($code -eq 0) { Add-Result 'index.json' 'FAIL' "unreachable: $($_.Exception.Message)" $true }
    elseif ($code -eq 401 -or $code -eq 403) { Add-Result 'index.json' 'FAIL' "HTTP $code - bucket is not public-read" $true }
    elseif ($code -eq 402) { Add-Result 'index.json' 'FAIL' 'HTTP 402 - egress/quota cap on the account' $true }
    else { Add-Result 'index.json' 'FAIL' "HTTP $code" $true }
}

# -- 3. ASCII object keys ----------------------------------------------------
if ($tracks.Count -gt 0) {
    $nonAscii = @($tracks | Where-Object {
        $_.file -and ($_.file.ToCharArray() | Where-Object { [int]$_ -gt 127 } | Select-Object -First 1)
    })
    if ($nonAscii.Count -eq 0) {
        Add-Result 'ASCII keys' 'PASS' 'all track keys are ASCII' $false
    } else {
        Add-Result 'ASCII keys' 'FAIL' "$($nonAscii.Count) non-ASCII key(s), e.g. '$($nonAscii[0].file)'" $false
    }

    # -- 4. Range support + size agreement -----------------------------------
    $sample = @($tracks | Get-Random -Count ([Math]::Min($SampleSize, $tracks.Count)))
    $rangeOk = 0
    $sizeOk = 0
    $firstFailure = ''
    foreach ($t in $sample) {
        $url = "$base/$(Encode-Key $t.file)"
        try {
            $r = Invoke-Probe -Url $url -From 0 -To ($ProbeBytes - 1)
            # A conforming server clamps the range to the object size, so a
            # track smaller than the probe legitimately returns fewer bytes.
            # Compare against min(ProbeBytes, total-from-Content-Range) instead
            # of demanding a full probe, or every short file false-fails.
            $total = 0L
            if ($r.ContentRange -match '/(\d+)\s*$') { $total = [long]$Matches[1] }
            $expected = if ($total -gt 0) { [Math]::Min([long]$ProbeBytes, $total) } else { [long]$ProbeBytes }
            if ($r.Status -eq 206 -and $r.Body.Length -eq $expected) {
                $rangeOk++
                if ($t.sizeBytes -gt 0 -and $total -gt 0 -and $total -eq [long]$t.sizeBytes) {
                    $sizeOk++
                }
            } elseif (-not $firstFailure) {
                $firstFailure = "$($t.file) -> HTTP $($r.Status), $($r.Body.Length) bytes (expected 206/$expected)"
            }
        } catch {
            $code = Get-ProbeFailure $_
            if (-not $firstFailure) { $firstFailure = "$($t.file) -> HTTP $code" }
        }
    }
    $n = $sample.Count
    if ($rangeOk -eq $n) {
        Add-Result 'Range 206' 'PASS' "$rangeOk/$n ranged GETs returned 206 (seekable)"
    } else {
        Add-Result 'Range 206' 'FAIL' "$rangeOk/$n ok - seeking will break. $firstFailure" $true
    }
    if ($n -gt 0 -and $sizeOk -eq $n) {
        Add-Result 'sizeBytes match' 'PASS' "$sizeOk/$n agree with the manifest"
    } else {
        Add-Result 'sizeBytes match' 'WARN' "$sizeOk/$n match the manifest" $false
    }
}

# -- Report ------------------------------------------------------------------
$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Output

$failed = @($results | Where-Object { $_.Hard -and $_.State -eq 'FAIL' })
$warned = @($results | Where-Object { $_.State -eq 'WARN' })

if ($failed.Count -gt 0) {
    Write-Output "VERDICT: NOT USABLE - $($failed.Count) hard failure(s)."
    exit 1
} elseif ($warned.Count -gt 0) {
    Write-Output 'VERDICT: usable, with warnings.'
    exit 0
} else {
    Write-Output 'VERDICT: usable - safe to migrate onto this host.'
    exit 0
}
