# gui/lib/gui-tab-inventario.ps1 - Tab Inventario (solo lectura). Cards expandibles por
# componente con el dato crudo del relevamiento (modelo de New-InventarioModel, lib/inventario.ps1).
# La GUI NO consulta WMI: recibe el modelo ya armado. Funciones puras de shaping (testeables con
# fixtures) + New-PanelInventarioXaml (reemplaza el placeholder) + Update-InventarioPanel (runtime).
# Sin recomendaciones scripteadas (spec 5.9): dato crudo y semaforo, nada prescriptivo.

# ---- PURAS (testeables, sin WPF ni WMI) ----

# Devuelve el valor como string legible, o 's/d' si esta vacio/null (campos pendientes de collector).
function Get-InvDato {
  param($Valor, [string]$Sufijo = '')
  if ($null -eq $Valor) { return 's/d' }
  $s = ([string]$Valor).Trim()
  if ([string]::IsNullOrWhiteSpace($s)) { return 's/d' }
  if ($Sufijo) { "$s$Sufijo" } else { $s }
}

# Uptime legible derivado de so.ultimoBoot (LastBootUpTime, DateTime o string parseable).
function Get-InvUptime {
  param($UltimoBoot, $Ahora = (Get-Date))
  if (-not $UltimoBoot) { return 's/d' }
  try {
    $boot = if ($UltimoBoot -is [datetime]) { $UltimoBoot } else { [datetime]$UltimoBoot }
    $ts = $Ahora - $boot
    if ($ts.TotalSeconds -lt 0) { return 's/d' }
    $d = [int][math]::Floor($ts.TotalDays)
    if ($d -ge 1) { return "$d d $($ts.Hours) h" }
    "$($ts.Hours) h $($ts.Minutes) min"
  } catch { 's/d' }
}

# "hace N dias" desde una fecha (DateTime o string). Devuelve 's/d' si no parsea.
function Get-InvFechaRel {
  param($Fecha, $Ahora = (Get-Date))
  if (-not $Fecha) { return 's/d' }
  try {
    $f = if ($Fecha -is [datetime]) { $Fecha } else { [datetime]$Fecha }
    $d = [int][math]::Floor(($Ahora - $f).TotalDays)
    if ($d -lt 0) { return 's/d' }
    if ($d -eq 0) { 'hoy' } elseif ($d -eq 1) { 'ayer' } else { "hace $d d" }
  } catch { 's/d' }
}

# Mapea un estado semaforo a la clave de brush del tema (tabla canonica spec 3.4).
function Get-InvSemBrush {
  param([string]$Estado)
  switch ($Estado) {
    'Ok'          { 'StiVerde' }
    'Advertencia' { 'StiAmbar' }
    'Error'       { 'StiNaranja' }
    'Critico'     { 'StiRojo' }
    'Crítico'     { 'StiRojo' }
    default       { 'StiNa' }
  }
}

# Etiqueta corta del badge por estado (texto sobre el dot). Sin emojis.
function Get-InvSemLabel {
  param([string]$Estado)
  switch ($Estado) {
    'Ok'          { 'OK' }
    'Advertencia' { 'ATENCIÓN' }
    'Error'       { 'REVISAR' }
    'Critico'     { 'CRÍTICO' }
    'Crítico'     { 'CRÍTICO' }
    default       { 'N/A' }
  }
}

