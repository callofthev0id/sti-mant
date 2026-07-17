# Pester 5. Logica pura de la tab Generar con fixtures JSON en temp dir (sin C:\zback real,
# sin WMI). Mas un test de carga WPF (STA) de la ventana entera con el panel Generar integrado.
BeforeAll {
  . "$PSScriptRoot/../gui/lib/gui-tab-generar.ps1"
  . "$PSScriptRoot/../gui/lib/gui-theme.ps1"
  . "$PSScriptRoot/../gui/lib/gui-branding.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-inventario.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-utilidades.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-mantenimiento.ps1"
  . "$PSScriptRoot/../gui/lib/gui-xaml.ps1"

  function New-FixtureJson {
    param([string]$Dir, [string]$Equipo, [string]$Tipo, [object[]]$Checks, [string]$Cliente = 'ACME SA', [bool]$EsVm = $false, [string]$Tecnico = '', [string]$Usuario = '', [bool]$HypervHost = $false)
    $obj = [ordered]@{
      meta = [ordered]@{ cliente = $Cliente; tag = 'TAG-1'; hostname = $Equipo; usuario = $Usuario; tipo = $Tipo; esVm = $EsVm; hypervHost = $HypervHost; tecnico = $Tecnico }
      hardwareIds = [ordered]@{ hostname = $Equipo }
      checks = $Checks
      errores = @()
    }
    $path = Join-Path $Dir "${Equipo}_FLEET_MANT_${Tipo}_20260618.json"
    ($obj | ConvertTo-Json -Depth 6) | Out-File -FilePath $path -Encoding UTF8
    $path
  }

  $script:tmp = Join-Path ([IO.Path]::GetTempPath()) ("genfix_" + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $script:tmp | Out-Null
  New-FixtureJson -Dir $script:tmp -Equipo 'PC-VENTAS-01' -Tipo 'terminales' -EsVm $false -Tecnico 'Juan Pérez' -Usuario 'María González' -Checks @(
    @{ categoria='Seguridad'; key='chk_firewall'; label='Firewall'; estado='Ok'; detalle='activo' }
    @{ categoria='Seguridad'; key='chk_antivirus_eset'; label='Antivirus ESET'; estado='Advertencia'; detalle='desactualizado' }
  ) | Out-Null
  New-FixtureJson -Dir $script:tmp -Equipo 'PC-DEPO-02' -Tipo 'terminales' -EsVm $true -Usuario 'Depósito' -Checks @(
    @{ categoria='Seguridad'; key='chk_firewall'; label='Firewall'; estado='Error'; detalle='off' }
  ) | Out-Null
  New-FixtureJson -Dir $script:tmp -Equipo 'SRV-DC-01' -Tipo 'servidores' -EsVm $false -Usuario 'Administrador' -Checks @(
    @{ categoria='Seguridad'; key='srv_firewall'; label='Firewall'; estado='Ok'; detalle='ok' }
    @{ categoria='Seguridad'; key='srv_backup'; label='Backup (Acronis/Cobian)'; estado='Advertencia'; detalle='última 3d' }
  ) | Out-Null
  # Host fisico Hyper-V + una VM colgando, para el arbol VM->host de servidores.
  New-FixtureJson -Dir $script:tmp -Equipo 'HYPERV-HOST' -Tipo 'servidores' -EsVm $false -HypervHost $true -Usuario 'svc_backup' -Checks @(
    @{ categoria='Seguridad'; key='srv_firewall'; label='Firewall'; estado='Ok'; detalle='ok' }
    @{ categoria='Estado'; key='srv_vms'; label='Estado VMs (host Hyper-V)'; estado='Crítico'; detalle='1 VM caída' }
  ) | Out-Null
  New-FixtureJson -Dir $script:tmp -Equipo 'SRV-APP-VM' -Tipo 'servidores' -EsVm $true -Usuario 'svc_backup' -Checks @(
    @{ categoria='Seguridad'; key='srv_firewall'; label='Firewall'; estado='Error'; detalle='off' }
  ) | Out-Null
  # JSON roto (no debe abortar la deteccion)
  'no-es-json' | Out-File -FilePath (Join-Path $script:tmp 'roto_FLEET_MANT_terminales_20260618.json') -Encoding UTF8
  # JSON sin meta.tipo
  '{"meta":{"hostname":"X"},"checks":[]}' | Out-File -FilePath (Join-Path $script:tmp 'sintipo_FLEET_MANT_x_20260618.json') -Encoding UTF8
}
AfterAll {
  if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item -Recurse -Force $script:tmp }
}

