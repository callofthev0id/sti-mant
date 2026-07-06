# lib/audit.ps1 - Subsistema de logging de auditoria de STI Mantenimiento.
#
# Registra CADA accion sensible (scan/apply/undo de la tab Utilidades, o cualquier otra que el
# resto del codigo quiera auditar) con campos estructurados, a tres destinos en paralelo:
#   (a) Windows Event Log (fuente custom 'STI Mantenimiento' en el log Application). Es el registro
#       de auditoria del SO: tamper-evident (limpiar el log exige admin y genera el evento 1102).
#   (b) Archivo JSON-lines (un objeto JSON por linea), para consumo de maquina (panel/backend interno).
#   (c) Archivo de texto humano legible.
# Best-effort: ningun destino que falle aborta la accion ni rompe la GUI. Si no hay admin para
# registrar la fuente del Event Log, se degrada (try/catch) y se sigue con archivo.
#
# Inmutabilidad: se aplica una ACL restrictiva a la carpeta de auditoria (solo SYSTEM y
# Administradores con control total; los usuarios estandar pierden delete/write). Esto es
# tamper-RESISTANT, no tamper-PROOF: un admin local siempre puede tocar el archivo. La
# inmutabilidad total local no es posible sin WORM o copia remota append-only; el forward al
# backend interno (follow-up) cubre ese caso.

# Carpeta y archivos de auditoria. Fijos (no dependen del cwd). ProgramData es la ruta canonica
# para datos de aplicacion a nivel maquina; cae a C:\zback\sti-audit si ProgramData no resuelve.
function Get-StiAuditDir {
  $base = $env:ProgramData
  if ([string]::IsNullOrWhiteSpace($base)) { return 'C:\zback\sti-audit' }
  Join-Path $base 'STI\audit'
}
function Get-StiAuditJsonPath  { Join-Path (Get-StiAuditDir) 'sti-audit.jsonl' }
function Get-StiAuditTextPath  { Join-Path (Get-StiAuditDir) 'sti-audit.log' }
# Registro de eventos DEDICADO: aparece en el Visor de Eventos bajo
# "Registros de aplicaciones y servicios" -> "STI Mantenimiento" (no mezclado en Application).
# Es el registro de auditoria de cada cambio de mantenimiento (evidencia consultable/exportable).
function Get-StiAuditEventLog   { 'STI Mantenimiento' }
function Get-StiAuditEventSource { 'STI Mantenimiento' }

# EventId por tipo de accion (estable, documentado): permite filtrar el Event Log por evento.
function Get-StiAuditEventId {
  param([string]$Accion)
  switch ($Accion) {
    'scan'   { 1001 }
    'apply'  { 1002 }
    'undo'   { 1003 }
    'safety' { 1004 }
    default  { 1000 }
  }
}

# Crea la carpeta de auditoria y le aplica una ACL restrictiva (best-effort). Tras el endurecimiento
# solo SYSTEM y Administradores tienen control total; se desactiva la herencia para que un permiso
# heredado de usuarios estandar no reabra el delete/write. Nunca tira: si Set-Acl falla (no admin,
# FS sin ACL), se sigue con la carpeta tal cual. Devuelve $true si pudo endurecer.
function Initialize-StiAuditStore {
  $dir = Get-StiAuditDir
  try {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  } catch { return $false }
  try {
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)  # corta herencia, no copia reglas heredadas
    $full = [System.Security.AccessControl.FileSystemRights]::FullControl
    $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    $prop = [System.Security.AccessControl.PropagationFlags]::None
    $allow = [System.Security.AccessControl.AccessControlType]::Allow
    foreach ($sid in @('S-1-5-18','S-1-5-32-544')) {  # SYSTEM, Administradores (locale-neutral)
      $acct = (New-Object System.Security.Principal.SecurityIdentifier($sid))
      $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($acct, $full, $inherit, $prop, $allow)
      $acl.AddAccessRule($rule)
    }
    Set-Acl -Path $dir -AclObject $acl -ErrorAction Stop
    return $true
  } catch { return $false }
}