# Estado semaforo del fin de soporte del SO a partir del objeto soFinSoporte (Get-OsEol):
# campos eol (fecha 'yyyy-MM-dd' o $null) y soportado ($true/$false/$null). Regla:
#   fuera de soporte (soportado=$false)         -> Critico
#   soportado pero EOL dentro de ~6 meses        -> Advertencia
#   soportado y EOL lejano                        -> Ok
#   desconocido (sin mapeo: soportado=$null)      -> '' (neutro, sin semaforo)
# Devuelve @{ estado; tono } donde tono es good|warn|bad|'' para el par clave/valor.
function Get-InvEolEstado {
  param($SoFinSoporte, $Ahora = (Get-Date))
  if (-not $SoFinSoporte) { return @{ estado = 'Ok'; tono = '' } }
  $sop = $SoFinSoporte.soportado
  if ($sop -eq $false) { return @{ estado = 'Critico'; tono = 'bad' } }
  if ($sop -eq $true) {
    $eol = $SoFinSoporte.eol
    if ($eol) {
      try {
        $f = if ($eol -is [datetime]) { $eol } else { [datetime]::ParseExact([string]$eol, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) }
        if (($f - $Ahora).TotalDays -le 183) { return @{ estado = 'Advertencia'; tono = 'warn' } }
      } catch {}
    }
    return @{ estado = 'Ok'; tono = 'good' }
  }
  # soportado=$null: SO sin mapeo de EOL, no afirmamos nada.
  @{ estado = 'Ok'; tono = '' }
}

# Helper interno: arma un par clave/valor de card. tono opcional: good|warn|bad|''(neutro).
function New-InvKv {
  param([string]$K, $V, [string]$Tono = '')
  [ordered]@{ k = $K; v = (Get-InvDato $V); tono = $Tono }
}

# Card Sistema operativo (spec 5.3). Expandida por defecto.
function Get-InvCardSistema {
  param($Inv)
  $so = $Inv.so; $eq = $Inv.equipo; $o = $Inv.obsolescencia; $cx = $Inv.contexto; $sl = $Inv.salud
  $eolEtq = if ($o -and $o.soFinSoporte) { $o.soFinSoporte.etiqueta } else { $null }
  $eol    = if ($o -and $o.soFinSoporte) { $o.soFinSoporte.eol } else { $null }
  $eolEst = Get-InvEolEstado $(if ($o) { $o.soFinSoporte } else { $null })
  $estado = $eolEst.estado
  $dom = 's/d'
  if ($cx -and $cx.dominio) {
    $dom = if ($cx.dominio.enDominio) { "dominio: $($cx.dominio.dominio)" } else { "workgroup: $($cx.dominio.dominio)" }
  }
  $upd = 's/d'
  if ($cx -and $cx.ultimoUpdate) { $upd = "$($cx.ultimoUpdate.id) · $(Get-InvFechaRel $cx.ultimoUpdate.fecha)" }
  $bsod = 's/d'
  if ($sl -and $sl.bsod) { $bsod = "$($sl.bsod.minidumps) minidump(s)" + $(if ($sl.bsod.ultimo) { " · últ $(Get-InvFechaRel $sl.bsod.ultimo)" } else { '' }) }
  [ordered]@{
    titulo    = (Get-InvDato $so.caption)
    subtitulo = "capa de software · NT $(Get-InvDato $so.version)"
    estado    = $estado
    cols = @(
      [ordered]@{ titulo = 'Versión'; kv = @(
        (New-InvKv 'Edición'      $so.caption)
        (New-InvKv 'Versión NT'   $so.version)
        (New-InvKv 'Build'        $so.build)
        (New-InvKv 'Etiqueta'     $null)
        (New-InvKv 'Arquitectura' $so.arch)
        (New-InvKv 'Activación'   $null)
        (New-InvKv 'Dominio'      $dom)
      )}
      [ordered]@{ titulo = 'Estado'; kv = @(
        (New-InvKv 'Fin de soporte' $(if ($eolEtq) { "$eolEtq" + $(if ($eol) { " · $eol" } else { '' }) } else { $null }) $eolEst.tono)
        (New-InvKv 'Último update'  $upd)
        (New-InvKv 'Uptime'         (Get-InvUptime $so.ultimoBoot))
        (New-InvKv 'BSOD 30d'       $bsod)
        (New-InvKv 'Apagados 30d'   $(if ($sl) { $sl.apagadosInesperados30d } else { $null }))
        (New-InvKv 'Reinicio pend.' $null)
      )}
    )
  }
}

