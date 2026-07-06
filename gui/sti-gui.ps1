# sti-gui.ps1 - GUI de relevamiento/mantenimiento (WPF). Capa de presentacion sobre el core.
# Uso:  PowerShell -ExecutionPolicy Bypass -File sti-gui.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreDir = Join-Path $scriptDir '..'
. "$coreDir\lib\common.ps1"
. "$coreDir\lib\thresholds.ps1"
. "$coreDir\lib\runspace.ps1"
. "$coreDir\lib\output.ps1"
. "$coreDir\lib\manual.ps1"
. "$coreDir\lib\cobian.ps1"
. "$coreDir\lib\inv-obsolescencia.ps1"
. "$coreDir\lib\inv-seguridad.ps1"
. "$coreDir\lib\inv-contexto.ps1"
. "$coreDir\lib\inv-salud.ps1"
. "$coreDir\lib\inventario.ps1"
. "$coreDir\lib\core.ps1"
. "$coreDir\lib\audit.ps1"
Get-ChildItem "$coreDir\modules\*.ps1" | ForEach-Object { . $_.FullName }
. "$scriptDir\lib\gui-logic.ps1"
. "$scriptDir\lib\gui-tab-mantenimiento.ps1"
. "$scriptDir\lib\gui-theme.ps1"
. "$scriptDir\lib\gui-branding.ps1"
. "$scriptDir\lib\gui-tab-inventario.ps1"
. "$scriptDir\lib\gui-tab-utilidades.ps1"
. "$scriptDir\lib\gui-tab-generar.ps1"
. "$scriptDir\lib\gui-xaml.ps1"
. "$scriptDir\lib\gui-runspace.ps1"
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms  # FolderBrowserDialog

$hostName = $env:COMPUTERNAME
$xaml = New-StiWindowXaml -Hostname $hostName -Version $SCRIPT_VERSION
$win  = Get-StiWindow -Xaml $xaml
$ctl  = {param($n) $win.FindName($n)}

$ff  = Get-FormFactor
$os  = Get-OsInfo
$tipo = Get-EquipoTipo -FormFactor $ff.formFactor -SoClase $os.class
$detalle = "detectado · $($ff.formFactor)$(if ($ff.isVm) { ', VM' } else { ', no-VM' })"
(& $ctl 'TxtHostname').Text = $hostName
(& $ctl 'LblTipo').Text = if ($tipo -eq 'servidores') { 'Servidor' } else { 'Terminal' }
(& $ctl 'LblTipoDetalle').Text = $detalle
(& $ctl 'LblRelevar').Text = Get-RelevarLabel $tipo
$script:tipoActual = $tipo

# Usuario/Sector solo tiene sentido en terminales: en servidores se oculta el campo.
function Update-UsuarioVisibilidad([string]$t) {
  (& $ctl 'PanelUsuario').Visibility = if ($t -eq 'servidores') { 'Collapsed' } else { 'Visible' }
}
Update-UsuarioVisibilidad $script:tipoActual

# Flujo hibrido: Principal es el arranque. Hasta relevar, Inventario/Mantenimiento/Generar quedan
# deshabilitadas (se habilitan en el done-block del relevamiento). Principal y Utilidades quedan
# siempre habilitadas: Utilidades es una caja de herramientas independiente del relevamiento.
foreach ($c in @('ChipInventario','ChipMantenimiento','ChipGenerar')) {
  (& $ctl $c).IsEnabled = $false
  (& $ctl $c).ToolTip = 'Relevá el equipo primero (tab Principal).'
}
function Enable-TabsPostRelevamiento {
  foreach ($c in @('ChipInventario','ChipMantenimiento','ChipGenerar')) {
    (& $ctl $c).IsEnabled = $true
    (& $ctl $c).ToolTip = $null
  }
}

