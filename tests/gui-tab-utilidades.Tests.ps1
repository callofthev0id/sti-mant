# Pester 5. Tab Utilidades: logica pura (catalogo como datos, shaping de estado, listas) con fixtures,
# sin WMI ni acciones reales. Mas un test de carga WPF real (STA) de la ventana con el panel integrado.
BeforeAll {
  . "$PSScriptRoot/../lib/audit.ps1"
  . "$PSScriptRoot/../gui/lib/gui-theme.ps1"
  . "$PSScriptRoot/../gui/lib/gui-branding.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-inventario.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-utilidades.ps1"
  . "$PSScriptRoot/../gui/lib/gui-runspace.ps1"  # New-CoreInitialSessionState (stream de acciones)
  . "$PSScriptRoot/../gui/lib/gui-tab-generar.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-mantenimiento.ps1"
  . "$PSScriptRoot/../gui/lib/gui-xaml.ps1"
}

Describe "Get-StiUtilCatalogo" {
  BeforeAll { $script:cat = Get-StiUtilCatalogo }
  It "tiene las 5 categorias del spec" {
    $cats = @($cat | ForEach-Object { $_.categoria } | Sort-Object -Unique)
    $cats | Should -Be @('debloat','limpieza','reparaciones','servicios','tweaks')
  }
  It "respeta los conteos del catalogo (7.9)" {
    @($cat | Where-Object categoria -eq 'limpieza').Count     | Should -Be 8
    @($cat | Where-Object categoria -eq 'reparaciones').Count | Should -Be 9
    @($cat | Where-Object categoria -eq 'tweaks').Count       | Should -Be 9
    @($cat | Where-Object categoria -eq 'debloat').Count      | Should -Be 7
    @($cat | Where-Object categoria -eq 'servicios').Count    | Should -Be 5
  }
  It "tiene ids unicos" {
    $ids = @($cat | ForEach-Object { $_.id })
    ($ids | Sort-Object -Unique).Count | Should -Be $ids.Count
  }
  It "marca los items delicados del spec" {
    foreach ($id in @('winsxs','faststartup','onedrive','appsoem','xbox')) {
      ($cat | Where-Object id -eq $id).delicado | Should -BeTrue
    }
  }
  It "OneDrive es aviso no reversible y los listados son tipo listado" {
    ($cat | Where-Object id -eq 'onedrive').tipo | Should -Be 'aviso'
    foreach ($id in @('bloatware','appsoem','appsinicio','servinnec','tareastele')) {
      ($cat | Where-Object id -eq $id).tipo | Should -Be 'listado'
    }
  }
}

Describe "Get-StiUtilPorCategoria" {
  It "filtra por categoria" {
    $lim = Get-StiUtilPorCategoria 'limpieza'
    @($lim).Count | Should -Be 8
    @($lim | Where-Object { $_.categoria -ne 'limpieza' }).Count | Should -Be 0
  }
}

Describe "Resolve-StiUtilEstado" {
  BeforeAll { $script:item = @{ id='temp'; nombre='Temporales' } }
  It "aplicado -> clase s-on, display por defecto 'aplicado'" {
    $r = Resolve-StiUtilEstado -Item $item -Deteccion @{ estado='aplicado' }
    $r.clase | Should -Be 's-on'; $r.display | Should -Be 'aplicado'
  }
  It "aplicado con dato usa el dato" {
    (Resolve-StiUtilEstado -Item $item -Deteccion @{ estado='aplicado'; dato='1.2 GB' }).display | Should -Be '1.2 GB'
  }
  It "disponible -> clase s-off, display 'no' por defecto" {
    $r = Resolve-StiUtilEstado -Item $item -Deteccion @{ estado='disponible' }
    $r.clase | Should -Be 's-off'; $r.display | Should -Be 'no'
  }
  It "no-aplica -> clase s-na" {
    (Resolve-StiUtilEstado -Item $item -Deteccion @{ estado='no-aplica' }).clase | Should -Be 's-na'
  }
  It "sin deteccion cae a disponible" {
    (Resolve-StiUtilEstado -Item $item -Deteccion @{}).estado | Should -Be 'disponible'
  }
}

Describe "Get-StiUtilResumen" {
  It "cuenta por estado y arma el texto de la barra" {
    $estados = @(
      @{ estado='aplicado' }, @{ estado='aplicado' },
      @{ estado='disponible' }, @{ estado='disponible' }, @{ estado='disponible' },
      @{ estado='no-aplica' }
    )
    $r = Get-StiUtilResumen -Estados $estados
    $r.aplicadas | Should -Be 2; $r.disponibles | Should -Be 3; $r.noaplican | Should -Be 1
    $r.texto | Should -Match '2 aplicadas'
  }
}

