# Fails when a tracked file looks like it contains a live credential.
# Deliberately pattern-based: it catches the classes we have actually shipped
# keys for (Firebase service accounts, Google API keys, GitHub/Slack/OpenAI
# tokens, private keys, database URLs) without flagging test placeholders.
$ErrorActionPreference = 'Stop'
$patterns = @(
  @{ Name = 'private key block'; Regex = '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' },
  @{ Name = 'Firebase service-account JSON'; Regex = '"private_key"\s*:\s*"-----BEGIN' },
  @{ Name = 'Google API key'; Regex = 'AIza[0-9A-Za-z_\-]{35}' },
  @{ Name = 'GitHub token'; Regex = 'gh[pousr]_[A-Za-z0-9]{36,}' },
  @{ Name = 'Slack token'; Regex = 'xox[baprs]-[A-Za-z0-9-]{10,}' },
  @{ Name = 'OpenAI/Anthropic key'; Regex = 'sk-(ant-)?[A-Za-z0-9_\-]{24,}' },
  @{ Name = 'database URL with password'; Regex = 'postgres(ql)?://[^\s:@/]+:[^\s:@/]+@' }
)

$root = Split-Path $PSScriptRoot -Parent
$files = @(git -C $root ls-files)
if ($LASTEXITCODE -ne 0) {
  throw "git ls-files failed in $root"
}
$findings = New-Object System.Collections.Generic.List[string]
foreach ($file in $files) {
  $file = "$file".Trim()
  if ([string]::IsNullOrWhiteSpace($file)) { continue }
  if ($file -match '(^|/)(build|\.dart_tool|node_modules|\.git)/') { continue }
  # google-services.json is Firebase's client config, committed by design; its
  # API key is app-restricted and public. Still scanned for private keys.
  $isFirebaseClientConfig = $file -eq 'android/app/google-services.json'
  $path = Join-Path (Split-Path $PSScriptRoot -Parent) $file
  if (-not (Test-Path $path -PathType Leaf)) { continue }
  $info = Get-Item $path
  if ($info.Length -gt 2MB) { continue }
  $text = Get-Content $path -Raw -ErrorAction SilentlyContinue
  if ($null -eq $text) { continue }
  foreach ($pattern in $patterns) {
    $match = [regex]::Match($text, $pattern.Regex)
    if ($match.Success -and -not ($isFirebaseClientConfig -and $pattern.Name -eq 'Google API key')) {
      $line = ($text.Substring(0, $match.Index) -split "`n").Count
      $findings.Add("$file`:$line  $($pattern.Name)")
    }
  }
}

if ($findings.Count -gt 0) {
  Write-Host 'Secret scan failed:' -ForegroundColor Red
  $findings | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host "Secret scan passed ($($files.Count) tracked files)."
