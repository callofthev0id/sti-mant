# mod-servidores.ps1 - checks srv_* (corre sobre UN servidor). 5 funciones (1 por categoría).
# Comparte patrón de collectors con terminales pero emite keys srv_*.

function Invoke-STISrvSeguridad {
  param($Ctx)
  $items = @(); $errs = @()
  # srv_cuentas_sti
  try {
    $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop | ForEach-Object { ($_.Name -split '\\')[-1].ToLower() })
    $esperadas = @($Ctx.cuentasAdmin | ForEach-Object { ([string]$_).ToLower() })
    $faltan = @($esperadas | Where-Object { $admins -notcontains $_ })
    $detAdmin = if ($faltan.Count) { "faltan cuentas admin: $($faltan -join ', ')" } else { 'cuentas admin OK' }
    $items += New-CheckItem 'srv_cuentas_sti' 'Cuentas STI (admin)' (Get-StatusBool ($faltan.Count -eq 0)) $true $detAdmin
  } catch { $items += New-CheckItem 'srv_cuentas_sti' 'Cuentas STI (admin)' 'N/A' $true ''; $errs += "cuentas: $($_.Exception.Message)" }
  # srv_firewall
  try { $fw = Get-NetFirewallProfile -ErrorAction Stop; $allOn = -not ($fw | Where-Object { -not $_.Enabled })
    $items += New-CheckItem 'srv_firewall' 'Firewall' (Get-StatusBool $allOn) $true (($fw | ForEach-Object { "$($_.Name):$([bool]$_.Enabled)" }) -join ' ')
  } catch { $items += New-CheckItem 'srv_firewall' 'Firewall' 'N/A' $true ''; $errs += "firewall: $($_.Exception.Message)" }
  # srv_antivirus_eset
  try { $ekrn = Get-Service ekrn -ErrorAction SilentlyContinue
    if ($ekrn) { $items += New-CheckItem 'srv_antivirus_eset' 'Antivirus ESET' (Get-StatusBool ($ekrn.Status -eq 'Running')) $true "ekrn:$($ekrn.Status)" }
    else { $items += New-CheckItem 'srv_antivirus_eset' 'Antivirus ESET' 'Error' $true 'ESET no detectado' }
  } catch { $items += New-CheckItem 'srv_antivirus_eset' 'Antivirus ESET' 'N/A' $true ''; $errs += "eset: $($_.Exception.Message)" }
  # srv_updates
  try { $last = (Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn | Select-Object -Last 1).InstalledOn
    if ($last) { $d = [int]((Get-Date) - $last).TotalDays; $items += New-CheckItem 'srv_updates' 'Updates Windows Server' (Get-StatusByDays $d $THR.updates.okMax $THR.updates.advMax) $true "último KB hace $d días" }
    else { $items += New-CheckItem 'srv_updates' 'Updates Windows Server' 'Error' $true 'sin fecha de KB' }
  } catch { $items += New-CheckItem 'srv_updates' 'Updates Windows Server' 'N/A' $true ''; $errs += "updates: $($_.Exception.Message)" }
  # srv_rdp (server: debe estar habilitado + NLA)
  try {
    $deny = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
    $nla  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication
    $st = if ($deny -ne 0) { 'Error' } elseif ($nla -eq 1) { 'Ok' } else { 'Advertencia' }
    $items += New-CheckItem 'srv_rdp' 'RDP hardening (NLA)' $st $true "habilitado:$($deny -eq 0) NLA:$($nla -eq 1)"
  } catch { $items += New-CheckItem 'srv_rdp' 'RDP hardening (NLA)' 'N/A' $true ''; $errs += "rdp: $($_.Exception.Message)" }
  @{ category = 'Seguridad'; items = $items; errors = $errs }
}