Describe "Get-StiUtilPreset" {
  It "incluye preset=true y excluye delicados" {
    $preset = Get-StiUtilPreset
    $preset | Should -Contain 'temp'
    $preset | Should -Not -Contain 'winsxs'      # delicado
    $preset | Should -Not -Contain 'faststartup' # delicado
    $preset | Should -Not -Contain 'darkmode'    # preset=false
  }
}

Describe "Format-StiPopoverItem" {
  It "clasifica impacto alto/medio/bajo a su clase" {
    (Format-StiPopoverItem @{ nombre='X'; ubicacion='Y'; impacto='alto' }).clase  | Should -Be 'i-hi'
    (Format-StiPopoverItem @{ nombre='X'; ubicacion='Y'; impacto='medio' }).clase | Should -Be 'i-md'
    (Format-StiPopoverItem @{ nombre='X'; ubicacion='Y'; impacto='bajo' }).clase  | Should -Be 'i-lo'
  }
  It "default impacto bajo si falta" {
    (Format-StiPopoverItem @{ nombre='X'; ubicacion='Y' }).impacto | Should -Be 'bajo'
  }
  It "conserva nombre y ubicacion" {
    $r = Format-StiPopoverItem @{ nombre='Adobe Updater'; ubicacion='HKLM\...\Run · AdobeAAMUpdater.exe'; impacto='medio' }
    $r.nombre | Should -Be 'Adobe Updater'
    $r.ubicacion | Should -Match 'AdobeAAMUpdater'
  }
}

Describe "Detectores read-only" {
  # Mock de los cmdlets de sistema para que el detector no toque el equipo real. Cada test fuerza
  # un valor y verifica que Test-StiUtil lo traduce al estado correcto. NO muta nada.
  It "Get-StiRegValor devuelve null si la clave no existe (no tira)" {
    Mock Get-ItemProperty { throw 'no existe' }
    Get-StiRegValor 'HKCU:\Nada' 'X' | Should -Be $null
  }
  It "faststartup: HiberbootEnabled=1 -> feature activa (aplicado)" {
    Mock Get-ItemProperty { [pscustomobject]@{ HiberbootEnabled = 1 } }
    $r = Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'faststartup')
    $r.estado | Should -Be 'aplicado'
  }
  It "faststartup: HiberbootEnabled=0 -> apagado (disponible)" {
    Mock Get-ItemProperty { [pscustomobject]@{ HiberbootEnabled = 0 } }
    $r = Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'faststartup')
    $r.estado | Should -Be 'disponible'
  }
  It "darkmode: AppsUseLightTheme=0 -> dark activo (aplicado)" {
    Mock Get-ItemProperty { [pscustomobject]@{ AppsUseLightTheme = 0 } }
    (Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'darkmode')).estado | Should -Be 'aplicado'
  }
  It "diagtrack: servicio corriendo -> aplicado; ausente -> no-aplica" {
    Mock Get-Service { [pscustomobject]@{ Status = 'Running' } }
    Mock Get-CimInstance { [pscustomobject]@{ StartMode = 'Automatic' } }
    (Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'diagtrack')).estado | Should -Be 'aplicado'
    Mock Get-Service { throw 'no existe' }
    (Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'diagtrack')).estado | Should -Be 'no-aplica'
  }
  It "accion puntual (temp) no tiene estado persistente -> disponible" {
    (Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'temp')).estado | Should -Be 'disponible'
  }
  It "Get-StiUtilDeteccionReal cubre todo el catalogo con estado valido" {
    Mock Get-ItemProperty { throw 'x' }
    Mock Get-Service { throw 'x' }
    Mock Get-AppxPackage { $null }
    Mock Get-Process { throw 'x' }
    $d = Get-StiUtilDeteccionReal
    @($d.Keys).Count | Should -Be (Get-StiUtilCatalogo).Count
    foreach ($k in $d.Keys) { $d[$k].estado | Should -BeIn @('aplicado','disponible','no-aplica') }
  }
}