# Asegura la fuente del Event Log. Crearla la primera vez requiere admin (New-EventLog). Si no se
# puede (sin admin o ya existe con error), degrada: devuelve $false y el resto sigue con archivo.
function Initialize-StiAuditEventSource {
  $src = Get-StiAuditEventSource
  $log = Get-StiAuditEventLog
  try {
    if ([System.Diagnostics.EventLog]::SourceExists($src)) {
      # La fuente existe. Si quedo registrada en otro log (ej una version vieja la creo en
      # 'Application'), migrarla al registro dedicado: una fuente solo puede vivir en un log.
      $logActual = $null
      try { $logActual = [System.Diagnostics.EventLog]::LogNameFromSourceName($src, '.') } catch { }
      if ($logActual -eq $log) { return $true }
      try { Remove-EventLog -Source $src -ErrorAction Stop } catch { return $true }  # sin admin: dejarla donde esta
    }
  } catch { }
  try {
    New-EventLog -LogName $log -Source $src -ErrorAction Stop
    return $true
  } catch { return $false }
}

# Mapea resultado -> EntryType del Event Log. error -> Error; warning -> Warning; resto Information.
function Get-StiAuditEntryType {
  param([string]$Resultado)
  if ($Resultado -match '^(?i)error') { return 'Error' }
  if ($Resultado -match '^(?i)(warn|aviso)') { return 'Warning' }
  'Information'
}

# Arma el registro estructurado (hashtable ordenado) a partir de los campos. timestamp ISO 8601,
# tecnico y hostname auto-detectados si no se pasan. No escribe nada: solo da forma al dato.
function New-StiAuditRecord {
  param(
    [string]$Accion,                 # scan | apply | undo | safety
    [string]$UtilId = '',
    [string]$UtilLabel = '',
    [string]$Categoria = '',
    [string]$EstadoAnterior = '',
    [string]$EstadoNuevo = '',
    [string]$Resultado = 'ok',
    [string]$Mensaje = '',
    [string]$Tecnico = '',
    [string]$Hostname = ''
  )
  if (-not $Tecnico)  { $Tecnico  = if ($env:USERNAME) { $env:USERNAME } else { 'desconocido' } }
  if (-not $Hostname) { $Hostname = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { 'desconocido' } }
  [ordered]@{
    timestamp      = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    accion         = $Accion
    util_id        = $UtilId
    util_label     = $UtilLabel
    categoria      = $Categoria
    estado_anterior = $EstadoAnterior
    estado_nuevo   = $EstadoNuevo
    resultado      = $Resultado
    mensaje        = $Mensaje
    tecnico        = $Tecnico
    hostname       = $Hostname
  }
}

# Linea de texto humano a partir del registro. Una linea, campos clave en orden de lectura.
function Format-StiAuditTextLine {
  param([System.Collections.IDictionary]$Record)
  $r = $Record
  $util = if ($r.util_label) { "$($r.util_label) [$($r.util_id)]" } elseif ($r.util_id) { $r.util_id } else { '-' }
  $trans = if ($r.estado_anterior -or $r.estado_nuevo) { " ($($r.estado_anterior) -> $($r.estado_nuevo))" } else { '' }
  $msg = if ($r.mensaje) { " | $($r.mensaje)" } else { '' }
  "$($r.timestamp) | $($r.tecnico)@$($r.hostname) | $($r.accion.ToUpper()) | $util$trans | $($r.resultado)$msg"
}

