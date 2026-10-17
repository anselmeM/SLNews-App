# Generates the Android release signing keystore for SLNews Mobile.
#
# The keystore and android/key.properties are git-ignored (see android/.gitignore);
# they must never be committed. Losing the keystore means you can never update an
# app already published under it, so the files this script writes are credentials:
# back them up to a password manager or an encrypted drive before shipping.
#
# Usage:
#   powershell -NoProfile -File scripts/create_keystore.ps1
#   powershell -NoProfile -File scripts/create_keystore.ps1 -SetGitHubSecrets
#
# -SetGitHubSecrets pushes the four repository secrets the CI workflow reads
# (ANDROID_KEYSTORE_BASE64, ANDROID_STORE_PASSWORD, ANDROID_KEY_PASSWORD,
# ANDROID_KEY_ALIAS) with `gh`, so the values never appear on screen or in shell
# history.
[CmdletBinding()]
param(
    [string] $Alias = 'slnews',
    [int] $ValidityDays = 10000,
    [string] $DName = 'CN=SLNews, OU=Mobile, O=SLNews, L=Freetown, C=SL',
    [switch] $SetGitHubSecrets,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $repoRoot 'android'
$keystorePath = Join-Path $androidDir 'slnews-release.jks'
$propertiesPath = Join-Path $androidDir 'key.properties'

if (-not (Test-Path $androidDir)) {
    throw "android/ not found next to scripts/ - run this from the app repository."
}
if ((Test-Path $keystorePath) -and -not $Force) {
    throw "$keystorePath already exists. Refusing to overwrite a signing key; pass -Force only if you are certain."
}
if ((Test-Path $propertiesPath) -and -not $Force) {
    throw "$propertiesPath already exists. Refusing to overwrite; pass -Force only if you are certain."
}

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    $candidates = @(
        "$env:JAVA_HOME\bin\keytool.exe",
        'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
        'C:\Program Files\Java\jdk-17\bin\keytool.exe'
    )
    $keytool = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $keytool) {
    throw 'keytool not found. Install a JDK 17 (or Android Studio, which bundles one) and re-run.'
}

# 24 random characters: letters and digits only, so it is safe in key.properties
# and in the `gh secret set` pipe without quoting surprises.
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$password = -join (([Convert]::ToBase64String($bytes)) -replace '[^A-Za-z0-9]', '').ToCharArray()[0..23]

Write-Host "Generating $keystorePath (alias '$Alias', $ValidityDays days)..." -ForegroundColor Cyan
# keytool writes its progress to stderr. With ErrorActionPreference=Stop that
# becomes a terminating error in PowerShell 5.1, so relax it for the call and
# judge success by the exit code instead.
$savedPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$keytoolOutput = & $keytool -genkeypair -v -keystore $keystorePath -storetype JKS -keyalg RSA -keysize 2048 `
    -validity $ValidityDays -alias $Alias -storepass $password -keypass $password -dname $DName 2>&1
$keytoolExit = $LASTEXITCODE
$ErrorActionPreference = $savedPreference
$keytoolOutput | Select-Object -Last 2 | ForEach-Object { "  $_" }
if ($keytoolExit -ne 0) { throw "keytool failed with exit code $keytoolExit" }

# storeFile is resolved relative to android/app/, hence ../slnews-release.jks
@"
storePassword=$password
keyPassword=$password
keyAlias=$Alias
storeFile=../slnews-release.jks
"@ | Set-Content -Path $propertiesPath -Encoding ascii

Write-Host ''
Write-Host 'Wrote android/key.properties (git-ignored).' -ForegroundColor Green
Write-Host ''
Write-Host 'BACK THIS UP NOW - both files together:' -ForegroundColor Yellow
Write-Host "  $keystorePath"
Write-Host "  $propertiesPath   (contains the password)"
Write-Host ''
Write-Host 'Losing them means you cannot publish an update for an app already released under this key.'

if ($SetGitHubSecrets) {
    Write-Host ''
    Write-Host 'Pushing the four CI secrets to GitHub (values piped, never echoed)...' -ForegroundColor Cyan
    $storeBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath))
    Push-Location $repoRoot
    $ghPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $storeBase64 | gh secret set ANDROID_KEYSTORE_BASE64
        if ($LASTEXITCODE -ne 0) { throw 'gh secret set ANDROID_KEYSTORE_BASE64 failed' }
        $password | gh secret set ANDROID_STORE_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'gh secret set ANDROID_STORE_PASSWORD failed' }
        $password | gh secret set ANDROID_KEY_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'gh secret set ANDROID_KEY_PASSWORD failed' }
        $Alias | gh secret set ANDROID_KEY_ALIAS
        if ($LASTEXITCODE -ne 0) { throw 'gh secret set ANDROID_KEY_ALIAS failed' }
        Write-Host ''
        gh secret list
    }
    finally {
        $ErrorActionPreference = $ghPreference
        Pop-Location
    }
}
else {
    Write-Host ''
    Write-Host 'To hand the same key to GitHub Actions, re-run with -SetGitHubSecrets, or set these'
    Write-Host 'repository secrets manually: ANDROID_KEYSTORE_BASE64 (base64 of the .jks),'
    Write-Host 'ANDROID_STORE_PASSWORD, ANDROID_KEY_PASSWORD, ANDROID_KEY_ALIAS.'
}

Write-Host ''
Write-Host 'Verify locally: powershell -NoProfile -File scripts/build_apk.ps1'
Write-Host 'The build output should then report a CN=SLNews signer instead of the debug one.'