Describe "Mapeo util -> accion" {
  It "toda accion/aviso/toggle del catalogo (salvo listados) tiene aplicar definido" {
    $acc = Get-StiUtilAcciones
    foreach ($item in (Get-StiUtilCatalogo | Where-Object { $_.tipo -ne 'listado' -and $_.id -ne 'onedrive' })) {
      $acc.ContainsKey($item.id) | Should -BeTrue -Because "falta accion para $($item.id)"
      $acc[$item.id].aplicar | Should -Not -BeNullOrEmpty
    }
  }
  It "los reversibles tienen revertir; los no reversibles no exigen revertir" {
    $acc = Get-StiUtilAcciones
    foreach ($item in (Get-StiUtilCatalogo | Where-Object { $_.reversible -and $acc.ContainsKey($_.id) })) {
      $acc[$item.id].revertir | Should -Not -BeNullOrEmpty -Because "$($item.id) es reversible"
    }
  }
  It "las acciones son comandos REALES, no esqueletos (no empiezan con #)" {
    $acc = Get-StiUtilAcciones
    foreach ($id in $acc.Keys) {
      foreach ($modo in @('aplicar','revertir')) {
        $txt = $acc[$id][$modo]
        if ($txt) { $txt.TrimStart() | Should -Not -Match '^#' -Because "$id/$modo debe tener comando real" }
      }
    }
  }
  It "Invoke-StiUtilAccion no tira con id desconocido" {
    Invoke-StiUtilAccion -Id 'noexiste' | Should -Match 'sin accion'
  }
  It "Invoke-StiUtilAccion ejecuta el comando real y devuelve ok (con accion mockeada y SinLog)" {
    # Reemplazamos el catalogo de acciones por una accion inocua que toca una variable global.
    Mock Get-StiUtilAcciones { @{ probe = @{ aplicar = '$global:__stiProbe = 1' } } }
    $global:__stiProbe = 0
    (Invoke-StiUtilAccion -Id 'probe' -SinLog) | Should -Match 'ok: probe'
    $global:__stiProbe | Should -Be 1
    Remove-Variable -Name __stiProbe -Scope Global -ErrorAction SilentlyContinue
  }
}

Describe "Red de seguridad (log + checkpoint + batch)" {
  It "Write-StiUtilLog delega en Write-StiAudit traduciendo modo->accion con los campos" {
    $script:__a = $null; $script:__id = $null; $script:__ant = $null; $script:__nue = $null
    Mock Write-StiAudit { $script:__a = $Accion; $script:__id = $UtilId; $script:__ant = $EstadoAnterior; $script:__nue = $EstadoNuevo; @{ eventlog=$true; json=$true; texto=$true } }
    Write-StiUtilLog -Id 'faststartup' -Modo 'aplicar' -Antes 'activo' -Despues 'apagado' | Should -BeTrue
    Should -Invoke Write-StiAudit -Times 1 -Exactly
    $script:__a   | Should -Be 'apply'
    $script:__id  | Should -Be 'faststartup'
    $script:__ant | Should -Be 'activo'
    $script:__nue | Should -Be 'apagado'
  }
  It "Write-StiUtilLog mapea revertir->undo y safety->safety" {
    $script:__acc = $null
    Mock Write-StiAudit { $script:__acc = $Accion; @{} }
    Write-StiUtilLog -Id 'faststartup' -Modo 'revertir' | Out-Null
    $script:__acc | Should -Be 'undo'
    Write-StiUtilLog -Id '_checkpoint' -Modo 'safety' | Out-Null
    $script:__acc | Should -Be 'safety'
  }
  It "Write-StiUtilLog no tira aunque Write-StiAudit falle (best-effort)" {
    Mock Write-StiAudit { throw 'sin permiso' }
    Write-StiUtilLog -Id 'x' -Modo 'aplicar' | Should -BeFalse
  }
  It "New-StiUtilCheckpoint devuelve true si Checkpoint-Computer corre" {
    Mock Checkpoint-Computer {}
    Mock Write-StiUtilLog { $true }
    New-StiUtilCheckpoint | Should -BeTrue
  }
  It "New-StiUtilCheckpoint devuelve false (no tira) si Checkpoint-Computer falla (server)" {
    Mock Checkpoint-Computer { throw 'System Restore deshabilitado' }
    Mock Write-StiUtilLog { $true }
    New-StiUtilCheckpoint | Should -BeFalse
  }
  It "Invoke-StiUtilBatch crea checkpoint solo si hay cambios persistentes (tweaks/serv/debloat)" {
    Mock New-StiUtilCheckpoint { $true }
    Mock Invoke-StiUtilAccion { "ok: $Id ($Modo)" }
    # Solo limpieza/reparaciones -> sin checkpoint.
    $r1 = Invoke-StiUtilBatch -Pendientes @{ temp='aplicar'; sfc='aplicar' }
    $r1.persistente | Should -BeFalse
    Should -Invoke New-StiUtilCheckpoint -Times 0 -Exactly
    # Incluye un tweak -> checkpoint.
    $r2 = Invoke-StiUtilBatch -Pendientes @{ faststartup='aplicar' }
    $r2.persistente | Should -BeTrue
    Should -Invoke New-StiUtilCheckpoint -Times 1 -Exactly
  }
  It "Invoke-StiUtilBatch despacha cada pendiente por Invoke-StiUtilAccion" {
    Mock New-StiUtilCheckpoint { $true }
    Mock Invoke-StiUtilAccion { "ok: $Id ($Modo)" }
    $r = Invoke-StiUtilBatch -Pendientes @{ diagtrack='aplicar'; telemetria='revertir' }
    @($r.resultados).Count | Should -Be 2
    Should -Invoke Invoke-StiUtilAccion -Times 2 -Exactly
  }
}

