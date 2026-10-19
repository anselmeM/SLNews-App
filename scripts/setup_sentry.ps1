<#
.SYNOPSIS
Creates (or reuses) the SLNews Flutter project in Sentry, wires its DSN into CI and
verifies that the DSN accepts events.

.DESCRIPTION
Idempotent. Needs a Sentry auth token with `org:read` and `project:admin` (org owner
also works). The token is read from -AuthToken or $env:SENTRY_AUTH_TOKEN and is never
written to disk or printed.

Steps:
  1. find the organisation's first team (or use -Team);
  2. reuse the project if the slug exists, otherwise create it as a Flutter project;
  3. read the first active client key (the DSN);
  4. store the DSN as the SENTRY_DSN GitHub secret for the mobile repo;
  5. POST a test event straight to the DSN store endpoint to prove ingest works.

The DSN is a public client key, so printing it is safe; the auth token is not.

.EXAMPLE
$env:SENTRY_AUTH_TOKEN = 'sntrys_...'
powershell -NoProfile -File scripts/setup_sentry.ps1
#>
[CmdletBinding()]
param(
    [string]$AuthToken = $env:SENTRY_AUTH_TOKEN,
    [string]$Org = 'firstmiledevs',
    [string]$Project = 'slnews-flutter',
    [string]$Team = '',
    [string]$GitHubRepo = 'anselmeM/SLNews-Web-App',
    [switch]$SkipGitHubSecret
)

$ErrorActionPreference = 'Stop'
$api = 'https://sentry.io/api/0'
$headers = @{ Authorization = "Bearer $AuthToken" }

if ([string]::IsNullOrWhiteSpace($AuthToken)) {
    Write-Host 'A Sentry auth token is required.' -ForegroundColor Yellow
    Write-Host '  Sentry -> Settings -> Auth Tokens -> Create New Token'
    Write-Host '  scopes: org:read, project:admin (project:write also works).'
    Write-Host ''
    Write-Host 'Then either run:  $env:SENTRY_AUTH_TOKEN="sntrys_..."; powershell -NoProfile -File scripts/setup_sentry.ps1'
    exit 1
}

function Invoke-SentryApi {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body
    )
    $uri = "$api$Path"
    $args = @{
        Method      = $Method
        Uri         = $uri
        Headers     = $headers
        ContentType = 'application/json'
        ErrorAction = 'Stop'
    }
    if ($null -ne $Body) { $args.Body = ($Body | ConvertTo-Json -Depth 8 -Compress) }
    Invoke-RestMethod @args
}

# --- 1. team ---------------------------------------------------------------
if (-not $Team) {
    $teams = Invoke-SentryApi -Method GET -Path "/organizations/$Org/teams/"
    if (-not $teams -or $teams.Count -eq 0) {
        throw "The token can see no teams in organisation '$Org'. Check the org slug and token scopes."
    }
    $Team = $teams[0].slug
    Write-Host "Team: $Team" -ForegroundColor Cyan
} else {
    Write-Host "Team: $Team" -ForegroundColor Cyan
}

# --- 2. project ------------------------------------------------------------
$projectExists = $true
try {
    Invoke-SentryApi -Method GET -Path "/projects/$Org/$Project/" | Out-Null
    Write-Host "Project '$Project' already exists." -ForegroundColor Cyan
} catch {
    $projectExists = $false
}

if (-not $projectExists) {
    $body = @{
        name     = 'SLNews Flutter'
        slug     = $Project
        platform = 'flutter'
    }
    Invoke-SentryApi -Method POST -Path "/teams/$Org/$Team/projects/" -Body $body | Out-Null
    Write-Host "Created project '$Project' (platform: flutter)." -ForegroundColor Green
}

# --- 3. DSN ----------------------------------------------------------------
$keys = Invoke-SentryApi -Method GET -Path "/projects/$Org/$Project/keys/"
$key = $keys | Where-Object { $_.isActive } | Select-Object -First 1
if (-not $key) { $key = $keys | Select-Object -First 1 }
if (-not $key) { throw 'The project has no client key; open the project once in the UI and retry.' }

$dsn = $key.dsn.public
$publicKey = $key.public
$projectId = $key.projectId
Write-Host ''
Write-Host "DSN: $dsn" -ForegroundColor Green

# --- 4. GitHub secret ------------------------------------------------------
if (-not $SkipGitHubSecret) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        $dsn | gh secret set SENTRY_DSN --repo $GitHubRepo 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Stored SENTRY_DSN as a secret on $GitHubRepo." -ForegroundColor Green
        } else {
            Write-Warning "Could not set the GitHub secret (permissions?). Set it manually: $GitHubRepo -> Settings -> Secrets -> SENTRY_DSN"
        }
    } else {
        Write-Warning 'gh not on PATH; set the SENTRY_DSN secret manually.'
    }
}

# --- 5. verify ingest ------------------------------------------------------
$parsed = [uri]$dsn
$ingestHost = $parsed.Host
$storeUrl = "https://$ingestHost/api/$projectId/store/"
$eventId = [guid]::NewGuid().ToString('N')
$event = @{
    event_id  = $eventId
    timestamp = (Get-Date).ToUniversalTime().ToString('o')
    platform  = 'other'
    level     = 'info'
    release   = 'slnews-mobile@setup'
    message   = 'SLNews Sentry setup verification event'
    tags      = @{ source = 'setup_sentry.ps1' }
}
$authHeader = "Sentry sentry_version=7,sentry_client=slnews-setup/1.0,sentry_key=$publicKey"
try {
    $response = Invoke-WebRequest -Method POST -Uri $storeUrl -Headers @{ 'X-Sentry-Auth' = $authHeader } `
        -ContentType 'application/json' -Body ($event | ConvertTo-Json -Depth 5) -UseBasicParsing -TimeoutSec 20
    Write-Host "Ingest check: HTTP $($response.StatusCode) (event $eventId accepted)." -ForegroundColor Green
} catch {
    Write-Warning "Ingest check failed: $($_.Exception.Message)"
    Write-Host 'The DSN may be disabled, or the project id could not be parsed from it.'
}

Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  1. Sentry -> project -> Settings -> Security & Privacy: enable "Prevent Storing of IP Addresses".'
Write-Host '  2. Sentry -> project -> Settings -> Inbound Filters: add a daily rate limit (e.g. 1000 events).'
Write-Host "  3. Build with the DSN:  `$env:SENTRY_DSN='$dsn'; powershell -NoProfile -File scripts/build_apk.ps1"
Write-Host '  4. Debug build: Settings -> About -> "Send test event" confirms end to end.'
