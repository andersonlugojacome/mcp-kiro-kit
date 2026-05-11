[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param(
  [string]$WorkspacePath = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$MCPKiroKitVersion = "1.0.12"
$EngramPackageCanonical = "engram-mcp-server"
$EngramPackageFallback = "@modelcontextprotocol/server-memory"

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnMsg {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-DryRun {
  param([string]$Message)
  Write-Host "[DRYRUN] $Message" -ForegroundColor Magenta
}

function Test-NoOpMode {
  return ($DryRun -or $WhatIfPreference)
}

function Should-Modify {
  param(
    [Parameter(Mandatory = $true)][string]$Target,
    [Parameter(Mandatory = $true)][string]$Action
  )

  if ($DryRun) {
    Write-DryRun "$Action -> $Target"
    return $false
  }

  return $PSCmdlet.ShouldProcess($Target, $Action)
}

function Ensure-ExecutionPolicy {
  $policy = Get-ExecutionPolicy -Scope CurrentUser
  if ($policy -in @("RemoteSigned", "Unrestricted", "AllSigned")) {
    Write-Info "ExecutionPolicy(CurrentUser) ya esta en $policy"
    return
  }

  Write-Info "Ajustando ExecutionPolicy(CurrentUser) a RemoteSigned"
  if (-not (Should-Modify -Target "ExecutionPolicy(CurrentUser)" -Action "Set RemoteSigned")) {
    return
  }

  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

function Ensure-Scoop {
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Info "Scoop ya esta instalado"
    return
  }

  Write-Info "Instalando Scoop (modo usuario local)"
  if (-not (Should-Modify -Target "Scoop" -Action "Install via https://get.scoop.sh")) {
    return
  }

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
  if (-not (Should-Modify -Target $PackageName -Action "scoop install")) {
    return
  }

  scoop install $PackageName
  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw "No se pudo validar $CommandName despues de instalar $PackageName."
  }
}

function Ensure-Npx {
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    if (Test-NoOpMode) {
      Write-DryRun "npx no esta disponible en PATH actual; en instalacion real se validaria despues de instalar nodejs-lts."
      return
    }

    throw "npx no esta disponible. Verifica nodejs-lts."
  }

  if (Test-NoOpMode) {
    Write-DryRun "Validaria npx con 'cmd /c npx --version'."
    return
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
        if ($null -eq $server) {
          continue
        }

        if ($server.command -eq "engram") {
          return "engram-binary"
        }

        if ($null -eq $server.args) {
          continue
        }

        foreach ($arg in @($server.args)) {
          if ($arg -eq "@gentleman-programming/engram-mcp-server") {
            return $EngramPackageCanonical
          }

          if ($arg -eq "engram-mcp-server") {
            return $EngramPackageCanonical
          }

          if ($arg -eq "@modelcontextprotocol/server-memory") {
            return $EngramPackageFallback
          }
        }
      }
    }
    catch {
      Write-WarnMsg "No se pudo leer $settingsFile para detectar memory server: $($_.Exception.Message)"
    }
  }

  return $EngramPackageCanonical
}

function New-EngramBinaryServerConfig {
  return @{
    command = "engram"
    args = @("mcp")
  }
}

function New-EngramNpxServerConfig {
  return @{
    command = "cmd"
    args = @("/c", "npx", "-y", $EngramPackageCanonical)
  }
}

function New-MemoryFallbackServerConfig {
  return @{
    command = "cmd"
    args = @("/c", "npx", "-y", $EngramPackageFallback)
  }
}

function Get-EngramMcpServerConfig {
  if (Get-Command engram -ErrorAction SilentlyContinue) {
    Write-Info "Engram MCP: se detecto binario 'engram' en PATH; usando command='engram', args=['mcp']."
    return [ordered]@{
      Name = "engram"
      Config = (New-EngramBinaryServerConfig)
      FallbackApplied = $false
    }
  }

  if (Test-NoOpMode) {
    Write-DryRun "No se ejecuta 'npx -y $EngramPackageCanonical --help'; podria descargar/cachear paquetes. Se simula ruta Engram via npx."
    return [ordered]@{
      Name = "engram"
      Config = (New-EngramNpxServerConfig)
      FallbackApplied = $false
    }
  }

  Write-Info "Engram MCP: no se detecto binario 'engram'; probando paquete npm '$EngramPackageCanonical'."
  if (Test-EngramServer -PackageName $EngramPackageCanonical) {
    Write-Info "Engram MCP: paquete npm '$EngramPackageCanonical' disponible; usando npx."
    return [ordered]@{
      Name = "engram"
      Config = (New-EngramNpxServerConfig)
      FallbackApplied = $false
    }
  }

  Write-WarnMsg "Engram MCP: fallo paquete npm '$EngramPackageCanonical'; degradando a '$EngramPackageFallback'."
  return [ordered]@{
    Name = "memory"
    Config = (New-MemoryFallbackServerConfig)
    FallbackApplied = $true
  }
}

