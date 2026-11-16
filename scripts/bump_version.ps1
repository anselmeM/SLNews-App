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

# Read and write as UTF-8 **without a BOM**.
#
# `Get-Content`/`Set-Content` are not safe here on Windows PowerShell 5.1: the
# reader defaults to ANSI, which double-encodes the file's existing UTF-8 bytes,
# and `-Encoding utf8` writes a BOM. Either one silently rewrites every
# non-ASCII comment in pubspec.yaml, so the file is changed through
# System.IO with an explicit encoder instead.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($pubspecPath, $utf8)
$updated = [regex]::Replace(
    $text,
    '(?m)^version:[ \t]*\S+[ \t]*$',
    "version: $Version+$Build"
)
if ($updated -eq $text) { throw 'Could not rewrite the version line.' }
[System.IO.File]::WriteAllText($pubspecPath, $updated, $utf8)
Write-Host "pubspec.yaml version -> $Version+$Build" -ForegroundColor Green
Write-Host 'Remember: the same build is what Play compares; never reuse a versionCode.'
