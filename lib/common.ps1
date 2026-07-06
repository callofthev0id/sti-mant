# lib/common.ps1 - helpers puros (Pester) + collectors WMI (Windows-only) + manifiestos.
# Sin estado global; las funciones puras no tocan WMI/red.

# ---- Manifiesto de checks (orden = planilla-builder/src/column-spec.mjs). El TSV emite en este orden. ----
$script:CHK_ORDER_TERM = @(
  'chk_cuentas_sti','chk_firewall','chk_antivirus_eset','chk_updates','chk_reinicio_pendiente',
  'chk_visor_eventos','chk_ultimo_reinicio','chk_restaurar_vss','chk_inicio_no_deseado','chk_software_terceros',
  'chk_disco_smart','chk_espacio_disco','chk_ram','chk_hardware_visual','chk_perifericos','chk_ups','chk_bateria',
  'chk_conectividad','chk_teamviewer','chk_recursos_compartidos','chk_rdp','chk_wifi',
  'chk_ocs','chk_backup_cobian','chk_cloud_sync','chk_limpieza_temp'
)
$script:CHK_ORDER_SRV = @(
  'srv_cuentas_sti','srv_firewall','srv_antivirus_eset','srv_updates','srv_rdp',
  'srv_visor_eventos','srv_ultimo_reinicio','srv_vss','srv_disco_smart','srv_espacio_disco','srv_backup',
  'srv_ocs','srv_teamviewer','srv_encendido_auto','srv_apagado_auto','srv_servicios_rol','srv_vms',
  'srv_conectividad','srv_recursos_compartidos'
)
$script:SEM = @('Ok','Advertencia','Error','Crítico','N/A')
$script:SCRIPT_VERSION = '1.1.1'
# Cuentas admin estándar que se esperan en cada equipo gestionado.
# No se hardcodean nombres en el repo público: se leen de entorno o de un archivo
# local no versionado (sti-cuentas.local, una cuenta por línea). Si no hay fuente,
# la lista queda vacía y el check de cuentas admin degrada (no expone usernames internos).
function Get-CuentasAdmin {
  param([string]$LocalFile = (Join-Path $PSScriptRoot 'sti-cuentas.local'))
  $cuentas = @()
  # 1) Variable de entorno STI_CUENTAS_ADMIN: separadas por coma o punto y coma.
  if ($env:STI_CUENTAS_ADMIN) {
    $cuentas = @($env:STI_CUENTAS_ADMIN -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  }
  # 2) Archivo local opcional (gitignored): una cuenta por línea, '#' = comentario.
  if (-not $cuentas -and $LocalFile -and (Test-Path -LiteralPath $LocalFile)) {
    try {
      $cuentas = @(Get-Content -LiteralPath $LocalFile -ErrorAction Stop |
                   ForEach-Object { $_.Trim() } |
                   Where-Object { $_ -and -not $_.StartsWith('#') })
    } catch {}
  }
  @($cuentas)
}
$script:STI_CUENTAS_ADMIN = Get-CuentasAdmin

# ---- PURAS ----

# Normaliza una MAC: hex uppercase, separador ':'. Devuelve $null si <12 hex o es MAC virtual.
function Get-NormalizedMac {
  param([string]$Raw)
  if (-not $Raw) { return $null }
  $h = ($Raw -replace '[^0-9A-Fa-f]', '').ToUpper()
  if ($h.Length -lt 12) { return $null }
  $h = $h.Substring(0, 12)
  $virt = @('000C29','005056','00155D','080027','525400','001C42','00090F','000000','FFFFFF')
  if ($virt -contains $h.Substring(0, 6)) { return $null }
  (0..5 | ForEach-Object { $h.Substring($_ * 2, 2) }) -join ':'
}

# Limpia un serial: trim/upper. Devuelve $null si es basura OEM o <=4 chars.
function Get-CleanSerial {
  param([string]$Raw)
  if (-not $Raw) { return $null }
  $s = $Raw.Trim().ToUpper()
  $junk = @('DEFAULT STRING','TO BE FILLED BY O.E.M.','SYSTEM SERIAL NUMBER','NONE','N/A','-','.','0')
  if ($junk -contains $s) { return $null }
  if ($s.Length -le 4) { return $null }
  $s
}

# Clasifica el SO desde el Caption de Win32_OperatingSystem.
function Get-OsClass {
  param([string]$Caption)
  if (-not $Caption) { return 'Otro' }
  if ($Caption -match 'Server')      { return 'Server' }
  if ($Caption -match 'Windows 11')  { return 'Win11' }
  if ($Caption -match 'Windows 10')  { return 'Win10' }
  if ($Caption -match 'Windows 8')   { return 'Win8' }
  if ($Caption -match 'Windows 7')   { return 'Win7' }
  return 'Otro'
}

# Escapa texto para insertar en HTML (contenido o atributos). Fuente única usada por los renderers.
function ConvertTo-HtmlSafe {
  param([string]$s)
  ([string]$s) -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&#39;'
}

# Item del contrato de módulo.
function New-CheckItem {
  param([string]$Key, [string]$Label, [string]$Status = 'N/A',
        [bool]$Automated = $true, [string]$Detail = '', $RawData = $null)
  @{ key = $Key; label = $Label; status = $Status; automated = $Automated; detail = $Detail; rawData = $RawData }
}

# ---- OCS Inventory NG (estado del agente + último inventario enviado) ----

# PURO: parsea el último timestamp de un log del agente OCS. El agente loguea líneas tipo
# "Mon Jun 09 03:00:01 2026 => Inventory sent" o variantes con fecha ISO. Devuelve [datetime] o $null.
function Get-OcsLastInventoryFromLog {
  param([string]$Text)
  if (-not $Text) { return $null }
  $cands = @()
  # Formato ISO: 2026-06-09 03:00:01
  foreach ($m in [regex]::Matches($Text, '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})')) {
    try { $cands += [datetime]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) } catch {}
  }
  # Formato C runtime: "Mon Jun 09 03:00:01 2026". Ignoramos el día de la semana (ddd) porque
  # ParseExact lo valida contra la fecha y algunos logs lo traen inconsistente; parseamos el resto.
  foreach ($m in [regex]::Matches($Text, '[A-Z][a-z]{2} ([A-Z][a-z]{2} +\d{1,2} \d{2}:\d{2}:\d{2} \d{4})')) {
    $rest = $m.Groups[1].Value -replace ' +', ' '
    foreach ($fmt in @('MMM d HH:mm:ss yyyy', 'MMM dd HH:mm:ss yyyy')) {
      try { $cands += [datetime]::ParseExact($rest, $fmt, [Globalization.CultureInfo]::InvariantCulture); break } catch {}
    }
  }
  if ($cands.Count -eq 0) { return $null }
  ($cands | Sort-Object -Descending | Select-Object -First 1)
}