# Identificadores del equipo (panel Principal): lectura local rapida (registro + CIM). Arrays
# (mac, disk_serial) unidos por coma; campo vacio -> 's/d'. Defensivo: si Get-HardwareIds falla,
# no rompe el arranque de la GUI.
function Show-HwIdDato($v) {
  if ($null -eq $v) { return 's/d' }
  if ($v -is [array]) { $j = (@($v | Where-Object { $_ }) -join ', '); return $(if ($j) { $j } else { 's/d' }) }
  $s = ([string]$v).Trim(); if ($s) { $s } else { 's/d' }
}
try {
  $hwIds = Get-HardwareIds
  (& $ctl 'TxtIdOsUuid').Text     = Show-HwIdDato $hwIds.os_uuid
  (& $ctl 'TxtIdHwUuid').Text     = Show-HwIdDato $hwIds.hw_uuid
  (& $ctl 'TxtIdDiskSerial').Text = Show-HwIdDato $hwIds.disk_serial
  (& $ctl 'TxtIdBiosSerial').Text = Show-HwIdDato $hwIds.bios_serial
  (& $ctl 'TxtIdMac').Text        = Show-HwIdDato $hwIds.mac
} catch {
  foreach ($n in @('TxtIdOsUuid','TxtIdHwUuid','TxtIdDiskSerial','TxtIdBiosSerial','TxtIdMac')) { (& $ctl $n).Text = 's/d' }
}

# Poblar la tab Mantenimiento con el catalogo vacio (pre-relevamiento): AUTO en N/A, manuales "a marcar".
function Update-MantVista([string]$t) {
  $cat   = Get-MantCheckCatalog -Tipo $t
  $filas = ConvertTo-MantFilas -Catalogo $cat -Items @()
  $res   = Get-MantResumen -Filas $filas
  Update-MantenimientoPanel -Window $win -Filas $filas -Resumen $res -Tipo $t
}
Update-MantVista $script:tipoActual

$paneles = @{
  ChipPrincipal='PanelPrincipal'; ChipInventario='PanelInventario'; ChipMantenimiento='PanelMantenimiento';
  ChipUtilidades='PanelUtilidades'; ChipGenerar='PanelGenerar'
}
function Show-Panel($nombre) {
  foreach ($p in @('PanelPrincipal','PanelInventario','PanelMantenimiento','PanelUtilidades','PanelGenerar','PanelEjecucion')) {
    (& $ctl $p).Visibility = if ($p -eq $nombre) { 'Visible' } else { 'Collapsed' }
  }
}
foreach ($chip in $paneles.Keys) {
  $panel = $paneles[$chip]
  (& $ctl $chip).Add_Checked([System.Windows.RoutedEventHandler]{ Show-Panel $panel }.GetNewClosure())
}

