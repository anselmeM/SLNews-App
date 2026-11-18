<#
.SYNOPSIS
Builds the Play Store Android App Bundle.

.DESCRIPTION
Play rejects APKs for new apps, so the store artefact is an .aab signed with the
upload key from android/key.properties. The script refuses to continue when the
key is missing, because a debug-signed bundle would be rejected after upload.

Runs the same gates as the APK build (format, analyze, tests) so an AAB is never
produced from code that does not pass them.

.PARAMETER SkipTests
Skips analyze and tests. Only for a re-pack after a verified run.

.EXAMPLE
powershell -NoProfile -File scripts/build_aab.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$flutter = $null
$cmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($cmd) { $flutter = $cmd.Source }
if (-not $flutter) {
    $candidate = 'C:\Users\amotc\flutter\flutter\bin\flutter.bat'
    if (Test-Path $candidate) { $flutter = $candidate }
}
if (-not $flutter) { throw 'flutter was not found on PATH and the fallback path is missing.' }

# Resolve the SDK's own dart next to flutter: bare `dart` is not on PATH inside
# this script's child process, which made the first run fail at the format gate.
$dart = Join-Path (Split-Path -Parent $flutter) 'dart.bat'
if (-not (Test-Path $dart)) {
    $dartCommand = Get-Command dart -ErrorAction SilentlyContinue
    if (-not $dartCommand) { throw 'dart was not found next to flutter.' }
    $dart = $dartCommand.Source
}

if (-not (Test-Path (Join-Path $root 'android\key.properties'))) {
    throw 'android/key.properties is missing: the bundle would be debug-signed and Play would reject it. Run scripts/create_keystore.ps1 first.'
}

# Version from pubspec: "1.2.3+4" -> name/code.
$pubspec = Get-Content (Join-Path $root 'pubspec.yaml')
$versionLine = ($pubspec | Select-String -Pattern '^version:\s*(\S+)' | Select-Object -First 1).Line
if (-not $versionLine) { throw 'pubspec.yaml has no version line.' }
$version = ($versionLine -replace '^version:\s*', '').Trim()
$versionName = ($version -split '\+')[0]
$versionCode = if ($version -match '\+(\d+)$') { $Matches[1] } else { '0' }
Write-Host "Building SLNews $versionName ($versionCode)" -ForegroundColor Cyan

if (-not $SkipTests) {
    Write-Host 'Formatting check...' -ForegroundColor Cyan
    & $flutter pub get | Out-Null
    & $dart format --output=none --set-exit-if-changed lib test
    if ($LASTEXITCODE -ne 0) { throw 'dart format found unformatted files.' }

    Write-Host 'Analyzing...' -ForegroundColor Cyan
    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }

    Write-Host 'Running tests...' -ForegroundColor Cyan
    & $flutter test test/core test/data test/features test/sync test/security
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
}

# Crash reporting is configuration: pass the DSN when the environment has one,
# and always stamp the release so Sentry can group by version.
$defineArgs = @()
if ($env:SENTRY_DSN) {
    $defineArgs += '--dart-define=SENTRY_DSN=' + $env:SENTRY_DSN
    Write-Host '  sentry  : DSN set, crash reporting enabled' -ForegroundColor Cyan
} else {
    Write-Warning 'SENTRY_DSN is not set: this bundle ships without crash reporting.'
}
if ($env:SENTRY_ENV) { $defineArgs += '--dart-define=SENTRY_ENV=' + $env:SENTRY_ENV }

# Identity is configuration too: without the publishable key the app boots
# anonymously, which also switches off push registration (the devices endpoint
# needs a session) and account sync. The key is publishable by design.
if ($env:CLERK_PUBLISHABLE_KEY) {
    $defineArgs += '--dart-define=CLERK_PUBLISHABLE_KEY=' + $env:CLERK_PUBLISHABLE_KEY
    Write-Host '  clerk   : publishable key set, sign-in enabled' -ForegroundColor Cyan
} else {
    Write-Warning 'CLERK_PUBLISHABLE_KEY is not set: this bundle runs anonymously, so sign-in, account sync and push registration are off.'
}

$defineArgs += '--dart-define=SLNEWS_RELEASE=slnews-mobile@' + $version

Write-Host 'Building app bundle...' -ForegroundColor Cyan
& $flutter build appbundle --release @defineArgs
if ($LASTEXITCODE -ne 0) { throw 'flutter build appbundle failed.' }

$built = Join-Path $root 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $built)) { throw "Expected bundle not found at $built" }

$dist = Join-Path $root 'build\dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$target = Join-Path $dist ("SLNews-{0}-{1}.aab" -f $versionName, $versionCode)
Copy-Item $built $target -Force

$size = [math]::Round((Get-Item $target).Length / 1MB, 1)
$hash = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()

Write-Host ''
Write-Host "AAB: $target"
Write-Host "  version : $versionName ($versionCode)"
Write-Host "  size    : $size MB"
Write-Host "  sha256  : $hash"

# Verify the jar signature rather than the APK signature: an AAB is a jar.
$jarsigner = Get-Command jarsigner -ErrorAction SilentlyContinue
if ($jarsigner) {
    $verify = & $jarsigner -verify $target 2>&1
    $verified = ($verify | Select-String -Pattern 'jar verified' -Quiet)
    Write-Host ("  signing : " + $(if ($verified) { 'verified' } else { 'NOT VERIFIED - inspect before upload' }))
} else {
    Write-Host '  signing : jarsigner not on PATH, upload signature not checked here'
}

Write-Host ''
Write-Host 'Next: Play Console -> Testing -> Internal testing -> Create new release and upload this .aab.'