# Collector (Windows-only): estado de instalación OCS + fecha del último inventario.
# Cruza servicio, registro (HKLM Software\OCS Inventory NG\Agent) y logs en ProgramData.
# Devuelve @{ installed; service; status; lastInventory([datetime]o$null); logsDir }.
function Get-OcsInventoryStatus {
  $svc = Get-Service -ErrorAction SilentlyContinue |
         Where-Object { $_.Name -match 'OCS' -or $_.DisplayName -match 'OCS Inventory' } | Select-Object -First 1
  $logsDir = $null
  foreach ($p in @("$env:ProgramData\OCS Inventory NG\Agent", "$env:ALLUSERSPROFILE\OCS Inventory NG\Agent")) {
    if ($p -and (Test-Path -LiteralPath $p)) { $logsDir = $p; break }
  }
  $last = $null
  # 1) Registro: la clave del agente suele guardar TTO_WAIT / last run; intentamos LastRun-ish.
  foreach ($rk in @('HKLM:\SOFTWARE\OCS Inventory NG\Agent', 'HKLM:\SOFTWARE\WOW6432Node\OCS Inventory NG\Agent')) {
    try {
      $p = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
      if ($p) {
        foreach ($prop in @('LastRun','LastInventory','TTO_WAIT')) {
          if ($p.PSObject.Properties.Name -contains $prop -and $p.$prop) {
            try { $dt = [datetime]$p.$prop; if ($dt -gt [datetime]'2000-01-01') { $last = $dt } } catch {}
          }
        }
      }
    } catch {}
  }
  # 2) Logs: parsear el más reciente.
  if (-not $last -and $logsDir) {
    try {
      $f = Get-ChildItem -Path $logsDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($f) {
        $txt = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        $last = Get-OcsLastInventoryFromLog $txt
        if (-not $last) { $last = $f.LastWriteTime }
      }
    } catch {}
  }
  @{ installed = [bool]$svc; service = $(if ($svc) { $svc.Name } else { $null })
     status = $(if ($svc) { [string]$svc.Status } else { $null })
     lastInventory = $last; logsDir = $logsDir }
}