# Inventario on-demand: la primera vez que el tecnico entra a la tab, releva el inventario
# (New-InventarioModel, CIM read, no toca el equipo) en un runspace de fondo y puebla las cards.
# Si ya se relevo (o ya esta poblado), no vuelve a correr. El campo InvVacio muestra el estado.
$script:invCargado = $false
function Start-InventarioCarga {
  if ($script:invCargado -or $script:invJob) { return }
  $coreDir = (Resolve-Path (Join-Path $scriptDir '..')).Path
  $invArgs = New-GuiMantArgs -Tag (& $ctl 'TxtTag').Text -Cliente (& $ctl 'TxtCliente').Text `
           -Usuario (& $ctl 'TxtUsuario').Text -Nota '' -ScriptDir $coreDir
  $ctxInv = New-MantContext @invArgs -Tecnico (& $ctl 'TxtTecnico').Text
  (& $ctl 'InvVacio').Text = 'Relevando inventario del equipo...'
  $script:invJob = Start-InventarioAsync -Ctx $ctxInv -ScriptDir $coreDir
  $script:invTimer = New-Object System.Windows.Threading.DispatcherTimer
  $script:invTimer.Interval = [TimeSpan]::FromMilliseconds(250)
  $script:invTimer.Add_Tick({
    $res = Receive-InventarioResult -Job $script:invJob
    if (-not $res.done) { return }
    $script:invTimer.Stop()
    $script:invJob = $null
    if ($res.error) { (& $ctl 'InvVacio').Text = "No se pudo relevar el inventario: $($res.error)"; return }
    Update-InventarioPanel -Window $win -Inv $res.inv
    $script:invCargado = $true
  })
  $script:invTimer.Start()
}
(& $ctl 'ChipInventario').Add_Checked([System.Windows.RoutedEventHandler]{ Start-InventarioCarga })

(& $ctl 'LnkCambiarTipo').Add_MouseLeftButtonUp({
  $script:tipoActual = if ($script:tipoActual -eq 'servidores') { 'terminales' } else { 'servidores' }
  (& $ctl 'LblTipo').Text = if ($script:tipoActual -eq 'servidores') { 'Servidor' } else { 'Terminal' }
  (& $ctl 'LblTipoDetalle').Text = 'override manual'
  (& $ctl 'LblRelevar').Text = Get-RelevarLabel $script:tipoActual
  Update-UsuarioVisibilidad $script:tipoActual
  Update-MantVista $script:tipoActual
})

(& $ctl 'BtnExaminar').Add_Click({
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  if ($dlg.ShowDialog() -eq 'OK') { (& $ctl 'TxtSalida').Text = $dlg.SelectedPath }
})

(& $ctl 'BtnAbrirSalidas').Add_Click({
  $dir = Get-MantDir -Path (& $ctl 'TxtSalida').Text
  Start-Process explorer.exe $dir
})

(& $ctl 'BtnRelevar').Add_Click({
  $val = Test-IdentificacionValida -Tag (& $ctl 'TxtTag').Text -Cliente (& $ctl 'TxtCliente').Text
  if (-not $val.ok) { [System.Windows.MessageBox]::Show($val.mensaje, 'STI'); return }

  $coreDir = (Resolve-Path (Join-Path $scriptDir '..')).Path
  # NO usar $args: es variable automatica de PowerShell (array de argumentos). Usar $mantArgs.
  $mantArgs = New-GuiMantArgs -Tag (& $ctl 'TxtTag').Text -Cliente (& $ctl 'TxtCliente').Text `
            -Usuario (& $ctl 'TxtUsuario').Text -Nota (& $ctl 'TxtObservaciones').Text -ScriptDir $coreDir
  $ctx = New-MantContext @mantArgs -Tecnico (& $ctl 'TxtTecnico').Text
  $salida = (& $ctl 'TxtSalida').Text
  $tipo = $script:tipoActual

  # El runspace de fondo arranca con el core ya inyectado via InitialSessionState
  # (Start-RelevamientoAsync -> New-CoreInitialSessionState): no dot-sourcea por ruta, asi funciona
  # tanto en dev como en el dist single-file (donde no hay carpeta lib/ al lado). $coreDir se pasa
  # por compatibilidad de firma; ya no se usa para cargar el core.
  $script:job = Start-RelevamientoAsync -Ctx $ctx -Tipo $tipo -ScriptDir $coreDir
  $script:ctxRelev = $ctx; $script:tipoRelev = $tipo; $script:salidaRelev = $salida
  Show-Panel 'PanelEjecucion'
  (& $ctl 'TxtEstadoRelev').Text = 'relevando'

  # El timer es $script:-scoped: el scriptblock del tick corre despues de que Add_Click retorno,
  # asi que una variable local del handler ya no existe (era el bug de "$timer null" en Stop).
  $script:timer = New-Object System.Windows.Threading.DispatcherTimer
  $script:timer.Interval = [TimeSpan]::FromMilliseconds(200)
  $script:timer.Add_Tick({
    $msg = Get-RelevamientoProgreso -Job $script:job
    if ($msg) { (& $ctl 'TxtEstadoRelev').Text = $msg }
    $r = Receive-RelevamientoResult -Job $script:job
    if ($r.done) {
      $script:timer.Stop()
      if ($r.error) {
        (& $ctl 'ProgRelev').IsIndeterminate = $false
        (& $ctl 'TxtEstadoRelev').Text = "error: $($r.error)"
        return
      }
      # carpeta de salida: New-MetaExport usa Get-MantDir (default C:\zback). Para respetar TxtSalida,
      # se setea el default via Get-MantDir antes; en Fase 1 se usa la carpeta del campo.
      [void](Get-MantDir -Path $script:salidaRelev)
      $jsonPath = New-MetaExport -Ctx $script:ctxRelev -Rel $r.rel -Tipo $script:tipoRelev
      # Relevamiento OK: habilitar las tabs Inventario/Mantenimiento/Utilidades/Generar.
      Enable-TabsPostRelevamiento
      (& $ctl 'ProgRelev').IsIndeterminate = $false
      (& $ctl 'ProgRelev').Value = 100
      $items = @($r.rel.items).Count
      (& $ctl 'TxtEstadoRelev').Text = "listo · $items checks · JSON: $jsonPath"
      foreach ($m in $r.rel.modules) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "$($m.category): $(@($m.items).Count) items"
        $tb.Foreground = 'White'; $tb.FontFamily = 'DM Mono, Consolas'; $tb.FontSize = 11
        (& $ctl 'ListaModulos').Items.Add($tb)
      }
      # Guardar el resultado para que Generar JSON pueda incluir hardwareIds + meta.
      $script:relResult = $r.rel
      # Poblar la tab Mantenimiento con los checks relevados (cruce catalogo + items).
      $cat   = Get-MantCheckCatalog -Tipo $script:tipoRelev
      $filas = ConvertTo-MantFilas -Catalogo $cat -Items @($r.rel.items)
      $res   = Get-MantResumen -Filas $filas
      Update-MantenimientoPanel -Window $win -Filas $filas -Resumen $res -Tipo $script:tipoRelev
    }
  })
  $script:timer.Start()
})