Describe "Get-ChkOrder (drift vs column-spec.mjs)" {
  It "terminales tiene 26 checks" { (Get-ChkOrder -Tipo 'terminales').Count | Should -Be 26 }
  It "servidores tiene 19 checks" { (Get-ChkOrder -Tipo 'servidores').Count | Should -Be 19 }
}

Describe "Get-GenerarVocab" {
  It "term -> terminales"        { Get-GenerarVocab 'term' | Should -Be @('terminales') }
  It "srv -> servidores"         { Get-GenerarVocab 'srv'  | Should -Be @('servidores') }
  It "both -> ambos"            { (Get-GenerarVocab 'both').Count | Should -Be 2 }
}

Describe "Read-RelevamientoJson" {
  It "lee un JSON valido" {
    $r = Read-RelevamientoJson -Path (Join-Path $script:tmp 'PC-VENTAS-01_FLEET_MANT_terminales_20260618.json')
    $r.ok | Should -BeTrue
    $r.tipo | Should -Be 'terminales'
    $r.hostname | Should -Be 'PC-VENTAS-01'
    $r.usuario | Should -Be 'María González'
    @($r.checks).Count | Should -Be 2
  }
  It "no tira con JSON roto, marca invalido" {
    $r = Read-RelevamientoJson -Path (Join-Path $script:tmp 'roto_FLEET_MANT_terminales_20260618.json')
    $r.ok | Should -BeFalse
    $r.error | Should -Be 'JSON ilegible'
  }
  It "marca invalido un JSON sin meta.tipo" {
    $r = Read-RelevamientoJson -Path (Join-Path $script:tmp 'sintipo_FLEET_MANT_x_20260618.json')
    $r.ok | Should -BeFalse
    $r.error | Should -Be 'sin meta.tipo'
  }
}

Describe "Resolve-DeteccionGenerar" {
  It "term: cuenta solo terminales validos, ignora invalidos" {
    $items = Get-JsonsDeCarpeta -Carpeta $script:tmp
    $det = Resolve-DeteccionGenerar -Items $items -Seg 'term'
    $det.total | Should -Be 2
    @($det.invalidos).Count | Should -Be 2
    $det.pill | Should -Be 'terminales'
  }
  It "both: separa en dos grupos, no suma todo" {
    $items = Get-JsonsDeCarpeta -Carpeta $script:tmp
    $det = Resolve-DeteccionGenerar -Items $items -Seg 'both'
    $det.porTipo['terminales'] | Should -Be 2
    $det.porTipo['servidores'] | Should -Be 3
    $det.pill | Should -Match 'terminales'
    $det.pill | Should -Match 'servidores'
  }
  It "marca el chip de servidor con flag srv" {
    $items = Get-JsonsDeCarpeta -Carpeta $script:tmp
    $det = Resolve-DeteccionGenerar -Items $items -Seg 'srv'
    @($det.equipos).Count | Should -Be 3
    $det.equipos[0].srv | Should -BeTrue
  }
}

Describe "Resolve-PeriodoGenerar" {
  It "YYYY-MM -> label humano" {
    $p = Resolve-PeriodoGenerar -Texto '2026-06'
    $p.ym | Should -Be '2026-06'
    $p.label | Should -Be 'Jun 2026'
  }
  It "Mes YYYY -> ym" {
    $p = Resolve-PeriodoGenerar -Texto 'Junio 2026'
    $p.ym | Should -Be '2026-06'
  }
  It "formato desconocido: ym null, label = texto" {
    $p = Resolve-PeriodoGenerar -Texto 'el mes que viene'
    $p.ym | Should -BeNullOrEmpty
    $p.label | Should -Be 'el mes que viene'
  }
}

Describe "Get-EstadoCheck" {
  It "resuelve campo 'status' cuando 'estado' esta ausente (no devuelve vacio)" {
    $item = [PSCustomObject]@{
      checks = @(
        [PSCustomObject]@{ key = 'chk_test'; status = 'Ok'; categoria = 'Test' }
      )
    }
    $result = Get-EstadoCheck -Item $item -Key 'chk_test'
    $result | Should -Be 'Ok'
  }
}

