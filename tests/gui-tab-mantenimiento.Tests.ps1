# Pester 5. Logica pura de la tab Mantenimiento + carga WPF del panel integrado.
BeforeAll {
  . "$PSScriptRoot/../gui/lib/gui-tab-mantenimiento.ps1"
  . "$PSScriptRoot/../gui/lib/gui-logic.ps1"
  . "$PSScriptRoot/../gui/lib/gui-branding.ps1"
  . "$PSScriptRoot/../gui/lib/gui-theme.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-inventario.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-utilidades.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-generar.ps1"
  . "$PSScriptRoot/../gui/lib/gui-xaml.ps1"

  # Fixture: items de relevamiento (forma de New-CheckItem), sin CIM.
  $script:itemsFixture = @(
    @{ key = 'chk_cuentas_admin';   label = 'Cuentas admin (gestionadas)'; status = 'Ok';          automated = $true;  detail = 'cuentas admin OK'; rawData = $null }
    @{ key = 'chk_firewall';      label = 'Firewall';            status = 'Ok';          automated = $true;  detail = '3 perfiles';    rawData = $null }
    @{ key = 'chk_disco_smart';   label = 'Estado disco (SMART)';status = 'Error';       automated = $true;  detail = '37 reallocated';rawData = $null }
    @{ key = 'chk_updates';       label = 'Updates Windows';     status = 'Advertencia'; automated = $true;  detail = 'KB 22 dias';    rawData = $null }
    @{ key = 'chk_bateria';       label = 'Batería (laptop)';    status = 'N/A';         automated = $true;  detail = 'desktop';       rawData = $null }
    # manuales NO traen estado del script
    @{ key = 'chk_visor_eventos'; label = 'Visor de eventos';    status = 'N/A';         automated = $false; detail = '';              rawData = $null }
  )
}

Describe "Get-MantCheckCatalog" {
  It "terminal tiene 26 checks" {
    (Get-MantCheckCatalog -Tipo 'terminales').Count | Should -Be 26
  }
  It "servidor tiene 19 checks" {
    (Get-MantCheckCatalog -Tipo 'servidores').Count | Should -Be 19
  }
  It "el orden del terminal arranca por cuentas_admin y termina en limpieza_temp (orden de rowColumns)" {
    $c = Get-MantCheckCatalog -Tipo 'terminales'
    $c[0].name  | Should -Be 'chk_cuentas_admin'
    $c[-1].name | Should -Be 'chk_limpieza_temp'
  }
  It "terminal tiene 18 AUTO y 8 MANUAL" {
    $c = Get-MantCheckCatalog -Tipo 'terminales'
    @($c | Where-Object { $_.automated }).Count       | Should -Be 18
    @($c | Where-Object { -not $_.automated }).Count  | Should -Be 8
  }
  It "servidor tiene 16 AUTO y 3 MANUAL" {
    $c = Get-MantCheckCatalog -Tipo 'servidores'
    @($c | Where-Object { $_.automated }).Count       | Should -Be 16
    @($c | Where-Object { -not $_.automated }).Count  | Should -Be 3
  }
  It "no incluye host_fisico (no es check) en servidor" {
    (Get-MantCheckCatalog -Tipo 'servidores').name | Should -Not -Contain 'host_fisico'
  }
}

Describe "Get-MantCategorias" {
  It "terminal usa las 4 categorias en orden de presentacion" {
    Get-MantCategorias -Tipo 'terminales' | Should -Be @('Seguridad','Sistema y actualizaciones','Hardware y salud','Red y herramientas')
  }
}

