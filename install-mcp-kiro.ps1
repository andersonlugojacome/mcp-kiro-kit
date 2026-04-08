param(
  [string]$WorkspacePath = ""
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

function Ensure-ExecutionPolicy {
  $policy = Get-ExecutionPolicy -Scope CurrentUser
  if ($policy -in @("RemoteSigned", "Unrestricted", "Bypass", "AllSigned")) {
    Write-Info "ExecutionPolicy(CurrentUser) ya esta en $policy"
    return
  }

  Write-Info "Ajustando ExecutionPolicy(CurrentUser) a RemoteSigned"
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

function Ensure-Scoop {
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Info "Scoop ya esta instalado"
    return
  }

  Write-Info "Instalando Scoop (modo usuario, sin admin)"
  Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw "No se pudo instalar Scoop."
  }
}

function Ensure-ScoopPackage {
  param(
    [Parameter(Mandatory = $true)][string]$CommandName,
    [Parameter(Mandatory = $true)][string]$PackageName
  )

  if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
    Write-Info "$CommandName ya esta disponible"
    return
  }

  Write-Info "Instalando $PackageName con scoop"
  scoop install $PackageName
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "No se pudo validar $CommandName despues de instalar $PackageName."
  }
}

function Ensure-Npx {
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "npx no esta disponible. Verifica nodejs-lts."
  }

  $version = & cmd /c npx --version
  if ($LASTEXITCODE -ne 0) {
    throw "npx esta instalado pero no responde correctamente."
  }

  Write-Info "npx OK ($version)"
}

function Merge-Hashtable {
  param(
    [hashtable]$Base,
    [hashtable]$Incoming
  )

  foreach ($key in $Incoming.Keys) {
    $incomingValue = $Incoming[$key]

    if ($null -eq $Base[$key]) {
      $Base[$key] = $incomingValue
      continue
    }

    if ($Base[$key] -is [hashtable] -and $incomingValue -is [hashtable]) {
      Merge-Hashtable -Base $Base[$key] -Incoming $incomingValue
      continue
    }

    $Base[$key] = $incomingValue
  }
}

function Ensure-KiroMcpSettings {
  param([string]$RootPath)

  $settingsDir = Join-Path $RootPath ".kiro/settings"
  $settingsFile = Join-Path $settingsDir "mcp.json"
  New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null

  $desired = @{
    mcpServers = @{
      context7 = @{
        command = "cmd"
        args = @("/c", "npx", "-y", "@upstash/context7-mcp")
      }
      engram = @{
        command = "cmd"
        args = @("/c", "npx", "-y", "engram-mcp-server")
      }
    }
  }

  $existing = @{}
  if (Test-Path -LiteralPath $settingsFile) {
    $raw = Get-Content -LiteralPath $settingsFile -Raw
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
      try {
        $parsed = $raw | ConvertFrom-Json -AsHashtable
        if ($parsed -is [hashtable]) {
          $existing = $parsed
        }
      }
      catch {
        Write-WarnMsg "mcp.json invalido detectado en $settingsFile. Se recreara config valida."
      }
    }
  }

  Merge-Hashtable -Base $existing -Incoming $desired
  $json = $existing | ConvertTo-Json -Depth 20
  Set-Content -LiteralPath $settingsFile -Value $json -Encoding UTF8
  Write-Info "MCP configurado en $settingsFile"
}

function Ensure-KiroBaseContent {
  param([string]$HomePath)

  $steeringDir = Join-Path $HomePath ".kiro/steering"
  $skillDir = Join-Path $HomePath ".kiro/skills"
  New-Item -ItemType Directory -Path $steeringDir -Force | Out-Null
  New-Item -ItemType Directory -Path $skillDir -Force | Out-Null

  $agentsPath = Join-Path $steeringDir "AGENTS.md"
  if (-not (Test-Path -LiteralPath $agentsPath)) {
    @"
# Kiro AGENTS

- Verifica prerequisitos y salida de comandos antes de concluir.
- No hardcodees secretos en prompts, scripts ni JSON.
- Prioriza cambios idempotentes y reportes cortos.
"@ | Set-Content -LiteralPath $agentsPath -Encoding UTF8
    Write-Info "Creado $agentsPath"
  }

  $workflowPath = Join-Path $steeringDir "01-mcp-workflow.md"
  if (-not (Test-Path -LiteralPath $workflowPath)) {
    @"
---
inclusion: always
---

# MCP Workflow

1. Validar npx.
2. Validar mcp.json.
3. Reiniciar Kiro.
"@ | Set-Content -LiteralPath $workflowPath -Encoding UTF8
    Write-Info "Creado $workflowPath"
  }

  $baseSkillPath = Join-Path $skillDir "README.md"
  if (-not (Test-Path -LiteralPath $baseSkillPath)) {
    "Base de skills local para Kiro." | Set-Content -LiteralPath $baseSkillPath -Encoding UTF8
    Write-Info "Creado $baseSkillPath"
  }
}

Write-Info "Inicio de instalacion MCP para Kiro (Windows sin admin)"
Ensure-ExecutionPolicy
Ensure-Scoop
Ensure-ScoopPackage -CommandName "git" -PackageName "git"
Ensure-ScoopPackage -CommandName "node" -PackageName "nodejs-lts"
Ensure-Npx

$home = [Environment]::GetFolderPath("UserProfile")
Ensure-KiroMcpSettings -RootPath $home

if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
  if (Test-Path -LiteralPath $WorkspacePath) {
    Ensure-KiroMcpSettings -RootPath $WorkspacePath
  }
  else {
    Write-WarnMsg "WorkspacePath no existe: $WorkspacePath"
  }
}

Ensure-KiroBaseContent -HomePath $home
Write-Info "Listo. Reinicia Kiro para aplicar la configuracion MCP."