# Card CPU (spec 5.4).
function Get-InvCardCpu {
  param($Inv)
  $c = $Inv.cpu
  $mhz = if ($c.mhz) { "$([math]::Round([double]$c.mhz/1000,2)) GHz" } else { $null }
  [ordered]@{
    titulo    = (Get-InvDato $c.modelo)
    subtitulo = "procesador · $(Get-InvDato $c.nucleos)N / $(Get-InvDato $c.logicos)H"
    estado    = 'Ok'
    cols = @(
      [ordered]@{ titulo = 'Specs'; kv = @(
        (New-InvKv 'Modelo'         $c.modelo)
        (New-InvKv 'Núcleos / hilos' "$(Get-InvDato $c.nucleos) / $(Get-InvDato $c.logicos)")
        (New-InvKv 'Clock base'     $null)
        (New-InvKv 'Clock máx'      $mhz)
        (New-InvKv 'Caché L3'       $null)
        (New-InvKv 'Socket'         $null)
      )}
      [ordered]@{ titulo = 'Estado'; kv = @(
        (New-InvKv 'Uso actual'     $null)
        (New-InvKv 'Temperatura'    $null)
        (New-InvKv 'Virtualización' $null)
        (New-InvKv 'WHEA 30d'       $null)
      )}
    )
  }
}

# Card RAM (spec 5.5). Una card, con filas por modulo presente.
function Get-InvCardRam {
  param($Inv)
  $r = $Inv.ram
  $mods = @($r.modulos)
  $usados = $mods.Count
  $card = [ordered]@{
    titulo    = "$(Get-InvDato $r.totalGB) GB · $usados slot(s) usado(s)"
    subtitulo = "memoria física"
    estado    = 'Ok'
    cols = @(
      [ordered]@{ titulo = 'Resumen'; kv = @(
        (New-InvKv 'Total'        $(if ($null -ne $r.totalGB) { "$($r.totalGB) GB" } else { $null }))
        (New-InvKv 'Slots usados' $usados)
        (New-InvKv 'Slots totales' $null)
        (New-InvKv 'Uso actual'   $null)
      )}
    )
    modulos = @($mods | ForEach-Object {
      [ordered]@{
        slot       = (Get-InvDato $_.slot)
        gb         = $(if ($null -ne $_.gb) { "$($_.gb) GB" } else { 's/d' })
        mhz        = $(if ($_.mhz) { "$($_.mhz) MHz" } else { 's/d' })
        fabricante = (Get-InvDato $_.fabricante)
      }
    })
  }
  $card
}

# Cards Discos (spec 5.6). Una card POR disco fisico. Salud SMART es 's/d' (collector pendiente).
function Get-InvCardsDiscos {
  param($Inv)
  @(@($Inv.discos) | ForEach-Object {
    [ordered]@{
      titulo    = (Get-InvDato $_.modelo)
      subtitulo = "$(Get-InvDato $_.tipo) · $(Get-InvDato $_.gb) GB"
      estado    = 'Ok'
      cols = @(
        [ordered]@{ titulo = 'Identidad'; kv = @(
          (New-InvKv 'Modelo'    $_.modelo)
          (New-InvKv 'Tipo'      $_.tipo)
          (New-InvKv 'Capacidad' $(if ($null -ne $_.gb) { "$($_.gb) GB" } else { $null }))
          (New-InvKv 'Uso %'     $null)
          (New-InvKv 'Firmware'  $null)
          (New-InvKv 'Serial'    $null)
        )}
        [ordered]@{ titulo = 'Salud SMART'; kv = @(
          (New-InvKv 'Estado global' $null)
          (New-InvKv 'Reallocated'   $null)
          (New-InvKv 'Pending'       $null)
          (New-InvKv 'Uncorrectable' $null)
          (New-InvKv 'Power-on h'    $null)
          (New-InvKv 'Temperatura'   $null)
        )}
      )
    }
  })
}