Describe "FIX seguridad #2: resetred/winsock delicados, fuera del preset, con aviso" {
  BeforeAll { $script:cat = Get-StiUtilCatalogo }
  It "resetred y winsock son delicado=true y preset=false" {
    foreach ($id in @('resetred','winsock')) {
      ($cat | Where-Object id -eq $id).delicado | Should -BeTrue -Because "$id corta la red"
      ($cat | Where-Object id -eq $id).preset   | Should -BeFalse -Because "$id no debe entrar al Preset STI"
    }
  }
  It "resetred y winsock declaran un aviso de corte de red" {
    foreach ($id in @('resetred','winsock')) {
      $a = ($cat | Where-Object id -eq $id).aviso
      $a | Should -Not -BeNullOrEmpty
      $a | Should -Match '(?i)(cort|sesion|remot|rdp)'
    }
  }
  It "el Preset STI ya NO incluye resetred ni winsock" {
    $preset = Get-StiUtilPreset
    $preset | Should -Not -Contain 'resetred'
    $preset | Should -Not -Contain 'winsock'
  }
}

Describe "FIX seguridad #4: chequeo de elevacion (admin)" {
  It "Test-StiUtilElevado devuelve un booleano sin tirar" {
    $r = Test-StiUtilElevado
    $r | Should -BeOfType ([bool])
  }
  It "las acciones que tocan HKLM/servicios/DISM estan marcadas como requieren-admin" {
    foreach ($id in @('telemetria','faststartup','diagtrack','xbox','dism','sfc')) {
      Test-StiUtilRequiereAdmin -Id $id | Should -BeTrue -Because "$id muta estado privilegiado"
    }
  }
  It "un tweak de HKCU (darkmode) no exige admin" {
    Test-StiUtilRequiereAdmin -Id 'darkmode' | Should -BeFalse
  }
  It "Invoke-StiUtilAccion reporta 'requiere admin' y audita error si no esta elevado" {
    Mock Test-StiUtilElevado { $false }
    Mock Get-StiUtilAcciones { @{ telemetria = @{ aplicar = '$global:__nunca = 1' } } }
    $script:__res = $null
    Mock Write-StiUtilLog { $script:__res = $Resultado; $true }
    $global:__nunca = 0
    $out = Invoke-StiUtilAccion -Id 'telemetria' -Modo 'aplicar'
    $out | Should -Match 'requiere admin'
    $global:__nunca | Should -Be 0 -Because "no debe ejecutar el comando sin privilegios"
    $script:__res | Should -Match 'sin privilegios'
    Remove-Variable -Name __nunca -Scope Global -ErrorAction SilentlyContinue
  }
  It "Invoke-StiUtilAccion ejecuta normal si esta elevado" {
    Mock Test-StiUtilElevado { $true }
    Mock Get-StiUtilAcciones { @{ telemetria = @{ aplicar = '$global:__si = 1' } } }
    $global:__si = 0
    (Invoke-StiUtilAccion -Id 'telemetria' -Modo 'aplicar' -SinLog) | Should -Match 'ok: telemetria'
    $global:__si | Should -Be 1
    Remove-Variable -Name __si -Scope Global -ErrorAction SilentlyContinue
  }
}

