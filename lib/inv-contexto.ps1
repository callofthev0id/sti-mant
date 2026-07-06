# lib/inv-contexto.ps1 - contexto/inventario que complementa OCS: red, periféricos,
# último update, y cross-check local de ESET/OCS (confirma vs consola).

# ---- PURA ----
# Decodifica un array uint16 de WmiMonitorID (serial/modelo) a string ASCII.
function ConvertFrom-MonitorBytes {
  param($Arr)
  if (-not $Arr) { return '' }
  -join ($Arr | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ })
}

# ---- COLLECTOR (Windows-only) ----
function Get-InvContexto {
  # Red
  $red = @()
  try {
    $speed = @{}
    try { Get-NetAdapter -ErrorAction Stop | ForEach-Object { $speed[(([string]$_.MacAddress) -replace '-', ':').ToUpper()] = $_.LinkSpeed } } catch {}
    Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction Stop | Where-Object { $_.IPEnabled } | ForEach-Object {
      $mac = (([string]$_.MACAddress) -replace '-', ':').ToUpper()
      $red += [ordered]@{
        adaptador = ([string]$_.Description)
        ip = (@($_.IPAddress) | Where-Object { $_ -match '\.' } | Select-Object -First 1)
        gateway = (@($_.DefaultIPGateway) | Select-Object -First 1)
        dns = (@($_.DNSServerSearchOrder) -join ', ')
        dhcp = [bool]$_.DHCPEnabled
        velocidad = $speed[$mac]
      }
    }
  } catch {}

  # Dominio / workgroup
  $dom = $null
  try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop; $dom = [ordered]@{ dominio = $cs.Domain; enDominio = [bool]$cs.PartOfDomain } } catch {}

  # Periféricos
  $gpu = @(); try { $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object { ([string]$_.Name).Trim() } | Where-Object { $_ }) } catch {}
  $monitores = @()
  try {
    Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorID -ErrorAction Stop | ForEach-Object {
      $monitores += [ordered]@{ fabricante = (ConvertFrom-MonitorBytes $_.ManufacturerName); modelo = (ConvertFrom-MonitorBytes $_.UserFriendlyName); serie = (ConvertFrom-MonitorBytes $_.SerialNumberID) }
    }
  } catch {}
  $impresoras = @()
  try { $impresoras = @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'OneNote|Microsoft (Print|XPS)|Fax|PDF' } | ForEach-Object { ([string]$_.Name).Trim() }) } catch {}

  # Último update instalado
  $ultUpdate = $null
  try {
    $hf = Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($hf) { $ultUpdate = [ordered]@{ id = $hf.HotFixID; fecha = $hf.InstalledOn } }
  } catch {}

  # Cross-check ESET (versión + firmas) - registro
  $eset = $null
  foreach ($k in @('HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\Info', 'HKLM:\SOFTWARE\Wow6432Node\ESET\ESET Security\CurrentVersion\Info')) {
    try {
      $p = Get-ItemProperty $k -ErrorAction Stop
      $eset = [ordered]@{ producto = ([string]$p.ProductName).Trim(); version = ([string]$p.ProductVersion).Trim(); firmas = ([string]$p.ScannerVersion).Trim() }
      break
    } catch {}
  }

  # Cross-check OCS (servicio + última inventario si está en registro)
  $ocs = $null
  try {
    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'OCS' -or $_.DisplayName -match 'OCS' } | Select-Object -First 1
    if ($svc) {
      $last = $null; try { $last = (Get-ItemProperty 'HKLM:\SOFTWARE\OCS Inventory Agent\Agent' -Name LastReport -ErrorAction Stop).LastReport } catch {}
      $ocs = [ordered]@{ servicio = $svc.Status.ToString(); ultimoReporte = $last }
    }
  } catch {}

  [ordered]@{
    red = $red
    dominio = $dom
    gpu = $gpu
    monitores = $monitores
    impresoras = $impresoras
    ultimoUpdate = $ultUpdate
    eset = $eset
    ocs = $ocs
  }
}