# Card Motherboard / Firmware (spec 5.7).
function Get-InvCardMboard {
  param($Inv)
  $eq = $Inv.equipo; $o = $Inv.obsolescencia
  $bios = if ($o) { $o.bios } else { $null }
  $tpm  = if ($o) { $o.tpm } else { $null }
  $tpmTxt = if ($tpm -and $tpm.presente) { "presente · v$(Get-InvDato $tpm.version)" } else { 'ausente' }
  $sbVal = if ($o -and $null -ne $o.secureBoot) { $(if ($o.secureBoot) { 'activado' } else { 'desactivado' }) } else { $null }
  $win11 = if ($o -and $o.win11Apto) { $(if ($o.win11Apto.apto) { 'sí' } else { "no · falta: $((@($o.win11Apto.faltan)) -join ', ')" }) } else { $null }
  $estado = if ($o -and $o.secureBoot -eq $false) { 'Advertencia' } else { 'Ok' }
  [ordered]@{
    titulo    = "$(Get-InvDato $eq.fabricante) $(Get-InvDato $eq.modelo)"
    subtitulo = "placa base · firmware"
    estado    = $estado
    cols = @(
      [ordered]@{ titulo = 'Placa / BIOS'; kv = @(
        (New-InvKv 'Fabricante'    $eq.fabricante)
        (New-InvKv 'Modelo'        $eq.modelo)
        (New-InvKv 'Chipset'       $null)
        (New-InvKv 'BIOS versión'  $(if ($bios) { $bios.version } else { $null }))
        (New-InvKv 'BIOS fecha'    $(if ($bios) { $bios.fecha } else { $null }))
        (New-InvKv 'Antigüedad'    $(if ($bios -and $bios.antiguedadAnios) { "~$($bios.antiguedadAnios) años" } else { $null }) $(if ($bios -and [double]($bios.antiguedadAnios) -ge 5) { 'warn' } else { '' }))
      )}
      [ordered]@{ titulo = 'Seguridad firmware'; kv = @(
        (New-InvKv 'TPM'         $tpmTxt $(if ($tpm -and $tpm.presente) { 'good' } else { 'bad' }))
        (New-InvKv 'Secure Boot' $sbVal $(if ($o -and $o.secureBoot) { 'good' } elseif ($o -and $o.secureBoot -eq $false) { 'bad' } else { '' }))
        (New-InvKv 'Modo'        $null)
        (New-InvKv 'Apto Win 11' $win11 $(if ($o -and $o.win11Apto -and $o.win11Apto.apto) { 'good' } else { '' }))
      )}
    )
  }
}

# Cards Red (spec 5.8). Una card por adaptador activo. Expandida por densidad.
function Get-InvCardsRed {
  param($Inv)
  $cx = $Inv.contexto
  if (-not $cx) { return @() }
  @(@($cx.red) | ForEach-Object {
    $up = if ($_.ip) { 'Up' } else { 'Down' }
    [ordered]@{
      titulo    = (Get-InvDato $_.adaptador)
      subtitulo = "adaptador de red · $up"
      estado    = $(if ($_.ip) { 'Ok' } else { 'Advertencia' })
      cols = @(
        [ordered]@{ titulo = 'Adaptador'; kv = @(
          (New-InvKv 'Adaptador' $_.adaptador)
          (New-InvKv 'Tipo'      $null)
          (New-InvKv 'MAC'       $null)
          (New-InvKv 'Velocidad' $_.velocidad)
          (New-InvKv 'Estado'    $up $(if ($_.ip) { 'good' } else { 'warn' }))
        )}
        [ordered]@{ titulo = 'Configuración IP'; kv = @(
          (New-InvKv 'IP'      $_.ip)
          (New-InvKv 'Máscara' $null)
          (New-InvKv 'Gateway' $_.gateway)
          (New-InvKv 'DNS'     $(if ($_.dns) { ((@($_.dns)) -join ', ') } else { $null }))
          (New-InvKv 'DHCP'    $(if ($null -ne $_.dhcp) { $(if ($_.dhcp) { 'sí' } else { 'no' }) } else { $null }))
        )}
      )
    }
  })
}

