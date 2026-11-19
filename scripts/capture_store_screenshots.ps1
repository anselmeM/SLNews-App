# Captures the seven Play listing screens from a connected Android phone.
#
#   powershell -NoProfile -File scripts/capture_store_screenshots.ps1
#
# Each screen is captured with `adb shell screencap` (binary-safe), then
# tools/generate_store_assets.py composes the marketing frames.
param(
    [string]$OutDir = 'store/play/captures',
    [string]$Only,
    [string]$Serial
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
    $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    $adb = Join-Path $sdk 'platform-tools\adb.exe'
    if (-not (Test-Path $adb)) { throw "adb not found at $adb" }

    $adbArgs = @()
    if ($Serial) { $adbArgs = @('-s', $Serial) }

    $devices = & $adb @adbArgs devices | Select-String 'device$'
    if (-not $devices) {
        throw 'No Android device. Connect a phone with USB debugging enabled and run adb devices.'
    }
    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

    $screens = [ordered]@{
        for_you   = 'For You feed (scrolled just past any offline banner)'
        news      = 'News tab (first category, images loaded)'
        sports    = 'Sports tab (scoreboard and standings visible)'
        following = 'Following tab (top of the subscriptions)'
        article   = 'Any article reader (hero image loaded)'
        section   = 'Top stories section'
        search    = 'Search results for "leone"'
    }

    $remote = '/sdcard/slnews-store-capture.png'
    $captured = 0
    foreach ($name in $screens.Keys) {
        if ($Only -and $Only -ne $name) { continue }
        Write-Host ''
        Write-Host "→ $($screens[$name])" -ForegroundColor Cyan
        Read-Host '  Navigate there on the phone, then press Enter' | Out-Null

        & $adb @adbArgs shell screencap -p $remote | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "screencap failed for $name" }
        & $adb @adbArgs pull $remote (Join-Path $OutDir "$name.png") | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "pull failed for $name" }
        & $adb @adbArgs shell rm -f $remote | Out-Null
        Write-Host "  saved $OutDir\$name.png" -ForegroundColor Green
        $captured++
    }

    if ($captured -eq 0) { throw 'Nothing captured; check -Only value.' }

    Write-Host ''
    Write-Host 'Composing listing images...' -ForegroundColor Cyan
    python tools/generate_store_assets.py
    if ($LASTEXITCODE -ne 0) { throw 'store asset generation failed' }

    Write-Host ''
    Write-Host 'Review store/play/screenshots/phone-*.png before uploading.' -ForegroundColor Green
}
finally {
    Pop-Location
}