# Funcion principal: registra una accion de auditoria en los tres destinos. Best-effort total.
# Devuelve un resumen { eventlog; json; texto } de que destinos pudieron escribir (util en tests).
function Write-StiAudit {
  param(
    [Parameter(Mandatory)][ValidateSet('scan','apply','undo','safety')][string]$Accion,
    [string]$UtilId = '',
    [string]$UtilLabel = '',
    [string]$Categoria = '',
    [string]$EstadoAnterior = '',
    [string]$EstadoNuevo = '',
    [string]$Resultado = 'ok',
    [string]$Mensaje = '',
    [string]$Tecnico = '',
    [string]$Hostname = ''
  )
  $rec = New-StiAuditRecord -Accion $Accion -UtilId $UtilId -UtilLabel $UtilLabel -Categoria $Categoria `
         -EstadoAnterior $EstadoAnterior -EstadoNuevo $EstadoNuevo -Resultado $Resultado -Mensaje $Mensaje `
         -Tecnico $Tecnico -Hostname $Hostname
  $out = @{ eventlog = $false; json = $false; texto = $false }

  # (a) Windows Event Log
  try {
    if (Initialize-StiAuditEventSource) {
      $type = Get-StiAuditEntryType -Resultado $Resultado
      $eid  = Get-StiAuditEventId -Accion $Accion
      $body = (Format-StiAuditTextLine -Record $rec) + "`n`n" + (($rec.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join "`n")
      Write-EventLog -LogName (Get-StiAuditEventLog) -Source (Get-StiAuditEventSource) -EntryType $type -EventId $eid -Message $body -ErrorAction Stop
      $out.eventlog = $true
    }
  } catch { }

  # carpeta + ACL (best-effort) antes de los archivos
  try { Initialize-StiAuditStore | Out-Null } catch { }

  # (b) JSON-lines (append-only)
  try {
    $json = ($rec | ConvertTo-Json -Compress -Depth 5)
    Add-Content -Path (Get-StiAuditJsonPath) -Value $json -Encoding UTF8 -ErrorAction Stop
    $out.json = $true
  } catch { }

  # (c) Texto humano (append-only)
  try {
    Add-Content -Path (Get-StiAuditTextPath) -Value (Format-StiAuditTextLine -Record $rec) -Encoding UTF8 -ErrorAction Stop
    $out.texto = $true
  } catch { }

  $out
}

# Lee las ultimas N entradas del JSON-lines (mas recientes primero) para el panel interno de la GUI
# y para export programatico. Tolerante a fallo: si el archivo no existe o una linea esta corrupta,
# la saltea y devuelve lo que pueda (array, posiblemente vacio). Solo LEE.
function Get-StiAuditRecent {
  param([int]$Count = 20)
  $path = Get-StiAuditJsonPath
  if (-not (Test-Path $path)) { return @() }
  $lines = @()
  try { $lines = @(Get-Content -Path $path -Encoding UTF8 -ErrorAction Stop) } catch { return @() }
  if (-not $lines.Count) { return @() }
  $tail = if ($lines.Count -gt $Count) { $lines[($lines.Count - $Count)..($lines.Count - 1)] } else { $lines }
  $out = @()
  foreach ($l in $tail) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $out += ($l | ConvertFrom-Json) } catch { }
  }
  # mas recientes primero
  [array]::Reverse($out)
  @($out)
}

# Linea legible para el panel interno (compacta, una linea por entrada del JSON-lines parseado).
function Format-StiAuditPanelLine {
  param($Record)
  if (-not $Record) { return '' }
  $hora = $Record.timestamp
  try { $hora = ([datetime]$Record.timestamp).ToString('MM-dd HH:mm:ss') } catch { }
  $util = if ($Record.util_label) { $Record.util_label } elseif ($Record.util_id) { $Record.util_id } else { '-' }
  $acc = ([string]$Record.accion).ToUpper()
  $res = $Record.resultado
  $trans = if ($Record.estado_anterior -or $Record.estado_nuevo) { " $($Record.estado_anterior)->$($Record.estado_nuevo)" } else { '' }
  "$hora  $acc  $util$trans  [$res]"
}