# Rollup: todas las cards agrupadas + el contador real de discos.
function Get-InvModel {
  param($Inv)
  $discos = @(Get-InvCardsDiscos $Inv)
  [ordered]@{
    sistema = (Get-InvCardSistema $Inv)
    cpu     = (Get-InvCardCpu $Inv)
    ram     = (Get-InvCardRam $Inv)
    discos  = $discos
    nDiscos = $discos.Count
    mboard  = (Get-InvCardMboard $Inv)
    red     = @(Get-InvCardsRed $Inv)
  }
}

# ---- XAML del panel (reemplaza el placeholder) ----

function New-PanelInventarioXaml {
@'
      <ScrollViewer x:Name="PanelInventario" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
        <StackPanel>
          <TextBlock x:Name="InvVacio" Style="{StaticResource StiSecHeader}" Foreground="{StaticResource StiTexto2}" Text="Relevá el equipo (pestaña Principal) para ver el inventario."/>
          <TextBlock Style="{StaticResource StiGrupoHeader}" Text="SISTEMA OPERATIVO"/>
          <StackPanel x:Name="InvSistemaHost"/>
          <TextBlock Style="{StaticResource StiGrupoHeader}" Text="PROCESADOR"/>
          <StackPanel x:Name="InvCpuHost"/>
          <TextBlock Style="{StaticResource StiGrupoHeader}" Text="MEMORIA RAM"/>
          <StackPanel x:Name="InvRamHost"/>
          <TextBlock x:Name="InvDiscosTitulo" Style="{StaticResource StiGrupoHeader}" Text="DISCOS"/>
          <StackPanel x:Name="InvDiscosHost"/>
          <TextBlock Style="{StaticResource StiGrupoHeader}" Text="MOTHERBOARD / FIRMWARE"/>
          <StackPanel x:Name="InvMboardHost"/>
          <TextBlock Style="{StaticResource StiGrupoHeader}" Text="RED"/>
          <StackPanel x:Name="InvRedHost"/>
        </StackPanel>
      </ScrollViewer>
'@
}

# ---- Runtime: construye los Expander desde el modelo y los inserta en los hosts ----

# Crea un dot de semaforo (Ellipse) del color del estado.
function New-InvDot {
  param($Window, [string]$Estado)
  $e = New-Object System.Windows.Shapes.Ellipse
  $e.Width = 9; $e.Height = 9; $e.Margin = '0,0,7,0'; $e.VerticalAlignment = 'Center'
  $e.Fill = $Window.FindResource((Get-InvSemBrush $Estado))
  $e
}

