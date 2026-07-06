# lib/cobian.ps1 - auto-relevamiento de backups Cobian Reflector/Gravity.
# Lee history.db (SQLite, con la DLL que trae Cobian) → por tarea: último run, próximo
# programado (NEXTBACKUP) y frecuencia (SCHEDULETYPE 1=diario 2=semanal 3=mensual).
# Staleness según la frecuencia configurada (no umbral fijo). Fallback: parsear los logs.
# Todo defensivo: si algo falla, degrada a N/A manual (nunca tira excepción al módulo).

# Etiqueta de cadencia desde SCHEDULETYPE (inline; sin $script: para sobrevivir a los runspaces).
function Get-CobianCadencia { param([int]$Sched) switch ($Sched) { 0 { 'única' } 1 { 'diario' } 2 { 'semanal' } 3 { 'mensual' } 4 { 'timer' } 5 { 'manual' } default { "tipo$Sched" } } }

# Rango de severidad (inline; no depender de $script: en Pester). N/A = -1.
function Get-CobianRank { param([string]$E) switch ($E) { 'Ok' { 0 } 'Advertencia' { 1 } 'Error' { 2 } 'Crítico' { 3 } default { -1 } } }

function Find-CobianInstall {
  foreach ($p in @(
      "$env:ProgramFiles\Cobian Reflector",
      "${env:ProgramFiles(x86)}\Cobian Reflector",
      "$env:ProgramFiles\Cobian Backup 11",
      "${env:ProgramFiles(x86)}\Cobian Backup 11")) {
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  }
  $null
}

# PURO: día/cadencia → estado semáforo. $Now inyectable para test.
# $LastRun/$NextDue: [datetime] o $null. $Sched: int (COB_SCHED). $HadErrors: bool.
function ConvertTo-CobianEstado {
  # $LastRun/$NextDue: $null, [datetime]::MinValue o [datetime]. Sin tipo en el param
  # porque PS 5.1 no maneja bien $null en params tipados [datetime]/[Nullable].
  param($LastRun, $NextDue, [int]$Sched, [bool]$HadErrors, [datetime]$Now)
  $hasLast = ($LastRun -is [datetime]) -and ($LastRun -ne [datetime]::MinValue)
  if (-not $hasLast) { return 'N/A' }
  $hasNext = ($NextDue -is [datetime]) -and ($NextDue -ne [datetime]::MinValue)
  $grace = switch ($Sched) { 1 { 1 } 2 { 2 } 3 { 5 } default { 1 } }   # días de tolerancia
  $period = switch ($Sched) { 1 { 1 } 2 { 7 } 3 { 31 } default { 2 } } # largo del ciclo
  $estado = 'Ok'
  if ($hasNext) {
    $overdue = ($Now - $NextDue).TotalDays
    if ($overdue -le 0) { $estado = 'Ok' }
    elseif ($overdue -le $grace) { $estado = 'Advertencia' }
    elseif ($overdue -le $period) { $estado = 'Error' }
    else { $estado = 'Crítico' }
  } else {
    # sin próximo programado: juzgar por antigüedad del último run
    $age = ($Now - $LastRun).TotalDays
    if ($age -le ($period + $grace)) { $estado = 'Ok' } else { $estado = 'Error' }
  }
  if ($HadErrors -and (Get-CobianRank $estado) -lt (Get-CobianRank 'Advertencia')) { $estado = 'Advertencia' }
  $estado
}

# El peor de dos estados (para el agregado de varias tareas).
function Get-PeorCobianEstado {
  param([string]$A, [string]$B)
  if (-not $A) { return $B }; if (-not $B) { return $A }
  if ((Get-CobianRank $A) -ge (Get-CobianRank $B)) { $A } else { $B }
}

