# lib/inv-salud.ps1 - salud/estabilidad para la sección "estado del equipo" del informe:
# BSOD/minidumps, apagados inesperados, servicios auto detenidos, autoruns/tareas, batería.

# ---- PURA ----
# Salud de batería: % = full/design. $null si faltan datos.
function Get-BateriaSaludPct {
  param($DesignmWh, $FullmWh)
  if (-not $DesignmWh -or [int]$DesignmWh -le 0 -or -not $FullmWh) { return $null }
  [math]::Round(([double]$FullmWh / [double]$DesignmWh) * 100, 0)
}

# ---- COLLECTOR (Windows-only) ----
function Get-InvSalud {
  # BSOD / minidumps
  $bsod = [ordered]@{ minidumps = 0; ultimo = $null }
  try {
    $dmps = @(Get-ChildItem 'C:\Windows\Minidump\*.dmp' -ErrorAction SilentlyContinue)
    $bsod.minidumps = $dmps.Count
    if ($dmps.Count) { $bsod.ultimo = ($dmps | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime }
  } catch {}

  # Apagados inesperados (Event 6008) últimos 30 días
  $apagados = 0
  try {
    $desde = (Get-Date).AddDays(-30)
    $apagados = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 6008; StartTime = $desde } -ErrorAction SilentlyContinue).Count
  } catch {}

  # Servicios auto pero detenidos (excluye ruido conocido de arranque retrasado/trigger)
  $svcDet = @()
  try {
    $ruido = 'sppsvc|gupdate|edgeupdate|MapsBroker|RemoteRegistry|tiledatamodelsvc|CDPSvc|WbioSrvc|DoSvc|BITS|wuauserv|TrustedInstaller'
    $svcDet = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
      Where-Object { $_.StartMode -eq 'Auto' -and $_.State -eq 'Stopped' -and $_.Name -notmatch $ruido } |
      ForEach-Object { $_.DisplayName })
  } catch {}

  # Autoruns: Run/RunOnce (HKLM+HKCU) + tareas programadas no-Microsoft
  $autoruns = 0
  try {
    foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
                     'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')) {
      try { $p = Get-ItemProperty $k -ErrorAction Stop; $autoruns += @($p.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' }).Count } catch {}
    }
  } catch {}
  $tareas = 0
  try { $tareas = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notmatch '^\\Microsoft\\' }).Count } catch {}

  # Batería (notebooks)
  $bateria = $null
  try {
    $b = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($b) {
      $design = $null; $full = $null
      try { $design = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity } catch {}
      try { $full = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity } catch {}
      $bateria = [ordered]@{ presente = $true; saludPct = (Get-BateriaSaludPct $design $full); design = $design; full = $full }
    }
  } catch {}

  [ordered]@{
    bsod = $bsod
    apagadosInesperados30d = $apagados
    serviciosAutoDetenidos = $svcDet
    autoruns = $autoruns
    tareasProgramadasNoMs = $tareas
    bateria = $bateria
  }
}
