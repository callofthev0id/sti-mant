# gui/lib/gui-runspace.ps1 - corre el relevamiento en un runspace propio para no congelar
# el hilo STA de WPF. La UI drena la cola de progreso por DispatcherTimer (ver sti-gui.ps1).

# Captura las definiciones de funcion de la sesion actual + las variables del core en un
# InitialSessionState. Asi el runspace de fondo arranca con Invoke-Relevamiento, los modulos,
# los helpers y $MOD_FNS/$THR/$FLEET_CUENTAS_ADMIN ya cargados, SIN depender de dot-source por ruta.
# Esto hace que el relevamiento funcione tanto en dev (libs sueltas) como en el dist single-file
# (todo el core inline en el proceso, pero invisible para un runspace nuevo sin esta inyeccion).
# Mismo patron que Invoke-ModulesParallel en lib/runspace.ps1.
function New-CoreInitialSessionState {
  $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  # Funciones que ya trae un default ISS (cd, help, more, prompt, etc.): no se reinyectan para no
  # pisar las del runtime. Solo van las funciones del core/modulos/helpers de ESTE proceso.
  $builtin = @{}
  foreach ($e in $iss.Commands) { if ($e.CommandType -eq 'Function') { $builtin[$e.Name] = $true } }
  foreach ($cmd in (Get-Command -CommandType Function -ErrorAction SilentlyContinue)) {
    if (-not $cmd.Definition -or $builtin.ContainsKey($cmd.Name)) { continue }
    try {
      $iss.Commands.Add(
        (New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($cmd.Name, $cmd.Definition)))
    } catch {}
  }
  foreach ($vn in @('MOD_FNS','THR','FLEET_CUENTAS_ADMIN')) {
    $v = Get-Variable $vn -ErrorAction SilentlyContinue
    if ($v) {
      $iss.Variables.Add(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry($vn, $v.Value, '')))
    }
  }
  $iss
}

function Start-RelevamientoAsync {
  param(
    [hashtable]$Ctx, [string]$Tipo, [string]$ScriptDir
  )
  $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
  # El runspace se abre con un ISS que ya trae el core inyectado (ver New-CoreInitialSessionState):
  # no se dot-sourcea nada por ruta, asi funciona aun cuando el dist single-file corre suelto y no
  # hay carpeta lib/ al lado. Los datos viajan como argumentos posicionales (Ctx, Tipo), no como
  # variables de sesion.
  $iss = New-CoreInitialSessionState
  $rs = [runspacefactory]::CreateRunspace($iss)
  $rs.ApartmentState = 'MTA'
  $rs.Open()
  $ps = [powershell]::Create()
  $ps.Runspace = $rs
  [void]$ps.AddScript({
    param($Ctx, $Tipo, $Queue)
    $Queue.Enqueue('relevando')
    $rel = Invoke-Relevamiento -Ctx $Ctx -Tipo $Tipo
    $Queue.Enqueue('listo')
    $rel
  }).AddArgument($Ctx).AddArgument($Tipo).AddArgument($queue)
  @{ ps = $ps; handle = $ps.BeginInvoke(); queue = $queue; rs = $rs }
}

# No bloquea. Si termino, recoge el resultado, limpia y devuelve done=$true.
function Receive-RelevamientoResult {
  param($Job)
  if (-not $Job.handle.IsCompleted) { return @{ done = $false; rel = $null; error = $null } }
  $rel = $null
  $err = $null
  try { $rel = @($Job.ps.EndInvoke($Job.handle))[0] }
  catch { $err = $_.Exception.Message }
  finally { $Job.ps.Dispose(); $Job.rs.Close(); $Job.rs.Dispose() }
  if ($err) { return @{ done = $true; rel = $null; error = $err } }
  @{ done = $true; rel = $rel; error = $null }
}

# Corre New-InventarioModel en un runspace de fondo (CIM read, no toca el equipo) para no
# congelar el hilo STA de WPF. Mismo patron que Start-RelevamientoAsync: el core se inyecta via
# InitialSessionState (no dot-source por ruta, asi anda igual en el dist single-file) y los datos
# viajan como argumentos. Devuelve un job; usar Receive-InventarioResult para recoger el modelo.
# $ScriptDir se conserva por compatibilidad de firma; ya no se usa para dot-sourcear.
function Start-InventarioAsync {
  param([hashtable]$Ctx, [string]$ScriptDir)
  $iss = New-CoreInitialSessionState
  $rs = [runspacefactory]::CreateRunspace($iss)
  $rs.ApartmentState = 'MTA'
  $rs.Open()
  $ps = [powershell]::Create()
  $ps.Runspace = $rs
  [void]$ps.AddScript({
    param($Ctx)
    New-InventarioModel -Ctx $Ctx
  }).AddArgument($Ctx)
  @{ ps = $ps; handle = $ps.BeginInvoke(); rs = $rs }
}

# No bloquea. Si termino, recoge el modelo de inventario, limpia y devuelve done=$true.
function Receive-InventarioResult {
  param($Job)
  if (-not $Job.handle.IsCompleted) { return @{ done = $false; inv = $null; error = $null } }
  $inv = $null; $err = $null
  try { $inv = @($Job.ps.EndInvoke($Job.handle))[0] }
  catch { $err = $_.Exception.Message }
  finally { $Job.ps.Dispose(); $Job.rs.Close(); $Job.rs.Dispose() }
  if ($err) { return @{ done = $true; inv = $null; error = $err } }
  @{ done = $true; inv = $inv; error = $null }
}

# Drena la cola de progreso sin bloquear. Devuelve el ultimo mensaje, o $null si esta vacia.
function Get-RelevamientoProgreso {
  param($Job)
  $msg = $null
  $out = ''
  while ($Job.queue.TryDequeue([ref]$out)) { $msg = $out }
  $msg
}