Describe "FIX seguridad #3: batch con checkpoint fallido y acciones no reversibles" {
  It "marca checkpoint_failed y lista las no reversibles cuando el checkpoint falla" {
    Mock New-StiUtilCheckpoint { $false }
    Mock Invoke-StiUtilAccion { "ok: $Id ($Modo)" }
    Mock Write-StiUtilLog { $true }
    # copilot/widgets son debloat reversible=false (no reinstala).
    $r = Invoke-StiUtilBatch -Pendientes @{ copilot='aplicar'; faststartup='aplicar' } -Confirmador { $false }
    $r.checkpoint_failed | Should -BeTrue
    $r.no_reversibles | Should -Contain 'copilot'
    $r.no_reversibles | Should -Not -Contain 'faststartup'  # reversible
  }
  It "si el caller NO reconfirma, omite las no reversibles pero aplica las reversibles" {
    Mock New-StiUtilCheckpoint { $false }
    Mock Invoke-StiUtilAccion { "ok: $Id ($Modo)" }
    Mock Write-StiUtilLog { $true }
    $r = Invoke-StiUtilBatch -Pendientes @{ copilot='aplicar'; faststartup='aplicar' } -Confirmador { $false }
    $r.omitidas | Should -Contain 'copilot'
    # faststartup (reversible) se aplico igual.
    Should -Invoke Invoke-StiUtilAccion -Times 1 -Exactly -ParameterFilter { $Id -eq 'faststartup' }
    Should -Invoke Invoke-StiUtilAccion -Times 0 -Exactly -ParameterFilter { $Id -eq 'copilot' }
  }
  It "si el caller reconfirma, aplica tambien las no reversibles" {
    Mock New-StiUtilCheckpoint { $false }
    Mock Invoke-StiUtilAccion { "ok: $Id ($Modo)" }
    Mock Write-StiUtilLog { $true }
    $r = Invoke-StiUtilBatch -Pendientes @{ copilot='aplicar' } -Confirmador { $true }
    @($r.omitidas).Count | Should -Be 0
    Should -Invoke Invoke-StiUtilAccion -Times 1 -Exactly -ParameterFilter { $Id -eq 'copilot' }
  }
  It "con checkpoint OK no pide reconfirmacion (aplica todo)" {
    Mock New-StiUtilCheckpoint { $true }
    Mock Invoke-StiUtilAccion { "ok: $Id ($Modo)" }
    $r = Invoke-StiUtilBatch -Pendientes @{ copilot='aplicar' } -Confirmador { $false }
    $r.checkpoint_failed | Should -BeFalse
    @($r.omitidas).Count | Should -Be 0
  }
}

Describe "FIX seguridad #5: repwu usa backup con timestamp unico" {
  It "el comando de streaming renombra a SoftwareDistribution.bak_<timestamp> y verifica" {
    $acc = Get-StiUtilAcciones
    $acc['repwu'].aplicar | Should -Match '\.bak_'           # backup con sufijo timestamp, no fijo
    $acc['repwu'].aplicar | Should -Match 'yyyyMMddHHmmss'   # timestamp unico por ejecucion
    $acc['repwu'].aplicar | Should -Match 'throw'            # aborta si el rename no se confirma
    $acc['repwu'].aplicar | Should -Not -Match 'SoftwareDistribution\.bak"'  # no usa el nombre fijo viejo
  }
  It "el comando de consola tambien usa un .bak con timestamp" {
    $cmd = Get-StiUtilComandoConsola -Id 'repwu'
    $cmd | Should -Match 'SoftwareDistribution\.bak_'
  }
}

Describe "FIX seguridad #7: seleccion de listado y reconfirmacion del popover" {
  It "Set/Get-StiUtilSeleccion registra y recupera la seleccion en el Tag" {
    $win = [pscustomobject]@{ Tag = $null }
    $n = Set-StiUtilSeleccion -Window $win -Id 'appsinicio' -Marcados @(@{ nombre='Spotify' }, @{ nombre='Steam' })
    $n | Should -Be 2
    @((Get-StiUtilSeleccion -Window $win)['appsinicio']).Count | Should -Be 2
  }
  It "una seleccion vacia limpia la entrada" {
    $win = [pscustomobject]@{ Tag = @{ utilSel = @{ appsinicio = @(@{nombre='X'}) } } }
    Set-StiUtilSeleccion -Window $win -Id 'appsinicio' -Marcados @() | Out-Null
    (Get-StiUtilSeleccion -Window $win).ContainsKey('appsinicio') | Should -BeFalse
  }
}

