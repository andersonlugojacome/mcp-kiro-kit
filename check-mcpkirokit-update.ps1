param(
  [string]$InstalledVersion = "",
  [switch]$Force,
  [switch]$QuietIfCheckedToday
)

$ErrorActionPreference = "Stop"

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnMsg {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Get-NormalizedVersion {
  param([string]$VersionText)

  if ([string]::IsNullOrWhiteSpace($VersionText)) {
    return ""
  }

  return $VersionText.Trim().TrimStart("v")
}

function Try-GetVersionObject {
  param([string]$VersionText)

  try {
    if ([string]::IsNullOrWhiteSpace($VersionText)) {
      return $null
    }
    return [version](Get-NormalizedVersion -VersionText $VersionText)
  }
  catch {
    return $null
  }
}

$userHome = [Environment]::GetFolderPath("UserProfile")
$stateDir = Join-Path $userHome ".kiro/state"
$statePath = Join-Path $stateDir "mcpkirokit-update-check.json"
$installMetaPath = Join-Path $userHome ".kiro/mcpkirokit-install.json"

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

$today = (Get-Date).ToString("yyyy-MM-dd")
$state = $null

if (Test-Path -LiteralPath $statePath) {
  try {
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
  }
  catch {
    $state = $null
  }
}

if (-not $Force -and $null -ne $state -and $state.lastCheckDate -eq $today) {
  if (-not $QuietIfCheckedToday) {
    Write-Info "Chequeo de actualizaciones ya ejecutado hoy."
  }
  exit 0
}

if ([string]::IsNullOrWhiteSpace($InstalledVersion) -and (Test-Path -LiteralPath $installMetaPath)) {
  try {
    $meta = Get-Content -LiteralPath $installMetaPath -Raw | ConvertFrom-Json
    if ($null -ne $meta.installedVersion) {
      $InstalledVersion = "$($meta.installedVersion)"
    }
  }
  catch {
    # ignore metadata parse issues
  }
}

$apiUrl = "https://api.github.com/repos/andersonlugojacome/mcp-kiro-kit/releases/latest"
$latestTag = ""

try {
  $resp = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing -Headers @{ "User-Agent" = "MCPKiroKit-UpdateChecker" }
  $json = $resp.Content | ConvertFrom-Json
  $latestTag = "$($json.tag_name)"
}
catch {
  Write-WarnMsg "No se pudo consultar la version mas reciente: $($_.Exception.Message)"
  exit 0
}

$installedNormalized = Get-NormalizedVersion -VersionText $InstalledVersion
$latestNormalized = Get-NormalizedVersion -VersionText $latestTag
$installedObj = Try-GetVersionObject -VersionText $installedNormalized
$latestObj = Try-GetVersionObject -VersionText $latestNormalized

$result = "unknown"

if ($null -ne $installedObj -and $null -ne $latestObj) {
  if ($latestObj -gt $installedObj) {
    $result = "update-available"
    Write-WarnMsg "Nueva version disponible: v$latestNormalized (instalada: v$installedNormalized)."
    Write-Info "Ejecuta: actualizame"
  }
  else {
    $result = "up-to-date"
    Write-Info "MCPKiroKit al dia (v$installedNormalized)."
  }
}
else {
  Write-Info "Version instalada: $installedNormalized"
  Write-Info "Version mas reciente: $latestTag"
}

$newState = [ordered]@{
  lastCheckDate = $today
  checkedAt = (Get-Date).ToString("o")
  installedVersion = $installedNormalized
  latestTag = $latestTag
  result = $result
}

$newState | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $statePath -Encoding UTF8

exit 0