function Invoke-STISrvSistema {
  param($Ctx)
  $items = @(); $errs = @()
  try { $since = (Get-Date).AddDays(-7); $n = 0
    foreach ($log in 'System','Application') { $n += @(Get-WinEvent -FilterHashtable @{ LogName=$log; Level=1,2; StartTime=$since } -ErrorAction SilentlyContinue).Count }
    $items += New-CheckItem 'srv_visor_eventos' 'Visor de eventos' 'N/A' $false "$n errores/críticos en 7 días (revisar)"
  } catch { $items += New-CheckItem 'srv_visor_eventos' 'Visor de eventos' 'N/A' $false ''; $errs += "eventos: $($_.Exception.Message)" }
  try { $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime; $d = [int]((Get-Date) - $boot).TotalDays
    $items += New-CheckItem 'srv_ultimo_reinicio' 'Último reinicio' (Get-StatusByDays $d $THR.reinicio.okMax $THR.reinicio.advMax) $true "hace $d días"
  } catch { $items += New-CheckItem 'srv_ultimo_reinicio' 'Último reinicio' 'N/A' $true ''; $errs += "reinicio: $($_.Exception.Message)" }
  try { $sh = @(Get-CimInstance Win32_ShadowCopy -ErrorAction SilentlyContinue)
    if ($sh.Count -gt 0) { $latest = ($sh | ForEach-Object { $_.InstallDate } | Sort-Object -Descending | Select-Object -First 1); $d = [int]((Get-Date) - $latest).TotalDays
      $items += New-CheckItem 'srv_vss' 'Versiones anteriores / VSS' (Get-StatusVss $d $true) $true "último punto hace $d días" }
    else { $items += New-CheckItem 'srv_vss' 'Versiones anteriores / VSS' (Get-StatusVss 0 $false) $true 'sin shadow copies' }
  } catch { $items += New-CheckItem 'srv_vss' 'Versiones anteriores / VSS' 'N/A' $true ''; $errs += "vss: $($_.Exception.Message)" }
  @{ category = 'Sistema'; items = $items; errors = $errs }
}

function Invoke-STISrvAlmacenamiento {
  param($Ctx)
  $items = @(); $errs = @()
  try { $pd = @(Get-PhysicalDisk -ErrorAction Stop); $bad = $pd | Where-Object { $_.HealthStatus -ne 'Healthy' }
    $st = if (-not $pd) { 'N/A' } elseif (-not $bad) { 'Ok' } elseif ($bad | Where-Object { $_.HealthStatus -eq 'Unhealthy' }) { 'Crítico' } else { 'Advertencia' }
    $items += New-CheckItem 'srv_disco_smart' 'Estado discos (SMART)' $st $true (($pd | ForEach-Object { "$($_.FriendlyName):$($_.HealthStatus)" }) -join ' | ')
  } catch { $items += New-CheckItem 'srv_disco_smart' 'Estado discos (SMART)' 'N/A' $true ''; $errs += "smart: $($_.Exception.Message)" }
  # espacio: peor volumen fijo
  try {
    $vols = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
    $worst = 0; $det = @()
    foreach ($v in $vols) { $p = [int]((($v.Size - $v.FreeSpace)/$v.Size)*100); if ($p -gt $worst) { $worst = $p }; $det += "$($v.DeviceID)$p%" }
    $items += New-CheckItem 'srv_espacio_disco' 'Espacio en disco' (Get-StatusByPct $worst $THR.disco.okMax $THR.disco.advMax) $true ($det -join ' ')
  } catch { $items += New-CheckItem 'srv_espacio_disco' 'Espacio en disco' 'N/A' $true ''; $errs += "espacio: $($_.Exception.Message)" }
  # srv_backup: AUTO desde Cobian (history.db/logs); MANUAL (Acronis/Veeam/…) si no hay Cobian.
  $items += Get-BackupCheckItem 'srv_backup' 'Backup (Acronis/Cobian)'
  @{ category = 'Almacenamiento'; items = $items; errors = $errs }
}

