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
$home = [Environment]::GetFolderPath("UserProfile")

$requiredPaths = @(
  (Join-Path $home ".kiro"),
  (Join-Path $home ".kiro/settings"),
  (Join-Path $home ".kiro/settings/mcp.json"),
  (Join-Path $home ".kiro/steering"),
  (Join-Path $home ".kiro/skills")
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

$mcpPath = Join-Path $home ".kiro/settings/mcp.json"
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

if ($failed) {
  Write-Host "Verificacion final: FAIL" -ForegroundColor Red
  exit 1
}

Write-Host "Verificacion final: OK" -ForegroundColor Green
exit 0
