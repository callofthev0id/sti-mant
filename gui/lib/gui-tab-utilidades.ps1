# gui/lib/gui-tab-utilidades.ps1 - tab Utilidades (caja de herramientas estilo winutil).
# Esta tab ESCRIBE sobre el equipo (limpieza/reparaciones/tweaks/debloat/servicios). NO releva,
# NO toca el JSON ni New-MetaExport (spec 7.1). Aca vive la LOGICA PURA (catalogo como datos,
# shaping de estado, armado de listas), los DETECTORES read-only (consultan registro/servicios sin
# mutar) y el XAML/UI del panel. Las ACCIONES que mutan el equipo (Invoke-/Undo-) se despachan desde
# aca pero solo se ejecutan ante un click real del tecnico; en los tests no se invocan.

# Catalogo completo de utilidades (spec 7.9), como DATOS. No contiene comandos a ejecutar: es
# metadata. categoria in limpieza|reparaciones|tweaks|debloat|servicios. tipo in toggle|accion|
# listado|aviso. delicado = punto naranja (7.4). preset = entra en el preset recomendado (7.6, excluye delicados).
#
# Semantica del toggle (FIX feedback): el toggle en "si"/verde significa que la FEATURE/SERVICIO esta
# HABILITADO en el equipo, no que la accion fue aplicada. Por eso los items que apagan algo declaran
# 'feature' (lo que el toggle refleja: Fast Startup ON, telemetria ON, DiagTrack corriendo) y un
# 'sentidoOn' que dice si "feature ON" coincide con "lo que se recomienda" (acordToggle):
#   sentidoOn='feature' -> toggle ON = la feature esta presente (ej Dark mode ON = dark activo).
#   sentidoOn='presente'-> idem, pero apagarlo es la accion recomendada (ej Fast Startup ON = activo,
#                          se recomienda apagarlo; el toggle ON refleja el estado REAL, no la accion).
function Get-UtilCatalogo {
  @(
    # Limpieza (accion puntual, muestra tamano recuperable)
    @{ id='temp';        categoria='limpieza'; nombre='Temporales y %TEMP%';       tipo='accion'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='wucache';     categoria='limpieza'; nombre='Cache Windows Update';      tipo='accion'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='papelera';    categoria='limpieza'; nombre='Papelera de reciclaje';     tipo='accion'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='cachenav';    categoria='limpieza'; nombre='Cache de navegadores';      tipo='accion'; delicado=$false; reversible=$false; preset=$true; aviso='Cerra Chrome/Edge/Firefox antes de limpiar: con el navegador abierto el cache esta bloqueado y la limpieza queda a medias.' }
    @{ id='logsdumps';   categoria='limpieza'; nombre='Logs y dumps';              tipo='accion'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='winsxs';      categoria='limpieza'; nombre='WinSxS cleanup (DISM)';     tipo='accion'; delicado=$true;  reversible=$false; preset=$false }
    @{ id='colaimp';     categoria='limpieza'; nombre='Cola de impresion';         tipo='accion'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='prefetch';    categoria='limpieza'; nombre='Prefetch';                  tipo='accion'; delicado=$false; reversible=$false; preset=$false }

    # Reparaciones (accion puntual, ejecuta y reporta)
    @{ id='sfc';         categoria='reparaciones'; nombre='SFC scannow';           tipo='accion'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='dism';        categoria='reparaciones'; nombre='DISM RestoreHealth';    tipo='accion'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='resetred';    categoria='reparaciones'; nombre='Reset de red + flush DNS'; tipo='accion'; delicado=$true;  reversible=$false; preset=$false; aviso='Reinicia la pila de red (netsh int ip reset). Puede CORTAR la sesion RDP/RMM. Correr en consola local; reiniciar el equipo al terminar.' }
    @{ id='repwu';       categoria='reparaciones'; nombre='Reparar Windows Update'; tipo='accion'; delicado=$false; reversible=$false; preset=$false }
    @{ id='reindex';     categoria='reparaciones'; nombre='Reconstruir indice de busqueda'; tipo='accion'; delicado=$false; reversible=$false; preset=$false }
    @{ id='chkdsk';      categoria='reparaciones'; nombre='chkdsk';                tipo='accion'; delicado=$false; reversible=$false; preset=$false }
    @{ id='wsreset';     categoria='reparaciones'; nombre='Reset de Windows Store'; tipo='accion'; delicado=$false; reversible=$false; preset=$false }
    @{ id='winsock';     categoria='reparaciones'; nombre='Reset de Winsock / TCP-IP'; tipo='accion'; delicado=$true;  reversible=$false; preset=$false; aviso='Reinicia el catalogo Winsock (netsh winsock reset). Puede CORTAR la sesion RDP/RMM. Correr en consola local; reiniciar el equipo al terminar.' }
    @{ id='iconcache';   categoria='reparaciones'; nombre='Reconstruir icon cache'; tipo='accion'; delicado=$false; reversible=$false; preset=$false }

    # Tweaks (estado real detectado, reversibles salvo aviso). El toggle refleja el estado REAL del
    # registro: "si" = la feature esta activa hoy. La accion (aplicar/revertir) la decide el tecnico.
    @{ id='ctxclasico';  categoria='tweaks'; nombre='Menu contextual clasico';     tipo='toggle'; delicado=$false; reversible=$true;  preset=$true;  feature='Menu contextual clasico' }
    @{ id='telemetria';  categoria='tweaks'; nombre='Telemetria de Windows';       tipo='toggle'; delicado=$false; reversible=$true;  preset=$true;  feature='Telemetria activa'; sentidoOn='presente' }
    @{ id='darkmode';    categoria='tweaks'; nombre='Dark mode';                   tipo='toggle'; delicado=$false; reversible=$true;  preset=$false; feature='Tema oscuro' }
    @{ id='visorfotos';  categoria='tweaks'; nombre='Visor de fotos clasico';      tipo='toggle'; delicado=$false; reversible=$true;  preset=$false; feature='Visor clasico asociado' }
    @{ id='extocultos';  categoria='tweaks'; nombre='Mostrar extensiones y ocultos'; tipo='toggle'; delicado=$false; reversible=$true;  preset=$true;  feature='Extensiones/ocultos visibles' }
    @{ id='faststartup'; categoria='tweaks'; nombre='Fast Startup';                tipo='toggle'; delicado=$true;  reversible=$true;  preset=$false; feature='Fast Startup activo'; sentidoOn='presente' }
    @{ id='energia';     categoria='tweaks'; nombre='Plan energia alto rendimiento'; tipo='toggle'; delicado=$false; reversible=$true;  preset=$true;  feature='Plan alto rendimiento activo' }
    @{ id='esteequipo';  categoria='tweaks'; nombre='Mostrar Este equipo en escritorio'; tipo='toggle'; delicado=$false; reversible=$true;  preset=$false; feature='Icono Este equipo visible' }
    @{ id='bingcortana'; categoria='tweaks'; nombre='Bing/Cortana en busqueda';    tipo='toggle'; delicado=$false; reversible=$true;  preset=$true;  feature='Bing en busqueda activo'; sentidoOn='presente' }

    # Debloat / Desinstalacion (no reinstala)
    @{ id='bloatware';   categoria='debloat'; nombre='Bloatware (juegos, promo)';  tipo='listado'; delicado=$false; reversible=$false; preset=$true  }
    @{ id='copilot';     categoria='debloat'; nombre='Copilot / Cortana';          tipo='toggle';  delicado=$false; reversible=$false; preset=$true;  feature='Copilot presente'; sentidoOn='presente' }
    @{ id='teamsper';    categoria='debloat'; nombre='Teams personal';             tipo='toggle';  delicado=$false; reversible=$false; preset=$true;  feature='Teams personal instalado'; sentidoOn='presente' }
    @{ id='onedrive';    categoria='debloat'; nombre='OneDrive';                   tipo='aviso';   delicado=$true;  reversible=$false; preset=$false }
    @{ id='widgets';     categoria='debloat'; nombre='Widgets de Windows 11';      tipo='toggle';  delicado=$false; reversible=$false; preset=$true;  feature='Widgets activos'; sentidoOn='presente' }
    @{ id='edgedebloat'; categoria='debloat'; nombre='Edge sidebar';              tipo='toggle';  delicado=$false; reversible=$false; preset=$false; feature='Sidebar de Edge activo'; sentidoOn='presente' }
    @{ id='appsoem';     categoria='debloat'; nombre='Apps OEM del fabricante';    tipo='listado'; delicado=$true;  reversible=$false; preset=$false }

    # Servicios / Inicio (listado, seleccion por popover). Los toggles reflejan estado real del servicio.
    @{ id='diagtrack';   categoria='servicios'; nombre='Servicio DiagTrack';       tipo='toggle';  delicado=$false; reversible=$true;  preset=$true;  feature='DiagTrack corriendo'; sentidoOn='presente' }
    @{ id='appsinicio';  categoria='servicios'; nombre='Apps de inicio';           tipo='listado'; delicado=$false; reversible=$false; preset=$false }
    @{ id='servinnec';   categoria='servicios'; nombre='Servicios innecesarios';   tipo='listado'; delicado=$false; reversible=$false; preset=$false }
    @{ id='xbox';        categoria='servicios'; nombre='Xbox services';            tipo='toggle';  delicado=$true;  reversible=$true;  preset=$false; feature='Servicios Xbox activos'; sentidoOn='presente' }
    @{ id='tareastele';  categoria='servicios'; nombre='Tareas telemetria';        tipo='listado'; delicado=$false; reversible=$false; preset=$false }
  )
}

# Categorias en orden de presentacion (spec 7.2) con su etiqueta de naturaleza (.ch .n).
function Get-UtilCategorias {
  @(
    @{ id='limpieza';     titulo='Limpieza';                 nat='accion puntual' }
    @{ id='reparaciones'; titulo='Reparaciones';             nat='accion puntual' }
    @{ id='tweaks';       titulo='Tweaks';                   nat='estado real detectado' }
    @{ id='debloat';      titulo='Debloat / Desinstalacion'; nat='no reinstala' }
    @{ id='servicios';    titulo='Servicios / Inicio';       nat='listado' }
  )
}

# Items del catalogo de una categoria (mapeo categoria->items).
function Get-UtilPorCategoria {
  param([string]$Categoria)
  @(Get-UtilCatalogo | Where-Object { $_.categoria -eq $Categoria })
}

# Normaliza el estado detectado de un item a las tres clases del spec 7.3.
# $Deteccion es { estado = 'aplicado'|'disponible'|'no-aplica'; dato = '1.2 GB' }. Puede venir de un
# FIXTURE (tests) o del detector real (Get-UtilDeteccionReal). NO corre nada: solo da forma al dato
# para la UI. Devuelve estado + display + clase de color.
function Resolve-UtilEstado {
  param([hashtable]$Item, [hashtable]$Deteccion)
  $estado = if ($Deteccion -and $Deteccion.ContainsKey('estado')) { [string]$Deteccion.estado } else { 'disponible' }
  $dato   = if ($Deteccion -and $Deteccion.ContainsKey('dato'))   { [string]$Deteccion.dato }   else { '' }
  switch ($estado) {
    'aplicado'  { $clase = 's-on'; $display = if ($dato) { $dato } else { 'aplicado' } }
    'no-aplica' { $clase = 's-na'; $display = if ($dato) { $dato } else { 'no aplica' } }
    default     { $estado = 'disponible'; $clase = 's-off'; $display = if ($dato) { $dato } else { 'no' } }
  }
  @{ id = $Item.id; estado = $estado; display = $display; clase = $clase }
}