Describe "Detectores de listado read-only (popovers)" {
  It "Get-StiListadoAppsInicio normaliza claves Run a { nombre; ubicacion; impacto }" {
    Mock Get-ItemProperty { [pscustomobject]@{ Spotify = 'C:\spotify.exe'; PSPath = 'x' } }
    Mock Get-ChildItem { throw 'sin carpeta' }
    $r = @(Get-StiListadoAppsInicio)
    ($r | Where-Object nombre -eq 'Spotify').Count | Should -BeGreaterThan 0
    ($r | Where-Object nombre -eq 'Spotify')[0].ubicacion | Should -Match 'Run'
  }
  It "Get-StiListadoServiciosInnec solo lista servicios presentes" {
    Mock Get-Service { if ($Name -eq 'Fax') { [pscustomobject]@{ DisplayName='Fax'; Status='Stopped' } } else { throw 'no existe' } }
    $r = @(Get-StiListadoServiciosInnec)
    @($r).Count | Should -Be 1
    $r[0].nombre | Should -Be 'Fax'
  }
  It "Get-StiUtilListadosReal cubre los 5 ids de listado del catalogo" {
    Mock Get-ItemProperty { throw 'x' }; Mock Get-ChildItem { throw 'x' }
    Mock Get-Service { throw 'x' }; Mock Get-AppxPackage { @() }; Mock Get-ScheduledTask { throw 'x' }
    $l = Get-StiUtilListadosReal
    foreach ($id in @('appsinicio','servinnec','bloatware','appsoem','tareastele')) {
      $l.ContainsKey($id) | Should -BeTrue
    }
  }
}

Describe "Sin etiquetas Aplicada/Revertida en la card (FIX UX)" {
  # El usuario rechazo las etiquetas/cards "Aplicada DD-MM" y "Revertida". La card NO debe tener
  # historial pegado: el toggle refleja el estado REAL y el rastro vive en el log/auditoria. Estos
  # tests blindan que las funciones de badge ya no existan y que la UI no las pinte.
  It "no existen las funciones de badge en la card (Resolve-StiUtilBadges / Get-StiUtilBadge)" {
    Get-Command Resolve-StiUtilBadges -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    Get-Command Get-StiUtilBadge     -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
  }
  It "el codigo de la UI no construye etiquetas 'Aplicada'/'Revertida' permanentes" {
    $src = Get-Content "$PSScriptRoot/../gui/lib/gui-tab-utilidades.ps1" -Raw
    # El verbo 'Revertida'/'Aplicada' como TEXTO de badge en la card no debe aparecer en la UI.
    ($src -match "verbo\s*=.*Revertida") | Should -BeFalse
    ($src -match "Get-StiUtilBadge")     | Should -BeFalse
  }
  It "el toggle de un item reversible toma su estado del detector (ON=aplicado, OFF=disponible)" {
    # El estado del toggle se deriva de Resolve-StiUtilEstado sobre la deteccion real: 'aplicado'->ON.
    $item = Get-StiUtilCatalogo | Where-Object id -eq 'darkmode'
    $on  = Resolve-StiUtilEstado -Item $item -Deteccion @{ estado='aplicado'; dato='si' }
    $off = Resolve-StiUtilEstado -Item $item -Deteccion @{ estado='disponible'; dato='no' }
    ($on.estado  -eq 'aplicado')   | Should -BeTrue   # toggle ON
    ($off.estado -eq 'disponible') | Should -BeTrue   # toggle OFF
  }
}

Describe "Detector Dark Mode (estado real)" {
  # FIX 1: el detector debe traducir el valor REAL del registro al estado correcto. AppsUseLightTheme=0
  # => dark activo => 'aplicado' (toggle ON). =1 => light => 'disponible'. Ausente => light por defecto.
  It "AppsUseLightTheme=0 -> dark activo (aplicado)" {
    Mock Get-ItemProperty { [pscustomobject]@{ AppsUseLightTheme = 0 } }
    (Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'darkmode')).estado | Should -Be 'aplicado'
  }
  It "AppsUseLightTheme=1 -> light (disponible)" {
    Mock Get-ItemProperty { [pscustomobject]@{ AppsUseLightTheme = 1 } }
    (Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'darkmode')).estado | Should -Be 'disponible'
  }
  It "valor ausente -> light por defecto (disponible)" {
    Mock Get-ItemProperty { throw 'no existe' }
    (Test-StiUtil -Item (Get-StiUtilCatalogo | Where-Object id -eq 'darkmode')).estado | Should -Be 'disponible'
  }
}