function Get-EngramDbPaths {
  param([string]$HomePath)

  $primaryDir = Join-Path $HomePath ".engram"
  $candidates = @(
    $primaryDir,
    (Join-Path $HomePath ".kiro/engram"),
    (Join-Path $HomePath ".config/engram")
  )

  $detected = $null
  foreach ($candidate in $candidates) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
      continue
    }

    $dbFile = Join-Path $candidate "engram.db"
    $walFile = Join-Path $candidate "engram.db-wal"
    $shmFile = Join-Path $candidate "engram.db-shm"
    if ((Test-Path -LiteralPath $dbFile) -or (Test-Path -LiteralPath $walFile) -or (Test-Path -LiteralPath $shmFile)) {
      $detected = $candidate
      break
    }
  }

  return [ordered]@{
    PrimaryDir = $primaryDir
    DetectedDir = $detected
  }
}

function Backup-EngramDb {
  param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$HomePath
  )

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupRoot = Join-Path $HomePath ".kiro/backups/engram"
  $backupDir = Join-Path $backupRoot $stamp
  if (-not (Should-Modify -Target $backupDir -Action "Create Engram DB backup from $SourceDir")) {
    return $backupDir
  }

  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  Copy-Item -Path (Join-Path $SourceDir "*") -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue
  Write-Info "Backup Engram creado: $backupDir"
  return $backupDir
}

