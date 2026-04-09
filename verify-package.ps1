$ErrorActionPreference = "Stop"

function Write-Ok {
  param([string]$Message)
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Fail {
  param([string]$Message)
  Write-Host "[FAIL] $Message" -ForegroundColor Red
}

$failed = $false
$userHome = [Environment]::GetFolderPath("UserProfile")

$requiredPaths = @(
  (Join-Path $userHome ".kiro"),
  (Join-Path $userHome ".kiro/settings"),
  (Join-Path $userHome ".kiro/settings/mcp.json"),
  (Join-Path $userHome ".kiro/steering"),
  (Join-Path $userHome ".kiro/skills")
)

foreach ($path in $requiredPaths) {
  if (Test-Path -LiteralPath $path) {
    Write-Ok "Existe: $path"
  }
  else {
    Write-Fail "Falta: $path"
    $failed = $true
  }
}

$mcpPath = Join-Path $userHome ".kiro/settings/mcp.json"
if (Test-Path -LiteralPath $mcpPath) {
  try {
    $json = Get-Content -LiteralPath $mcpPath -Raw | ConvertFrom-Json
    if ($null -eq $json.mcpServers) {
      Write-Fail "JSON valido pero sin nodo mcpServers"
      $failed = $true
    }
    else {
      Write-Ok "mcp.json es JSON valido y contiene mcpServers"
    }
  }
  catch {
    Write-Fail "mcp.json invalido: $($_.Exception.Message)"
    $failed = $true
  }
}

$skillsRoot = Join-Path $userHome ".kiro/skills"
if (Test-Path -LiteralPath $skillsRoot) {
  $skillFiles = Get-ChildItem -Path $skillsRoot -Recurse -Filter "SKILL.md" -ErrorAction SilentlyContinue
  $skillCount = @($skillFiles).Count
  if ($skillCount -gt 0) {
    Write-Ok "Skills detectadas: $skillCount"
  }
  else {
    Write-Fail "No se detectaron skills instaladas (SKILL.md)."
    $failed = $true
  }
}

if ($failed) {
  Write-Host "Verificacion final: FAIL" -ForegroundColor Red
  exit 1
}

Write-Host "Verificacion final: OK" -ForegroundColor Green
exit 0