Describe "Modelo de estado de ejecucion (Resolve-StiUtilEjecucion)" {
  It "listo: boton 'Aplicar', habilitado, sin progreso" {
    $r = Resolve-StiUtilEjecucion -Fase 'listo'
    $r.etiqueta | Should -Be 'Aplicar'; $r.habilitado | Should -BeTrue; $r.progreso | Should -BeFalse
  }
  It "ejecutando: boton 'Ejecutando...', deshabilitado, con progreso" {
    $r = Resolve-StiUtilEjecucion -Fase 'ejecutando'
    $r.etiqueta | Should -Be 'Ejecutando...'; $r.habilitado | Should -BeFalse; $r.progreso | Should -BeTrue
  }
  It "ok: vuelve a habilitado y corta el progreso" {
    $r = Resolve-StiUtilEjecucion -Fase 'ok'
    $r.habilitado | Should -BeTrue; $r.progreso | Should -BeFalse; $r.clase | Should -Be 'e-ok'
  }
  It "error: boton 'Reintentar', habilitado, clase de error" {
    $r = Resolve-StiUtilEjecucion -Fase 'error'
    $r.etiqueta | Should -Be 'Reintentar'; $r.clase | Should -Be 'e-err'
  }
}

Describe "Acciones de consola visible vs streaming" {
  It "sfc/DISM/chkdsk/winsxs van a consola visible" {
    $c = Get-StiUtilAccionesConsola
    foreach ($id in @('sfc','dism','chkdsk','winsxs')) { $c | Should -Contain $id }
  }
  It "una accion corta (temp) NO va a consola visible (se streamea)" {
    (Get-StiUtilAccionesConsola) | Should -Not -Contain 'temp'
  }
  It "Get-StiUtilComandoConsola arma el comando cmd /k para sfc y null para acciones cortas" {
    $cmd = Get-StiUtilComandoConsola -Id 'sfc'
    $cmd | Should -Match '/k'
    $cmd | Should -Match 'sfc /scannow'
    Get-StiUtilComandoConsola -Id 'temp' | Should -Be $null
  }
}

Describe "Streaming de la salida (plumbing async)" {
  It "Start/Receive-StiUtilStream encolan stdout y devuelven done+resultado ok" {
    # Reemplazamos el catalogo de acciones por un comando inocuo que emite una linea conocida.
    Mock Get-StiUtilAcciones { @{ probe = @{ aplicar = 'Write-Output "linea-de-prueba"' } } }
    $sd = (Resolve-Path "$PSScriptRoot/..").Path
    $job = Start-StiUtilAccionStream -Id 'probe' -Modo 'aplicar' -ScriptDir $sd
    $lineas = @(); $resultado = ''; $intentos = 0
    do {
      Start-Sleep -Milliseconds 100
      $r = Receive-StiUtilStream -Job $job
      $lineas += $r.lineas
      if ($r.done) { $resultado = $r.resultado }
      $intentos++
    } until ($r.done -or $intentos -gt 100)
    $r.done | Should -BeTrue
    $resultado | Should -Be 'ok'
    ($lineas -join "`n") | Should -Match 'linea-de-prueba'
  }
  It "Receive-StiUtilStream marca error si el comando tira" {
    Mock Get-StiUtilAcciones { @{ probe = @{ aplicar = 'throw "boom"' } } }
    $sd = (Resolve-Path "$PSScriptRoot/..").Path
    $job = Start-StiUtilAccionStream -Id 'probe' -Modo 'aplicar' -ScriptDir $sd
    $resultado = ''; $lineas = @(); $intentos = 0
    do {
      Start-Sleep -Milliseconds 100
      $r = Receive-StiUtilStream -Job $job
      $lineas += $r.lineas
      if ($r.done) { $resultado = $r.resultado }
      $intentos++
    } until ($r.done -or $intentos -gt 100)
    $resultado | Should -Be 'error'
    ($lineas -join "`n") | Should -Match 'boom'
  }
}

Describe "Config de la tab (ScriptDir + OnRescan)" {
  It "Set/Get-StiUtilCfg guarda y recupera la config en el Tag de la ventana" {
    $win = [pscustomobject]@{ Tag = $null }
    Set-StiUtilCfg -Window $win -ScriptDir 'C:\x' -OnRescan ([scriptblock]{ 1 })
    (Get-StiUtilCfg -Window $win).ScriptDir | Should -Be 'C:\x'
    (Get-StiUtilCfg -Window $win).OnRescan | Should -BeOfType ([scriptblock])
  }
  It "Set-StiUtilCfg preserva otras claves del Tag (pendientes)" {
    $win = [pscustomobject]@{ Tag = @{ utilPend = @{ temp = 'aplicar' } } }
    Set-StiUtilCfg -Window $win -ScriptDir 'C:\y' -OnRescan ([scriptblock]{})
    $win.Tag['utilPend']['temp'] | Should -Be 'aplicar'
    (Get-StiUtilCfg -Window $win).ScriptDir | Should -Be 'C:\y'
  }
}

