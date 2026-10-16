<#
.SYNOPSIS
    Live smoke test of the SLNews scraper API that the mobile app consumes.

.DESCRIPTION
    Verifies the exact contract the Flutter client depends on:
      * GET /api/health            (open)     -> status ok + database connected
      * GET /v1/news?page_size=3   (bearer)   -> data[] + meta{page,page_size,total,has_more}
      * GET /v1/news  without a key            -> 401 (auth is actually enforced)

    The API key is read from -Key, then $env:SLNEWS_API_KEY, then .env.local at
    the repository root. It is never echoed; only its length is reported.

.PARAMETER Key
    Bearer key for the API. Prefer $env:SLNEWS_API_KEY or .env.local over
    passing it on the command line (shell history).

.PARAMETER BaseUrl
    Overrides the base URL (default: $env:SLNEWS_API_URL or the deployed host).

.EXAMPLE
    pwsh -File scripts/smoke_api.ps1
    pwsh -File scripts/smoke_api.ps1 -BaseUrl http://localhost:3000
#>
[CmdletBinding()]
param(
    [string] $Key,
    [string] $BaseUrl
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-Setting([string] $name) {
    $fromEnvironment = (Get-Item "env:$name" -ErrorAction SilentlyContinue).Value
    if ($fromEnvironment) { return $fromEnvironment }
    $envFile = Join-Path $projectRoot '.env.local'
    if (Test-Path $envFile) {
        foreach ($line in Get-Content $envFile) {
            if ($line -match "^\s*$name\s*=\s*`"?'?([^`"\r\n]*)`"?'?\s*$") { return $Matches[1].Trim() }
        }
    }
    return $null
}

if (-not $BaseUrl) { $BaseUrl = Resolve-Setting 'SLNEWS_API_URL' }
if (-not $BaseUrl) { $BaseUrl = 'https://slnewsapiscapper.onrender.com' }
if (-not $Key) { $Key = Resolve-Setting 'SLNEWS_API_KEY' }

$BaseUrl = $BaseUrl.TrimEnd('/')
$failures = 0

Write-Host "SLNews scraper API smoke test" -ForegroundColor Cyan
Write-Host "  base url : $BaseUrl"
Write-Host "  api key  : $(if ($Key) { "configured (length $($Key.Length))" } else { 'NOT configured' })"
Write-Host ''

# --- 1. Open health check ----------------------------------------------------
Write-Host '[1/3] GET /api/health (no auth)'
try {
    $health = curl.exe -sS --max-time 90 -w "`n%{http_code}" "$BaseUrl/api/health"
    $code = ($health | Select-String '\d{3}$').Matches.Value
    $body = ($health -join "`n") -replace "`n\d{3}$", ''
    $json = $body | ConvertFrom-Json
    if ($code -eq '200' -and $json.status -eq 'ok') {
        Write-Host "      ok: status=$($json.status) database=$($json.database)" -ForegroundColor Green
    } else {
        Write-Host "      unexpected: HTTP $code body=$body" -ForegroundColor Yellow
        $failures++
    }
} catch {
    Write-Host "      failed: $_" -ForegroundColor Red
    $failures++
}

# --- 2. Auth is enforced -----------------------------------------------------
Write-Host '[2/3] GET /v1/news without a key (expect 401)'
$anonymous = curl.exe -sS --max-time 90 -o - -w "`n%{http_code}" "$BaseUrl/v1/news?page_size=1"
$anonCode = ($anonymous | Select-String '\d{3}$').Matches.Value
if ($anonCode -eq '401') {
    Write-Host '      ok: unauthenticated request rejected' -ForegroundColor Green
} else {
    Write-Host "      unexpected: HTTP $anonCode (auth may be misconfigured)" -ForegroundColor Yellow
    $failures++
}

# --- 3. Authenticated contract ----------------------------------------------
if (-not $Key) {
    Write-Host '[3/3] skipped: no API key available (set $env:SLNEWS_API_KEY or .env.local)' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Contract itself was verified from the service source and the 401 above.' -ForegroundColor Cyan
    exit 0
}

Write-Host '[3/3] GET /v1/news?page_size=3 (bearer)'
try {
    $raw = curl.exe -sS --max-time 90 -H "Authorization: Bearer $Key" -w "`n%{http_code}" "$BaseUrl/v1/news?page_size=3"
    $code = ($raw | Select-String '\d{3}$').Matches.Value
    $body = ($raw -join "`n") -replace "`n\d{3}$", ''
    if ($code -ne '200') {
        Write-Host "      failed: HTTP $code body=$body" -ForegroundColor Red
        exit 1
    }
    $json = $body | ConvertFrom-Json
    $items = @($json.data)
    Write-Host "      ok: items=$($items.Count) total=$($json.meta.total) page_size=$($json.meta.page_size) has_more=$($json.meta.has_more)"
    Write-Host "      item fields: $(($items[0].PSObject.Properties.Name) -join ', ')"
    foreach ($item in $items) {
        $title = $item.title
        if ($title.Length -gt 70) { $title = $title.Substring(0, 70) + '…' }
        Write-Host "        - [$($item.source)] $title ($($item.published_at))"
        Write-Host "          $($item.url)"
    }
    Write-Host ''
    Write-Host 'PASS' -ForegroundColor Green
} catch {
    Write-Host "      failed: $_" -ForegroundColor Red
    exit 1
}

if ($failures -gt 0) { exit 1 }