function Backup-KiroRoot {
  param([Parameter(Mandatory = $true)][string]$HomePath)

  $kiroRoot = Join-Path $HomePath ".kiro"
  if (-not (Test-Path -LiteralPath $kiroRoot -PathType Container)) {
    Write-Info "No existe $kiroRoot; no hay backup completo de .kiro para crear."
    return $null
  }

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backupRoot = Join-Path $kiroRoot "backups/full"
  $backupDir = Join-Path $backupRoot $stamp
  $stagingRoot = Join-Path $env:TEMP "mcpkirokit-kiro-backup"
  $stagingDir = Join-Path $stagingRoot $stamp

  if (-not (Should-Modify -Target $backupDir -Action "Create full .kiro backup excluding previous backups")) {
    return $backupDir
  }

  if (Test-Path -LiteralPath $stagingDir) {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

  foreach ($item in Get-ChildItem -LiteralPath $kiroRoot -Force -ErrorAction SilentlyContinue) {
    if ($item.Name -eq "backups") {
      continue
    }

    Copy-Item -LiteralPath $item.FullName -Destination $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  Copy-Item -Path (Join-Path $stagingDir "*") -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

  Write-Info "Backup completo de .kiro creado: $backupDir"
  Write-Info "Nota: se excluyo .kiro/backups para evitar recursion de backups."
  return $backupDir
}

function Prepare-EngramDbForCanonical {
  param(
    [string]$DetectedDir,
    [Parameter(Mandatory = $true)][string]$PrimaryDir
  )

  if ([string]::IsNullOrWhiteSpace($DetectedDir)) {
    Write-Info "No se detecto DB previa de Engram. Se continuara con DB limpia en $PrimaryDir"
    return
  }

  if ($DetectedDir -eq $PrimaryDir) {
    Write-Info "DB Engram detectada y reutilizada in-place: $DetectedDir"
    return
  }

  if (-not (Should-Modify -Target $PrimaryDir -Action "Copy Engram DB from $DetectedDir")) {
    return
  }

  New-Item -ItemType Directory -Path $PrimaryDir -Force | Out-Null
  Copy-Item -Path (Join-Path $DetectedDir "*") -Destination $PrimaryDir -Recurse -Force -ErrorAction SilentlyContinue
  Write-Info "DB Engram migrada para linea canonica: $DetectedDir -> $PrimaryDir"
}

function Test-EngramServer {
  param([Parameter(Mandatory = $true)][string]$PackageName)

  if (Test-NoOpMode) {
    Write-DryRun "Probaria paquete MCP con 'cmd /c npx -y $PackageName --help'."
    return $true
  }

  $job = Start-Job -ScriptBlock {
    param($InnerPackageName)
    $ErrorActionPreference = "Stop"
    & cmd /c "npx -y $InnerPackageName --help"
    if ($LASTEXITCODE -ne 0) {
      throw "El proceso devolvio codigo $LASTEXITCODE"
    }
  } -ArgumentList $PackageName

  try {
    $completed = Wait-Job -Job $job -Timeout 30
    if (-not $completed) {
      Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
      return $false
    }

    if ($job.State -eq "Failed") {
      return $false
    }

    Receive-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
    return $true
  }
  finally {
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null
  }
}

function Show-RestoreGuidance {
  param(
    [string]$KiroBackupDir,
    [string]$EngramBackupDir,
    [string]$DetectedDir,
    [Parameter(Mandatory = $true)][string]$PrimaryDir,
    [switch]$FallbackApplied
  )

  if (-not $FallbackApplied) {
    return
  }

  Write-WarnMsg "Modo degradado: se uso '$EngramPackageFallback' porque Engram no quedo disponible."

  if (-not [string]::IsNullOrWhiteSpace($KiroBackupDir)) {
    Write-WarnMsg "Backup completo .kiro conservado en $KiroBackupDir"
    Write-Host "  Restaurar .kiro completo:" -ForegroundColor Yellow
    Write-Host "  `$restoreStaging = Join-Path `$env:TEMP 'mcpkirokit-restore-kiro'" -ForegroundColor Yellow
    Write-Host "  if (Test-Path `$restoreStaging) { Remove-Item `$restoreStaging -Recurse -Force }" -ForegroundColor Yellow
    Write-Host "  New-Item -ItemType Directory -Path `$restoreStaging -Force | Out-Null" -ForegroundColor Yellow
    Write-Host "  Copy-Item -Path '$KiroBackupDir\*' -Destination `$restoreStaging -Recurse -Force" -ForegroundColor Yellow
    Write-Host "  if (Test-Path \"`$env:USERPROFILE\.kiro\") { Remove-Item \"`$env:USERPROFILE\.kiro\" -Recurse -Force }" -ForegroundColor Yellow
    Write-Host "  New-Item -ItemType Directory -Path \"`$env:USERPROFILE\.kiro\" -Force | Out-Null" -ForegroundColor Yellow
    Write-Host "  Copy-Item -Path (Join-Path `$restoreStaging '*') -Destination \"`$env:USERPROFILE\.kiro\" -Recurse -Force" -ForegroundColor Yellow
  }

  if (-not [string]::IsNullOrWhiteSpace($EngramBackupDir)) {
    Write-WarnMsg "Backup Engram conservado en $EngramBackupDir"
    Write-Host "  Restaurar Engram en path canonico:" -ForegroundColor Yellow
    Write-Host "  New-Item -ItemType Directory -Path '$PrimaryDir' -Force | Out-Null" -ForegroundColor Yellow
    Write-Host "  Copy-Item -Path '$EngramBackupDir\*' -Destination '$PrimaryDir' -Recurse -Force" -ForegroundColor Yellow
    if (-not [string]::IsNullOrWhiteSpace($DetectedDir) -and $DetectedDir -ne $PrimaryDir) {
      Write-Host "  Restaurar Engram en path previo:" -ForegroundColor Yellow
      Write-Host "  New-Item -ItemType Directory -Path '$DetectedDir' -Force | Out-Null" -ForegroundColor Yellow
      Write-Host "  Copy-Item -Path '$EngramBackupDir\*' -Destination '$DetectedDir' -Recurse -Force" -ForegroundColor Yellow
    }
  }
}

function Invoke-PreflightNpxPackage {
  param(
    [Parameter(Mandatory = $true)][string]$PackageName,
    [Parameter(Mandatory = $true)][string]$CheckLabel,
    [int]$TimeoutSeconds = 25
  )

  if (Test-NoOpMode) {
    Write-DryRun "Preflight ${CheckLabel}: ejecutaria 'cmd /c npx -y $PackageName --help' con timeout de $TimeoutSeconds s."
    return $true
  }

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

function Invoke-PreflightEngramBinary {
  param([int]$TimeoutSeconds = 25)

  if (Test-NoOpMode) {
    Write-DryRun "Preflight Engram binario: ejecutaria 'engram mcp --help' con timeout de $TimeoutSeconds s."
    return $true
  }

  $job = Start-Job -ScriptBlock {
    $ErrorActionPreference = "Stop"
    & engram mcp --help *> $null
    if ($LASTEXITCODE -ne 0) {
      throw "El proceso devolvio codigo $LASTEXITCODE"
    }
  }

  try {
    $completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
    if (-not $completed) {
      Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
      Write-WarnMsg "Preflight Engram binario: WARN (timeout de $TimeoutSeconds s)"
      return $false
    }

    if ($job.State -eq "Failed") {
      $jobError = Receive-Job -Job $job -ErrorAction SilentlyContinue
      if ([string]::IsNullOrWhiteSpace("$jobError")) {
        $jobError = $job.ChildJobs[0].JobStateInfo.Reason.Message
      }

      Write-WarnMsg "Preflight Engram binario: WARN ($jobError)"
      return $false
    }

    Receive-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
    Write-Info "Preflight Engram binario: OK"
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
    if (Test-NoOpMode) {
      Write-DryRun "Preflight node: validaria 'cmd /c node --version'."
      Write-Info "Preflight node: SKIP (DryRun/WhatIf)"
    }
    else {
      & cmd /c node --version *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Info "Preflight node: OK"
      }
      else {
        Write-WarnMsg "Preflight node: WARN (node no responde correctamente)"
        $warnings.Add("node") | Out-Null
      }
    }
  }
  else {
    Write-WarnMsg "Preflight node: WARN (node no encontrado en PATH de esta sesion)"
    $warnings.Add("node") | Out-Null
  }

  if (Get-Command npx -ErrorAction SilentlyContinue) {
    if (Test-NoOpMode) {
      Write-DryRun "Preflight npx: validaria 'cmd /c npx --version'."
      Write-Info "Preflight npx: SKIP (DryRun/WhatIf)"
    }
    else {
      & cmd /c npx --version *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Info "Preflight npx: OK"
      }
      else {
        Write-WarnMsg "Preflight npx: WARN (npx no responde correctamente)"
        $warnings.Add("npx") | Out-Null
      }
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

  if ($MemoryServerPackage -eq "engram-binary") {
    $memoryOk = Invoke-PreflightEngramBinary
  }
  else {
    $memoryOk = Invoke-PreflightNpxPackage -PackageName $MemoryServerPackage -CheckLabel "memory server ($MemoryServerPackage)"
  }
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
  $memoryRoute = Get-EngramMcpServerConfig

  $desired = @{
    mcpServers = @{
      context7 = @{
        command = "cmd"
        args = @("/c", "npx", "-y", "@upstash/context7-mcp")
      }
    }
  }

  $desired.mcpServers[$memoryRoute["Name"]] = $memoryRoute["Config"]

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
  if ($memoryRoute["Name"] -eq "engram" -and $existing["mcpServers"] -is [hashtable]) {
    $existing["mcpServers"].Remove("memory") | Out-Null
  }
  elseif ($memoryRoute["Name"] -eq "memory" -and $existing["mcpServers"] -is [hashtable]) {
    $existing["mcpServers"].Remove("engram") | Out-Null
  }

  $json = $existing | ConvertTo-Json -Depth 20
  if (-not (Should-Modify -Target $settingsFile -Action "Write MCP settings")) {
    Write-Info "MCP quedaria configurado en $settingsFile"
    Write-Info "Servidores MCP declarados: context7, $($memoryRoute["Name"])"
    return $memoryRoute
  }

  New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
  Set-Content -LiteralPath $settingsFile -Value $json -Encoding UTF8
  Write-Info "MCP configurado en $settingsFile"
  Write-Info "Servidores MCP declarados: context7, $($memoryRoute["Name"])"
  return $memoryRoute
}

function Ensure-KiroBaseContent {
  param([string]$HomePath)

  $steeringDir = Join-Path $HomePath ".kiro/steering"
  $skillDir = Join-Path $HomePath ".kiro/skills"
  if (-not (Should-Modify -Target (Join-Path $HomePath ".kiro") -Action "Create base steering and skills content")) {
    return
  }

  New-Item -ItemType Directory -Path $steeringDir -Force | Out-Null
  New-Item -ItemType Directory -Path $skillDir -Force | Out-Null

  $agentsPath = Join-Path $steeringDir "AGENTS.md"
  if (-not (Test-Path -LiteralPath $agentsPath)) {
    @'
# Kiro AGENTS (MCP + Verificacion)

## Rules
- NEVER add "Co-Authored-By" or any AI attribution to commits. Use conventional commits format only.
- Never build after changes.
- When asking user a question, STOP and wait for response. Never continue or assume answers.
- Never agree with user claims without verification. Say "dejame verificar" and check code/docs first.
- If user is wrong, explain WHY with evidence. If you were wrong, acknowledge with proof.
- Always propose alternatives with tradeoffs when relevant.
- Verify technical claims before stating them. If unsure, investigate first.

## Personality
Senior Architect, 15+ years experience, GDE & MVP. Passionate teacher who genuinely wants people to learn and grow.

## Reuso Inteligente (Engram + Context7)
- En cada consulta del usuario, consultar Engram primero para recuperar contexto relevante.
- Refrescar Context7 cada 4 consultas de usuario o antes si hay incertidumbre tecnica.

## Politica de Seguridad
- Nunca escribas API keys en `.kiro/settings/mcp.json` ni en steering.
- Usa variables de entorno para credenciales cuando un server lo requiera.

## Verificacion Tecnica Obligatoria
1. Confirmar prerequisitos (`git`, `node`, `npx`).
2. Validar JSON antes de guardar configuraciones.
3. Probar comandos MCP con `npx -y <paquete> --help` (en Windows puede usarse `cmd /c` como wrapper).
4. Informar resultado con estado claro: OK, warning o bloqueo.
'@ | Set-Content -LiteralPath $agentsPath -Encoding UTF8
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

  if (-not (Should-Modify -Target $targetKiroRoot -Action "Copy steering and skills for $TargetLabel")) {
    return
  }

  New-Item -ItemType Directory -Path $targetSteering -Force | Out-Null
  New-Item -ItemType Directory -Path $targetSkills -Force | Out-Null

  Copy-Item -Path (Join-Path $sourceSteering "*") -Destination $targetSteering -Recurse -Force
  Copy-Item -Path (Join-Path $sourceSkills "*") -Destination $targetSkills -Recurse -Force

  $legacySharedSkillPath = Join-Path $targetSkills "_shared/SKILL.md"
  if (Test-Path -LiteralPath $legacySharedSkillPath) {
    Remove-Item -LiteralPath $legacySharedSkillPath -Force -ErrorAction SilentlyContinue
    Write-Info "Removido archivo legado no valido: $legacySharedSkillPath"
  }

  $skillFiles = Get-ChildItem -Path $targetSkills -Recurse -Filter "SKILL.md" -ErrorAction SilentlyContinue
  $skillCount = @($skillFiles).Count

  Write-Info "Steering y skills sincronizados para $TargetLabel en $targetKiroRoot"
  Write-Info "Skills detectadas en ${TargetLabel}: $skillCount"
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

  if (-not (Should-Modify -Target $tempRoot -Action "Download and sync steering/skills assets from $zipUrl")) {
    Write-DryRun "Copiaria steering/skills a $HomePath\.kiro y, si existe, al WorkspacePath '$WorkspacePath'."
    return $true
  }

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
    $sourceUpdateChecker = Join-Path $repoRoot "check-mcpkirokit-update.ps1"
    $targetToolsDir = Join-Path $HomePath ".kiro/tools"
    $targetUpdateChecker = Join-Path $targetToolsDir "check-mcpkirokit-update.ps1"

    Copy-KiroAssets -SourceKiroRoot $sourceKiroRoot -TargetRoot $HomePath -TargetLabel "usuario"

    if (Test-Path -LiteralPath $sourceUpdateChecker) {
      New-Item -ItemType Directory -Path $targetToolsDir -Force | Out-Null
      Copy-Item -LiteralPath $sourceUpdateChecker -Destination $targetUpdateChecker -Force
      Write-Info "Checker de actualizaciones instalado en $targetUpdateChecker"
    }

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

function Save-InstallMetadata {
  param(
    [Parameter(Mandatory = $true)][string]$HomePath,
    [Parameter(Mandatory = $true)][string]$InstalledVersion
  )

  $metaPath = Join-Path $HomePath ".kiro/mcpkirokit-install.json"
  $meta = [ordered]@{
    installedVersion = $InstalledVersion
    installedAt = (Get-Date).ToString("o")
  }

  if (-not (Should-Modify -Target $metaPath -Action "Write install metadata")) {
    return
  }

  $meta | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $metaPath -Encoding UTF8
  Write-Info "Version instalada registrada en $metaPath"
}

function Invoke-DailyUpdateNotice {
  param(
    [Parameter(Mandatory = $true)][string]$HomePath,
    [Parameter(Mandatory = $true)][string]$InstalledVersion
  )

  $checkerPath = Join-Path $HomePath ".kiro/tools/check-mcpkirokit-update.ps1"
  if (-not (Test-Path -LiteralPath $checkerPath)) {
    return
  }

  if (-not (Should-Modify -Target $checkerPath -Action "Run daily update notice")) {
    return
  }

  try {
    & powershell -ExecutionPolicy RemoteSigned -File $checkerPath -InstalledVersion $InstalledVersion -QuietIfCheckedToday
  }
  catch {
    Write-WarnMsg "No se pudo ejecutar el chequeo diario de actualizacion: $($_.Exception.Message)"
  }
}

function Show-KiroCliStatus {
  $kiroCli = Get-Command kiro-cli -ErrorAction SilentlyContinue
  $kiro = Get-Command kiro -ErrorAction SilentlyContinue

  if ($null -ne $kiroCli) {
    Write-Info "Kiro CLI detectado: kiro-cli ($($kiroCli.Source))"
    return
  }

  if ($null -ne $kiro) {
    Write-Info "Comando Kiro detectado: kiro ($($kiro.Source))"
    Write-WarnMsg "En Windows puede no estar disponible el binario kiro-cli oficial. Usa 'kiro'."
    return
  }

  Write-WarnMsg "No se detecto comando Kiro en PATH (comandos probados: kiro-cli, kiro)."
  Write-WarnMsg "Verifica instalacion de Kiro y abre una terminal nueva para refrescar PATH."
}

Write-Info "Inicio de instalacion MCP para Kiro (modo usuario local)"
if ($DryRun) {
  Write-DryRun "Simulacion activa: se permiten detecciones read-only, pero no escrituras, descargas, instalaciones ni comandos externos de prueba."
}
elseif ($WhatIfPreference) {
  Write-Info "WhatIf activo: PowerShell mostrara acciones modificadoras sin ejecutarlas."
}
Ensure-ExecutionPolicy
Ensure-Scoop
Ensure-ScoopPackage -CommandName "git" -PackageName "git"
Ensure-ScoopPackage -CommandName "node" -PackageName "nodejs-lts"
Ensure-Npx

$userHome = [Environment]::GetFolderPath("UserProfile")
$dbPaths = Get-EngramDbPaths -HomePath $userHome
$backupDir = $null
if (-not [string]::IsNullOrWhiteSpace($dbPaths.DetectedDir)) {
  Write-Info "DB Engram detectada: $($dbPaths.DetectedDir)"
  $backupDir = Backup-EngramDb -SourceDir $dbPaths.DetectedDir -HomePath $userHome
}
Prepare-EngramDbForCanonical -DetectedDir $dbPaths.DetectedDir -PrimaryDir $dbPaths.PrimaryDir

$kiroBackupDir = Backup-KiroRoot -HomePath $userHome
$memoryRoute = Ensure-KiroMcpSettings -RootPath $userHome
Show-RestoreGuidance -KiroBackupDir $kiroBackupDir -EngramBackupDir $backupDir -DetectedDir $dbPaths.DetectedDir -PrimaryDir $dbPaths.PrimaryDir -FallbackApplied:([bool]$memoryRoute["FallbackApplied"])

if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
  if (Test-Path -LiteralPath $WorkspacePath) {
    Ensure-KiroMcpSettings -RootPath $WorkspacePath | Out-Null
  }
  else {
    Write-WarnMsg "WorkspacePath no existe: $WorkspacePath"
  }
}

$assetsSynced = Sync-KiroAssetsFromRepo -HomePath $userHome -WorkspacePath $WorkspacePath
if (-not $assetsSynced) {
  Ensure-KiroBaseContent -HomePath $userHome
}

Save-InstallMetadata -HomePath $userHome -InstalledVersion $MCPKiroKitVersion
Invoke-DailyUpdateNotice -HomePath $userHome -InstalledVersion $MCPKiroKitVersion

$settingsFiles = @(
  (Join-Path $userHome ".kiro/settings/mcp.json")
)

if (-not [string]::IsNullOrWhiteSpace($WorkspacePath)) {
  $settingsFiles += (Join-Path $WorkspacePath ".kiro/settings/mcp.json")
}

$memoryServerPackage = Get-MemoryServerPackage -SettingsFiles $settingsFiles
Invoke-McpPreflight -MemoryServerPackage $memoryServerPackage
Show-KiroCliStatus
if (Test-NoOpMode) {
  Write-Info "Simulacion finalizada. No se aplicaron cambios; no hace falta reiniciar Kiro por esta ejecucion."
}
else {
  Write-Info "Listo. Reinicia Kiro para aplicar la configuracion MCP."
}