Describe "ConvertTo-MantFilas" {
  BeforeAll {
    $script:filas = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
  }
  It "produce una fila por check del catalogo" {
    $script:filas.Count | Should -Be 26
  }
  It "AUTO con item trae el estado y el detalle del relevamiento" {
    $smart = $script:filas | Where-Object { $_.name -eq 'chk_disco_smart' }
    $smart.estado  | Should -Be 'Error'
    $smart.detalle | Should -Be '37 reallocated'
    $smart.marcado | Should -BeTrue
  }
  It "AUTO sin item queda en N/A (no relevado)" {
    $rdp = $script:filas | Where-Object { $_.name -eq 'chk_rdp' }
    $rdp.estado | Should -Be 'N/A'
  }
  It "MANUAL sin estado del script queda sin marcar (estado null)" {
    $visor = $script:filas | Where-Object { $_.name -eq 'chk_visor_eventos' }
    $visor.estado  | Should -BeNullOrEmpty
    $visor.marcado | Should -BeFalse
  }
  It "estado fuera de EST_SEM se normaliza a N/A" {
    $f = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') `
         -Items @(@{ key = 'chk_firewall'; status = 'Verde'; automated = $true; detail = ''; rawData = $null })
    ($f | Where-Object { $_.name -eq 'chk_firewall' }).estado | Should -Be 'N/A'
  }
}

Describe "Get-MantResumen" {
  It "cuenta por estado y los manuales sin estado como AMarcar" {
    $filas = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
    $r = Get-MantResumen -Filas $filas
    $r.Ok          | Should -Be 2   # cuentas_admin + firewall
    $r.Advertencia | Should -Be 1   # updates
    $r.Error       | Should -Be 1   # smart
    # bateria N/A + los AUTO sin item (cada uno N/A); AMarcar = 8 manuales (ninguno marcado)
    $r.AMarcar     | Should -Be 8
  }
}

Describe "Get-MantPendientes" {
  It "cuenta solo manuales sin estado" {
    $filas = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
    Get-MantPendientes -Filas $filas | Should -Be 8
  }
}

Describe "Get-SemBrushKey y Get-SemHex" {
  It "mapea cada estado a su brush del theme" {
    Get-SemBrushKey 'Ok'          | Should -Be 'AppAccent'
    Get-SemBrushKey 'Advertencia' | Should -Be 'AppAmbar'
    Get-SemBrushKey 'Error'       | Should -Be 'AppNaranja'
    Get-SemBrushKey 'Crítico'     | Should -Be 'AppRojo'
    Get-SemBrushKey 'N/A'         | Should -Be 'AppNa'
    Get-SemBrushKey 'loquesea'    | Should -Be 'AppNa'
  }
  It "el hex de Ok es el verde de marca #5EAE87" {
    Get-SemHex 'Ok' | Should -Be '#5EAE87'
  }
}

Describe "Badge de estado de la card (Get-SemBadgeBg / Get-SemBadgeLabel)" {
  It "el badge bg es un tinte oscuro por estado, no el hex pleno" {
    Get-SemBadgeBg 'Ok' | Should -Be '#1C2D25'
    Get-SemBadgeBg 'Ok' | Should -Not -Be (Get-SemHex 'Ok')
    Get-SemBadgeBg 'loquesea' | Should -Be '#1F2723'
  }
  It "no usa verdes ajenos al branding (#22c55e / #10b981)" {
    foreach ($e in @('Ok','Advertencia','Error','Crítico','N/A')) {
      Get-SemBadgeBg $e | Should -Not -Be '#22c55e'
      Get-SemBadgeBg $e | Should -Not -Be '#10b981'
    }
  }
  It "la etiqueta de un estado normal es el estado normalizado" {
    Get-SemBadgeLabel 'Ok'  | Should -Be 'Ok'
    Get-SemBadgeLabel 'Verde' | Should -Be 'N/A'
  }
  It "la etiqueta de un manual sin marcar (null/vacio) es 'A marcar'" {
    Get-SemBadgeLabel $null | Should -Be 'A marcar'
    Get-SemBadgeLabel ''    | Should -Be 'A marcar'
  }
}

