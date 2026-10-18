<#
.SYNOPSIS
Bumps the app version in pubspec.yaml.

.DESCRIPTION
Play requires a higher versionCode on every upload and it can never be reused.
`flutter build` reads both values from the single `version:` line in pubspec, so
this script is the only place they are edited.

.PARAMETER Version
Semantic version to set, e.g. 1.0.1.

.PARAMETER Build
versionCode (integer, strictly increasing). Defaults to the current value + 1.

.EXAMPLE
powershell -NoProfile -File scripts/bump_version.ps1 -Version 1.0.1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [int]$Build = 0
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $root 'pubspec.yaml'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must look like 1.2.3, got '$Version'."
}

$lines = Get-Content $pubspecPath
$index = -1
$currentCode = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^version:\s*(.+)$') {
        $index = $i
        $current = $Matches[1].Trim()
        if ($current -match '\+(\d+)$') { $currentCode = [int]$Matches[1] }
        break
    }
}
if ($index -lt 0) { throw 'pubspec.yaml has no version line.' }

if ($Build -le 0) { $Build = $currentCode + 1 }
if ($Build -le $currentCode) {
    throw "versionCode must increase: current $currentCode, requested $Build."
}

$lines[$index] = "version: $Version+$Build"
Set-Content -Path $pubspecPath -Value $lines -Encoding utf8
Write-Host "pubspec.yaml version -> $Version+$Build" -ForegroundColor Green
Write-Host 'Remember: the same build is what Play compares; never reuse a versionCode.'
