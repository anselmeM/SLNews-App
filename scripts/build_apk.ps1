<#
.SYNOPSIS
    Builds a release APK for SLNews and copies it to build/dist with a checksum.

.DESCRIPTION
    Resolves the Flutter SDK (PATH, then the well-known local install), runs the
    quality gates, builds the release APK and reports the artefact path, size and
    SHA-256. Exits non-zero on the first failure so CI can rely on it.

.PARAMETER SplitPerAbi
    Emit one APK per ABI (~15 MB each) instead of a single fat APK (~43 MB).

.PARAMETER SkipTests
    Skip `flutter analyze` and `flutter test` (not recommended).

.PARAMETER OutDir
    Output directory for the copied artefact. Defaults to build/dist.

.PARAMETER DartDefine
    Extra `--dart-define` values as NAME=value strings. Ambient environment
    variables and a git-ignored .env.local are read automatically for
    SLNEWS_API_URL, S LNEWS_API_KEY, SLNEWS_API_PAGE_SIZE and
    CLERK_PUBLISHABLE_KEY; values passed here win.

.EXAMPLE
    powershell -NoProfile -File scripts/build_apk.ps1
    powershell -NoProfile -File scripts/build_apk.ps1 -SplitPerAbi -OutDir dist
    powershell -NoProfile -File scripts/build_apk.ps1 -DartDefine 'SLNEWS_API_KEY=abc123'

.NOTES
    Runs on Windows PowerShell 5.1 as well as PowerShell 7, so `powershell -File`
    and `pwsh -File` both work.
#>
[CmdletBinding()]
param(
    [switch] $SplitPerAbi,
    [switch] $SkipTests,
    [string] $OutDir = 'build/dist',
    [string[]] $DartDefine = @()
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    # --- Resolve the Flutter SDK -------------------------------------------------
    # No `?.` here: this must also parse under Windows PowerShell 5.1, which is
    # what a stock Windows box has (PowerShell 7 is not installed by default).
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $flutter = if ($flutterCommand) { $flutterCommand.Source } else { $null }
    if (-not $flutter) {
        $candidates = @(
            'C:\Users\amotc\flutter\flutter\bin\flutter.bat',
            "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
            'C:\src\flutter\bin\flutter.bat'
        )
        $flutter = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $flutter) {
        throw 'Flutter SDK not found. Add flutter to PATH or set FLUTTER_ROOT.'
    }

    Write-Host "SLNews release build" -ForegroundColor Cyan
    Write-Host "  project : $projectRoot"
    Write-Host "  flutter : $flutter"

    if (-not (Test-Path 'android/key.properties')) {
        Write-Warning 'android/key.properties not found - the release APK will be signed with the debug key.'
    }

    # --- Compile-time configuration ----------------------------------------------
    # Secrets are never committed: they come from -DartDefine, from the ambient
    # environment, or from the git-ignored .env.local. Only the names are printed.
    $defines = @{}
    $envFile = Join-Path $projectRoot '.env.local'
    if (Test-Path $envFile) {
        foreach ($line in Get-Content $envFile) {
            if ($line -match '^\s*([A-Z_][A-Z0-9_]*)\s*=\s*"?([^"\r\n]*)"?\s*$') {
                $defines[$Matches[1]] = $Matches[2].Trim()
            }
        }
    }
    foreach ($name in @('SLNEWS_API_URL', 'SLNEWS_API_KEY', 'SLNEWS_API_PAGE_SIZE', 'CLERK_PUBLISHABLE_KEY', 'SENTRY_DSN', 'SENTRY_ENV', 'THESPORTSDB_ENABLED', 'THESPORTSDB_KEY')) {
        $fromEnvironment = (Get-Item "env:$name" -ErrorAction SilentlyContinue).Value
        if ($fromEnvironment) { $defines[$name] = $fromEnvironment }
    }
    foreach ($entry in $DartDefine) {
        $parts = $entry -split '=', 2
        if ($parts.Count -eq 2) { $defines[$parts[0]] = $parts[1] }
    }

    $defineArgs = @()
    foreach ($name in ($defines.Keys | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace($defines[$name])) { continue }
        $defineArgs += "--dart-define=$name=$($defines[$name])"
        $shown = if ($name -match 'KEY|SECRET|TOKEN') { '<set>' } else { $defines[$name] }
        Write-Host "  define  : $name=$shown"
    }
    if ($defineArgs.Count -eq 0) {
        Write-Warning 'No --dart-define values: no identity and no scraper key, so the scraper API and sign-in are disabled in this build.'
    }

    # --- Gates -------------------------------------------------------------------
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

    if (-not $SkipTests) {
        & $flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
        & $flutter test test/core test/data test/features test/sync
        if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
    }

    # --- Build -------------------------------------------------------------------
    $buildArgs = @('build', 'apk', '--release') + $defineArgs
    if ($SplitPerAbi) { $buildArgs += '--split-per-abi' }
    & $flutter @buildArgs
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }

    # --- Collect -----------------------------------------------------------------
    $apkDir = 'build/app/outputs/flutter-apk'
    $apks = Get-ChildItem -Path $apkDir -Filter '*.apk' -File |
        Where-Object { $_.Name -notlike '*unsigned*' }
    if (-not $apks) { throw "No APK produced in $apkDir" }

    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    foreach ($apk in $apks) {
        $target = Join-Path $OutDir $apk.Name
        Copy-Item $apk.FullName $target -Force
        $hash = (Get-FileHash $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $sizeMb = [math]::Round((Get-Item $target).Length / 1MB, 1)
        Write-Host ''
        Write-Host "APK: $target" -ForegroundColor Green
        Write-Host "  size   : $sizeMb MB"
        Write-Host "  sha256 : $hash"
    }
    Write-Host ''
    Write-Host 'Install on a connected device with:' -ForegroundColor Cyan
    Write-Host "  & '$flutter' install --release"
}
finally {
    Pop-Location
}