Describe "New-PanelMantenimientoXaml" {
  It "define los x:Name que el wiring usa" {
    $x = New-PanelMantenimientoXaml
    foreach ($n in @('PanelMantenimiento','MantResumen','MantCategorias','MantPendientes','BtnGenerarMant')) {
      $x | Should -Match ([regex]::Escape("x:Name=`"$n`""))
    }
  }
  It "los estilos locales del panel van prefijados 'Mant' (no chocan con el theme)" {
    $x = New-PanelMantenimientoXaml
    $x | Should -Match ([regex]::Escape('x:Key="MantPillBorder"'))
    $x | Should -Match ([regex]::Escape('x:Key="MantPillText"'))
  }
  It "no usa verdes ajenos al branding" {
    $x = New-PanelMantenimientoXaml
    $x | Should -Not -Match '22c55e'
    $x | Should -Not -Match '10b981'
  }
}

Describe "New-MantCatHeader" {
  $script:hdrOk = $false
  try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop; $script:hdrOk = $true } catch {}
  It "arma un header con la categoria en mayusculas (render STA)" -Skip:(-not $script:hdrOk) {
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($lib)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      . $lib
      $h = New-MantCatHeader -Categoria 'Seguridad' -Count 5
      [bool]($h -is [System.Windows.Controls.Grid] -and $h.Children.Count -eq 3)
    }).AddArgument("$PSScriptRoot/../gui/lib/gui-tab-mantenimiento.ps1")
    $res = $ps.Invoke(); $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }
}

Describe "Set-MantEstadoManual y Resolve-MantEstadoEfectivo" {
  BeforeEach {
    $script:f = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
  }
  It "marca un MANUAL sin estado y queda como estado efectivo" {
    Set-MantEstadoManual -Filas $script:f -Name 'chk_visor_eventos' -Estado 'Ok' | Out-Null
    $r = $script:f | Where-Object { $_.name -eq 'chk_visor_eventos' }
    $r.estadoManual | Should -Be 'Ok'
    Resolve-MantEstadoEfectivo $r | Should -Be 'Ok'
  }
  It "el tecnico pisa un AUTO (override) y el efectivo es el manual" {
    $r = $script:f | Where-Object { $_.name -eq 'chk_disco_smart' }   # AUTO en Error
    Resolve-MantEstadoEfectivo $r | Should -Be 'Error'
    Set-MantEstadoManual -Filas $script:f -Name 'chk_disco_smart' -Estado 'Advertencia' | Out-Null
    Resolve-MantEstadoEfectivo $r | Should -Be 'Advertencia'
    Test-MantOverride $r | Should -BeTrue
  }
  It "estado manual fuera de EST_SEM se normaliza a N/A" {
    Set-MantEstadoManual -Filas $script:f -Name 'chk_visor_eventos' -Estado 'Verde' | Out-Null
    ($script:f | Where-Object { $_.name -eq 'chk_visor_eventos' }).estadoManual | Should -Be 'N/A'
  }
  It "limpiar el override ($null) vuelve al estado AUTO" {
    Set-MantEstadoManual -Filas $script:f -Name 'chk_disco_smart' -Estado 'Ok' | Out-Null
    Set-MantEstadoManual -Filas $script:f -Name 'chk_disco_smart' -Estado $null | Out-Null
    $r = $script:f | Where-Object { $_.name -eq 'chk_disco_smart' }
    $r.estadoManual | Should -BeNullOrEmpty
    Resolve-MantEstadoEfectivo $r | Should -Be 'Error'
    Test-MantOverride $r | Should -BeFalse
  }
  It "un MANUAL sin marcar tiene estado efectivo null" {
    $r = $script:f | Where-Object { $_.name -eq 'chk_visor_eventos' }
    Resolve-MantEstadoEfectivo $r | Should -BeNullOrEmpty
  }
  It "name inexistente devuelve null y no rompe" {
    Set-MantEstadoManual -Filas $script:f -Name 'no_existe' -Estado 'Ok' | Should -BeNullOrEmpty
  }
}

Describe "Set-MantObservacion" {
  It "setea la observacion y vacio la limpia" {
    $f = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
    Set-MantObservacion -Filas $f -Name 'chk_disco_smart' -Texto 'HDD de datos, cotizar reemplazo' | Out-Null
    ($f | Where-Object { $_.name -eq 'chk_disco_smart' }).observacion | Should -Be 'HDD de datos, cotizar reemplazo'
    Set-MantObservacion -Filas $f -Name 'chk_disco_smart' -Texto '' | Out-Null
    ($f | Where-Object { $_.name -eq 'chk_disco_smart' }).observacion | Should -Be ''
  }
}

Describe "Get-MantAccion" {
  It "mapea visor de eventos a un proceso eventvwr.msc" {
    $a = Get-MantAccion 'chk_visor_eventos'
    $a.tipo | Should -Be 'proceso'
    $a.comando | Should -Be 'eventvwr.msc'
  }
  It "mapea recursos compartidos a \\localhost (terminal y servidor)" {
    (Get-MantAccion 'chk_recursos_compartidos').comando | Should -Be '\\localhost'
    (Get-MantAccion 'srv_recursos_compartidos').comando | Should -Be '\\localhost'
  }
  It "inicio no deseado y software de terceros son popover" {
    (Get-MantAccion 'chk_inicio_no_deseado').tipo | Should -Be 'popover'
    (Get-MantAccion 'chk_software_terceros').tipo  | Should -Be 'popover'
  }
  It "backup y disco usan argFromRaw (carpeta de logs / desglose desde raw)" {
    (Get-MantAccion 'chk_backup_cobian').argFromRaw | Should -BeTrue
    (Get-MantAccion 'srv_backup').argFromRaw        | Should -BeTrue
    (Get-MantAccion 'chk_disco_smart').argFromRaw   | Should -BeTrue
  }
  It "el backup es popover_backup (muestra estado/logs, no abre el Explorador)" {
    (Get-MantAccion 'chk_backup_cobian').tipo | Should -Be 'popover_backup'
    (Get-MantAccion 'srv_backup').tipo        | Should -Be 'popover_backup'
    (Get-MantAccion 'chk_backup_cobian').etiqueta | Should -Be 'Ver logs'
  }
}

Describe "ConvertTo-MantBackupInfo" {
  It "arma lineas legibles desde fuente + detalle + logsDir del raw (forma de Get-BackupCheckItem)" {
    $raw = @{ fuente = 'Cobian'; logsDir = 'C:\Cobian\Logs'; installDir = 'C:\Cobian'; detalle = 'Diario: al día (últ 21/06); Semanal: atrasado (últ 14/06)' }
    $info = ConvertTo-MantBackupInfo -Detalle 'Cobian (Diario: al día)' -Raw $raw
    @($info.lineas) | Should -Contain 'Fuente: Cobian'
    @($info.lineas) | Should -Contain 'Diario: al día (últ 21/06)'
    @($info.lineas) | Should -Contain 'Semanal: atrasado (últ 14/06)'
    @($info.lineas) | Should -Contain 'Carpeta de logs: C:\Cobian\Logs'
    $info.logsDir | Should -Be 'C:\Cobian\Logs'
  }
  It "desglosa tasks crudas del raw (taskId / last / next) si vienen" {
    $raw = @{ fuente = 'Cobian'; tasks = @(
      @{ taskId = 'Docs'; last = ([datetime]'2026-06-21T03:00:00'); next = ([datetime]'2026-06-22T03:00:00'); sched = 1 }
    ) }
    $info = ConvertTo-MantBackupInfo -Detalle '' -Raw $raw
    (@($info.lineas) -join "`n") | Should -Match 'Tarea Docs'
    (@($info.lineas) -join "`n") | Should -Match 'últ 21/06'
    (@($info.lineas) -join "`n") | Should -Match 'próx 22/06'
  }
  It "cae al detalle del check cuando el raw no trae detalle" {
    $info = ConvertTo-MantBackupInfo -Detalle 'servicio:Acronis Agent:Running (revisar último backup a mano)' -Raw @{ fuente = 'Acronis Agent'; logsDir = $null }
    @($info.lineas) | Should -Contain 'Fuente: Acronis Agent'
    (@($info.lineas) -join "`n") | Should -Match 'Acronis'
    $info.logsDir | Should -BeNullOrEmpty
  }
  It "sin datos (raw null y detalle vacio) devuelve lineas vacias" {
    $info = ConvertTo-MantBackupInfo -Detalle '' -Raw $null
    @($info.lineas).Count | Should -Be 0
    $info.logsDir | Should -BeNullOrEmpty
  }
  It "un check sin accion devuelve null" {
    Get-MantAccion 'chk_firewall' | Should -BeNullOrEmpty
  }
}

Describe "ConvertTo-MantJson" {
  BeforeAll {
    $script:ctxJson = @{
      cliente = 'ACME'; tag = 'PC-01'; formFactor = 'desktop'; isVm = $false; hypervHost = $false;
      usuario = 'recepcion'; nota = '';
      os = @{ caption = 'Windows 10 Pro'; class = 'cliente'; version = '10.0.19045' }
      hw = @{ hostname = 'PC-01'; os_uuid = 'uuid-1'; disk_serial = @('S1'); hw_uuid = 'hw-1'; mac = @('AA:BB'); bios_serial = 'B1' }
    }
  }
  It "produce un check por fila con estado efectivo + observacion + override" {
    $f = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
    Set-MantEstadoManual -Filas $f -Name 'chk_visor_eventos' -Estado 'Ok' | Out-Null
    Set-MantEstadoManual -Filas $f -Name 'chk_disco_smart' -Estado 'Advertencia' | Out-Null
    Set-MantObservacion  -Filas $f -Name 'chk_disco_smart' -Texto 'HDD de datos' | Out-Null
    $obj = ConvertTo-MantJson -Filas $f -Ctx $script:ctxJson -Tipo 'terminales'
    $obj.checks.Count | Should -Be 26
    $smart = $obj.checks | Where-Object { $_.key -eq 'chk_disco_smart' }
    $smart.estado      | Should -Be 'Advertencia'   # manual pisa el AUTO Error
    $smart.override    | Should -BeTrue
    $smart.observacion | Should -Be 'HDD de datos'
    ($obj.checks | Where-Object { $_.key -eq 'chk_visor_eventos' }).estado | Should -Be 'Ok'
  }
  It "el meta y hardwareIds salen del ctx (mismo espiritu que New-MetaExport)" {
    $f = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
    $obj = ConvertTo-MantJson -Filas $f -Ctx $script:ctxJson -Tipo 'terminales'
    $obj.meta.cliente      | Should -Be 'ACME'
    $obj.meta.hostname     | Should -Be 'PC-01'
    $obj.meta.tipo         | Should -Be 'terminales'
    $obj.meta.so           | Should -Be 'Windows 10 Pro'
    $obj.hardwareIds.os_uuid | Should -Be 'uuid-1'
    $obj.hardwareIds.mac     | Should -Be @('AA:BB')
  }
  It "serializa a JSON valido (round-trip)" {
    $f = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
    $obj = ConvertTo-MantJson -Filas $f -Ctx $script:ctxJson -Tipo 'terminales'
    $json = $obj | ConvertTo-Json -Depth 8
    $back = $json | ConvertFrom-Json
    $back.meta.cliente | Should -Be 'ACME'
    @($back.checks).Count | Should -Be 26
  }
  It "un MANUAL sin marcar queda con estado vacio (null) en el JSON" {
    $f = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $script:itemsFixture
    $obj = ConvertTo-MantJson -Filas $f -Ctx $script:ctxJson -Tipo 'terminales'
    ($obj.checks | Where-Object { $_.key -eq 'chk_perifericos' }).estado | Should -BeNullOrEmpty
  }
}

# Carga WPF real: la ventana entera con el panel Mantenimiento integrado. Solo Windows+WPF, runspace STA.
Describe "Carga WPF de la ventana con el panel Mantenimiento" {
  $script:wpfOk = $false
  try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop; $script:wpfOk = $true } catch {}

  It "XamlReader.Load instancia la ventana y encuentra los x:Name del panel" -Skip:(-not $script:wpfOk) {
    $xaml = New-AppWindowXaml -Hostname 'CLAUDE' -Version '1.0'
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($x)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
      $w = [Windows.Markup.XamlReader]::Load($r)
      [bool]($w -and $w.FindName('PanelMantenimiento') -and $w.FindName('MantResumen') -and `
             $w.FindName('MantCategorias') -and $w.FindName('BtnGenerarMant'))
    }).AddArgument($xaml)
    $res = $ps.Invoke()
    $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }

  It "Update-MantenimientoPanel puebla headers de categoria + cards de check sin error" -Skip:(-not $script:wpfOk) {
    $xaml = New-AppWindowXaml -Hostname 'CLAUDE' -Version '1.0'
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($x, $libDir)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      . "$libDir/gui-tab-mantenimiento.ps1"
      $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
      $w = [Windows.Markup.XamlReader]::Load($r)
      $items = @(
        @{ key = 'chk_disco_smart'; status = 'Error'; automated = $true; detail = '37 reallocated'; rawData = $null }
        @{ key = 'chk_visor_eventos'; status = 'N/A'; automated = $false; detail = ''; rawData = $null }
      )
      $filas = ConvertTo-MantFilas -Catalogo (Get-MantCheckCatalog -Tipo 'terminales') -Items $items
      $res = Get-MantResumen -Filas $filas
      Update-MantenimientoPanel -Window $w -Filas $filas -Resumen $res -Tipo 'terminales'
      $cat = $w.FindName('MantCategorias')
      # 4 categorias presentes => al menos 4 headers (Grid) + 26 cards (Border).
      $headers = @($cat.Children | Where-Object { $_ -is [System.Windows.Controls.Grid] }).Count
      $cards   = @($cat.Children | Where-Object { $_ -is [System.Windows.Controls.Border] }).Count
      [bool]($headers -eq 4 -and $cards -eq 26)
    }).AddArgument($xaml).AddArgument("$PSScriptRoot/../gui/lib")
    $res = $ps.Invoke()
    $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }

  It "el boton de Mantenimiento dice 'Generar JSON del equipo' (no genera planilla)" -Skip:(-not $script:wpfOk) {
    $xaml = New-AppWindowXaml -Hostname 'CLAUDE' -Version '1.0'
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($x)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
      $w = [Windows.Markup.XamlReader]::Load($r)
      [string]($w.FindName('BtnGenerarMant').Content)
    }).AddArgument($xaml)
    $res = $ps.Invoke()
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $res[0] | Should -Be 'Generar JSON del equipo'
    $res[0] | Should -Not -Match 'planilla'
  }

  It "New-MantBackupPopover arma el popover con el estado del backup desde detalle+raw sin error" -Skip:(-not $script:wpfOk) {
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($libDir)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      . "$libDir/gui-tab-mantenimiento.ps1"
      $btn = New-Object System.Windows.Controls.Button
      $raw = @{ fuente = 'Cobian'; logsDir = 'C:\Cobian\Logs'; detalle = 'Diario: al día (últ 21/06)' }
      $pop = New-MantBackupPopover -Anchor $btn -Titulo 'Estado del backup' -Detalle 'Cobian (Diario)' -Raw $raw
      [bool]($pop -is [System.Windows.Controls.Primitives.Popup] -and $null -ne $pop.Child)
    }).AddArgument("$PSScriptRoot/../gui/lib")
    $res = $ps.Invoke()
    $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }
}