Describe "New-PlanillaHtml" {
  BeforeAll {
    $script:items = Get-JsonsDeCarpeta -Carpeta $script:tmp
    $script:pTerm = New-PlanillaHtml -Items $script:items -Cliente 'ACME SA' -Periodo '2026-06' -Seg 'term'
    $script:pSrv  = New-PlanillaHtml -Items $script:items -Cliente 'ACME SA' -Periodo '2026-06' -Seg 'srv'
  }
  It "contiene los equipos y el banner con icono (circulo+check SVG)" {
    $script:pTerm | Should -Match 'PC-VENTAS-01'
    $script:pTerm | Should -Match 'PC-DEPO-02'
    $script:pTerm | Should -Match 'MANTENIMIENTO'
    $script:pTerm | Should -Match 'M50 12 A38 38'   # path del icono
  }
  It "terminales: 2 firmas al final (Tecnico + Referente), SIN columna Firma por fila" {
    $script:pTerm | Should -Match "class='firma-lbl'>Técnico<"
    $script:pTerm | Should -Match "class='firma-lbl'>Referente<"
    $script:pTerm | Should -Not -Match "<th class='firma'"
    $script:pTerm | Should -Not -Match "td class='firma'"
  }
  It "servidores: SIN firmas (ni por fila ni al final) y portrait" {
    $script:pSrv | Should -Not -Match "class='firmas'"
    $script:pSrv | Should -Not -Match "class='firma-box'"
    $script:pSrv | Should -Not -Match 'td class=.firma'
    $script:pSrv | Should -Match 'size:A4 portrait'
  }
  It "terminales: A4 landscape" {
    $script:pTerm | Should -Match 'size:A4 landscape'
  }
  It "columna Obs. es editable (contenteditable)" {
    $script:pTerm | Should -Match "td class='obs' contenteditable='true'"
  }
  It "campo Tecnico editable, prefilado desde meta.tecnico" {
    $script:pTerm | Should -Match 'Juan Pérez'
    $script:pTerm | Should -Match "class='v edit' contenteditable='true'"
  }
  It "diferencia VM vs fisico con clases en la fila" {
    $script:pTerm | Should -Match "<tr class='fisico'"
    $script:pTerm | Should -Match "<tr class='vm'"
  }
  It "terminales: celdas con label COMPACTO + color (Adv/Err entran en el recuadro)" {
    # Ok verde texto blanco; Advertencia abreviada a 'Adv' (ambar, texto oscuro legible)
    $script:pTerm | Should -Match "background:#5EAE87;color:#ffffff'>Ok<"
    $script:pTerm | Should -Match "background:#D7A858;color:#312209'>Adv<"
    $script:pTerm | Should -Match "background:#C77539;color:#ffffff'>Err<"
    $script:pTerm | Should -Match "class='st na'>N/A<"
    # NO debe salir el label largo en la grilla de terminales
    $script:pTerm | Should -Not -Match "background:#D7A858;color:#312209'>Advertencia<"
  }
  It "terminales: columna Usuario con nombre desde meta.usuario" {
    $script:pTerm | Should -Match "<th class='usr'>Usuario</th>"
    $script:pTerm | Should -Match "<td class='usr'>María González</td>"
  }
  It "footer real al pie: firmas dentro del body, footer fuera de doc-body al final" {
    $script:pTerm | Should -Match "<div class='doc'>"
    $script:pTerm | Should -Match "<div class='doc-body'>"
    # el footer cierra el doc-body antes (firmas quedan adentro, footer afuera)
    $script:pTerm | Should -Match "</div>\s*<div class='footer'>"
    $script:pTerm | Should -Match "position:fixed;bottom:0"
  }
  It "servidores: formato vertical, un bloque por servidor con tabla 3 columnas y fila por check" {
    $script:pSrv | Should -Match "<th class='mnt'>Mantenimiento</th>"
    $script:pSrv | Should -Match "<th class='est'>Estado</th>"
    $script:pSrv | Should -Match "<th class='obs'>Observaciones</th>"
    $script:pSrv | Should -Match "class='srv-card"
    $script:pSrv | Should -Match "class='srv-host'>SRV-DC-01<"
    # una fila por check (Firewall + Backup), con label + color en Estado
    $script:pSrv | Should -Match "<td class='mnt'>Firewall</td>"
    $script:pSrv | Should -Match "<td class='mnt'>Backup \(Acronis/Cobian\)</td>"
    $script:pSrv | Should -Match "background:#5EAE87;color:#ffffff'>Ok<"
    # NO grilla apaisada de servidores (no checks como columnas verticales)
    $script:pSrv | Should -Not -Match "MANTENIMIENTO DE TERMINALES"
  }
  It "servidores: Obs editable por fila (contenteditable)" {
    $script:pSrv | Should -Match "<td class='obs' contenteditable='true'>"
  }
  It "servidores: NO muestra usuario (cuenta de servicio svc_backup no aparece)" {
    $script:pSrv | Should -Not -Match 'svc_backup'
    $script:pSrv | Should -Not -Match 'Administrador'
    $script:pSrv | Should -Not -Match "class='srv-usr'"
  }
  It "servidores: header centrado con fondo suave por tipo (fisico verde, VM azul) + borde izq" {
    $script:pSrv | Should -Match 'justify-content:center'
    $script:pSrv | Should -Match '.srv-card.fisico .srv-hdr\{background:#E3EFE9'
    $script:pSrv | Should -Match '.srv-card.vm .srv-hdr\{background:#dce9fb'
    # borde izquierdo de color que le gusta al usuario
    $script:pSrv | Should -Match '.srv-card.fisico\{border-left:5px solid var\(--verde\)'
  }
  It "servidores: bloques flat con color por tipo y header centrado, sin arbol/indentacion" {
    # cada servidor es un bloque plano (sin srv-child ni conector de arbol); se mantiene el
    # color por tipo (vm/fisico) y el host en el header centrado.
    $script:pSrv | Should -Match "class='srv-host'>HYPERV-HOST<"
    $script:pSrv | Should -Match "class='srv-card vm'"
    $script:pSrv | Should -Match "class='srv-card fisico'"
    $script:pSrv | Should -Not -Match "srv-child"
    $script:pSrv | Should -Not -Match "srv-tree"
  }
}