# Generar JSON del equipo (spec 6.11): junta el estado vivo del panel (manuales + observaciones) y
# serializa con ConvertTo-MantJson al JSON de ESTE equipo en la carpeta de salida. NO arma la planilla:
# la planilla se construye al final, en la tab Generar, cuando estan todos los JSON de todos los equipos.
(& $ctl 'BtnGenerarMant').Add_Click({
  $filas = Get-MantPanelFilas -Window $win
  if (-not $filas) { [System.Windows.MessageBox]::Show('Relevá el equipo antes de generar el JSON.', 'STI'); return }
  $tipoMant = Get-MantPanelTipo -Window $win

  # Ctx para el JSON: identificacion + os/formFactor + hardwareIds del ultimo relevamiento (si hubo).
  $coreDir = (Resolve-Path (Join-Path $scriptDir '..')).Path
  $jsonArgs = New-GuiMantArgs -Tag (& $ctl 'TxtTag').Text -Cliente (& $ctl 'TxtCliente').Text `
            -Usuario (& $ctl 'TxtUsuario').Text -Nota (& $ctl 'TxtObservaciones').Text -ScriptDir $coreDir
  $ctxJson = New-MantContext @jsonArgs -Tecnico (& $ctl 'TxtTecnico').Text
  if ($script:relResult -and $script:relResult.hw) { $ctxJson.hw = $script:relResult.hw }

  # Avisar (no bloquear) si quedan manuales sin marcar.
  $pend = @($filas | Where-Object { (-not $_.automated) -and ($null -eq (Resolve-MantEstadoEfectivo $_)) }).Count
  if ($pend -gt 0) {
    $resp = [System.Windows.MessageBox]::Show("Quedan $pend checks manuales sin marcar. ¿Generar igual?", 'STI', 'YesNo', 'Warning')
    if ($resp -ne 'Yes') { return }
  }

  $obj = ConvertTo-MantJson -Filas $filas -Ctx $ctxJson -Tipo $tipoMant
  $dir = Get-MantDir -Path (& $ctl 'TxtSalida').Text
  $hostOut = if ($obj.meta.hostname) { $obj.meta.hostname } else { $env:COMPUTERNAME }
  $stamp = Get-Date -Format 'yyyyMMdd'
  $out = Join-Path $dir "${hostOut}_STI_MANT_${tipoMant}_${stamp}.json"
  ($obj | ConvertTo-Json -Depth 8) | Out-File -FilePath $out -Encoding UTF8
  [System.Windows.MessageBox]::Show("JSON generado: $out", 'STI')
})

(& $ctl 'BtnInstalarOcs').Add_Click({ [System.Windows.MessageBox]::Show('Instalar OCS requiere red. Disponible en una fase siguiente.', 'STI') })
(& $ctl 'BtnInforme').Add_Click({ [System.Windows.MessageBox]::Show('Informe local: disponible en una fase siguiente.', 'STI') })

# Tab Utilidades: detectar el estado REAL (read-only: registro/servicios/appx) y poblar el catalogo.
# Los detectores no mutan nada (Get-StiUtilDeteccionReal/Get-StiUtilListadosReal). Las acciones que
# mutan el equipo se despachan (Invoke-StiUtilBatch: checkpoint best-effort + auditoria) solo ante
# "Aplicar cambios", con aviso previo.
#
# UX: el scan corre EN EL HILO UI (no en un runspace). Los 38 detectores son lecturas rapidas de
# registro/servicios/appx (~1-2s); no justifican un runspace async, que ademas rompia el puente del
# scan: al cruzar el runspace los hashtables anidados volvian como PSCustomObject sin .ContainsKey, asi
# que Resolve-StiUtilEstado caia a 'disponible' (toggle OFF) para todo y el toggle nunca reflejaba el
# estado real. Corriendo Get-StiUtilDeteccionReal/Get-StiUtilListadosReal en el hilo UI (con la barra de
# progreso breve ya existente) el detector probado funciona tal cual y los toggles arrancan en el estado
# REAL del equipo. El apply de acciones SI sigue async (streaming), que es donde el async aporta.
# Al volver: repuebla los toggles con el estado REAL detectado (sin etiqueta "Aplicada/Revertida": el
# toggle ES el estado actual) y refresca el panel de log interno. El scan queda auditado (accion 'scan').
# El refresco del log se hace en cada apertura de tab, tras cada apply/undo y con el boton Refrescar.

# Refresca el panel de log interno leyendo el JSON-lines de auditoria (no bloquea: es lectura local).
function Update-StiUtilLog {
  try { Update-StiUtilLogPanel -Window $win -Count 25 } catch {}
}

$utilScan = {
  (& $ctl 'TxtUtilResumen').Text = 'Escaneando estado del equipo...'
  $prog = (& $ctl 'ProgUtil')
  if ($prog) { $prog.Visibility = 'Visible'; $prog.IsIndeterminate = $true }
  # Forzar a pintar el "Escaneando..." y la barra antes de la lectura sincrona (sin congelar visualmente).
  try { $win.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render) } catch {}
  # Lectura read-only directa en el hilo UI: los detectores ya probados devuelven hashtables con
  # .ContainsKey utilizables por Resolve-StiUtilEstado (toggle ON = feature presente). Tolerante a fallo.
  $estados = @{}; $scanErr = $null
  try { $estados = Get-StiUtilDeteccionReal } catch { $scanErr = $_.Exception.Message }
  $listados = @{}; try { $listados = Get-StiUtilListadosReal } catch {}
  if (-not $estados) { $estados = @{} }
  if (-not $listados) { $listados = @{} }
  # Sin badges en la card: el toggle muestra el estado REAL y el historial vive en el panel de log.
  Update-UtilidadesPanel -Window $win -Estados $estados -Listados $listados
  $aplic = @($estados.Values | Where-Object { $_.estado -eq 'aplicado' }).Count
  $scanRes = if ($scanErr) { "error: $scanErr" } else { 'ok' }
  try { Write-StiAudit -Accion 'scan' -Resultado $scanRes -Mensaje "escaneo de utilidades · $aplic features activas" -Tecnico (& $ctl 'TxtTecnico').Text | Out-Null } catch {}
  Update-StiUtilLog
  $prog = (& $ctl 'ProgUtil')
  if ($prog) { $prog.IsIndeterminate = $false; $prog.Visibility = 'Collapsed' }
}
# Config de la tab (FIX 2): ScriptDir para los runspaces de streaming de "Aplicar" + el re-escaneo a
# correr al terminar cada accion (refresca toggles al estado real + log). La leen los botones "Aplicar" de las
# acciones via Invoke-StiUtilAccionDesdeClick.
Set-StiUtilCfg -Window $win -ScriptDir $scriptDir -OnRescan ([scriptblock]{ & $utilScan }.GetNewClosure())
# Scan AL ABRIR la tab Utilidades (la primera vez y en cada re-entrada): el toggle siempre refleja el
# estado real detectado, no un click recordado. Tambien se corre una vez al iniciar para precalentar.
(& $ctl 'ChipUtilidades').Add_Checked([System.Windows.RoutedEventHandler]{ & $utilScan }.GetNewClosure())
(& $ctl 'BtnUtilReescanear').Add_Click($utilScan)
Update-StiUtilLog
(& $ctl 'BtnUtilLogRefrescar').Add_Click({ Update-StiUtilLog })
(& $ctl 'BtnUtilLogAbrir').Add_Click({
  try { $d = Get-StiAuditDir; if (-not (Test-Path $d)) { Initialize-StiAuditStore | Out-Null }; Start-Process explorer.exe $d } catch {}
})
# Preset STI: marca los ids del preset como pendientes (no aplica nada; el tecnico confirma).
(& $ctl 'BtnUtilPreset').Add_Click({
  $p = Get-StiUtilPendientes -Window $win
  foreach ($id in (Get-StiUtilPreset)) { $p[$id] = 'aplicar' }
  Update-StiUtilPendientesUI -Window $win
  [System.Windows.MessageBox]::Show('Preset STI marcado. Revisá y confirmá con "Aplicar cambios".', 'STI')
})
# Aplicar cambios: ejecuta el batch de pendientes sobre el equipo (muta) con red de seguridad
# (Invoke-StiUtilBatch: punto de restauracion best-effort + auditoria por accion). Confirmacion
# explicita. Tras aplicar, & $utilScan re-escanea (refresca toggles al estado real y panel de log).
(& $ctl 'BtnUtilAplicar').Add_Click({
  $p = Get-StiUtilPendientes -Window $win
  $n = @($p.Keys).Count
  if ($n -eq 0) { [System.Windows.MessageBox]::Show('No hay cambios marcados.', 'STI'); return }
  $resp = [System.Windows.MessageBox]::Show("Se aplicarán $n cambios sobre este equipo. Se intentará un punto de restauración y se registrará todo en $(Get-StiUtilLogPath). ¿Continuar?", 'STI', 'YesNo', 'Warning')
  if ($resp -ne 'Yes') { return }
  $batch = Invoke-StiUtilBatch -Pendientes $p
  $p.Clear()
  & $utilScan
  $cp = if ($batch.persistente) { if ($batch.checkpoint) { 'Punto de restauración creado.' } else { 'Punto de restauración no disponible (server o System Restore off).' } } else { 'Sin punto de restauración (solo limpieza/reparaciones).' }
  [System.Windows.MessageBox]::Show("Cambios aplicados. $cp Log: $(Get-StiUtilLogPath). Estado re-escaneado.", 'STI')
})
# Revertir aplicadas: marca como 'revertir' las features reversibles hoy activas.
(& $ctl 'BtnUtilRevertir').Add_Click({
  $estados = @{}; try { $estados = Get-StiUtilDeteccionReal } catch {}
  $p = Get-StiUtilPendientes -Window $win
  foreach ($item in (Get-StiUtilCatalogo)) {
    if ($item.reversible -and $estados.ContainsKey($item.id) -and $estados[$item.id].estado -eq 'aplicado') {
      $p[$item.id] = 'revertir'
    }
  }
  Update-StiUtilPendientesUI -Window $win
  [System.Windows.MessageBox]::Show('Reversiones marcadas. Confirmá con "Aplicar cambios".', 'STI')
})

# ---- Tab Generar (consolidacion local de JSONs) ----
# Recalcula la deteccion leyendo la carpeta y la pinta. Pura + Update-GenerarPanel (runtime).
function Update-GenerarDeteccion {
  $carpeta = (& $ctl 'TxtGenCarpeta').Text
  $seg = Get-GenerarSegFromWindow -Window $win
  $script:genItems = @(Get-JsonsDeCarpeta -Carpeta $carpeta)
  $det = Resolve-DeteccionGenerar -Items $script:genItems -Seg $seg
  Update-GenerarPanel -Window $win -Deteccion $det
}
(& $ctl 'BtnGenExaminar').Add_Click({
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  if ($dlg.ShowDialog() -eq 'OK') { (& $ctl 'TxtGenCarpeta').Text = $dlg.SelectedPath; Update-GenerarDeteccion }
})
foreach ($c in @('ChipGenTerm','ChipGenSrv','ChipGenBoth')) {
  (& $ctl $c).Add_Checked([System.Windows.RoutedEventHandler]{ if ($script:genItems) { Update-GenerarDeteccion } })
}
(& $ctl 'BtnGenPlanilla').Add_Click({
  $carpeta = (& $ctl 'TxtGenCarpeta').Text
  if (-not $script:genItems -or @($script:genItems).Count -eq 0) { [System.Windows.MessageBox]::Show('Elegí una carpeta con JSONs primero.', 'STI'); return }
  $seg = Get-GenerarSegFromWindow -Window $win
  $html = New-PlanillaHtml -Items $script:genItems -Cliente (& $ctl 'TxtGenCliente').Text -Periodo (& $ctl 'TxtGenPeriodo').Text -Seg $seg
  $out = Save-GenerarHtml -Html $html -Carpeta $carpeta -Nombre ('STI_Planilla_{0}.html' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  Start-Process $out
})
(& $ctl 'BtnGenInforme').Add_Click({
  $carpeta = (& $ctl 'TxtGenCarpeta').Text
  if (-not $script:genItems -or @($script:genItems).Count -eq 0) { [System.Windows.MessageBox]::Show('Elegí una carpeta con JSONs primero.', 'STI'); return }
  $seg = Get-GenerarSegFromWindow -Window $win
  $html = New-InformeLocalHtml -Items $script:genItems -Cliente (& $ctl 'TxtGenCliente').Text -Periodo (& $ctl 'TxtGenPeriodo').Text -Seg $seg
  $out = Save-GenerarHtml -Html $html -Carpeta $carpeta -Nombre ('STI_Informe_local_{0}.html' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  Start-Process $out
})

[void]$win.ShowDialog()