# Conteos para la barra .scan (spec 7.3): aplicadas / disponibles / no aplican.
# $Estados es el array de salidas de Resolve-UtilEstado.
function Get-UtilResumen {
  param([object[]]$Estados)
  $aplicadas    = @($Estados | Where-Object { $_.estado -eq 'aplicado' }).Count
  $disponibles  = @($Estados | Where-Object { $_.estado -eq 'disponible' }).Count
  $noaplican    = @($Estados | Where-Object { $_.estado -eq 'no-aplica' }).Count
  @{ aplicadas = $aplicadas; disponibles = $disponibles; noaplican = $noaplican;
     texto = "Estado detectado al abrir · $aplicadas aplicadas · $disponibles disponibles · $noaplican no aplican" }
}

# NOTA (FIX UX): se eliminaron las etiquetas "Aplicada/Revertida" de la UI. El usuario NO quiere
# badges permanentes en la card: el estado del equipo se ve directo en el toggle (estado real) y el
# rastro de "ya se ejecuto" vive en el panel de log interno y en la auditoria (Event Log + JSON +
# texto), no como una etiqueta que parezca el estado actual. Por eso se quitaron las funciones de
# badge de la card: la card es estado-real-o-accion, sin historial pegado.

# Ids del preset recomendado (spec 7.6): los marcados preset=$true, excluyendo delicados (decision conservadora).
function Get-UtilPreset {
  @(Get-UtilCatalogo | Where-Object { $_.preset -and -not $_.delicado } | ForEach-Object { $_.id })
}

# Normaliza un elemento detectado de un listado (apps de inicio, servicios, bloatware, tareas) para el
# popover (spec 7.8). $Raw es un fixture { nombre; ubicacion; impacto }. Clasifica el badge de impacto.
function Format-PopoverItem {
  param([hashtable]$Raw)
  $imp = if ($Raw.ContainsKey('impacto')) { [string]$Raw.impacto } else { 'bajo' }
  switch ($imp) {
    'alto'  { $clase = 'i-hi' }
    'medio' { $clase = 'i-md' }
    default { $imp = 'bajo'; $clase = 'i-lo' }
  }
  @{ nombre    = [string]$Raw.nombre
     ubicacion = [string]$Raw.ubicacion
     impacto   = $imp
     clase     = $clase }
}

# ============================================================================================
# DETECTORES READ-ONLY (FIX 1). Cada uno consulta el estado REAL del equipo SIN mutar nada
# (Get-ItemProperty / Get-Service / Get-AppxPackage). Devuelve { estado; dato } consumible por
# Resolve-UtilEstado. Para items toggle: estado='aplicado' cuando la feature esta presente (toggle
# ON), 'disponible' cuando no. Tolerantes a fallo: ante excepcion devuelven 'disponible'.

# Helper: lee un valor de registro sin tirar si la clave/valor no existe.
function Get-RegValor {
  param([string]$Path, [string]$Name)
  try {
    $p = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
    return $p.$Name
  } catch { return $null }
}

# Helper: estado de un servicio por nombre. Devuelve 'running'|'stopped'|'disabled'|$null (no existe).
function Get-ServicioEstado {
  param([string]$Name)
  try {
    $s = Get-Service -Name $Name -ErrorAction Stop
    $startup = $null
    try { $startup = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction Stop).StartMode } catch {}
    if ($startup -eq 'Disabled') { return 'disabled' }
    if ($s.Status -eq 'Running') { return 'running' }
    return 'stopped'
  } catch { return $null }
}