Describe "New-InformeLocalHtml (informe de hallazgos)" {
  BeforeAll {
    $script:items = Get-JsonsDeCarpeta -Carpeta $script:tmp
    $script:inf = New-InformeLocalHtml -Items $script:items -Cliente 'ACME SA' -Periodo '2026-06' -Seg 'term'
  }
  It "lleva la leyenda de que NO es el informe oficial y los equipos" {
    $script:inf | Should -Match 'no es el informe oficial mensual del cliente'
    $script:inf | Should -Match 'PC-VENTAS-01'
  }
  It "tiene resumen ejecutivo con total de equipos y distribucion de estados" {
    $script:inf | Should -Match 'Resumen ejecutivo'
    $script:inf | Should -Match 'Equipos relevados'
    $script:inf | Should -Match 'Con hallazgos'
    # KPIs de distribucion: las tarjetas de estado con su label
    $script:inf | Should -Match "class='kpi-l'>Advertencia<"
    $script:inf | Should -Match "class='kpi-l'>Error<"
  }
  It "por equipo muestra SOLO checks no-Ok (Firewall Ok no aparece como hallazgo de PC-VENTAS-01)" {
    # PC-VENTAS-01 tiene Firewall=Ok y Antivirus=Advertencia. Solo el Advertencia debe estar como item.
    $script:inf | Should -Match "<td class='item'>Antivirus ESET</td>"
    $script:inf | Should -Not -Match "<td class='item'>Firewall</td>\s*<td class='st' style='background:#5EAE87"
  }
  It "estado general por equipo (badge) y conteo de hallazgos" {
    $script:inf | Should -Match "class='gen'"
    $script:inf | Should -Match 'hallazgo\(s\)'
  }
  It "el detalle del hallazgo aparece (no editable: es un informe, no checklist)" {
    $script:inf | Should -Match 'desactualizado'
    $script:inf | Should -Not -Match "td class='det' contenteditable='true'"
  }
  It "estado con label + color legible (Advertencia texto oscuro, Error)" {
    $script:inf | Should -Match "background:#D7A858;color:#312209'>Advertencia<"
    $script:inf | Should -Match "background:#C77539;color:#ffffff'>Error<"
  }
  It "diferencia VM vs fisico en las secciones de hallazgos" {
    $script:inf | Should -Match "<section class='fisico'"
    $script:inf | Should -Match "<section class='vm'"
  }
}

Describe "Get-AppWindow (carga WPF real con panel Generar)" {
  $script:wpfOk = $false
  try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop; $script:wpfOk = $true } catch {}

  It "la ventana entera carga y los x:Name del panel Generar se encuentran" -Skip:(-not $script:wpfOk) {
    $xaml = New-AppWindowXaml -Hostname 'CLAUDE' -Version '1.0'
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($x)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
      $w = [Windows.Markup.XamlReader]::Load($r)
      $names = @('PanelGenerar','TxtGenCarpeta','BtnGenExaminar','TxtGenCliente','TxtGenPeriodo',
                 'ChipGenTerm','ChipGenSrv','ChipGenBoth','TxtGenConteo','TxtGenPill',
                 'PanelGenEquipos','TxtGenInvalidos','BtnGenPlanilla','BtnGenInforme',
                 'TxtTecnico')
      [bool]($w -and -not (@($names | Where-Object { -not $w.FindName($_) })))
    }).AddArgument($xaml)
    $res = $ps.Invoke()
    $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }
}