function Invoke-STISrvServicios {
  param($Ctx)
  $items = @(); $errs = @()
  # srv_ocs
  try {
    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'OCS' -or $_.DisplayName -match 'OCS Inventory' } | Select-Object -First 1
    if (-not $svc -and $Ctx.installOcs) {
      $exe = Join-Path $Ctx.scriptDir 'OcsPackage-x64.exe'
      if (Test-Path $exe) { Start-Process $exe -ArgumentList "/FORCE","/TAG=`"$($Ctx.tag)`"" -Wait; Start-Sleep 3; $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'OCS' } | Select-Object -First 1 }
      else { $errs += "ocs: OcsPackage-x64.exe no encontrado" }
    }
    if ($svc) {
      # robustez: además del servicio, traer fecha del último inventario (registro/logs).
      $ocs = $null; try { $ocs = Get-OcsInventoryStatus } catch {}
      $last = $null; if ($ocs) { $last = $ocs.lastInventory }
      $det = "servicio:$($svc.Status)"
      $st = if ($svc.Status -eq 'Running') { 'Ok' } else { 'Advertencia' }
      if ($last -is [datetime]) {
        $dInv = [int]((Get-Date) - $last).TotalDays
        $det += " · último inventario $($last.ToString('dd/MM HH:mm')) (hace $dInv días)"
        # inventario muy viejo es señal de agente colgado aunque el servicio corra.
        if ($svc.Status -eq 'Running' -and $dInv -gt 7) { $st = 'Advertencia' }
      } else { $det += ' · último inventario no determinable' }
      $raw = @{ servicio = $svc.Name; estado = [string]$svc.Status
        ultimoInventario = $(if ($last -is [datetime]) { $last.ToString('yyyy-MM-dd HH:mm') } else { $null })
        rutaLogs = $(if ($ocs) { $ocs.logsDir } else { $null }) }
      $items += New-CheckItem 'srv_ocs' 'OCS Agent + inventario' $st $true $det $raw
    }
    else { $items += New-CheckItem 'srv_ocs' 'OCS Agent + inventario' 'Error' $true ($(if($Ctx.installOcs){'instalación falló'}else{'no instalado (usar -InstallOCS)'})) }
  } catch { $items += New-CheckItem 'srv_ocs' 'OCS Agent + inventario' 'N/A' $true ''; $errs += "ocs: $($_.Exception.Message)" }
  # srv_teamviewer
  try { $tv = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'TeamViewer' } | Select-Object -First 1
    if ($tv) { $items += New-CheckItem 'srv_teamviewer' 'TeamViewer Host STI' (Get-StatusBool ($tv.Status -eq 'Running')) $true "servicio:$($tv.Status)" }
    else { $items += New-CheckItem 'srv_teamviewer' 'TeamViewer Host STI' 'Error' $true 'no instalado' }
  } catch { $items += New-CheckItem 'srv_teamviewer' 'TeamViewer Host STI' 'N/A' $true ''; $errs += "tv: $($_.Exception.Message)" }
  # srv_encendido_auto / srv_apagado_auto (SEMI): best-effort - tareas programadas de apagado; BIOS wake no accesible.
  try {
    $shutTask = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.Actions.Execute -match 'shutdown' })
    $items += New-CheckItem 'srv_encendido_auto' 'Encendido automático' 'N/A' $false 'BIOS/Wake - verificar manual'
    $items += New-CheckItem 'srv_apagado_auto' 'Apagado automático' 'N/A' $false ($(if($shutTask.Count){"tarea de apagado detectada ($($shutTask.Count))"}else{'sin tarea de apagado - verificar'}))
  } catch { $items += New-CheckItem 'srv_encendido_auto' 'Encendido automático' 'N/A' $false ''; $items += New-CheckItem 'srv_apagado_auto' 'Apagado automático' 'N/A' $false ''; $errs += "power: $($_.Exception.Message)" }
  # srv_servicios_rol: roles instalados + estado de servicios clave.
  try {
    $rolesMap = @{ 'AD DS'='NTDS'; 'DNS'='DNS'; 'DHCP'='DHCPServer'; 'File'='LanmanServer'; 'IIS'='W3SVC'; 'Hyper-V'='vmms'; 'RDS-Lic'='TermServLicensing' }
    $found = @(); $bad = $false
    foreach ($k in $rolesMap.Keys) {
      $s = Get-Service $rolesMap[$k] -ErrorAction SilentlyContinue
      if ($s) { $found += "$($k):$($s.Status)"; if ($s.Status -ne 'Running') { $bad = $true } }
    }
    # SQL (nombre dinámico)
    $sql = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^MSSQL' } | Select-Object -First 1
    if ($sql) { $found += "SQL:$($sql.Status)"; if ($sql.Status -ne 'Running') { $bad = $true } }
    if ($found.Count -eq 0) { $items += New-CheckItem 'srv_servicios_rol' 'Servicios por rol' 'N/A' $true 'sin roles típicos detectados' }
    else { $items += New-CheckItem 'srv_servicios_rol' 'Servicios por rol' (Get-StatusBool (-not $bad)) $true ($found -join ' | ') }
  } catch { $items += New-CheckItem 'srv_servicios_rol' 'Servicios por rol' 'N/A' $true ''; $errs += "roles: $($_.Exception.Message)" }
  # srv_vms: si es host Hyper-V.
  try {
    $vmms = Get-Service vmms -ErrorAction SilentlyContinue
    if ($vmms -and $vmms.Status -eq 'Running' -and (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
      $vms = @(Get-VM -ErrorAction SilentlyContinue)
      if ($vms.Count -gt 0) {
        $off = @($vms | Where-Object { $_.State -ne 'Running' })
        $st = if ($off.Count -eq 0) { 'Ok' } else { 'Advertencia' }
        $items += New-CheckItem 'srv_vms' 'Estado VMs (host Hyper-V)' $st $true (($vms | ForEach-Object { "$($_.Name):$($_.State)" }) -join ' | ')
      } else { $items += New-CheckItem 'srv_vms' 'Estado VMs (host Hyper-V)' 'N/A' $true 'host Hyper-V sin VMs' }
    } else { $items += New-CheckItem 'srv_vms' 'Estado VMs (host Hyper-V)' 'N/A' $true 'no es host Hyper-V' }
  } catch { $items += New-CheckItem 'srv_vms' 'Estado VMs (host Hyper-V)' 'N/A' $true ''; $errs += "vms: $($_.Exception.Message)" }
  @{ category = 'Servicios'; items = $items; errors = $errs }
}

function Invoke-STISrvRed {
  param($Ctx)
  $items = @(); $errs = @()
  try {
    $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
    $pingGw = if ($gw) { Test-Connection -ComputerName $gw -Count 1 -Quiet -ErrorAction SilentlyContinue } else { $false }
    $dns = $false; try { $dns = [bool](Resolve-DnsName 'google.com' -ErrorAction Stop) } catch {}
    $items += New-CheckItem 'srv_conectividad' 'Conectividad (gateway+DNS)' (Get-StatusBool ($pingGw -and $dns)) $true "gw:$gw ping:$pingGw dns:$dns"
  } catch { $items += New-CheckItem 'srv_conectividad' 'Conectividad (gateway+DNS)' 'N/A' $true ''; $errs += "conect: $($_.Exception.Message)" }
  try { $sh = @(Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '\$$' } | ForEach-Object { $_.Name })
    $items += New-CheckItem 'srv_recursos_compartidos' 'Recursos compartidos' 'N/A' $false ("$($sh.Count): " + ($sh -join ', '))
  } catch { $items += New-CheckItem 'srv_recursos_compartidos' 'Recursos compartidos' 'N/A' $false ''; $errs += "shares: $($_.Exception.Message)" }
  @{ category = 'Red'; items = $items; errors = $errs }
}
