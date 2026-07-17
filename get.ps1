# get.ps1 - bootstrap remoto de Fleet Maintenance Toolkit (interfaz grafica).
# Uso en cualquier equipo Windows, desde PowerShell:
#   irm https://raw.githubusercontent.com/callofthev0id/sti-mant/main/get.ps1 | iex
#
# Que hace: descarga la ultima version publicada (latest release) de fleet-gui a una carpeta
# temporal y la abre, auto-elevando (UAC) para que las Utilidades y los checks que leen estado
# del sistema funcionen. La GUI corre en su propio proceso STA (WPF lo exige); este script solo
# resuelve la descarga y el lanzamiento, no carga la GUI en el proceso del pipe.

$ErrorActionPreference = 'Stop'
$repo = 'callofthev0id/sti-mant'

function Write-Paso($t) { Write-Host "[FLEET] $t" -ForegroundColor Green }

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

Write-Paso 'Buscando la ultima version publicada...'
try {
  $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'fleet-mant-bootstrap' }
} catch {
  Write-Host "[FLEET] No se pudo consultar el ultimo release ($($_.Exception.Message))." -ForegroundColor Red
  Write-Host '      Verifica la conexion a internet y volve a intentar.' -ForegroundColor Red
  return
}

# Asset preferido: el dist single-file de la GUI (fleet-gui-v<ver>.ps1).
$asset = @($rel.assets | Where-Object { $_.name -like 'fleet-gui-v*.ps1' }) | Select-Object -First 1
if (-not $asset) {
  Write-Host "[FLEET] El release $($rel.tag_name) no publica el dist de la GUI (fleet-gui-v*.ps1)." -ForegroundColor Red
  return
}

$destino = Join-Path $env:TEMP $asset.name
Write-Paso "Descargando $($asset.name) ($([math]::Round($asset.size/1KB)) KB)..."
try {
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $destino -Headers @{ 'User-Agent' = 'fleet-mant-bootstrap' }
} catch {
  Write-Host "[FLEET] Fallo la descarga ($($_.Exception.Message))." -ForegroundColor Red
  return
}

# Lanzar la GUI en un proceso STA con ExecutionPolicy Bypass. Si la sesion no esta elevada,
# relanzar como administrador (UAC). Las Utilidades mutan el equipo y varios checks necesitan admin.
$psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', $destino)
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if ($esAdmin) {
  Write-Paso 'Abriendo la interfaz grafica...'
  Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs
} else {
  Write-Paso 'Abriendo la interfaz grafica (se pedira elevacion para las Utilidades)...'
  try {
    Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -Verb RunAs
  } catch {
    # El usuario cancelo el UAC: abrir sin elevar (las acciones de Utilidades y algunos checks
    # quedaran limitados, el resto funciona).
    Write-Host '[FLEET] Elevacion cancelada; abriendo sin privilegios de administrador.' -ForegroundColor Yellow
    Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs
  }
}