# Construye una fila clave/valor (label Space Grotesk + valor DM Mono, tono opcional).
function New-InvKvRow {
  param($Window, $Kv)
  $g = New-Object System.Windows.Controls.Grid
  $g.Margin = '0,0,0,3'
  $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = 'Auto'
  $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = '*'
  $g.ColumnDefinitions.Add($c1); $g.ColumnDefinitions.Add($c2)
  $lbl = New-Object System.Windows.Controls.TextBlock
  $lbl.Text = $Kv.k; $lbl.FontFamily = 'Space Grotesk, Segoe UI'; $lbl.FontSize = 11
  $lbl.Foreground = $Window.FindResource('StiTexto2'); $lbl.Margin = '0,0,12,0'
  $val = New-Object System.Windows.Controls.TextBlock
  $val.Text = $Kv.v; $val.FontFamily = 'DM Mono, Consolas'; $val.FontSize = 11
  $val.HorizontalAlignment = 'Right'; $val.TextWrapping = 'Wrap'; $val.TextAlignment = 'Right'
  $tonoBrush = switch ($Kv.tono) {
    'good' { 'StiVerde' } 'warn' { 'StiAmbar' } 'bad' { 'StiRojo' } default { 'StiTexto' }
  }
  $val.Foreground = $Window.FindResource($tonoBrush)
  [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
  [System.Windows.Controls.Grid]::SetColumn($val, 1)
  [void]$g.Children.Add($lbl); [void]$g.Children.Add($val)
  $g
}

# Construye una columna (titulo + filas kv).
function New-InvCol {
  param($Window, $Col)
  $sp = New-Object System.Windows.Controls.StackPanel
  $sp.Margin = '0,0,0,0'
  $h = New-Object System.Windows.Controls.TextBlock
  $h.Text = $Col.titulo; $h.FontFamily = 'Space Grotesk, Segoe UI'; $h.FontSize = 10
  $h.FontWeight = 'Bold'; $h.Foreground = $Window.FindResource('StiTenue'); $h.Margin = '0,0,0,6'
  [void]$sp.Children.Add($h)
  foreach ($kv in $Col.kv) { [void]$sp.Children.Add((New-InvKvRow -Window $Window -Kv $kv)) }
  $sp
}

# Construye un Expander completo desde un modelo de card. Inserta filas de modulos (RAM) si hay.
function New-InvCardControl {
  param($Window, $Card, [bool]$Expandido = $false)
  $exp = New-Object System.Windows.Controls.Expander
  $exp.IsExpanded = $Expandido
  if ($Window.Resources.Contains('StiCardExpander')) { $exp.Style = $Window.FindResource('StiCardExpander') }
  $exp.Margin = '0,0,0,10'

  # Header
  $hg = New-Object System.Windows.Controls.Grid
  $hc1 = New-Object System.Windows.Controls.ColumnDefinition; $hc1.Width = '*'
  $hc2 = New-Object System.Windows.Controls.ColumnDefinition; $hc2.Width = 'Auto'
  $hg.ColumnDefinitions.Add($hc1); $hg.ColumnDefinitions.Add($hc2)
  $tit = New-Object System.Windows.Controls.StackPanel
  $t1 = New-Object System.Windows.Controls.TextBlock
  $t1.Text = $Card.titulo; $t1.FontFamily = 'Space Grotesk, Segoe UI'; $t1.FontSize = 14
  $t1.FontWeight = 'SemiBold'; $t1.Foreground = $Window.FindResource('StiTexto')
  $t2 = New-Object System.Windows.Controls.TextBlock
  $t2.Text = $Card.subtitulo; $t2.FontFamily = 'Space Grotesk, Segoe UI'; $t2.FontSize = 11
  $t2.Foreground = $Window.FindResource('StiTexto2')
  [void]$tit.Children.Add($t1); [void]$tit.Children.Add($t2)
  $estPanel = New-Object System.Windows.Controls.StackPanel
  $estPanel.Orientation = 'Horizontal'; $estPanel.VerticalAlignment = 'Center'
  [void]$estPanel.Children.Add((New-InvDot -Window $Window -Estado $Card.estado))
  $badge = New-Object System.Windows.Controls.TextBlock
  $badge.Text = (Get-InvSemLabel $Card.estado); $badge.FontFamily = 'Space Grotesk, Segoe UI'
  $badge.FontSize = 10; $badge.FontWeight = 'SemiBold'; $badge.VerticalAlignment = 'Center'
  $badge.Foreground = $Window.FindResource((Get-InvSemBrush $Card.estado))
  [void]$estPanel.Children.Add($badge)
  [System.Windows.Controls.Grid]::SetColumn($tit, 0)
  [System.Windows.Controls.Grid]::SetColumn($estPanel, 1)
  [void]$hg.Children.Add($tit); [void]$hg.Children.Add($estPanel)
  $exp.Header = $hg

  # Body: columnas en grid + modulos RAM
  $body = New-Object System.Windows.Controls.StackPanel
  $body.Margin = '4,8,4,4'
  $cg = New-Object System.Windows.Controls.Grid
  $cols = @($Card.cols)
  for ($i = 0; $i -lt $cols.Count; $i++) {
    $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = '*'
    $cg.ColumnDefinitions.Add($cd)
    $colCtl = New-InvCol -Window $Window -Col $cols[$i]
    $colCtl.Margin = $(if ($i -gt 0) { '16,0,0,0' } else { '0' })
    [System.Windows.Controls.Grid]::SetColumn($colCtl, $i)
    [void]$cg.Children.Add($colCtl)
  }
  [void]$body.Children.Add($cg)

  if ($Card.Contains('modulos') -and @($Card.modulos).Count) {
    $mh = New-Object System.Windows.Controls.TextBlock
    $mh.Text = 'Módulos por slot'; $mh.FontFamily = 'Space Grotesk, Segoe UI'; $mh.FontSize = 10
    $mh.FontWeight = 'Bold'; $mh.Foreground = $Window.FindResource('StiTenue'); $mh.Margin = '0,10,0,6'
    [void]$body.Children.Add($mh)
    foreach ($m in $Card.modulos) {
      $row = New-Object System.Windows.Controls.TextBlock
      $row.Text = ("{0}  ·  {1}  ·  {2}  ·  {3}" -f $m.slot, $m.gb, $m.mhz, $m.fabricante)
      $row.FontFamily = 'DM Mono, Consolas'; $row.FontSize = 11
      $row.Foreground = $Window.FindResource('StiTexto'); $row.Margin = '0,0,0,3'
      [void]$body.Children.Add($row)
    }
  }
  $exp.Content = $body
  $exp
}

# Puebla los hosts del panel Inventario desde el modelo $Inv (resultado de New-InventarioModel).
function Update-InventarioPanel {
  param($Window, $Inv)
  if (-not $Window -or -not $Inv) { return }
  $m = Get-InvModel $Inv
  $find = { param($n) $Window.FindName($n) }

  $vacio = & $find 'InvVacio'; if ($vacio) { $vacio.Visibility = 'Collapsed' }

  $hostSp = & $find 'InvSistemaHost'
  if ($hostSp) { $hostSp.Children.Clear(); [void]$hostSp.Children.Add((New-InvCardControl -Window $Window -Card $m.sistema -Expandido $true)) }

  $hostSp = & $find 'InvCpuHost'
  if ($hostSp) { $hostSp.Children.Clear(); [void]$hostSp.Children.Add((New-InvCardControl -Window $Window -Card $m.cpu)) }

  $hostSp = & $find 'InvRamHost'
  if ($hostSp) { $hostSp.Children.Clear(); [void]$hostSp.Children.Add((New-InvCardControl -Window $Window -Card $m.ram)) }

  $titDiscos = & $find 'InvDiscosTitulo'; if ($titDiscos) { $titDiscos.Text = "DISCOS ($($m.nDiscos))" }
  $hostSp = & $find 'InvDiscosHost'
  if ($hostSp) { $hostSp.Children.Clear(); foreach ($d in $m.discos) { [void]$hostSp.Children.Add((New-InvCardControl -Window $Window -Card $d)) } }

  $hostSp = & $find 'InvMboardHost'
  if ($hostSp) { $hostSp.Children.Clear(); [void]$hostSp.Children.Add((New-InvCardControl -Window $Window -Card $m.mboard)) }

  $hostSp = & $find 'InvRedHost'
  if ($hostSp) { $hostSp.Children.Clear(); foreach ($r in $m.red) { [void]$hostSp.Children.Add((New-InvCardControl -Window $Window -Card $r -Expandido $true)) } }
}
