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
  if ($policy -in @("RemoteSigned", "Unrestricted", "AllSigned")) {
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

  Write-Info "Instalando Scoop (modo usuario local)"
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

function Get-MemoryServerPackage {
  param(
    [string[]]$SettingsFiles
  )

  foreach ($settingsFile in $SettingsFiles) {
    if (-not (Test-Path -LiteralPath $settingsFile)) {
      continue
    }

    try {
      $raw = Get-Content -LiteralPath $settingsFile -Raw
      if ([string]::IsNullOrWhiteSpace($raw)) {
        continue
      }

      $parsed = $raw | ConvertFrom-Json
      if ($null -eq $parsed -or $null -eq $parsed.mcpServers) {
        continue
      }

      foreach ($serverProp in $parsed.mcpServers.PSObject.Properties) {
        $server = $serverProp.Value
        if ($null -eq $server -or $null -eq $server.args) {
          continue
        }

        foreach ($arg in @($server.args)) {
          if ($arg -eq "engram-mcp-server") {
            return "engram-mcp-server"
          }

          if ($arg -eq "@modelcontextprotocol/server-memory") {
            return "@modelcontextprotocol/server-memory"
          }
        }
      }
    }
    catch {
      Write-WarnMsg "No se pudo leer $settingsFile para detectar memory server: $($_.Exception.Message)"
    }
  }

  return "engram-mcp-server"
}

function Invoke-PreflightNpxPackage {
  param(
    [Parameter(Mandatory = $true)][string]$PackageName,
    [Parameter(Mandatory = $true)][string]$CheckLabel,
    [int]$TimeoutSeconds = 25
  )

  $job = Start-Job -ScriptBlock {
    param($InnerPackageName)

    $ErrorActionPreference = "Stop"
    & cmd /c "npx -y $InnerPackageName --help" *> $null
    if ($LASTEXITCODE -ne 0) {
      throw "El proceso devolvio codigo $LASTEXITCODE"
    }
  } -ArgumentList $PackageName

  try {
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
    if (-not $completed) {
      Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
      Write-WarnMsg "Preflight ${CheckLabel}: WARN (timeout de $TimeoutSeconds s)"
      return $false
    }

    if ($job.State -eq "Failed") {
      $jobError = Receive-Job -Job $job -ErrorAction SilentlyContinue
      if ([string]::IsNullOrWhiteSpace("$jobError")) {
        $jobError = $job.ChildJobs[0].JobStateInfo.Reason.Message
      }

      Write-WarnMsg "Preflight ${CheckLabel}: WARN ($jobError)"
      return $false
    }

    Receive-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
    Write-Info "Preflight ${CheckLabel}: OK"
    return $true
  }
  finally {
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
  }
}

function Invoke-McpPreflight {
  param(
    [string]$MemoryServerPackage
  )

  Write-Info "Ejecutando preflight MCP (validacion rapida de runtime)"
  $warnings = New-Object System.Collections.Generic.List[string]

  if (Get-Command node -ErrorAction SilentlyContinue) {
    & cmd /c node --version *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Info "Preflight node: OK"
    }
    else {
      Write-WarnMsg "Preflight node: WARN (node no responde correctamente)"
      $warnings.Add("node") | Out-Null
    }
  }
  else {
    Write-WarnMsg "Preflight node: WARN (node no encontrado en PATH de esta sesion)"
    $warnings.Add("node") | Out-Null
  }

  if (Get-Command npx -ErrorAction SilentlyContinue) {
    & cmd /c npx --version *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Info "Preflight npx: OK"
    }
    else {
      Write-WarnMsg "Preflight npx: WARN (npx no responde correctamente)"
      $warnings.Add("npx") | Out-Null
    }
  }
  else {
    Write-WarnMsg "Preflight npx: WARN (npx no encontrado en PATH de esta sesion)"
    $warnings.Add("npx") | Out-Null
  }

  $context7Ok = Invoke-PreflightNpxPackage -PackageName "@upstash/context7-mcp" -CheckLabel "Context7"
  if (-not $context7Ok) {
    $warnings.Add("context7") | Out-Null
  }

  $memoryOk = Invoke-PreflightNpxPackage -PackageName $MemoryServerPackage -CheckLabel "memory server ($MemoryServerPackage)"
  if (-not $memoryOk) {
    $warnings.Add("memory") | Out-Null
  }

  $context7Status = if ($context7Ok) { "OK" } else { "WARN" }
  $memoryStatus = if ($memoryOk) { "OK" } else { "WARN" }
  Write-Info "Estado Context7: $context7Status"
  Write-Info "Estado Memory ($MemoryServerPackage): $memoryStatus"

  if ($warnings.Count -eq 0) {
    Write-Info "Preflight MCP finalizado: OK"
    return
  }

  Write-WarnMsg "Preflight MCP finalizado: WARN ($($warnings.Count) chequeo(s) con problema). La instalacion NO se detuvo."
  Write-Host "  Sugerencias:" -ForegroundColor Yellow
  Write-Host "  1) Cerrar y abrir una terminal nueva para refrescar PATH." -ForegroundColor Yellow
  Write-Host "  2) Si estas en red corporativa, revisar proxy/certificados TLS para npm/npx." -ForegroundColor Yellow
  Write-Host "  3) Fallback: usar @modelcontextprotocol/server-memory en mcp.json si Engram falla." -ForegroundColor Yellow
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
  Write-Info "Servidores MCP declarados: context7, engram"
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