# Detector por item. $Item es la entrada del catalogo. Devuelve { estado; dato }.
# Las acciones puntuales (limpieza/reparaciones) no tienen estado persistente: quedan 'disponible'
# (con un dato neutro). Los toggles reflejan la feature real.
function Test-Util {
  param([hashtable]$Item)
  $on  = @{ estado = 'aplicado';   dato = 'si' }
  $off = @{ estado = 'disponible'; dato = 'no' }
  try {
    switch ($Item.id) {
      # --- Tweaks (registro) ---
      'ctxclasico' {
        $v = Get-RegValor 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(default)'
        if ($null -ne $v) { return @{ estado='aplicado'; dato='clasico' } } else { return @{ estado='disponible'; dato='Win11' } }
      }
      'telemetria' {
        $v = Get-RegValor 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
        if ($null -ne $v -and [int]$v -eq 0) { return @{ estado='disponible'; dato='apagada' } }
        return @{ estado='aplicado'; dato='activa' }
      }
      'darkmode' {
        $v = Get-RegValor 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme'
        if ($null -ne $v -and [int]$v -eq 0) { return $on } else { return $off }
      }
      'visorfotos' {
        $v = Get-RegValor 'HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations' '.jpg'
        if ($null -ne $v) { return @{ estado='aplicado'; dato='asociado' } } else { return $off }
      }
      'extocultos' {
        $ext = Get-RegValor 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt'
        $hid = Get-RegValor 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden'
        if (($null -ne $ext -and [int]$ext -eq 0) -and ($null -ne $hid -and [int]$hid -eq 1)) { return $on }
        return $off
      }
      'faststartup' {
        $v = Get-RegValor 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled'
        if ($null -eq $v -or [int]$v -eq 1) { return @{ estado='aplicado'; dato='activo' } }
        return @{ estado='disponible'; dato='apagado' }
      }
      'energia' {
        $hp = $false
        try { $hp = ((& powercfg /getactivescheme) -match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c') } catch {}
        if ($hp) { return @{ estado='aplicado'; dato='activo' } } else { return $off }
      }
      'esteequipo' {
        $v = Get-RegValor 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{20D04FE0-3AEA-1069-A2D8-08002B30309D}'
        if ($null -ne $v -and [int]$v -eq 0) { return @{ estado='aplicado'; dato='visible' } } else { return $off }
      }
      'bingcortana' {
        $v = Get-RegValor 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled'
        if ($null -ne $v -and [int]$v -eq 0) { return @{ estado='disponible'; dato='quitado' } }
        return @{ estado='aplicado'; dato='activo' }
      }
      # --- Debloat (appx / registro) ---
      'copilot' {
        $v = Get-RegValor 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
        if ($null -ne $v -and [int]$v -eq 1) { return @{ estado='disponible'; dato='quitado' } }
        return @{ estado='aplicado'; dato='presente' }
      }
      'teamsper' {
        $pkg = $null; try { $pkg = Get-AppxPackage -Name 'MicrosoftTeams' -ErrorAction Stop } catch {}
        if ($pkg) { return @{ estado='aplicado'; dato='instalado' } } else { return @{ estado='disponible'; dato='ausente' } }
      }
      'widgets' {
        $pkg = $null; try { $pkg = Get-AppxPackage -Name '*WebExperience*' -ErrorAction Stop } catch {}
        if ($pkg) { return @{ estado='aplicado'; dato='activos' } } else { return @{ estado='disponible'; dato='ausentes' } }
      }
      'edgedebloat' {
        $v = Get-RegValor 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HubsSidebarEnabled'
        if ($null -ne $v -and [int]$v -eq 0) { return @{ estado='disponible'; dato='off' } }
        return @{ estado='aplicado'; dato='activo' }
      }
      # --- Servicios ---
      'diagtrack' {
        $e = Get-ServicioEstado 'DiagTrack'
        if ($null -eq $e) { return @{ estado='no-aplica'; dato='no existe' } }
        if ($e -eq 'running') { return @{ estado='aplicado'; dato='corriendo' } }
        return @{ estado='disponible'; dato=$e }
      }
      'xbox' {
        $any = $false
        foreach ($svc in @('XblAuthManager','XblGameSave','XboxGipSvc','XboxNetApiSvc')) {
          $e = Get-ServicioEstado $svc
          if ($e -eq 'running') { $any = $true; break }
        }
        if ($any) { return @{ estado='aplicado'; dato='activos' } } else { return @{ estado='disponible'; dato='detenidos' } }
      }
      # --- OneDrive (aviso): detecta si esta en uso para informar al tecnico ---
      'onedrive' {
        $od = $null; try { $od = Get-Process -Name 'OneDrive' -ErrorAction Stop } catch {}
        if ($od) { return @{ estado='aplicado'; dato='en uso' } } else { return @{ estado='disponible'; dato='ausente' } }
      }
      default {
        # Limpieza/reparaciones (accion puntual) y listados: sin estado persistente.
        if ($Item.tipo -eq 'listado') { return @{ estado='disponible'; dato='elegir' } }
        return @{ estado='disponible'; dato='disp.' }
      }
    }
  } catch {
    return @{ estado='disponible'; dato='' }
  }
}

# Corre TODOS los detectores read-only y devuelve un hashtable id -> { estado; dato }, listo para
# pasar a Update-UtilidadesPanel. Solo LEE (registro/servicios/appx). Pensado para correr en background
# (runspace) al abrir la tab y al Re-escanear; no muta nada.
function Get-UtilDeteccionReal {
  $out = @{}
  foreach ($item in (Get-UtilCatalogo)) {
    $out[$item.id] = Test-Util -Item $item
  }
  $out
}

# Detectores de LISTADO read-only (FIX 4, spec 7.8). Devuelven el listado REAL del equipo para los
# popovers "elegir...": cada elemento es { nombre; ubicacion; impacto }. Solo LEEN (registro/servicios/
# appx/tareas). Tolerantes a fallo: ante excepcion devuelven array vacio. Get-UtilListadosReal
# arma el hashtable id -> array que consume Update-UtilidadesPanel/New-UtilPopover.

# Apps de inicio: claves Run (HKLM/HKCU) + carpetas Startup. Impacto heuristico por nombre.
function Get-ListadoAppsInicio {
  $out = @()
  $runKeys = @(
    @{ path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; et = 'HKLM\...\Run' }
    @{ path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; et = 'HKCU\...\Run' }
  )
  foreach ($rk in $runKeys) {
    try {
      $p = Get-ItemProperty -Path $rk.path -ErrorAction Stop
      foreach ($pn in $p.PSObject.Properties.Name) {
        if ($pn -like 'PS*') { continue }
        $out += @{ nombre = $pn; ubicacion = "$($rk.et) · $($p.$pn)"; impacto = 'medio' }
      }
    } catch {}
  }
  foreach ($sf in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup","$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
    try {
      foreach ($f in (Get-ChildItem -Path $sf -File -ErrorAction Stop)) {
        $out += @{ nombre = $f.BaseName; ubicacion = "Startup folder · $($f.Name)"; impacto = 'bajo' }
      }
    } catch {}
  }
  $out
}

# Servicios innecesarios: subconjunto conocido (no esenciales) presente en el equipo. Impacto bajo.
function Get-ListadoServiciosInnec {
  $cand = @('Fax','RemoteRegistry','MapsBroker','RetailDemo','PhoneSvc','WMPNetworkSvc','dmwappushservice','WerSvc')
  $out = @()
  foreach ($n in $cand) {
    try {
      $s = Get-Service -Name $n -ErrorAction Stop
      $out += @{ nombre = $s.DisplayName; ubicacion = "Servicio · $n ($($s.Status))"; impacto = 'bajo' }
    } catch {}
  }
  $out
}

# Bloatware: AppxPackages que matchean patrones de promo/juegos. Impacto bajo.
function Get-ListadoBloatware {
  $pat = @('*king.com*','*CandyCrush*','*Xbox*','*ZuneMusic*','*ZuneVideo*','*BingNews*','*BingWeather*','*GetHelp*','*Getstarted*','*SolitaireCollection*','*MixedReality*','*Disney*','*Spotify*')
  $out = @()
  foreach ($p in $pat) {
    try {
      foreach ($pkg in (Get-AppxPackage -Name $p -ErrorAction SilentlyContinue)) {
        $out += @{ nombre = $pkg.Name; ubicacion = "Appx · $($pkg.PackageFullName)"; impacto = 'bajo' }
      }
    } catch {}
  }
  $out
}

# Apps OEM: AppxPackages cuyo Publisher no es Microsoft (fabricante). Impacto medio (algunas son utiles).
function Get-ListadoAppsOem {
  $out = @()
  try {
    foreach ($pkg in (Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Publisher -and $_.Publisher -notmatch 'Microsoft' })) {
      $out += @{ nombre = $pkg.Name; ubicacion = "Appx · $($pkg.Publisher)"; impacto = 'medio' }
    }
  } catch {}
  $out
}

# Tareas de telemetria: scheduled tasks de CEIP/Customer Experience/Application Experience. Impacto bajo.
function Get-ListadoTareasTele {
  $out = @()
  $paths = @('\Microsoft\Windows\Customer Experience Improvement Program\','\Microsoft\Windows\Application Experience\','\Microsoft\Windows\Autochk\')
  foreach ($tp in $paths) {
    try {
      foreach ($t in (Get-ScheduledTask -TaskPath $tp -ErrorAction Stop)) {
        $out += @{ nombre = $t.TaskName; ubicacion = "Tarea · $($t.TaskPath)$($t.State)"; impacto = 'bajo' }
      }
    } catch {}
  }
  $out
}

# Corre TODOS los detectores de listado y devuelve id -> array. Pensado para correr en background
# (runspace) junto con la deteccion. Solo LEE.
function Get-UtilListadosReal {
  @{
    appsinicio = @(Get-ListadoAppsInicio)
    servinnec  = @(Get-ListadoServiciosInnec)
    bloatware  = @(Get-ListadoBloatware)
    appsoem    = @(Get-ListadoAppsOem)
    tareastele = @(Get-ListadoTareasTele)
  }
}

# ============================================================================================
# RED DE SEGURIDAD (FIX 2, spec 7.7) + LOGGING DE AUDITORIA. Antes de aplicar cualquier batch que
# mute estado persistente (tweaks/servicios/debloat) se intenta un punto de restauracion
# (best-effort) y SIEMPRE se audita cada accion (scan/apply/undo/safety) via Write-Audit
# (lib/audit.ps1): Event Log del SO + JSON-lines + texto humano, con ACL restrictiva. El registro
# permite trazar y revertir a mano si algo sale mal. Limpieza/reparaciones solo se auditan.

# Ruta del log consultable que se muestra al tecnico. Apunta al texto humano del subsistema de
# auditoria (lib/audit.ps1). Si audit.ps1 no esta cargado (no deberia), cae a la ruta legacy.
function Get-UtilLogPath {
  if (Get-Command Get-AuditTextPath -ErrorAction SilentlyContinue) { return (Get-AuditTextPath) }
  'C:\zback\utilidades-log.txt'
}

# Wrapper de compatibilidad: las acciones de utilidades auditan via Write-Audit. Mantiene la
# firma vieja (Id/Modo/Antes/Despues/Resultado) y la traduce a un registro de auditoria. Modo
# 'aplicar'->apply, 'revertir'->undo, 'safety'->safety. Best-effort: no tira nunca.
function Write-UtilLog {
  param([string]$Id, [string]$Modo, [string]$Antes = '', [string]$Despues = '', [string]$Resultado = 'ok')
  try {
    $accion = switch ($Modo) { 'aplicar' { 'apply' } 'revertir' { 'undo' } 'safety' { 'safety' } default { 'apply' } }
    $cat = ''
    try { $cat = (Get-UtilCatalogo | Where-Object id -eq $Id | Select-Object -First 1).categoria } catch {}
    $label = ''
    try { $label = (Get-UtilCatalogo | Where-Object id -eq $Id | Select-Object -First 1).nombre } catch {}
    Write-Audit -Accion $accion -UtilId $Id -UtilLabel $label -Categoria $cat `
      -EstadoAnterior $Antes -EstadoNuevo $Despues -Resultado $Resultado | Out-Null
    return $true
  } catch { return $false }
}

# Intenta un punto de restauracion del sistema. En servidores System Restore suele estar
# deshabilitado: best-effort, devuelve $true/$false pero NUNCA tira ni aborta el batch (spec 7.7).
function New-UtilCheckpoint {
  param([string]$Descripcion = 'Utilidades - antes de aplicar')
  try {
    Checkpoint-Computer -Description $Descripcion -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    Write-UtilLog -Id '_checkpoint' -Modo 'safety' -Despues $Descripcion -Resultado 'ok' | Out-Null
    return $true
  } catch {
    Write-UtilLog -Id '_checkpoint' -Modo 'safety' -Resultado "fallo: $($_.Exception.Message)" | Out-Null
    return $false
  }
}

# Helper: escribe un valor de registro creando la clave si no existe. Lo usan las acciones de tweak.
function Set-RegValor {
  param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
  if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
  New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# Helper: borra un valor de registro si existe (para revertir un tweak a su default ausente).
function Remove-RegValor {
  param([string]$Path, [string]$Name)
  try { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop } catch {}
}

# Helper (FIX seguridad #4): ¿el proceso corre elevado (Administrador)? Las mutaciones de HKLM,
# Set-Service y DISM fallan en silencio (ErrorAction SilentlyContinue) sin privilegios y auditarian
# 'ok' sin haber mutado. Quien aplica una accion que requiere admin chequea esto antes y, si no esta
# elevado, reporta 'requiere admin' / 'error: sin privilegios' en vez de fingir exito.
function Test-UtilElevado {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return [bool]$pr.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  } catch { return $false }
}

# Ids cuyo comando muta HKLM / servicios / DISM y por lo tanto REQUIERE elevacion. Si el proceso no
# esta elevado, esas acciones se reportan como 'requiere admin' y NO se marcan 'ok'. Lo consumen
# Invoke-UtilAccion (no finge exito) y la UI (muestra el aviso).
function Get-UtilRequiereAdmin {
  @('winsxs','sfc','dism','resetred','repwu','reindex','chkdsk','winsock','telemetria','faststartup',
    'visorfotos','edgedebloat','diagtrack','xbox','wucache','colaimp')
}

# ¿El item id requiere admin? (helper de consulta sobre Get-UtilRequiereAdmin).
function Test-UtilRequiereAdmin {
  param([string]$Id)
  return ((Get-UtilRequiereAdmin) -contains $Id)
}

# ============================================================================================
# ACCIONES REALES (FIX 1/2/3). Mapeo util -> { aplicar; revertir } como TEXTO de scriptblock con el
# COMANDO REAL que muta el equipo. Es DATOS (testeable: cobertura del catalogo) y solo se ejecuta
# ante click real via Invoke-UtilAccion -> el batch (Invoke-UtilBatch) agrega checkpoint+log.
# Para los tweaks/servicios reversibles, 'aplicar' deja el estado recomendado y 'revertir'
# vuelve al estado por defecto de Windows; el detector read-only refleja el cambio al re-escanear.
function Get-UtilAcciones {
  @{
    # --- Limpieza (accion puntual, no reversible: borra cache/temp) ---
    temp      = @{ aplicar = 'Remove-Item "$env:TEMP\*","$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue' }
    wucache   = @{ aplicar = 'Stop-Service wuauserv -Force -ErrorAction SilentlyContinue; Remove-Item "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue; Start-Service wuauserv -ErrorAction SilentlyContinue' }
    papelera  = @{ aplicar = 'Clear-RecycleBin -Force -ErrorAction SilentlyContinue' }
    cachenav  = @{ aplicar = 'foreach ($nav in @(@{proc="chrome";  path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"}, @{proc="msedge"; path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"}, @{proc="firefox"; path="$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"})) { if (Get-Process -Name $nav.proc -ErrorAction SilentlyContinue) { Write-Output "OMITIDO: $($nav.proc) esta abierto, cerralo para limpiar su cache"; continue }; Remove-Item "$($nav.path)\*" -Recurse -Force -ErrorAction SilentlyContinue }' }
    logsdumps = @{ aplicar = 'Remove-Item "$env:WINDIR\Minidump\*","$env:LOCALAPPDATA\CrashDumps\*","$env:WINDIR\MEMORY.DMP" -Recurse -Force -ErrorAction SilentlyContinue' }
    winsxs    = @{ aplicar = 'Start-Process -FilePath dism.exe -ArgumentList "/Online","/Cleanup-Image","/StartComponentCleanup" -Wait -NoNewWindow' }
    colaimp   = @{ aplicar = 'Stop-Service spooler -Force -ErrorAction SilentlyContinue; Remove-Item "$env:WINDIR\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue; Start-Service spooler -ErrorAction SilentlyContinue' }
    prefetch  = @{ aplicar = 'Remove-Item "$env:WINDIR\Prefetch\*" -Force -ErrorAction SilentlyContinue' }
    # --- Reparaciones (accion puntual, no reversible) ---
    sfc       = @{ aplicar = 'Start-Process -FilePath sfc.exe -ArgumentList "/scannow" -Wait -NoNewWindow' }
    dism      = @{ aplicar = 'Start-Process -FilePath dism.exe -ArgumentList "/Online","/Cleanup-Image","/RestoreHealth" -Wait -NoNewWindow' }
    resetred  = @{ aplicar = 'ipconfig /flushdns | Out-Null; netsh int ip reset | Out-Null' }
    repwu     = @{ aplicar = 'foreach ($s in @("wuauserv","bits","cryptsvc")) { Stop-Service $s -Force -ErrorAction SilentlyContinue }; $sd = "$env:WINDIR\SoftwareDistribution"; if (Test-Path $sd) { $bak = "$sd.bak_" + (Get-Date -Format "yyyyMMddHHmmss"); try { Rename-Item -LiteralPath $sd -NewName (Split-Path $bak -Leaf) -ErrorAction Stop; if (-not (Test-Path $bak)) { throw "el rename de SoftwareDistribution no se confirmo" } } catch { foreach ($s in @("wuauserv","bits","cryptsvc")) { Start-Service $s -ErrorAction SilentlyContinue }; throw "Reparar WU abortado: $($_.Exception.Message)" } }; foreach ($s in @("wuauserv","bits","cryptsvc")) { Start-Service $s -ErrorAction SilentlyContinue }' }
    reindex   = @{ aplicar = 'Stop-Service WSearch -Force -ErrorAction SilentlyContinue; Set-RegValor "HKLM:\SOFTWARE\Microsoft\Windows Search" "SetupCompletedSuccessfully" 0; Start-Service WSearch -ErrorAction SilentlyContinue' }
    chkdsk    = @{ aplicar = 'Start-Process -FilePath chkdsk.exe -ArgumentList "/scan" -Wait -NoNewWindow' }
    wsreset   = @{ aplicar = 'Start-Process -FilePath wsreset.exe -Wait -NoNewWindow' }
    winsock   = @{ aplicar = 'netsh winsock reset | Out-Null' }
    iconcache = @{ aplicar = 'Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue; Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue' }

    # --- Tweaks (reversibles -> aplicar + revertir, comando real de registro/powercfg) ---
    ctxclasico  = @{
      aplicar = 'Set-RegValor "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "(default)" "" "String"'
      # MINOR (revert acotado): borrar SOLO la subclave InprocServer32 que creo "aplicar", no toda la
      # clave CLSID (podria tener otros subkeys ajenos). Si tras quitarla la clave padre quedo vacia, se
      # remueve tambien (sin -Recurse: falla si tiene hijos, lo que la preserva).
      revertir = 'Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force -ErrorAction SilentlyContinue; $k="HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"; if ((Test-Path $k) -and -not (Get-ChildItem $k -ErrorAction SilentlyContinue) -and -not (Get-Item $k).Property) { Remove-Item $k -Force -ErrorAction SilentlyContinue }' }
    telemetria  = @{
      aplicar = 'Set-RegValor "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0'
      revertir = 'Remove-RegValor "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"' }
    darkmode    = @{
      aplicar = 'Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0; Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0'
      revertir = 'Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1; Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 1' }
    visorfotos  = @{
      aplicar = 'foreach ($ext in @(".jpg",".jpeg",".png",".bmp",".gif")) { Set-RegValor "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" $ext "PhotoViewer.FileAssoc.Tiff" "String" }'
      revertir = 'foreach ($ext in @(".jpg",".jpeg",".png",".bmp",".gif")) { Remove-RegValor "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" $ext }' }
    extocultos  = @{
      aplicar = 'Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0; Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1'
      revertir = 'Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1; Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2' }
    faststartup = @{
      aplicar = 'Set-RegValor "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0'
      revertir = 'Set-RegValor "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1' }
    energia     = @{
      aplicar = 'powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null'
      revertir = 'powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null' }
    esteequipo  = @{
      aplicar = 'Set-RegValor "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" 0'
      revertir = 'Set-RegValor "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" 1' }
    bingcortana = @{
      aplicar = 'Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0; Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0'
      revertir = 'Set-RegValor "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1' }

    # --- Servicios (reversibles) ---
    diagtrack   = @{
      aplicar = 'Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue'
      revertir = 'Set-Service DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service DiagTrack -ErrorAction SilentlyContinue' }
    xbox        = @{
      aplicar = 'foreach ($s in @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc")) { Stop-Service $s -Force -ErrorAction SilentlyContinue; Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue }'
      revertir = 'foreach ($s in @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc")) { Set-Service $s -StartupType Manual -ErrorAction SilentlyContinue }' }

    # --- Debloat (no reversible -> solo aplicar; "no reinstala") ---
    copilot   = @{ aplicar = 'Set-RegValor "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1' }
    teamsper  = @{ aplicar = 'Get-AppxPackage -Name MicrosoftTeams -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue' }
    widgets   = @{ aplicar = 'Get-AppxPackage -Name "*WebExperience*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue' }
    edgedebloat = @{ aplicar = 'Set-RegValor "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled" 0' }
  }
}

# ============================================================================================
# FEEDBACK DE "APLICAR" (FIX 2). Las acciones de consola largas (sfc/DISM/chkdsk/WinSxS/wsreset) no
# dan progreso util por stdout streameado a un panel: el tecnico necesita VER la consola corriendo.
# Para esas se abre una CONSOLA VISIBLE (cmd /k que corre el comando y queda abierta con el resultado).
# El resto de acciones son cortas: se ejecutan async y su stdout/stderr se STREAMEA al panel de log
# interno en vivo, con el boton en "Ejecutando..." y la barra de progreso activa.

# Ids cuyo comando es de consola larga: conviene ventana VISIBLE en vez de streamear al panel.
function Get-UtilAccionesConsola {
  @('sfc','dism','chkdsk','winsxs','wsreset','repwu')
}

# Comando de consola (cmd.exe) equivalente para correr el util en una ventana VISIBLE. Devuelve el
# string de argumentos para cmd.exe (/k: deja la ventana abierta al terminar para leer el resultado).
# Solo para los ids de Get-UtilAccionesConsola; para el resto devuelve $null (se streamea).
function Get-UtilComandoConsola {
  param([string]$Id)
  $cmd = switch ($Id) {
    'sfc'    { 'sfc /scannow' }
    'dism'   { 'DISM /Online /Cleanup-Image /RestoreHealth' }
    'chkdsk' { 'chkdsk /scan' }
    'winsxs' { 'DISM /Online /Cleanup-Image /StartComponentCleanup' }
    'wsreset'{ 'wsreset.exe' }
    'repwu'  { 'net stop wuauserv & net stop bits & net stop cryptsvc & for /f "tokens=2 delims==" %T in (''wmic os get localdatetime /value ^| find "="'') do set FLEETWUTS=%T & ren "%WINDIR%\SoftwareDistribution" "SoftwareDistribution.bak_%FLEETWUTS:~0,14%" & net start wuauserv & net start bits & net start cryptsvc' }
    default  { $null }
  }
  if (-not $cmd) { return $null }
  # /k deja la consola abierta; el title ayuda al tecnico a identificarla.
  "/k title Fleet Toolkit - $Id & echo === Utilidades: $Id === & echo. & $cmd & echo. & echo === Termino. Podes cerrar esta ventana. ==="
}

# Modelo PURO del estado de ejecucion de una accion (FIX 2), para que la UI lo pinte sin congelarse.
# fase in 'listo'(idle) | 'ejecutando' | 'ok' | 'error'. Devuelve etiqueta de boton, si esta
# habilitado, color del estado y si la barra de progreso debe estar visible. Testeable sin WPF.
function Resolve-UtilEjecucion {
  param([string]$Fase = 'listo', [string]$Detalle = '')
  switch ($Fase) {
    'ejecutando' { @{ fase='ejecutando'; etiqueta='Ejecutando...'; habilitado=$false; progreso=$true;  clase='e-run'; color='#D1AA66'; texto = if ($Detalle) { $Detalle } else { 'Ejecutando...' } } }
    'ok'         { @{ fase='ok';         etiqueta='Aplicar';       habilitado=$true;  progreso=$false; clase='e-ok';  color='#5EAE87'; texto = if ($Detalle) { $Detalle } else { 'Listo' } } }
    'error'      { @{ fase='error';      etiqueta='Reintentar';    habilitado=$true;  progreso=$false; clase='e-err'; color='#EC8B92'; texto = if ($Detalle) { $Detalle } else { 'Error' } } }
    default      { @{ fase='listo';      etiqueta='Aplicar';       habilitado=$true;  progreso=$false; clase='e-idle';color='#ABD0BE'; texto = if ($Detalle) { $Detalle } else { '' } } }
  }
}

# Lanza una accion CORTA en un runspace de fondo y STREAMEA su stdout/stderr linea a linea a una cola
# concurrente que la UI drena por DispatcherTimer (mismo patron que Start-RelevamientoAsync). NO
# bloquea el hilo STA. Devuelve un job { ps; handle; queue; rs } consumible por Receive-UtilStream.
# El comando se ejecuta con [scriptblock]::Create del texto real (Get-UtilAcciones). Best-effort:
# captura excepciones y las encola como lineas 'ERROR: ...'. El log de auditoria lo hace el caller.
function Start-UtilAccionStream {
  param([string]$Id, [ValidateSet('aplicar','revertir')][string]$Modo = 'aplicar', [string]$ScriptDir)
  $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
  $acc = Get-UtilAcciones
  $txt = if ($acc.ContainsKey($Id)) { $acc[$Id][$Modo] } else { $null }
  # El runspace de fondo se crea con un InitialSessionState que inyecta las funciones del proceso
  # actual (incluidas las de esta lib: Set-RegValor, etc). Asi el comando corre SIN depender de
  # archivos en disco. Antes el runspace dot-sourceaba gui-tab-utilidades.ps1 por ruta y, en el dist
  # single-file (irm|iex, sin lib/ al lado), no lo encontraba: toda accion por streaming fallaba con
  # "no se pudo cargar" sin haber ejecutado el comando. Mismo patron que el relevamiento. $ScriptDir
  # queda en la firma por compatibilidad del caller; ya no se usa para cargar nada.
  $rs = if (Get-Command New-CoreInitialSessionState -ErrorAction SilentlyContinue) {
    [runspacefactory]::CreateRunspace((New-CoreInitialSessionState))
  } else {
    [runspacefactory]::CreateRunspace()
  }
  $rs.ApartmentState = 'MTA'
  $rs.Open()
  $ps = [powershell]::Create()
  $ps.Runspace = $rs
  [void]$ps.AddScript({
    param($Id, $Modo, $Queue, $CmdText)
    if (-not $CmdText) { $Queue.Enqueue("ERROR: sin comando para $Id ($Modo)"); return 'error' }
    $Queue.Enqueue("> $Id ($Modo): iniciando")
    try {
      $sb = [scriptblock]::Create($CmdText)
      & $sb 2>&1 | ForEach-Object {
        $line = if ($_ -is [System.Management.Automation.ErrorRecord]) { "ERROR: $($_.Exception.Message)" } else { [string]$_ }
        if ($line) { $Queue.Enqueue($line) }
      }
      $Queue.Enqueue("> $Id ($Modo): termino OK")
      'ok'
    } catch {
      $Queue.Enqueue("ERROR: $($_.Exception.Message)")
      'error'
    }
  }).AddArgument($Id).AddArgument($Modo).AddArgument($queue).AddArgument($txt)
  @{ ps = $ps; handle = $ps.BeginInvoke(); queue = $queue; rs = $rs; id = $Id; modo = $Modo }
}

# Drena las lineas nuevas de un job de streaming sin bloquear. Devuelve { lineas; done; resultado }.
# done=$true cuando el runspace termino (resultado 'ok'|'error'|''). Limpia el runspace al terminar.
function Receive-UtilStream {
  param($Job)
  $lineas = @()
  $out = ''
  while ($Job.queue.TryDequeue([ref]$out)) { $lineas += $out }
  if (-not $Job.handle.IsCompleted) { return @{ lineas = $lineas; done = $false; resultado = '' } }
  $resultado = ''
  try { $resultado = [string](@($Job.ps.EndInvoke($Job.handle))[0]) }
  catch { $resultado = 'error'; $lineas += "ERROR: $($_.Exception.Message)" }
  finally { try { $Job.ps.Dispose(); $Job.rs.Close(); $Job.rs.Dispose() } catch {} }
  if (-not $resultado) { $resultado = 'ok' }
  @{ lineas = $lineas; done = $true; resultado = $resultado }
}

# Captura el VALOR ANTERIOR de un util reversible para el log (spec 7.7), antes de mutar. Devuelve un
# string legible. Para los no reversibles / acciones puntuales devuelve un marcador neutro. Solo LEE.
function Get-UtilValorActual {
  param([string]$Id)
  try {
    $det = Test-Util -Item (Get-UtilCatalogo | Where-Object { $_.id -eq $Id } | Select-Object -First 1)
    if ($det -and $det.ContainsKey('dato')) { return [string]$det.dato }
  } catch {}
  return 'n/d'
}

# Despacha la accion real de un util (aplicar/revertir) CON LOG (spec 7.7). NO se llama desde tests.
# Captura el valor anterior, ejecuta el comando real y registra antes/despues/resultado en el log.
# El checkpoint del batch lo arma Invoke-UtilBatch (una vez por batch, no por util). Devuelve texto.
function Invoke-UtilAccion {
  param([string]$Id, [ValidateSet('aplicar','revertir')][string]$Modo = 'aplicar', [switch]$SinLog)
  $acc = Get-UtilAcciones
  if (-not $acc.ContainsKey($Id)) { return "sin accion: $Id" }
  $txt = $acc[$Id][$Modo]
  if (-not $txt) { return "sin $Modo para: $Id" }
  # FIX seguridad #4: si la accion muta HKLM/servicios/DISM y el proceso NO esta elevado, no la corremos
  # fingiendo exito (los cmdlets fallan con -ErrorAction SilentlyContinue y se auditaria 'ok' sin mutar).
  # Reportamos 'requiere admin' y auditamos resultado='error: sin privilegios'.
  if ((Test-UtilRequiereAdmin -Id $Id) -and -not (Test-UtilElevado)) {
    if (-not $SinLog) { Write-UtilLog -Id $Id -Modo $Modo -Resultado 'error: sin privilegios' | Out-Null }
    return "requiere admin: $Id ($Modo)"
  }
  $antes = if ($SinLog) { '' } else { Get-UtilValorActual -Id $Id }
  try {
    $sb = [scriptblock]::Create($txt)
    & $sb | Out-Null
    $despues = if ($SinLog) { '' } else { Get-UtilValorActual -Id $Id }
    if (-not $SinLog) { Write-UtilLog -Id $Id -Modo $Modo -Antes $antes -Despues $despues -Resultado 'ok' | Out-Null }
    return "ok: $Id ($Modo)"
  } catch {
    if (-not $SinLog) { Write-UtilLog -Id $Id -Modo $Modo -Antes $antes -Resultado "error: $($_.Exception.Message)" | Out-Null }
    return "error: $Id ($Modo) - $($_.Exception.Message)"
  }
}

# Ejecuta un BATCH de pendientes con la red de seguridad completa (spec 7.7): un solo punto de
# restauracion best-effort al inicio (solo si hay cambios que muten estado persistente: tweaks/
# servicios/debloat, no limpieza/reparaciones) y log por cada util via Invoke-UtilAccion.
# $Pendientes es la hashtable id -> 'aplicar'|'revertir'. Devuelve { checkpoint; resultados }.
# FIX seguridad #3: si el checkpoint falla (servidores con System Restore off) y hay acciones que
# MUTAN de forma NO reversible (debloat con Remove-AppxPackage = no reinstala, o cualquier persistente
# con reversible=$false), no las aplicamos a ciegas. Senalizamos checkpoint_failed + la lista de
# no-reversibles, y pedimos una reconfirmacion explicita ANTES de tocarlas. Las reversibles se aplican
# igual (se pueden deshacer). $Confirmador es un scriptblock que recibe la lista de ids no-reversibles
# y devuelve $true para seguir; por defecto muestra un MessageBox. Los tests inyectan el suyo.
function Invoke-UtilBatch {
  param([hashtable]$Pendientes, [scriptblock]$Confirmador)
  $resultados = @()
  $catById = @{}
  foreach ($it in (Get-UtilCatalogo)) { $catById[$it.id] = $it }
  # Clasificar pendientes: persistente (tweaks/servicios/debloat) y no-reversible (reversible=$false).
  $persistente = $false
  $noReversibles = @()
  foreach ($id in $Pendientes.Keys) {
    $it = if ($catById.ContainsKey($id)) { $catById[$id] } else { $null }
    $cat = if ($it) { [string]$it.categoria } else { '' }
    if ($cat -in @('tweaks','servicios','debloat')) {
      $persistente = $true
      # 'aplicar' una accion no reversible es lo que no se puede deshacer; 'revertir' no aplica aca.
      if ($it -and (-not $it.reversible) -and ($Pendientes[$id] -eq 'aplicar')) { $noReversibles += $id }
    }
  }
  $checkpoint = $false
  if ($persistente) { $checkpoint = New-UtilCheckpoint }
  $checkpointFailed = ($persistente -and -not $checkpoint)

  # Si el checkpoint fallo y hay no-reversibles, reconfirmar antes de aplicarlas. Si el caller no
  # confirma, se aplican solo las reversibles y las no-reversibles quedan 'omitido (sin checkpoint)'.
  $omitirNoRev = $false
  if ($checkpointFailed -and $noReversibles.Count -gt 0) {
    $okSeguir = $false
    if ($Confirmador) {
      try { $okSeguir = [bool](& $Confirmador $noReversibles) } catch { $okSeguir = $false }
    } else {
      try {
        $lst = ($noReversibles -join ', ')
        $msg = "No se pudo crear un punto de restauracion (System Restore puede estar deshabilitado). Las siguientes acciones NO son reversibles y se aplicaran SIN red de seguridad:`n`n$lst`n`nAplicarlas igual?"
        $okSeguir = ([System.Windows.MessageBox]::Show($msg, 'Fleet Toolkit - sin checkpoint', 'YesNo', 'Warning') -eq 'Yes')
      } catch { $okSeguir = $false }
    }
    $omitirNoRev = -not $okSeguir
  }

  foreach ($id in @($Pendientes.Keys)) {
    if ($omitirNoRev -and ($noReversibles -contains $id)) {
      $resultados += "omitido (sin checkpoint): $id"
      Write-UtilLog -Id $id -Modo $Pendientes[$id] -Resultado 'omitido: sin checkpoint (no reversible)' | Out-Null
      continue
    }
    $resultados += (Invoke-UtilAccion -Id $id -Modo $Pendientes[$id])
  }
  @{ checkpoint = $checkpoint; checkpoint_failed = $checkpointFailed; persistente = $persistente;
     no_reversibles = $noReversibles; omitidas = $(if ($omitirNoRev) { $noReversibles } else { @() });
     resultados = $resultados }
}

# ============================================================================================
# UI

# Construye un WPF Popup anclado al boton "elegir..." con la lista del listado (spec 7.8 / 3.6).
# Placement=Bottom + ScrollViewer con MaxHeight (no se corta) + StaysOpen=false (cierra al click
# afuera, no saca de la tab). El flip/shift completo (CustomPopupPlacementCallback) queda como mejora.
# $Items es un array de hashtables crudos { nombre; ubicacion; impacto }; se normaliza con
# Format-PopoverItem. Cada fila lleva checkbox (seleccion manual) + ubicacion + badge de impacto.
function New-UtilPopover {
  param($Anchor, [string]$Titulo, $Items, [string]$AccionId = '', [scriptblock]$OnConfirm)
  $norm = @()
  foreach ($r in @($Items)) { if ($r -is [hashtable]) { $norm += (Format-PopoverItem $r) } }
  # FIX seguridad #7: pares (checkbox -> item normalizado) para que "Confirmar seleccion" lea lo marcado.
  $checks = New-Object System.Collections.ArrayList

  $pop = New-Object System.Windows.Controls.Primitives.Popup
  $pop.PlacementTarget = $Anchor
  $pop.Placement = 'Bottom'
  $pop.StaysOpen = $false
  $pop.AllowsTransparency = $true
  $pop.MaxWidth = 440

  $card = New-Object System.Windows.Controls.Border
  $card.Background = '#101814'; $card.BorderBrush = '#5EAE87'; $card.BorderThickness = 1
  $card.CornerRadius = 8; $card.Padding = '11,9'
  $card.Effect = (New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 16; ShadowDepth = 2; Opacity = 0.55; Color = ([System.Windows.Media.ColorConverter]::ConvertFromString('#000000')) })
  $pop.Child = $card

  $col = New-Object System.Windows.Controls.StackPanel
  $card.Child = $col

  $h = New-Object System.Windows.Controls.TextBlock
  $h.Foreground = '#7DA792'; $h.FontFamily = 'Space Grotesk, Segoe UI'; $h.FontWeight = 'Bold'
  $h.FontSize = 11.5; $h.Margin = '0,0,0,7'
  [void]$col.Children.Add($h)

  $sv = New-Object System.Windows.Controls.ScrollViewer
  $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 230
  $list = New-Object System.Windows.Controls.StackPanel
  $sv.Content = $list
  [void]$col.Children.Add($sv)

  if (-not $norm.Count) {
    $empty = New-Object System.Windows.Controls.TextBlock
    $empty.Text = 'Sin elementos detectados.'; $empty.Foreground = '#A4BBB0'; $empty.FontSize = 11
    [void]$list.Children.Add($empty)
  } else {
    foreach ($it in $norm) {
      $row = New-Object System.Windows.Controls.Border
      $row.Padding = '4,3'; $row.Margin = '0,1,0,1'
      $rs = New-Object System.Windows.Controls.StackPanel
      $rs.Orientation = 'Horizontal'; $row.Child = $rs

      $cb = New-Object System.Windows.Controls.CheckBox
      $cb.VerticalAlignment = 'Center'; $cb.Margin = '0,0,7,0'
      [void]$rs.Children.Add($cb)
      [void]$checks.Add(@{ cb = $cb; item = $it })

      $info = New-Object System.Windows.Controls.StackPanel
      $info.Width = 300
      $nm = New-Object System.Windows.Controls.TextBlock
      $nm.Text = $it.nombre; $nm.Foreground = '#ECF0EE'; $nm.FontSize = 11; $nm.TextTrimming = 'CharacterEllipsis'
      [void]$info.Children.Add($nm)
      if ($it.ubicacion) {
        $ub = New-Object System.Windows.Controls.TextBlock
        $ub.Text = $it.ubicacion; $ub.Foreground = '#8BAC9C'; $ub.FontFamily = 'DM Mono, Consolas'
        $ub.FontSize = 9; $ub.TextTrimming = 'CharacterEllipsis'
        [void]$info.Children.Add($ub)
      }
      [void]$rs.Children.Add($info)

      $bg = New-Object System.Windows.Controls.Border
      $bg.CornerRadius = 4; $bg.Padding = '5,1'; $bg.VerticalAlignment = 'Center'; $bg.Margin = '6,0,0,0'
      $impHex = switch ($it.clase) { 'i-hi' { '#EC8B92' } 'i-md' { '#D1AA66' } default { '#77BC9A' } }
      $bg.Background = '#16211C'; $bg.BorderBrush = $impHex; $bg.BorderThickness = 1
      $bt = New-Object System.Windows.Controls.TextBlock
      $bt.Text = $it.impacto; $bt.Foreground = $impHex; $bt.FontFamily = 'DM Mono, Consolas'; $bt.FontSize = 8.5
      $bg.Child = $bt
      [void]$rs.Children.Add($bg)

      [void]$list.Children.Add($row)
    }
  }

  $h.Text = "$Titulo · $($norm.Count) detectadas"

  $pf = New-Object System.Windows.Controls.StackPanel
  $pf.Orientation = 'Horizontal'; $pf.Margin = '0,8,0,0'
  $resumen = New-Object System.Windows.Controls.TextBlock
  $resumen.Text = "$($norm.Count) elementos · selección manual"; $resumen.Foreground = '#A4BBB0'
  $resumen.FontSize = 10; $resumen.VerticalAlignment = 'Center'; $resumen.Margin = '0,0,10,0'
  [void]$pf.Children.Add($resumen)
  $cancel = New-Object System.Windows.Controls.Button
  $cancel.Content = 'Cancelar'; $cancel.FontSize = 10; $cancel.Padding = '8,3'; $cancel.Margin = '0,0,6,0'
  $cancel.Add_Click({ param($s,$e) $pop.IsOpen = $false }.GetNewClosure())
  [void]$pf.Children.Add($cancel)
  $ok = New-Object System.Windows.Controls.Button
  $ok.Content = 'Confirmar selección'; $ok.FontSize = 10; $ok.Padding = '8,3'
  $ok.Background = '#5EAE87'; $ok.Foreground = '#0E271B'
  # FIX seguridad #7: el OK leia nada (era inerte). Ahora itera los checkboxes, junta los marcados y
  # los expone en $pop.Tag (.seleccion = items marcados) e invoca $OnConfirm con (AccionId, marcados)
  # para que el caller los sume a los pendientes. Cierra el popover al confirmar.
  $checksRef = $checks; $accRef = $AccionId; $onConfRef = $OnConfirm; $popRef = $pop
  $ok.Add_Click({ param($s,$e)
    $marcados = @()
    foreach ($par in $checksRef) {
      if ($par.cb.IsChecked -eq $true) { $marcados += $par.item }
    }
    $popRef.Tag = @{ accionId = $accRef; seleccion = $marcados }
    if ($onConfRef) { try { & $onConfRef $accRef $marcados } catch {} }
    $popRef.IsOpen = $false
  }.GetNewClosure())
  [void]$pf.Children.Add($ok)
  [void]$col.Children.Add($pf)

  $pop
}

# Config de la tab guardada en $Window.Tag['utilCfg'] por sti-gui.ps1: ScriptDir (raiz del script,
# para los runspaces de streaming) y OnRescan (scriptblock que re-escanea el estado tras una accion).
# El bridge de click la lee de aca para no acoplar Update-UtilidadesPanel al wiring de la ventana.
function Get-UtilCfg {
  param($Window)
  if ($Window -and $Window.Tag -is [hashtable] -and $Window.Tag['utilCfg'] -is [hashtable]) { return $Window.Tag['utilCfg'] }
  @{}
}
function Set-UtilCfg {
  param($Window, [string]$ScriptDir, [scriptblock]$OnRescan)
  if (-not $Window) { return }
  if (-not ($Window.Tag -is [hashtable])) { $Window.Tag = @{} }
  $Window.Tag['utilCfg'] = @{ ScriptDir = $ScriptDir; OnRescan = $OnRescan }
}

# Bridge del click de "Aplicar" (accion/aviso) al runner con feedback en vivo (FIX 2). Pide
# confirmacion (estas acciones mutan/limpian y muchas no son reversibles), lee la config de la
# ventana y delega en Invoke-UtilAccionUI. Tolerante: si no hay config (test sin wiring) igual
# corre con ScriptDir vacio y sin re-escaneo.
function Invoke-UtilAccionDesdeClick {
  param($Window, [string]$Id, $Boton)
  $item = $null
  try { $item = Get-UtilCatalogo | Where-Object id -eq $Id | Select-Object -First 1 } catch {}
  $label = if ($item) { [string]$item.nombre } else { '' }
  $consola = (Get-UtilAccionesConsola) -contains $Id
  $aviso = if ($consola) { "Se ejecutara '$label' en una consola visible. Vas a ver el progreso en la ventana que se abre. Continuar?" } else { "Se ejecutara '$label' sobre este equipo y se registrara en la auditoria. Continuar?" }
  # FIX seguridad #2: si el item declara una advertencia (resetred/winsock cortan la red), mostrarla en
  # la confirmacion. Si ademas la sesion es remota (RDP), reforzar el aviso: estas acciones pueden cortar
  # justo la sesion desde la que se las dispara.
  $avisoItem = if ($item -and $item.ContainsKey('aviso')) { [string]$item.aviso } else { '' }
  if ($avisoItem) { $aviso = "ATENCION: $avisoItem`n`n$aviso" }
  if ($avisoItem -and ($env:SESSIONNAME -like 'RDP*')) {
    $aviso = "SESION REMOTA DETECTADA ($($env:SESSIONNAME)): esta accion puede CORTAR esta misma sesion. Conviene correrla en consola local.`n`n$aviso"
  }
  # FIX seguridad #4: acciones que tocan HKLM/servicios/DISM necesitan elevacion; sin admin fallan en
  # silencio. Avisar antes de intentar (igual se permite, pero con friccion).
  if ((Test-UtilRequiereAdmin -Id $Id) -and -not (Test-UtilElevado)) {
    $aviso = "SIN PRIVILEGIOS DE ADMINISTRADOR: '$label' requiere elevacion y puede fallar sin aplicar cambios. Reabri la herramienta como Administrador.`n`n$aviso"
  }
  try {
    $resp = [System.Windows.MessageBox]::Show($aviso, 'Fleet Toolkit', 'YesNo', 'Warning')
    if ($resp -ne 'Yes') { return }
  } catch {}
  $cfg = Get-UtilCfg -Window $Window
  $sd = [string]$cfg['ScriptDir']
  $onDone = $cfg['OnRescan']
  Invoke-UtilAccionUI -Window $Window -Id $Id -Modo 'aplicar' -Boton $Boton -OnDone $onDone -ScriptDir $sd
}

# Estado vivo de cambios pendientes del panel, guardado en $Window.Tag (mismo patron que Mantenimiento).
# pendientes = hashtable id -> 'aplicar'|'revertir' que el tecnico marco con los toggles, a ejecutar
# en el batch (boton "Aplicar cambios").
function Get-UtilPendientes {
  param($Window)
  if ($Window -and $Window.Tag -is [hashtable] -and $Window.Tag['utilPend'] -is [hashtable]) { return $Window.Tag['utilPend'] }
  $h = @{}
  if ($Window) { if (-not ($Window.Tag -is [hashtable])) { $Window.Tag = @{} }; $Window.Tag['utilPend'] = $h }
  $h
}

# Seleccion de los listados (apps de inicio, servicios, bloatware, etc) confirmada en cada popover,
# guardada en $Window.Tag. id-de-listado -> array de items marcados. Es lo que "Confirmar seleccion"
# registra (FIX seguridad #7) para que el batch sepa que elementos eligio el tecnico. Get-UtilCatalogo
# no tiene una accion por elemento (cada listado es heterogeneo), asi que por ahora se persiste la
# seleccion y se refleja en el contador; aplicarla queda para el runner de listados (pendiente).
function Get-UtilSeleccion {
  param($Window)
  if ($Window -and $Window.Tag -is [hashtable] -and $Window.Tag['utilSel'] -is [hashtable]) { return $Window.Tag['utilSel'] }
  $h = @{}
  if ($Window) { if (-not ($Window.Tag -is [hashtable])) { $Window.Tag = @{} }; $Window.Tag['utilSel'] = $h }
  $h
}

# Registra (FIX seguridad #7) la seleccion confirmada de un listado. $Marcados es el array de items
# marcados (hashtables normalizados). Vacio limpia la entrada. Devuelve la cantidad registrada.
function Set-UtilSeleccion {
  param($Window, [string]$Id, $Marcados)
  $sel = Get-UtilSeleccion -Window $Window
  $arr = @($Marcados)
  if ($arr.Count -gt 0) { $sel[$Id] = $arr } else { [void]$sel.Remove($Id) }
  Update-UtilPendientesUI -Window $Window
  $arr.Count
}

# Refresca el contador "N cambios pendientes de aplicar" en el footer.
function Update-UtilPendientesUI {
  param($Window)
  $pend = Get-UtilPendientes -Window $Window
  $n = @($pend.Keys).Count
  # FIX seguridad #7: sumar las selecciones de listado confirmadas (cada listado con items marcados
  # cuenta como un cambio pendiente). Best-effort: si no hay Tag aun, sel queda vacio.
  $sel = Get-UtilSeleccion -Window $Window
  $n += @($sel.Keys | Where-Object { @($sel[$_]).Count -gt 0 }).Count
  $ctl = $null
  try { if ($Window.PSObject.Methods['FindName']) { $ctl = $Window.FindName('TxtUtilPendientes') } } catch {}
  if ($ctl) { $ctl.Text = if ($n -eq 0) { '0 cambios pendientes de aplicar' } else { "$n cambios pendientes de aplicar" } }
}

# Pinta el cuerpo de un toggle (fondo/borde/knob) segun ON/OFF. Reutilizable para el repintado al click.
function Set-ToggleVisual {
  param($Toggle, $Knob, [bool]$On)
  $verde = '#5EAE87'
  $Toggle.Background  = if ($On) { $verde } else { '#27342E' }
  $Toggle.BorderBrush = if ($On) { $verde } else { '#3B4D44' }
  $Knob.Background    = if ($On) { '#0E271B' } else { '#71837A' }
  $Knob.HorizontalAlignment = if ($On) { 'Right' } else { 'Left' }
}

# XAML del panel Utilidades. Reemplaza el placeholder en gui-xaml.ps1. Las filas de cada categoria se
# pueblan en runtime con Update-UtilidadesPanel (los ItemsControl quedan vacios aca).
function New-PanelUtilidadesXaml {
  $cats = Get-UtilCategorias
  $bloques = foreach ($c in $cats) {
    $items = "Items" + (Get-Culture).TextInfo.ToTitleCase($c.id)
    @"
        <Grid Margin="0,11,0,6">
          <TextBlock Foreground="{StaticResource AppTenue}" FontWeight="700" FontSize="11" Text="$([System.Security.SecurityElement]::Escape($c.titulo.ToUpper()))" HorizontalAlignment="Left"/>
          <TextBlock Foreground="{StaticResource AppTexto3}" FontFamily="DM Mono, Consolas" FontSize="9" Text="$([System.Security.SecurityElement]::Escape($c.nat))" HorizontalAlignment="Right"/>
        </Grid>
        <ItemsControl x:Name="$items">
          <ItemsControl.ItemsPanel>
            <ItemsPanelTemplate><UniformGrid Columns="2"/></ItemsPanelTemplate>
          </ItemsControl.ItemsPanel>
        </ItemsControl>
"@
  }
  @"
<ScrollViewer x:Name="PanelUtilidades" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
  <StackPanel>
    <Border Background="#101B16" BorderBrush="{StaticResource AppBordeSutil}" BorderThickness="0,0,0,1" Padding="0,9" Margin="0,0,0,4">
      <StackPanel>
        <StackPanel Orientation="Horizontal">
          <TextBlock x:Name="TxtUtilResumen" VerticalAlignment="Center" Foreground="{StaticResource AppTexto2}" FontSize="11" Text="Estado detectado al abrir"/>
          <Button x:Name="BtnUtilReescanear" Content="Re-escanear" Margin="10,0,6,0" Padding="11,5"/>
          <Button x:Name="BtnUtilPreset" Style="{StaticResource AppBtnPrimary}" Content="Preset recomendado" Padding="11,5"/>
        </StackPanel>
        <Grid Margin="0,7,0,0">
          <ProgressBar x:Name="ProgUtil" Height="4" Background="#16201B" BorderThickness="0" Foreground="#5EAE87" IsIndeterminate="False" Visibility="Collapsed"/>
        </Grid>
      </StackPanel>
    </Border>
$($bloques -join "`n")
    <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
      <TextBlock Foreground="{StaticResource AppTexto3}" FontSize="9" Text="punto naranja = revisar antes de aplicar" Margin="0,0,14,0"/>
      <TextBlock Foreground="{StaticResource AppTexto3}" FontSize="9" Text="toggle verde = feature activa ahora (se puede revertir)" Margin="0,0,14,0"/>
      <TextBlock Foreground="{StaticResource AppTexto3}" FontSize="9" Text="historial de cambios en el registro de auditoria" Margin="0,0,14,0"/>
      <TextBlock Foreground="{StaticResource AppTexto3}" FontSize="9" Text="elegir... = popover de seleccion"/>
    </StackPanel>
    <Border Background="#0F1C16" BorderBrush="{StaticResource AppBordeSutil}" BorderThickness="0,1,0,0" Padding="0,11" Margin="0,8,0,0">
      <StackPanel Orientation="Horizontal">
        <TextBlock x:Name="TxtUtilPendientes" VerticalAlignment="Center" Foreground="{StaticResource AppTexto2}" FontSize="11" Text="0 cambios pendientes de aplicar"/>
        <Button x:Name="BtnUtilRevertir" Content="Revertir aplicadas" Margin="12,0,6,0" Padding="13,8"/>
        <Button x:Name="BtnUtilAplicar" Style="{StaticResource AppBtnPrimary}" Content="Aplicar cambios" Padding="16,9"/>
      </StackPanel>
    </Border>
    <Border Background="#0D1511" BorderBrush="{StaticResource AppBordeSutil}" BorderThickness="1" CornerRadius="6" Padding="10,8" Margin="0,10,0,4">
      <StackPanel>
        <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
          <TextBlock Foreground="{StaticResource AppTenue}" FontWeight="700" FontSize="11" Text="REGISTRO DE AUDITORIA" VerticalAlignment="Center"/>
          <TextBlock x:Name="TxtUtilLogInfo" Foreground="{StaticResource AppTexto3}" FontFamily="DM Mono, Consolas" FontSize="9" Margin="10,0,0,0" VerticalAlignment="Center" Text="Event Log + JSON + texto"/>
          <Button x:Name="BtnUtilLogRefrescar" Content="Refrescar" Margin="10,0,6,0" Padding="9,3" FontSize="10"/>
          <Button x:Name="BtnUtilLogAbrir" Content="Abrir carpeta" Padding="9,3" FontSize="10"/>
        </StackPanel>
        <Border Background="#08100C" BorderBrush="#212F28" BorderThickness="1" CornerRadius="4" Padding="6,4">
          <ScrollViewer MaxHeight="150" VerticalScrollBarVisibility="Auto">
            <ItemsControl x:Name="ItemsUtilLog"/>
          </ScrollViewer>
        </Border>
      </StackPanel>
    </Border>
  </StackPanel>
</ScrollViewer>
"@
}

# Puebla los ItemsControl de cada categoria en runtime y la barra de resumen. NO ejecuta acciones.
# $Estados es opcional: hashtable id -> deteccion { estado; dato } (del detector real o de un fixture).
# Sin el, todo queda 'disponible'. $Listados es opcional: hashtable id -> array crudo para los popovers.
# Controles por tipo (FIX 2/3/4):
#   toggle  -> Border clickeable que refleja el ESTADO REAL detectado (ON = feature activa hoy). Sin
#              etiqueta de "Aplicada/Revertida": el estado del equipo se ve directo en el toggle.
#   accion  -> boton "Aplicar" (una sola via, no reversible). Sin etiqueta de estado permanente.
#   aviso   -> boton "Aplicar" + etiqueta "no reversible".
#   listado -> boton "elegir..." que abre el popover.
# El feedback de "ya se ejecuto" NO va como badge en la card: vive en el panel de log interno y en la
# auditoria. La card refleja unicamente el estado REAL actual (toggle) o la accion disponible (boton).
# $Badges queda por compatibilidad de firma pero se ignora (no se pintan badges).
function Update-UtilidadesPanel {
  param($Window, [hashtable]$Estados, [hashtable]$Listados, [hashtable]$Badges)
  if (-not $Estados)  { $Estados = @{} }
  if (-not $Listados) { $Listados = @{} }
  $naranja = '#C77539'
  $sOn = '#77BC9A'; $sOff = '#96A9A0'; $sNa = '#606F68'
  $pend = Get-UtilPendientes -Window $Window
  $resueltos = @()
  foreach ($cat in (Get-UtilCategorias)) {
    $ctrlName = 'Items' + (Get-Culture).TextInfo.ToTitleCase($cat.id)
    $ctrl = $Window.FindName($ctrlName)
    if (-not $ctrl) { continue }
    $ctrl.Items.Clear()
    foreach ($item in (Get-UtilPorCategoria $cat.id)) {
      $det = if ($Estados.ContainsKey($item.id)) { $Estados[$item.id] } else { @{} }
      $est = Resolve-UtilEstado -Item $item -Deteccion $det
      $resueltos += $est

      $row = New-Object System.Windows.Controls.Border
      $row.Background = '#16211C'; $row.BorderBrush = '#293831'; $row.BorderThickness = 1
      $row.CornerRadius = 6; $row.Padding = '10,7'; $row.Margin = '0,0,5,5'
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Orientation = 'Horizontal'
      $row.Child = $sp

      if ($item.delicado) {
        $dot = New-Object System.Windows.Controls.Border
        $dot.Width = 6; $dot.Height = 6; $dot.CornerRadius = 3; $dot.Background = $naranja
        $dot.VerticalAlignment = 'Center'; $dot.Margin = '0,0,6,0'
        $dot.ToolTip = 'Revisar antes de aplicar'
        [void]$sp.Children.Add($dot)
      }
      $nm = New-Object System.Windows.Controls.TextBlock
      $nm.Text = $item.nombre; $nm.Foreground = '#E4ECE8'; $nm.FontSize = 11.5
      $nm.VerticalAlignment = 'Center'; $nm.Width = 150; $nm.TextTrimming = 'CharacterEllipsis'
      [void]$sp.Children.Add($nm)

      $st = New-Object System.Windows.Controls.TextBlock
      $st.Text = $est.display; $st.FontFamily = 'DM Mono, Consolas'; $st.FontSize = 9
      $st.VerticalAlignment = 'Center'; $st.Margin = '6,0,6,0'
      $st.Foreground = switch ($est.clase) { 's-on' { $sOn } 's-na' { $sNa } default { $sOff } }
      [void]$sp.Children.Add($st)

      switch ($item.tipo) {
        'listado' {
          $lk = New-Object System.Windows.Controls.Button
          $lk.Content = 'elegir...'; $lk.Foreground = '#ABD0BE'; $lk.Background = '#1C2D25'
          $lk.BorderBrush = '#375144'; $lk.FontSize = 10; $lk.Padding = '8,3'; $lk.Cursor = 'Hand'
          $listado = if ($Listados.ContainsKey($item.id)) { $Listados[$item.id] } else { @() }
          $winL = $Window
          $onConf = { param($accId, $marcados) Set-UtilSeleccion -Window $winL -Id $accId -Marcados $marcados | Out-Null }.GetNewClosure()
          $pop = New-UtilPopover -Anchor $lk -Titulo $item.nombre -Items $listado -AccionId $item.id -OnConfirm $onConf
          if (@($listado).Count -gt 0) { $lk.BorderBrush = '#5EAE87' }
          $lk.Add_Click({ param($s,$e) $pop.IsOpen = -not $pop.IsOpen }.GetNewClosure())
          [void]$sp.Children.Add($lk)
        }
        'aviso' {
          $nr = New-Object System.Windows.Controls.TextBlock
          $nr.Text = 'no reversible'; $nr.Foreground = '#D1AA66'; $nr.FontFamily = 'DM Mono, Consolas'
          $nr.FontSize = 8.5; $nr.VerticalAlignment = 'Center'; $nr.Margin = '0,0,6,0'
          [void]$sp.Children.Add($nr)
          $ap = New-Object System.Windows.Controls.Button
          $ap.Content = 'Aplicar'; $ap.Foreground = '#ABD0BE'; $ap.Background = '#1C2D25'
          $ap.BorderBrush = '#375144'; $ap.FontSize = 10; $ap.Padding = '8,3'; $ap.Cursor = 'Hand'
          $idA = $item.id; $winA = $Window
          $ap.Add_Click({ param($s,$e) Invoke-UtilAccionDesdeClick -Window $winA -Id $idA -Boton $s }.GetNewClosure())
          [void]$sp.Children.Add($ap)
        }
        'accion' {
          $ap = New-Object System.Windows.Controls.Button
          $ap.Content = 'Aplicar'; $ap.Foreground = '#ABD0BE'; $ap.Background = '#1C2D25'
          $ap.BorderBrush = '#375144'; $ap.FontSize = 10; $ap.Padding = '8,3'; $ap.Cursor = 'Hand'
          $idA = $item.id; $winA = $Window
          $ap.Add_Click({ param($s,$e) Invoke-UtilAccionDesdeClick -Window $winA -Id $idA -Boton $s }.GetNewClosure())
          [void]$sp.Children.Add($ap)
        }
        default {
          # toggle: refleja la feature real (ON = aplicado/presente) y permite togglear.
          $on = ($est.estado -eq 'aplicado')
          $tg = New-Object System.Windows.Controls.Border
          $tg.Width = 34; $tg.Height = 18; $tg.CornerRadius = 9; $tg.VerticalAlignment = 'Center'
          $tg.BorderThickness = 1; $tg.Cursor = 'Hand'
          $knob = New-Object System.Windows.Controls.Border
          $knob.Width = 14; $knob.Height = 14; $knob.CornerRadius = 7; $knob.VerticalAlignment = 'Center'
          $knob.Margin = '1,0,1,0'
          $tg.Child = $knob
          Set-ToggleVisual -Toggle $tg -Knob $knob -On $on
          # Estado de click guardado en el Tag del toggle (estado base real + estado actual).
          $tg.Tag = @{ id = $item.id; base = $on; cur = $on; reversible = [bool]$item.reversible }
          $knobRef = $knob; $stRef = $st; $winT = $Window
          $tg.AddHandler(
            [System.Windows.Controls.Border]::MouseLeftButtonUpEvent,
            [System.Windows.Input.MouseButtonEventHandler]{ param($s,$e)
              $t = $s.Tag
              $t.cur = -not $t.cur
              Set-ToggleVisual -Toggle $s -Knob $knobRef -On $t.cur
              $stRef.Text = if ($t.cur) { 'si' } else { 'no' }
              $stRef.Foreground = if ($t.cur) { '#77BC9A' } else { '#96A9A0' }
              $p = Get-UtilPendientes -Window $winT
              if ($t.cur -eq $t.base) {
                [void]$p.Remove($t.id)
              } else {
                $p[$t.id] = if ($t.cur) { 'aplicar' } else { 'revertir' }
              }
              Update-UtilPendientesUI -Window $winT
            }.GetNewClosure()
          )
          [void]$sp.Children.Add($tg)
        }
      }
      [void]$ctrl.Items.Add($row)
    }
  }
  $resumen = Get-UtilResumen -Estados $resueltos
  $txt = $Window.FindName('TxtUtilResumen')
  if ($txt) { $txt.Text = $resumen.texto }
  Update-UtilPendientesUI -Window $Window
}

# Puebla el panel interno de log (FIX UX 3c) con las ultimas entradas de auditoria (JSON-lines).
# Lee via Get-AuditRecent (mas recientes primero) y pinta una fila por entrada. Se llama al abrir
# la tab, tras cada apply/undo y con el boton Refrescar. Tolerante a fallo: si no hay log, muestra
# un aviso. Recibe $Records opcional (para tests); si no, los lee.
function Update-UtilLogPanel {
  param($Window, [int]$Count = 25, [object[]]$Records)
  $ctrl = $Window.FindName('ItemsUtilLog')
  if (-not $ctrl) { return }
  if ($null -eq $Records) {
    $Records = @()
    try { if (Get-Command Get-AuditRecent -ErrorAction SilentlyContinue) { $Records = @(Get-AuditRecent -Count $Count) } } catch {}
  }
  $ctrl.Items.Clear()
  if (-not @($Records).Count) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = 'Sin registros de auditoria todavia.'; $tb.Foreground = '#606F68'
    $tb.FontFamily = 'DM Mono, Consolas'; $tb.FontSize = 9.5; $tb.Margin = '2,1'
    [void]$ctrl.Items.Add($tb)
    return
  }
  foreach ($r in @($Records)) {
    $line = Format-AuditPanelLine -Record $r
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $line; $tb.FontFamily = 'DM Mono, Consolas'; $tb.FontSize = 9.5; $tb.Margin = '2,1'
    $err = ([string]$r.resultado -match '^(?i)error')
    $tb.Foreground = if ($err) { '#EC8B92' } elseif (([string]$r.accion) -eq 'apply') { '#AED8C3' } else { '#A4BBB0' }
    [void]$ctrl.Items.Add($tb)
  }
}

# Anexa UNA linea en vivo al panel de log interno (FIX 2: streaming de la salida de "Aplicar"). Pinta
# en rojo si la linea es un error, verde si es una marca de inicio/fin (>), gris si es salida normal.
# Auto-scroll al final. No lee el disco: la usa el runner async para mostrar stdout linea a linea.
function Add-UtilLogLinea {
  param($Window, [string]$Texto)
  $ctrl = $Window.FindName('ItemsUtilLog')
  if (-not $ctrl) { return }
  # Si el panel todavia muestra el placeholder "Sin registros...", limpiarlo antes de la primera linea.
  if ($ctrl.Items.Count -eq 1 -and ($ctrl.Items[0].Text -match '^Sin registros')) { $ctrl.Items.Clear() }
  $tb = New-Object System.Windows.Controls.TextBlock
  $tb.Text = $Texto; $tb.FontFamily = 'DM Mono, Consolas'; $tb.FontSize = 9.5; $tb.Margin = '2,1'
  $tb.TextWrapping = 'Wrap'
  $tb.Foreground = if ($Texto -match '^(?i)error|ERROR:') { '#EC8B92' } elseif ($Texto -match '^>') { '#5EAE87' } else { '#A4BBB0' }
  [void]$ctrl.Items.Add($tb)
}

# Ejecuta una accion de util CON FEEDBACK EN VIVO desde la UI (FIX 2). Es el handler real del boton
# "Aplicar" de las acciones puntuales/avisos. Decide la via segun el id:
#   - consola larga (Get-UtilAccionesConsola): abre una CONSOLA VISIBLE (cmd /k) para que el
#     tecnico vea el progreso de sfc/DISM/chkdsk; el boton vuelve a 'listo' enseguida (la consola es
#     independiente) y se audita el lanzamiento.
#   - resto: corre async (Start-UtilAccionStream) y STREAMEA stdout al panel de log en vivo; el
#     boton queda "Ejecutando..." (deshabilitado) + barra de progreso; al terminar muestra ok/error,
#     audita, y re-escanea via el callback OnDone. Todo async (DispatcherTimer): NO congela la UI.
# $Boton es el Button clickeado (para reflejar estado). $OnDone es un scriptblock opcional que corre
# al terminar (tipicamente el re-escaneo). $ScriptDir es la raiz del script (para el runspace).
function Invoke-UtilAccionUI {
  param($Window, [string]$Id, [string]$Modo = 'aplicar', $Boton, [scriptblock]$OnDone, [string]$ScriptDir)
  $prog = $Window.FindName('ProgUtil')
  $label = ''
  try { $label = (Get-UtilCatalogo | Where-Object id -eq $Id | Select-Object -First 1).nombre } catch {}
  $cat = ''
  try { $cat = (Get-UtilCatalogo | Where-Object id -eq $Id | Select-Object -First 1).categoria } catch {}

  # --- Via CONSOLA VISIBLE para comandos largos ---
  if ((Get-UtilAccionesConsola) -contains $Id) {
    $cmdArgs = Get-UtilComandoConsola -Id $Id
    Add-UtilLogLinea -Window $Window -Texto "> $label [$Id]: abriendo consola visible..."
    $resultado = 'ok'
    try { Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdArgs -WindowStyle Normal | Out-Null }
    catch { $resultado = "error: $($_.Exception.Message)"; Add-UtilLogLinea -Window $Window -Texto "ERROR: $($_.Exception.Message)" }
    try { Write-Audit -Accion 'apply' -UtilId $Id -UtilLabel $label -Categoria $cat -Mensaje 'lanzado en consola visible' -Resultado $resultado | Out-Null } catch {}
    Add-UtilLogLinea -Window $Window -Texto "> $label [$Id]: consola lanzada (segui el progreso en la ventana)"
    if ($OnDone) { & $OnDone }
    return
  }

  # --- Via STREAMING al panel para acciones cortas ---
  $estIni = Resolve-UtilEjecucion -Fase 'ejecutando'
  if ($Boton) { $Boton.IsEnabled = $estIni.habilitado; $Boton.Content = $estIni.etiqueta }
  if ($prog) { $prog.Visibility = 'Visible'; $prog.IsIndeterminate = $true }
  Add-UtilLogLinea -Window $Window -Texto "> $label [$Id]: ejecutando..."

  $antes = Get-UtilValorActual -Id $Id
  $job = Start-UtilAccionStream -Id $Id -Modo $Modo -ScriptDir $ScriptDir
  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromMilliseconds(120)
  $winR = $Window; $btnR = $Boton; $progR = $prog; $onDoneR = $OnDone
  $idR = $Id; $modoR = $Modo; $labelR = $label; $catR = $cat; $antesR = $antes
  # FIX seguridad #6: timeout duro. Sin esto, si la accion no termina nunca, el timer corre para siempre
  # y la card queda colgada en "Ejecutando...". A 120 ms/tick, 750 ticks = 90 s. Al excederlo cortamos
  # el runspace (Stop + limpieza), liberamos el boton y dejamos estado 'timeout' visible.
  $ticks = [ref]0
  $maxTicks = 750
  $timer.Add_Tick({
    $r = Receive-UtilStream -Job $job
    foreach ($l in $r.lineas) { Add-UtilLogLinea -Window $winR -Texto $l }
    if (-not $r.done) {
      $ticks.Value++
      if ($ticks.Value -lt $maxTicks) { return }
      # Timeout: cortar el runspace y reportar.
      $timer.Stop()
      try { $job.ps.Stop() } catch {}
      try { $job.ps.Dispose(); $job.rs.Close(); $job.rs.Dispose() } catch {}
      if ($progR) { $progR.IsIndeterminate = $false; $progR.Visibility = 'Collapsed' }
      $estTo = Resolve-UtilEjecucion -Fase 'error' -Detalle 'Timeout'
      if ($btnR) { $btnR.IsEnabled = $estTo.habilitado; $btnR.Content = $estTo.etiqueta }
      Add-UtilLogLinea -Window $winR -Texto "ERROR: $labelR [$idR]: timeout tras $([int]($maxTicks*120/1000))s, se corto la ejecucion"
      try { Write-Audit -Accion 'apply' -UtilId $idR -UtilLabel $labelR -Categoria $catR -EstadoAnterior $antesR -Resultado 'error: timeout' | Out-Null } catch {}
      if ($onDoneR) { & $onDoneR }
      return
    }
    $timer.Stop()
    if ($progR) { $progR.IsIndeterminate = $false; $progR.Visibility = 'Collapsed' }
    $fase = if ($r.resultado -eq 'ok') { 'ok' } else { 'error' }
    $est = Resolve-UtilEjecucion -Fase $fase
    if ($btnR) { $btnR.IsEnabled = $est.habilitado; $btnR.Content = $est.etiqueta }
    $despues = Get-UtilValorActual -Id $idR
    $res = if ($fase -eq 'ok') { 'ok' } else { 'error: la accion fallo (ver salida)' }
    try { Write-Audit -Accion 'apply' -UtilId $idR -UtilLabel $labelR -Categoria $catR -EstadoAnterior $antesR -EstadoNuevo $despues -Resultado $res | Out-Null } catch {}
    Add-UtilLogLinea -Window $winR -Texto "> $labelR [$idR]: $(if ($fase -eq 'ok') { 'completado' } else { 'con errores' })"
    if ($onDoneR) { & $onDoneR }
  }.GetNewClosure())
  $timer.Start()
}