# Lee history.db vía la System.Data.SQLite.dll que trae Cobian. Devuelve @() de tareas o $null.
function Get-CobianHistoryDb {
  param([string]$InstallDir)
  $db = Join-Path $InstallDir 'DB\history.db'
  $dll = Join-Path $InstallDir 'System.Data.SQLite.dll'
  if (-not (Test-Path $db) -or -not (Test-Path $dll)) { return $null }
  try {
    if (-not ([System.Management.Automation.PSTypeName]'System.Data.SQLite.SQLiteConnection').Type) {
      Add-Type -Path $dll -ErrorAction Stop
    }
    $cn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$db;Version=3;Read Only=True;Pooling=False;")
    $cn.Open()
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = "SELECT TASKID, MAX(TIMESTAMP) AS last, NEXTBACKUP AS next, SCHEDULETYPE AS sched FROM Backup GROUP BY TASKID"
    $rd = $cmd.ExecuteReader()
    $rows = @()
    while ($rd.Read()) {
      $last = $null; try { $last = [datetime]::Parse([string]$rd['last'], [Globalization.CultureInfo]::InvariantCulture) } catch {}
      $next = $null
      try {
        $vn = $rd['next']
        if ($vn -is [datetime]) { $next = $vn }
        elseif ($vn -and $vn -ne [DBNull]::Value) { $next = [datetime]::Parse([string]$vn, [Globalization.CultureInfo]::InvariantCulture) }
      } catch {}
      $sched = 0; try { $sched = [int]$rd['sched'] } catch {}
      $rows += @{ taskId = [string]$rd['TASKID']; last = $last; next = $next; sched = $sched }
    }
    $rd.Close(); $cn.Close()
    return $rows
  } catch { return $null }
}

# Fallback: último log con backup terminado + si hubo errores. Devuelve @{last;hadErrors} o $null.
function Get-CobianLogStatus {
  param([string]$InstallDir)
  $logs = Join-Path $InstallDir 'Logs'
  if (-not (Test-Path $logs)) { return $null }
  $f = Get-ChildItem $logs -Filter '*.txt' -File -ErrorAction SilentlyContinue |
       Where-Object { $_.Length -gt 0 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $f) { return $null }
  try {
    $txt = Get-Content $f.FullName -Raw -ErrorAction Stop
    $hadErr = ($txt -match 'Hay errores') -or ($txt -match '(?m)^ERR ')
    # última marca de tiempo "ha finalizado"
    $m = [regex]::Matches($txt, '(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}).*ha finalizado')
    $last = $null
    if ($m.Count -gt 0) { try { $last = [datetime]::Parse($m[$m.Count-1].Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) } catch {} }
    if (-not $last) { $last = $f.LastWriteTime }
    return @{ last = $last; hadErrors = [bool]$hadErr }
  } catch { return $null }
}

# Orquesta: @{ installed; source(db|log|none); estado; detail; tasks }
function Get-CobianBackupStatus {
  param([datetime]$Now = (Get-Date))
  $dir = Find-CobianInstall
  if (-not $dir) { return @{ installed = $false; source = 'none'; estado = 'N/A'; detail = 'Cobian no detectado' } }

  $rows = Get-CobianHistoryDb -InstallDir $dir
  if ($rows -and $rows.Count -gt 0) {
    $logSt = Get-CobianLogStatus -InstallDir $dir   # para flag global de errores
    $hadErr = [bool]($logSt -and $logSt.hadErrors)
    # Estado por tarea = SOLO cadencia (sin el flag de errores, que es global).
    $overall = $null; $parts = @()
    foreach ($r in ($rows | Sort-Object { [int]$_.sched })) {
      $cad = Get-CobianCadencia $r.sched
      $est = ConvertTo-CobianEstado -LastRun $r.last -NextDue $r.next -Sched $r.sched -HadErrors $false -Now $Now
      $overall = Get-PeorCobianEstado $overall $est
      $ultimo = if ($r.last) { $r.last.ToString('dd/MM') } else { 'nunca' }
      $tag = switch ($est) { 'Ok' { 'al día' } 'Advertencia' { 'atrasado' } 'Error' { 'VENCIDO' } 'Crítico' { 'VENCIDO+' } default { $est } }
      $parts += "$cad`: $tag (últ $ultimo)"
    }
    $det = ($parts -join '; ')
    # Los errores del log son un problema aparte: nota + sube el estado global a >= Advertencia.
    if ($hadErr) { $overall = Get-PeorCobianEstado $overall 'Advertencia'; $det += ' · el último log reporta errores' }
    return @{ installed = $true; source = 'db'; estado = $overall; detail = $det; tasks = $rows; producto = 'Cobian'; installDir = $dir; logsDir = (Join-Path $dir 'Logs') }
  }

  # fallback a logs
  $logSt = Get-CobianLogStatus -InstallDir $dir
  if ($logSt) {
    $est = ConvertTo-CobianEstado -LastRun $logSt.last -NextDue $null -Sched 1 -HadErrors $logSt.hadErrors -Now $Now
    $det = "último backup $($logSt.last.ToString('dd/MM HH:mm')) (cadencia no leída del DB)"
    if ($logSt.hadErrors) { $det += ' · con errores' }
    return @{ installed = $true; source = 'log'; estado = $est; detail = $det; producto = 'Cobian'; installDir = $dir; logsDir = (Join-Path $dir 'Logs') }
  }
  return @{ installed = $true; source = 'none'; estado = 'N/A'; detail = 'Cobian instalado pero sin historial legible'; producto = 'Cobian'; installDir = $dir; logsDir = (Join-Path $dir 'Logs') }
}

