param(
  [string]$WorkspacePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-ErrorMsg {
  param([string]$Message)
  Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-WarnMsg {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Set-Utf8Output {
  try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
  }
  catch {
    Write-Info "No se pudo ajustar la codificacion de consola a UTF-8. Continuando."
  }
}

function Enable-Tls12 {
  try {
    $tls12 = [Net.SecurityProtocolType]::Tls12
    if (([Net.ServicePointManager]::SecurityProtocol -band $tls12) -eq 0) {
      [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $tls12
    }
    Write-Info "TLS 1.2 habilitado para descargas HTTPS."
  }
  catch {
    throw "No se pudo habilitar TLS 1.2. Error: $($_.Exception.Message)"
  }
}

function Download-Installer {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  $destDir = Split-Path -Path $Destination -Parent
  if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
  }

  Write-Info "Descargando instalador desde GitHub..."
  try {
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
  }
  catch {
    throw "Fallo la descarga de '$Url'. Verifica conectividad y URL. Error: $($_.Exception.Message)"
  }

  if (-not (Test-Path -LiteralPath $Destination)) {
    throw "La descarga termino sin generar el archivo esperado: $Destination"
  }

  $length = (Get-Item -LiteralPath $Destination).Length
  if ($length -le 0) {
    throw "El archivo descargado esta vacio: $Destination"
  }

  Write-Info "Descarga completada: $Destination ($length bytes)"
}

function Run-Installer {
  param(
    [Parameter(Mandatory = $true)][string]$InstallerPath,
    [string]$WorkspacePathValue = ""
  )

  $args = @(
    "-ExecutionPolicy", "RemoteSigned",
    "-File", $InstallerPath
  )

  if (-not [string]::IsNullOrWhiteSpace($WorkspacePathValue)) {
    $args += @("-WorkspacePath", $WorkspacePathValue)
  }

  Write-Info "Ejecutando instalador descargado..."
  & powershell @args
  if ($LASTEXITCODE -ne 0) {
    throw "El instalador remoto finalizo con codigo de salida $LASTEXITCODE"
  }
}

function Run-VerificationFriendly {
  param(
    [Parameter(Mandatory = $true)][string]$VerifyScriptPath
  )

  if (-not (Test-Path -LiteralPath $VerifyScriptPath)) {
    Write-WarnMsg "No se encontro verify-package.ps1. Se omite verificacion final."
    return
  }

  Write-Info "Ejecutando verificacion final (modo amigable)..."

  $args = @(
    "-ExecutionPolicy", "RemoteSigned",
    "-File", $VerifyScriptPath
  )

  & powershell @args
  if ($LASTEXITCODE -eq 0) {
    Write-Info "Verificacion final: OK"
    return
  }

  Write-WarnMsg "Verificacion final: WARN (codigo $LASTEXITCODE). La instalacion ya quedo aplicada; revisa el detalle mostrado por verify-package.ps1."
}

try {
  Set-Utf8Output
  Enable-Tls12

  $rawUrl = "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/install-mcp-kiro.ps1"
  $verifyUrl = "https://raw.githubusercontent.com/andersonlugojacome/mcp-kiro-kit/main/verify-package.ps1"
  $localInstaller = Join-Path $env:TEMP "install-mcp-kiro.ps1"
  $localVerifyScript = Join-Path $env:TEMP "verify-package.ps1"

  Download-Installer -Url $rawUrl -Destination $localInstaller
  Run-Installer -InstallerPath $localInstaller -WorkspacePathValue $WorkspacePath
  Download-Installer -Url $verifyUrl -Destination $localVerifyScript
  Run-VerificationFriendly -VerifyScriptPath $localVerifyScript

  Write-Info "Instalacion online finalizada correctamente."
}
catch {
  Write-ErrorMsg $_.Exception.Message
  exit 1
}