function Copy-KiroAssets {
  param(
    [Parameter(Mandatory = $true)][string]$SourceKiroRoot,
    [Parameter(Mandatory = $true)][string]$TargetRoot,
    [string]$TargetLabel = "usuario"
  )

  $sourceSteering = Join-Path $SourceKiroRoot "steering"
  $sourceSkills = Join-Path $SourceKiroRoot "skills"
  $targetKiroRoot = Join-Path $TargetRoot ".kiro"
  $targetSteering = Join-Path $targetKiroRoot "steering"
  $targetSkills = Join-Path $targetKiroRoot "skills"

  if (-not (Test-Path -LiteralPath $sourceSteering) -or -not (Test-Path -LiteralPath $sourceSkills)) {
    throw "No se encontraron carpetas .kiro/steering y .kiro/skills en el paquete descargado."
  }

  New-Item -ItemType Directory -Path $targetSteering -Force | Out-Null
  New-Item -ItemType Directory -Path $targetSkills -Force | Out-Null

  Copy-Item -Path (Join-Path $sourceSteering "*") -Destination $targetSteering -Recurse -Force
  Copy-Item -Path (Join-Path $sourceSkills "*") -Destination $targetSkills -Recurse -Force

  $skillFiles = Get-ChildItem -Path $targetSkills -Recurse -Filter "SKILL.md" -ErrorAction SilentlyContinue
  $skillCount = @($skillFiles).Count

  Write-Info "Steering y skills sincronizados para $TargetLabel en $targetKiroRoot"
  Write-Info "Skills detectadas en $TargetLabel: $skillCount"
}

function Sync-KiroAssetsFromRepo {
  param(
    [Parameter(Mandatory = $true)][string]$HomePath,
    [string]$WorkspacePath = ""
  )

  $zipUrl = "https://github.com/andersonlugojacome/mcp-kiro-kit/archive/refs/heads/main.zip"
  $tempRoot = Join-Path $env:TEMP "mcpkirokit-assets"
  $zipPath = Join-Path $tempRoot "mcp-kiro-kit-main.zip"
  $extractPath = Join-Path $tempRoot "extracted"

  try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    if (Test-Path -LiteralPath $extractPath) {
      Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Info "Descargando assets de steering/skills desde el repositorio..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    if (-not (Test-Path -LiteralPath $zipPath)) {
      throw "No se pudo descargar el paquete de assets."
    }

    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
    $repoRoot = Join-Path $extractPath "mcp-kiro-kit-main"
    $sourceKiroRoot = Join-Path $repoRoot ".kiro"

    Copy-KiroAssets -SourceKiroRoot $sourceKiroRoot -TargetRoot $HomePath -TargetLabel "usuario"

    if (-not [string]::IsNullOrWhiteSpace($WorkspacePath) -and (Test-Path -LiteralPath $WorkspacePath)) {
      Copy-KiroAssets -SourceKiroRoot $sourceKiroRoot -TargetRoot $WorkspacePath -TargetLabel "workspace"
    }

    return $true
  }
  catch {
    Write-WarnMsg "No se pudieron sincronizar skills/steering completos desde el repo: $($_.Exception.Message)"
    Write-WarnMsg "Se mantiene configuracion base local para no bloquear la instalacion."
    return $false
  }
}

Write-Info "Inicio de instalacion MCP para Kiro (modo usuario local)"
Ensure-ExecutionPolicy
Ensure-Scoop
Ensure-ScoopPackage -CommandName "git" -PackageName "git"
Ensure-ScoopPackage -CommandName "node" -PackageName "nodejs-lts"
Ensure-Npx

$userHome = [Environment]::GetFolderPath("UserProfile")
Ensure-KiroMcpSettings -RootPath $userHome

if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
  if (Test-Path -LiteralPath $WorkspacePath) {
    Ensure-KiroMcpSettings -RootPath $WorkspacePath
  }
  else {
    Write-WarnMsg "WorkspacePath no existe: $WorkspacePath"
  }
}

$assetsSynced = Sync-KiroAssetsFromRepo -HomePath $userHome -WorkspacePath $WorkspacePath
if (-not $assetsSynced) {
  Ensure-KiroBaseContent -HomePath $userHome
}
$settingsFiles = @(
  (Join-Path $userHome ".kiro/settings/mcp.json")
)

if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
  $settingsFiles += (Join-Path $WorkspacePath ".kiro/settings/mcp.json")
}

$memoryServerPackage = Get-MemoryServerPackage -SettingsFiles $settingsFiles
Invoke-McpPreflight -MemoryServerPackage $memoryServerPackage
Write-Info "Listo. Reinicia Kiro para aplicar la configuracion MCP."