# ===== ACRONIS (segunda fuente de backup) =====
# Acronis no expone history.db ni programación legible desde el SO; lo mejor accesible es la
# fecha del último backup conocido (Event Log de Windows / logs de ProgramData). Sin cadencia,
# el estado se juzga por antigüedad: reciente=Ok, viejo=Advertencia, sin fecha=N/A.

# PURO: antigüedad del último backup → estado. $Last: [datetime] o $null. Umbrales en días.
function ConvertTo-AcronisEstado {
  param($Last, [datetime]$Now, [int]$OkMax = 2, [int]$AdvMax = 7)
  $hasLast = ($Last -is [datetime]) -and ($Last -ne [datetime]::MinValue)
  if (-not $hasLast) { return 'N/A' }
  $age = ($Now - $Last).TotalDays
  if ($age -le $OkMax) { 'Ok' } elseif ($age -le $AdvMax) { 'Advertencia' } else { 'Error' }
}

# Detecta instalación real de Acronis: servicios, carpetas en Program Files, o carpeta de datos.
# Devuelve @{ installed; service; serviceStatus; installDir; logsDir } o @{ installed=$false }.
function Find-AcronisInstall {
  # Solo nombres específicos de Acronis (evitar falsos positivos como vmms de Hyper-V).
  $svc = Get-Service -ErrorAction SilentlyContinue |
         Where-Object { $_.DisplayName -match 'Acronis' -or $_.Name -match 'Acronis|aakore|^AcrSch|MMS$' } |
         Where-Object { ($_.DisplayName -match 'Acronis') -or ($_.Name -match 'Acronis|aakore|AcrSch') } |
         Sort-Object { if ($_.DisplayName -match 'Managed Machine|Agent') { 0 } else { 1 } } |
         Select-Object -First 1
  $dir = $null
  foreach ($p in @("$env:ProgramFiles\Acronis", "${env:ProgramFiles(x86)}\Acronis", "$env:CommonProgramFiles\Acronis")) {
    if ($p -and (Test-Path -LiteralPath $p)) { $dir = $p; break }
  }
  $logs = $null
  foreach ($p in @("$env:ProgramData\Acronis", "$env:ALLUSERSPROFILE\Acronis")) {
    if ($p -and (Test-Path -LiteralPath $p)) { $logs = $p; break }
  }
  if (-not $svc -and -not $dir -and -not $logs) { return @{ installed = $false } }
  @{ installed = $true
     service = $(if ($svc) { $svc.DisplayName } else { $null })
     serviceStatus = $(if ($svc) { [string]$svc.Status } else { $null })
     installDir = $dir
     logsDir = $logs }
}

# Lee la fecha del último backup de Acronis desde el Event Log de Windows (best-effort).
# Acronis loguea en 'Application' (provider con 'Acronis') y/o canales propios. Buscamos el evento
# de "backup completado" más reciente. Devuelve [datetime] o $null si no se puede determinar.
function Get-AcronisLastBackupEvent {
  param([int]$Days = 60)
  $since = (Get-Date).AddDays(-$Days)
  try {
    # Canales de Applications and Services Logs de Acronis, si existen.
    $logNames = @(Get-WinEvent -ListLog '*Acronis*' -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 } | ForEach-Object { $_.LogName })
    $logNames += 'Application'
    foreach ($ln in ($logNames | Select-Object -Unique)) {
      try {
        $ev = Get-WinEvent -FilterHashtable @{ LogName = $ln; StartTime = $since } -ErrorAction SilentlyContinue |
              Where-Object { ($_.ProviderName -match 'Acronis') -or ($_.Message -match 'Acronis') } |
              Where-Object { $_.Message -match 'completed successfully|succeeded|backup.*success|copia de seguridad.*correctamente|completado' -or $_.LevelDisplayName -eq 'Information' } |
              Sort-Object TimeCreated -Descending | Select-Object -First 1
        if ($ev) { return $ev.TimeCreated }
      } catch {}
    }
  } catch {}
  $null
}