Describe "New-PanelUtilidadesXaml" {
  BeforeAll { $script:panel = New-PanelUtilidadesXaml }
  It "es XML bien formado (envuelto con los namespaces de la ventana)" {
    # El fragmento usa x:Name; declarado en el Window root. Se envuelve para validar bien formado.
    $wrap = '<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">' + $panel + '</Window>'
    { [xml]$wrap } | Should -Not -Throw
  }
  It "tiene los contenedores nombrados" {
    foreach ($n in @('PanelUtilidades','TxtUtilResumen','BtnUtilReescanear','BtnUtilPreset',
                     'BtnUtilAplicar','BtnUtilRevertir','TxtUtilPendientes',
                     'ItemsLimpieza','ItemsReparaciones','ItemsTweaks','ItemsDebloat','ItemsServicios',
                     'ProgUtil','ItemsUtilLog','BtnUtilLogRefrescar','BtnUtilLogAbrir')) {
      $panel | Should -Match ([regex]::Escape("x:Name=`"$n`""))
    }
  }
}

# Carga WPF real de la ventana ENTERA con el panel integrado. Verifica que el panel y la poblacion
# en runtime no rompen el parseo ni el wiring por nombre. Solo Windows + WPF, en runspace STA.
Describe "Utilidades carga WPF (STA)" {
  $script:wpfOk = $false
  try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop; $script:wpfOk = $true } catch {}

  It "la ventana carga, se hallan los x:Name del panel y Update-UtilidadesPanel puebla sin error" -Skip:(-not $script:wpfOk) {
    $libDir = (Resolve-Path "$PSScriptRoot/../gui/lib").Path
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($ld)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      . "$ld\..\..\lib\audit.ps1"
      . "$ld\gui-theme.ps1"; . "$ld\gui-branding.ps1"; . "$ld\gui-tab-inventario.ps1"; . "$ld\gui-tab-utilidades.ps1"; . "$ld\gui-tab-generar.ps1"; . "$ld\gui-tab-mantenimiento.ps1"; . "$ld\gui-xaml.ps1"
      $x = New-StiWindowXaml -Hostname 'CLAUDE' -Version '1.0'
      $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
      $w = [Windows.Markup.XamlReader]::Load($r)
      $listados = @{ appsinicio = @( @{ nombre='Spotify'; ubicacion='Startup folder · Spotify.exe'; impacto='medio' }, @{ nombre='Adobe Updater'; ubicacion='HKLM\...\Run'; impacto='alto' } ) }
      Update-UtilidadesPanel -Window $w -Estados @{ telemetria=@{estado='aplicado'}; temp=@{estado='disponible';dato='1.2 GB'}; diagtrack=@{estado='no-aplica';dato='deshab.'} } -Listados $listados
      # Panel de log interno con records explicitos (no toca el disco).
      $recs = @([pscustomobject]@{ timestamp='2026-06-18T10:00:00-03:00'; accion='apply'; util_id='temp'; util_label='Temporales'; estado_anterior=''; estado_nuevo=''; resultado='ok' })
      Update-StiUtilLogPanel -Window $w -Records $recs
      $names = @('PanelUtilidades','BtnUtilAplicar','BtnUtilPreset','ItemsLimpieza','ItemsTweaks','ItemsServicios','TxtUtilResumen','TxtUtilPendientes','ProgUtil','ItemsUtilLog','BtnUtilLogRefrescar','BtnUtilLogAbrir')
      $ok = $true
      foreach ($n in $names) { if (-not $w.FindName($n)) { $ok = $false } }
      $poblado = ($w.FindName('ItemsLimpieza').Items.Count -eq 8) -and ($w.FindName('ItemsTweaks').Items.Count -eq 9)
      $logOk = ($w.FindName('ItemsUtilLog').Items.Count -eq 1)
      # FIX 2: append en vivo al panel de log (lo usa el streaming de "Aplicar"). Debe sumar una fila.
      Add-StiUtilLogLinea -Window $w -Texto '> probe: ejecutando...'
      $liveOk = ($w.FindName('ItemsUtilLog').Items.Count -eq 2)
      # El popover se construye sin tirar (lista real con 2 elementos).
      $pop = New-StiUtilPopover -Anchor (New-Object System.Windows.Controls.Button) -Titulo 'Apps de inicio' -Items $listados.appsinicio
      $popOk = ($null -ne $pop) -and ($pop -is [System.Windows.Controls.Primitives.Popup])
      [bool]($ok -and $poblado -and $logOk -and $liveOk -and $popOk)
    }).AddArgument($libDir)
    $res = $ps.Invoke()
    $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }
}