# ---- COLLECTORS (WMI/CIM, Windows-only; no testeables en Linux) ----

function Get-OsInfo {
  $os = Get-CimInstance Win32_OperatingSystem
  @{ caption = $os.Caption; version = $os.Version; lastBoot = $os.LastBootUpTime;
     install = $os.InstallDate; class = (Get-OsClass $os.Caption) }
}

# laptop|desktop|server|vm + flags hyperv host.
function Get-FormFactor {
  $enc = @(Get-CimInstance Win32_SystemEnclosure | ForEach-Object { $_.ChassisTypes })
  $cs  = Get-CimInstance Win32_ComputerSystem
  $laptop = $enc | Where-Object { @(8,9,10,11,12,14,18,21,30,31,32) -contains $_ }
  $server = $enc | Where-Object { @(17,23,28,29) -contains $_ }
  $isVm = ($cs.Model -match 'Virtual|VMware|KVM|VirtualBox') -or ($cs.Manufacturer -match 'VMware|Microsoft Corporation.*Virtual|innotek|QEMU')
  $ff = 'desktop'
  if ($laptop) { $ff = 'laptop' } elseif ($server) { $ff = 'server' }
  if ($isVm) { $ff = 'vm' }
  $hypervHost = $false
  try { $hypervHost = (Get-Service vmms -ErrorAction SilentlyContinue).Status -eq 'Running' } catch {}
  @{ formFactor = $ff; isVm = [bool]$isVm; hypervHost = [bool]$hypervHost; model = $cs.Model }
}

# Emite TODOS los hardware-ids. Prioridad de cruce (consumidor): hw_uuid -> disk_serial -> bios_serial -> mac -> hostname.
function Get-HardwareIds {
  $osUuid = $null
  try { $osUuid = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid } catch {}
  # Serial de TODOS los discos fijos (no solo el primero): mas huellas para el cruce de identidad.
  # Get-CleanSerial limpia y descarta basura OEM; Where-Object filtra los nulos resultantes.
  $diskSerial = @()
  try {
    $diskSerial = @(Get-CimInstance Win32_DiskDrive | Where-Object { $_.MediaType -match 'Fixed' } |
                    ForEach-Object { Get-CleanSerial $_.SerialNumber } | Where-Object { $_ })
  } catch {}
  $biosSerial = $null
  try { $biosSerial = Get-CleanSerial ((Get-CimInstance Win32_BIOS).SerialNumber) } catch {}
  $hwUuid = $null
  try { $hwUuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID } catch {}
  $macs = @()
  try {
    $macs = @(Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true -and $_.MACAddress } |
              ForEach-Object { Get-NormalizedMac $_.MACAddress } | Where-Object { $_ })
  } catch {}
  @{ os_uuid = $osUuid; disk_serial = $diskSerial; hw_uuid = $hwUuid;
     mac = $macs; bios_serial = $biosSerial; hostname = $env:COMPUTERNAME }
}