# Orquesta Acronis: @{ installed; estado; last; detail; logsDir; service }.
function Get-AcronisBackupStatus {
  param([datetime]$Now = (Get-Date))
  $inst = Find-AcronisInstall
  if (-not $inst.installed) { return @{ installed = $false; estado = 'N/A'; detail = 'Acronis no detectado' } }
  $last = $null
  try { $last = Get-AcronisLastBackupEvent } catch {}
  $estado = ConvertTo-AcronisEstado -Last $last -Now $Now
  if ($last -is [datetime]) {
    $det = "último backup $($last.ToString('dd/MM HH:mm'))"
    if ($inst.service) { $det += " · servicio $($inst.service):$($inst.serviceStatus)" }
  } else {
    $estado = 'N/A'
    $svcTxt = if ($inst.service) { "servicio $($inst.service):$($inst.serviceStatus)" } else { 'instalación detectada' }
    $det = "Acronis detectado ($svcTxt), último backup no determinable desde SO"
  }
  @{ installed = $true; estado = $estado; last = $last; detail = $det
     logsDir = $inst.logsDir; service = $inst.service; producto = 'Acronis' }
}

# Helper para los módulos: devuelve un check item de backup ya resuelto (multi-fuente).
# Detecta Cobian (DB/logs) y Acronis (Event Log/ProgramData). Si hay ambos, reporta ambos y toma
# el peor estado. rawData lleva fuentes estructuradas (fuente, ultimoBackup, estado, rutaLogs) para
# que la GUI las muestre en un popover. Si no detecta ninguno, busca un servicio de backup y deja N/A.
function Get-BackupCheckItem {
  param([string]$Key, [string]$Label, [datetime]$Now = (Get-Date))

  $fuentes = @()   # cada una: @{ fuente; estado; ultimoBackup; detalle; rutaLogs }
  $partes  = @()

  # --- Cobian ---
  try {
    $st = Get-CobianBackupStatus -Now $Now
    if ($st.installed -and $st.source -ne 'none') {
      $ult = $null
      if ($st.tasks) { $ult = ($st.tasks | ForEach-Object { $_.last } | Where-Object { $_ -is [datetime] } | Sort-Object -Descending | Select-Object -First 1) }
      $fuentes += @{ fuente = 'Cobian'; estado = $st.estado
        ultimoBackup = $(if ($ult) { $ult.ToString('yyyy-MM-dd HH:mm') } else { $null })
        detalle = $st.detail; rutaLogs = $st.logsDir }
      $partes += "Cobian: $($st.estado) ($($st.detail))"
    }
  } catch {}

  # --- Acronis ---
  try {
    $ac = Get-AcronisBackupStatus -Now $Now
    if ($ac.installed) {
      $fuentes += @{ fuente = 'Acronis'; estado = $ac.estado
        ultimoBackup = $(if ($ac.last -is [datetime]) { $ac.last.ToString('yyyy-MM-dd HH:mm') } else { $null })
        detalle = $ac.detail; rutaLogs = $ac.logsDir }
      $partes += "Acronis: $($ac.estado) ($($ac.detail))"
    }
  } catch {}

  if ($fuentes.Count -gt 0) {
    $overall = $null
    foreach ($f in $fuentes) { $overall = Get-PeorCobianEstado $overall $f.estado }
    if (-not $overall) { $overall = 'N/A' }
    $raw = @{ fuentes = $fuentes; multiFuente = ($fuentes.Count -gt 1) }
    return New-CheckItem $Key $Label $overall $false ($partes -join ' | ') $raw
  }

  # sin Cobian ni Acronis: detectar otro backup (Veeam/genérico) y dejar MANUAL.
  try {
    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Acronis|Veeam|Cobian|Backup' } | Select-Object -First 1
    if ($svc) {
      $raw = @{ fuentes = @(@{ fuente = $svc.DisplayName; estado = 'N/A'; ultimoBackup = $null; detalle = "servicio $($svc.Status)"; rutaLogs = $null }) }
      return New-CheckItem $Key $Label 'N/A' $false "servicio:$($svc.DisplayName):$($svc.Status) (revisar último backup a mano)" $raw
    }
  } catch {}
  New-CheckItem $Key $Label 'N/A' $false 'sin backup detectado (verificar manual)'
}
