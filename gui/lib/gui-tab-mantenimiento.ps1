# gui/lib/gui-tab-mantenimiento.ps1 - Tab Mantenimiento: shaping puro de checks + panel XAML.
# El core NO conoce la GUI. Aca se cruzan los items[] del relevamiento con el catalogo de checks
# (derivado de planilla-builder/src/column-spec.mjs, SINGLE SOURCE OF TRUTH) y se arma la vista.
# Catalogo EMBEBIDO: el bundle de un solo .ps1 debe ser autosuficiente (spec 6.2), no se lee el .mjs en runtime.

# EST_SEM canonico (planilla-builder/src/column-spec.mjs).
$script:MANT_EST_SEM = @('Ok', 'Advertencia', 'Error', 'Crítico', 'N/A')

# Catalogo terminal: name, label, automated, categoria. ORDEN = SPECS.terminales.rowColumns.
# Categoria = mapeo GUI (spec 6.4), NO esta en column-spec.
$script:MANT_CAT_TERM = @(
  @{ name = 'chk_cuentas_admin';         label = 'Cuentas admin (gestionadas)';        automated = $true;  categoria = 'Seguridad' }
  @{ name = 'chk_firewall';            label = 'Firewall';                   automated = $true;  categoria = 'Seguridad' }
  @{ name = 'chk_antivirus_eset';      label = 'Antivirus ESET';             automated = $true;  categoria = 'Seguridad' }
  @{ name = 'chk_updates';             label = 'Updates Windows';            automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'chk_reinicio_pendiente';  label = 'Reinicio pendiente';         automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'chk_visor_eventos';       label = 'Visor de eventos';           automated = $false; categoria = 'Sistema y actualizaciones' }
  @{ name = 'chk_ultimo_reinicio';     label = 'Último reinicio';            automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'chk_restaurar_vss';       label = 'Restaurar sistema / VSS';    automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'chk_inicio_no_deseado';   label = 'Inicio no deseado';          automated = $false; categoria = 'Sistema y actualizaciones' }
  @{ name = 'chk_software_terceros';   label = 'Softwares de terceros';      automated = $false; categoria = 'Sistema y actualizaciones' }
  @{ name = 'chk_disco_smart';         label = 'Estado disco (SMART)';       automated = $true;  categoria = 'Hardware y salud' }
  @{ name = 'chk_espacio_disco';       label = 'Espacio en disco C:';        automated = $true;  categoria = 'Hardware y salud' }
  @{ name = 'chk_ram';                 label = 'Estado RAM';                 automated = $true;  categoria = 'Hardware y salud' }
  @{ name = 'chk_hardware_visual';     label = 'Check hardware (visual)';    automated = $false; categoria = 'Hardware y salud' }
  @{ name = 'chk_perifericos';         label = 'Estado periféricos';         automated = $false; categoria = 'Hardware y salud' }
  @{ name = 'chk_ups';                 label = 'UPS';                        automated = $false; categoria = 'Hardware y salud' }
  @{ name = 'chk_bateria';             label = 'Batería (laptop)';           automated = $true;  categoria = 'Hardware y salud' }
  @{ name = 'chk_conectividad';        label = 'Conectividad (gateway+DNS)'; automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'chk_teamviewer';          label = 'TeamViewer Host';        automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'chk_recursos_compartidos';label = 'Recursos compartidos';       automated = $false; categoria = 'Seguridad' }
  @{ name = 'chk_rdp';                 label = 'Configuración RDP';          automated = $true;  categoria = 'Seguridad' }
  @{ name = 'chk_wifi';                label = 'Adaptador WiFi (laptop)';    automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'chk_ocs';                 label = 'OCS Agent + inventario';     automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'chk_backup_cobian';       label = 'Backup Cobian';              automated = $false; categoria = 'Red y herramientas' }
  @{ name = 'chk_cloud_sync';          label = 'Google Drive / OneDrive';    automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'chk_limpieza_temp';       label = 'Limpieza temporales';        automated = $true;  categoria = 'Sistema y actualizaciones' }
)

# Catalogo servidor: ORDEN = SPECS.servidores.rowColumns. host_fisico no es check (se omite).
$script:MANT_CAT_SRV = @(
  @{ name = 'srv_cuentas_admin';          label = 'Cuentas admin (gestionadas)';        automated = $true;  categoria = 'Seguridad' }
  @{ name = 'srv_firewall';             label = 'Firewall';                   automated = $true;  categoria = 'Seguridad' }
  @{ name = 'srv_antivirus_eset';       label = 'Antivirus ESET';             automated = $true;  categoria = 'Seguridad' }
  @{ name = 'srv_updates';              label = 'Updates Windows Server';     automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'srv_rdp';                  label = 'RDP hardening (NLA)';        automated = $true;  categoria = 'Seguridad' }
  @{ name = 'srv_visor_eventos';        label = 'Visor de eventos';           automated = $false; categoria = 'Sistema y actualizaciones' }
  @{ name = 'srv_ultimo_reinicio';      label = 'Último reinicio';            automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'srv_vss';                  label = 'Versiones anteriores / VSS'; automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'srv_disco_smart';          label = 'Estado discos (SMART)';      automated = $true;  categoria = 'Hardware y salud' }
  @{ name = 'srv_espacio_disco';        label = 'Espacio en disco';           automated = $true;  categoria = 'Hardware y salud' }
  @{ name = 'srv_backup';               label = 'Backup (Acronis/Cobian)';    automated = $false; categoria = 'Red y herramientas' }
  @{ name = 'srv_ocs';                  label = 'OCS Agent + inventario';     automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'srv_teamviewer';           label = 'TeamViewer Host';        automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'srv_encendido_auto';       label = 'Encendido automático';       automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'srv_apagado_auto';         label = 'Apagado automático';         automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'srv_servicios_rol';        label = 'Servicios por rol';          automated = $true;  categoria = 'Sistema y actualizaciones' }
  @{ name = 'srv_vms';                  label = 'Estado VMs (host Hyper-V)';  automated = $true;  categoria = 'Hardware y salud' }
  @{ name = 'srv_conectividad';         label = 'Conectividad (gateway+DNS)'; automated = $true;  categoria = 'Red y herramientas' }
  @{ name = 'srv_recursos_compartidos'; label = 'Recursos compartidos';       automated = $false; categoria = 'Seguridad' }
)

# Orden de presentacion de las categorias (spec 6.4).
$script:MANT_CAT_ORDER = @('Seguridad', 'Sistema y actualizaciones', 'Hardware y salud', 'Red y herramientas')

# PURO. Devuelve el catalogo de checks para el tipo (copia, no la referencia compartida).
function Get-MantCheckCatalog {
  param([string]$Tipo = 'terminales')
  $src = if ($Tipo -eq 'servidores') { $script:MANT_CAT_SRV } else { $script:MANT_CAT_TERM }
  @($src | ForEach-Object { @{ name = $_.name; label = $_.label; automated = $_.automated; categoria = $_.categoria } })
}

# PURO. Categorias presentes en el tipo, en el orden de presentacion.
function Get-MantCategorias {
  param([string]$Tipo = 'terminales')
  $cat = Get-MantCheckCatalog -Tipo $Tipo
  $presentes = $cat.categoria | Select-Object -Unique
  @($script:MANT_CAT_ORDER | Where-Object { $presentes -contains $_ })
}

# PURO. Normaliza un estado al set EST_SEM; cualquier valor fuera de la tabla cae a N/A (spec 3.4).
function Get-MantEstadoNorm {
  param([string]$Estado)
  if ($script:MANT_EST_SEM -contains $Estado) { return $Estado }
  'N/A'
}

# PURO. Cruza el catalogo con los items[] del relevamiento (por key) y arma las filas shaped.
# AUTO: estado + detalle salen del item. MANUAL: estado $null (a marcar) salvo que el item ya traiga uno valido.
# La fila lleva: name, label, automated, categoria, estado (string o $null), detalle, raw, marcado (bool).
function ConvertTo-MantFilas {
  param([object[]]$Catalogo, [object[]]$Items)
  $byKey = @{}
  foreach ($i in $Items) { if ($i -and $i.key) { $byKey[$i.key] = $i } }
  @($Catalogo | ForEach-Object {
    $entry = $_
    $it = $byKey[$entry.name]
    $estado = $null
    $detalle = ''
    $raw = $null
    if ($it) {
      $detalle = [string]$it.detail
      $raw = $it.rawData
      $st = [string]$it.status
      if ($entry.automated) {
        # AUTO: el script siempre asigna un estado (aunque sea N/A).
        $estado = Get-MantEstadoNorm $st
      }
      # MANUAL: el script NO marca el estado (lo decide el tecnico). El item solo aporta detalle/contexto
      # pre-relevado (ej backup multi-fuente). 'N/A' que el script emite como placeholder NO cuenta como marcado.
    } elseif ($entry.automated) {
      # AUTO sin item (no relevado todavia): N/A.
      $estado = 'N/A'
    }
    [ordered]@{
      name = $entry.name; label = $entry.label; automated = [bool]$entry.automated;
      categoria = $entry.categoria; estado = $estado; detalle = $detalle; raw = $raw;
      marcado = ($null -ne $estado); estadoManual = $null; observacion = ''
    }
  })
}

# PURO. Conteo por estado del semaforo + "a marcar (tecnico)" = manuales sin estado (spec 6.3).
function Get-MantResumen {
  param([object[]]$Filas)
  $r = [ordered]@{ Ok = 0; Advertencia = 0; Error = 0; 'Crítico' = 0; 'N/A' = 0; AMarcar = 0 }
  foreach ($f in $Filas) {
    if ($null -eq $f.estado) {
      $r.AMarcar++
    } else {
      $e = Get-MantEstadoNorm $f.estado
      $r[$e]++
    }
  }
  $r
}

# PURO. Cantidad de checks manuales sin estado (los que bloquean el cierre limpio, spec 6.11).
function Get-MantPendientes {
  param([object[]]$Filas)
  @($Filas | Where-Object { (-not $_.automated) -and ($null -eq $_.estado) }).Count
}

# PURO. Key del brush del theme para un estado del semaforo (tabla central, spec 3.4). Nunca hardcode por fila.
function Get-SemBrushKey {
  param([string]$Estado)
  switch (Get-MantEstadoNorm $Estado) {
    'Ok'          { 'AppAccent' }
    'Advertencia' { 'AppAmbar' }
    'Error'       { 'AppNaranja' }
    'Crítico'     { 'AppRojo' }
    default       { 'AppNa' }
  }
}

# PURO. Hex del semaforo (para el punto de estado, que se pinta en runtime por fila).
function Get-SemHex {
  param([string]$Estado)
  switch (Get-MantEstadoNorm $Estado) {
    'Ok'          { '#5EAE87' }
    'Advertencia' { '#C79C53' }
    'Error'       { '#C77539' }
    'Crítico'     { '#DA6A72' }
    default       { '#71837A' }
  }
}

# PURO. Hex del fondo tenue del badge de estado (tinte del color del semaforo sobre la card oscura).
# Se usa como Background del badge; el texto va en el hex pleno de Get-SemHex.
function Get-SemBadgeBg {
  param([string]$Estado)
  switch (Get-MantEstadoNorm $Estado) {
    'Ok'          { '#1C2D25' }
    'Advertencia' { '#2E2414' }
    'Error'       { '#2E1F14' }
    'Crítico'     { '#351C1E' }
    default       { '#1F2723' }
  }
}

# PURO. Etiqueta corta del badge de estado para la card. $null (manual sin marcar) => "A marcar".
function Get-SemBadgeLabel {
  param($Estado)
  if ($null -eq $Estado -or '' -eq [string]$Estado) { return 'A marcar' }
  Get-MantEstadoNorm ([string]$Estado)
}

# PURO. Setea el estado MANUAL del tecnico sobre la fila cuyo name coincide (override del AUTO o
# unica via de marcar en los MANUAL). Valida contra EST_SEM; un valor fuera de la tabla cae a N/A.
# Pasar $Estado = $null o '' limpia el override (vuelve al AUTO). Muta la fila in-place y la devuelve.
function Set-MantEstadoManual {
  param([object[]]$Filas, [string]$Name, $Estado)
  foreach ($f in $Filas) {
    if ($f.name -eq $Name) {
      if ($null -eq $Estado -or '' -eq [string]$Estado) {
        $f.estadoManual = $null
      } else {
        $f.estadoManual = Get-MantEstadoNorm ([string]$Estado)
      }
      return $f
    }
  }
  $null
}

# PURO. Estado a usar para el output: el MANUAL del tecnico si esta seteado, si no el AUTO.
# Un MANUAL sin marcar y sin estado AUTO devuelve $null (sigue "a marcar").
function Resolve-MantEstadoEfectivo {
  param($Fila)
  $man = $null
  if ($Fila -is [System.Collections.IDictionary]) {
    if ($Fila.Contains('estadoManual')) { $man = $Fila['estadoManual'] }
  } else {
    $man = $Fila.estadoManual
  }
  if ($man) { return [string]$man }
  if ($Fila.estado) { return [string]$Fila.estado }
  $null
}

# PURO. True si el tecnico piso un estado AUTO con uno distinto (flag override para el JSON).
function Test-MantOverride {
  param($Fila)
  $man = $null
  if ($Fila -is [System.Collections.IDictionary]) {
    if ($Fila.Contains('estadoManual')) { $man = $Fila['estadoManual'] }
  } else { $man = $Fila.estadoManual }
  [bool]($Fila.automated -and $man -and ($man -ne $Fila.estado))
}

# PURO. Setea/actualiza la observacion del tecnico sobre la fila (spec 6.8). String vacio = sin nota.
# Muta in-place y devuelve la fila.
function Set-MantObservacion {
  param([object[]]$Filas, [string]$Name, [string]$Texto)
  foreach ($f in $Filas) {
    if ($f.name -eq $Name) {
      $f.observacion = if ($null -eq $Texto) { '' } else { [string]$Texto }
      return $f
    }
  }
  $null
}

# Mapeo check -> accion contextual, como DATOS (spec 6.9). NO ejecuta nada: describe la accion.
# tipo: 'proceso' (Start-Process de algo de Windows) | 'popover' (lista de fila.raw) |
#       'popover_backup' (muestra el estado/logs del backup desde detalle+raw, con "Abrir carpeta" opcional).
# Para 'proceso': comando + args. Para 'popover'/'popover_backup': titulo de la lista.
# El backup ('argFromRaw') resuelve la carpeta de logs en runtime desde fila.raw (fuente detectada).
$script:MANT_ACCIONES = @{
  'chk_visor_eventos'        = @{ tipo = 'proceso'; etiqueta = 'Abrir Visor';      comando = 'eventvwr.msc';  args = $null }
  'srv_visor_eventos'        = @{ tipo = 'proceso'; etiqueta = 'Abrir Visor';      comando = 'eventvwr.msc';  args = $null }
  'chk_recursos_compartidos' = @{ tipo = 'proceso'; etiqueta = 'Abrir \\localhost'; comando = '\\localhost';  args = $null }
  'srv_recursos_compartidos' = @{ tipo = 'proceso'; etiqueta = 'Abrir \\localhost'; comando = '\\localhost';  args = $null }
  'chk_backup_cobian'        = @{ tipo = 'popover_backup'; etiqueta = 'Ver logs';   titulo = 'Estado del backup'; argFromRaw = $true }
  'srv_backup'               = @{ tipo = 'popover_backup'; etiqueta = 'Ver logs';   titulo = 'Estado del backup'; argFromRaw = $true }
  'chk_disco_smart'          = @{ tipo = 'proceso'; etiqueta = 'Ver disco';        comando = 'explorer.exe';  args = $null; argFromRaw = $true }
  'srv_disco_smart'          = @{ tipo = 'proceso'; etiqueta = 'Ver disco';        comando = 'explorer.exe';  args = $null; argFromRaw = $true }
  'chk_inicio_no_deseado'    = @{ tipo = 'popover';  etiqueta = 'Ver lista';        titulo = 'Inicio no deseado' }
  'chk_software_terceros'    = @{ tipo = 'popover';  etiqueta = 'Ver lista';        titulo = 'Software de terceros' }
}

# PURO. Descriptor de accion contextual para un check (o $null si no tiene). Copia, no la referencia.
function Get-MantAccion {
  param([string]$Name)
  if (-not $script:MANT_ACCIONES.ContainsKey($Name)) { return $null }
  $a = $script:MANT_ACCIONES[$Name]
  $copy = @{}
  foreach ($k in $a.Keys) { $copy[$k] = $a[$k] }
  $copy
}

# PURO. Serializa las filas del panel al objeto JSON del equipo (spec 6.11, mismo espiritu que
# New-MetaExport de lib/output.ps1). Cada check lleva el estado EFECTIVO (manual u auto), el flag de
# override, automatizado, detalle, raw y la observacion del tecnico. $Ctx aporta meta + hardwareIds.
# Devuelve el [ordered] (no escribe disco: eso lo hace el handler con ConvertTo-Json + Out-File).
function ConvertTo-MantJson {
  param([object[]]$Filas, $Ctx, [string]$Tipo = 'terminales')
  $checks = @()
  foreach ($f in $Filas) {
    $obs = if ($f -is [System.Collections.IDictionary] -and $f.Contains('observacion')) { [string]$f['observacion'] }
           elseif ($f.PSObject.Properties['observacion']) { [string]$f.observacion } else { '' }
    $checks += [ordered]@{
      categoria    = $f.categoria
      key          = $f.name
      label        = $f.label
      estado       = Resolve-MantEstadoEfectivo $f
      automatizado = [bool]$f.automated
      override     = Test-MantOverride $f
      detalle      = [string]$f.detalle
      raw          = $f.raw
      observacion  = $obs
    }
  }
  $hw = if ($Ctx -and $Ctx.hw) { $Ctx.hw } else { $null }
  $host0 = if ($hw -and $hw.hostname) { $hw.hostname } elseif ($Ctx -and $Ctx.hostname) { $Ctx.hostname } else { $env:COMPUTERNAME }
  $osCap = if ($Ctx -and $Ctx.os) { $Ctx.os.caption } else { '' }
  $osCls = if ($Ctx -and $Ctx.os) { $Ctx.os.class }   else { '' }
  $osVer = if ($Ctx -and $Ctx.os) { $Ctx.os.version } else { '' }
  $sv = if (Get-Variable -Name SCRIPT_VERSION -Scope Global -ErrorAction SilentlyContinue) { $SCRIPT_VERSION } else { '' }
  [ordered]@{
    meta = [ordered]@{
      cliente = $Ctx.cliente; tag = $Ctx.tag; hostname = $host0; tipo = $Tipo;
      so = $osCap; soClase = $osCls; soVersion = $osVer;
      formFactor = $Ctx.formFactor; esVm = [bool]$Ctx.isVm; hypervHost = [bool]$Ctx.hypervHost;
      fecha = (Get-Date -Format 'o'); scriptVersion = $sv;
      usuario = $Ctx.usuario; nota = $Ctx.nota
    }
    hardwareIds = [ordered]@{
      os_uuid = $(if ($hw) { $hw.os_uuid } else { '' }); disk_serial = @($(if ($hw) { $hw.disk_serial }));
      hw_uuid = $(if ($hw) { $hw.hw_uuid } else { '' }); mac = @($(if ($hw) { $hw.mac }));
      bios_serial = $(if ($hw) { $hw.bios_serial } else { '' }); hostname = $host0
    }
    checks = $checks
    errores = @()
  }
}

# Devuelve el XAML del panel Mantenimiento (reemplaza el placeholder). Las pills y los grupos se
# pueblan en runtime con Update-MantenimientoPanel; el XAML define la estructura y los x:Name.
function New-PanelMantenimientoXaml {
  @"
      <Grid x:Name="PanelMantenimiento" Visibility="Collapsed">
        <Grid.Resources>
          <!-- Estilos LOCALES del panel (x:Key prefijado 'Mant' para no chocar con el theme global). -->
          <Style x:Key="MantPillBorder" TargetType="Border">
            <Setter Property="Background" Value="{StaticResource AppCard}"/>
            <Setter Property="BorderBrush" Value="{StaticResource AppBorde}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="13"/>
            <Setter Property="Padding" Value="11,5"/>
            <Setter Property="Margin" Value="0,0,7,0"/>
          </Style>
          <Style x:Key="MantPillText" TargetType="TextBlock">
            <Setter Property="Foreground" Value="{StaticResource AppTexto}"/>
            <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
          </Style>
        </Grid.Resources>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Resumen por estado (spec 6.3): conteo visual por estado del semaforo. -->
        <Border Grid.Row="0" Background="{StaticResource AppChipBar}" BorderBrush="{StaticResource AppAccent}" BorderThickness="0,0,0,2" Padding="4,10" Margin="0,0,0,10">
          <StackPanel>
            <TextBlock Text="RESUMEN DEL EQUIPO" Foreground="{StaticResource AppTenue}" FontFamily="Space Grotesk, Segoe UI" FontWeight="Bold" FontSize="10" Margin="2,0,0,7"/>
            <ItemsControl x:Name="MantResumen">
              <ItemsControl.ItemsPanel>
                <ItemsPanelTemplate><WrapPanel Orientation="Horizontal"/></ItemsPanelTemplate>
              </ItemsControl.ItemsPanel>
              <ItemsControl.ItemTemplate>
                <DataTemplate>
                  <Border Style="{StaticResource MantPillBorder}">
                    <StackPanel Orientation="Horizontal">
                      <Border Width="10" Height="10" CornerRadius="5" VerticalAlignment="Center" Margin="0,0,7,0">
                        <Border.Background><SolidColorBrush Color="{Binding Color}"/></Border.Background>
                      </Border>
                      <TextBlock Text="{Binding Texto}" Style="{StaticResource MantPillText}"/>
                    </StackPanel>
                  </Border>
                </DataTemplate>
              </ItemsControl.ItemTemplate>
            </ItemsControl>
          </StackPanel>
        </Border>

        <!-- Checks agrupados por categoria. Las cards se construyen en runtime (controles
             interactivos: selector de estado, observacion, accion contextual, popover). -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
          <StackPanel x:Name="MantCategorias"/>
        </ScrollViewer>

        <!-- Pie: pendientes + generar (spec 6.11) -->
        <Border Grid.Row="2" Background="{StaticResource AppChipBar}" BorderBrush="{StaticResource AppBordeSutil}" BorderThickness="0,1,0,0" Padding="4,11" Margin="0,10,0,0">
          <Grid>
            <TextBlock x:Name="MantPendientes" Foreground="{StaticResource AppTexto2}" FontFamily="Space Grotesk, Segoe UI" FontSize="11.5" VerticalAlignment="Center" Text="Relevá el equipo para poblar los checks."/>
            <Button x:Name="BtnGenerarMant" Style="{StaticResource AppBtnPrimary}" Content="Generar JSON del equipo" HorizontalAlignment="Right"/>
          </Grid>
        </Border>
      </Grid>
"@
}

# Estado vivo del panel guardado en $Window.Tag (no hay property-bag arbitrario en Window). El handler
# de BtnGenerarMant lo recupera con Get-MantPanelFilas para serializar lo que cargo el tecnico.
function Get-MantPanelFilas { param($Window) if ($Window -and $Window.Tag -is [hashtable]) { $Window.Tag['mantFilas'] } else { $null } }
function Get-MantPanelTipo  { param($Window) if ($Window -and $Window.Tag -is [hashtable] -and $Window.Tag['mantTipo']) { $Window.Tag['mantTipo'] } else { 'terminales' } }

# Refresca pills del resumen y el contador del pie desde las filas vivas (tras un cambio manual).
function Update-MantResumenUI {
  param($Window)
  $filas = Get-MantPanelFilas -Window $Window
  if ($null -eq $filas) { return }
  # Resumen recomputado con el estado EFECTIVO (manual pisa auto).
  $r = [ordered]@{ Ok = 0; Advertencia = 0; Error = 0; 'Crítico' = 0; 'N/A' = 0; AMarcar = 0 }
  foreach ($f in $filas) {
    $eff = Resolve-MantEstadoEfectivo $f
    if ($null -eq $eff) { $r.AMarcar++ } else { $r[(Get-MantEstadoNorm $eff)]++ }
  }
  $pills = New-Object System.Collections.ArrayList
  $defs = @(
    @{ k = 'Ok';          hex = '#5EAE87' }
    @{ k = 'Advertencia'; hex = '#C79C53' }
    @{ k = 'Error';       hex = '#C77539' }
    @{ k = 'Crítico';     hex = '#DA6A72' }
    @{ k = 'N/A';         hex = '#71837A' }
  )
  foreach ($d in $defs) { $n = [int]$r[$d.k]; if ($n -gt 0) { [void]$pills.Add([pscustomobject]@{ Color = $d.hex; Texto = "$n $($d.k)" }) } }
  if ([int]$r.AMarcar -gt 0) { [void]$pills.Add([pscustomobject]@{ Color = '#C79C53'; Texto = "$([int]$r.AMarcar) a marcar (técnico)" }) }
  $resCtl = $Window.FindName('MantResumen')
  if ($resCtl) { $resCtl.ItemsSource = $pills }
  # Pendientes = manuales sin estado efectivo.
  $pend = @($filas | Where-Object { (-not $_.automated) -and ($null -eq (Resolve-MantEstadoEfectivo $_)) }).Count
  $pendCtl = $Window.FindName('MantPendientes')
  if ($pendCtl) {
    $pendCtl.Text = if ($pend -gt 0) { "$pend checks manuales por completar antes de generar el JSON" } else { "Sin checks manuales pendientes." }
  }
}

# Puebla el panel en runtime desde las filas shaped + el resumen. Recibe el Window y los datos.
# Construye cada fila con controles interactivos (patron de Update-UtilidadesPanel): punto de estado,
# label, detalle, tag de naturaleza, selector de estado (ComboBox), boton de accion contextual/popover
# e input de observacion. Los controles mutan las filas vivas guardadas en $Window.Tag.
function Update-MantenimientoPanel {
  param($Window, [object[]]$Filas, $Resumen, [string]$Tipo = 'terminales')

  # Guardar las filas vivas para el handler de Generar.
  if (-not ($Window.Tag -is [hashtable])) { $Window.Tag = @{} }
  $Window.Tag['mantFilas'] = $Filas
  $Window.Tag['mantTipo']  = $Tipo

  # Pills del resumen (del Resumen pre-calculado para el primer pintado).
  $pills = New-Object System.Collections.ArrayList
  $defs = @(
    @{ k = 'Ok';          hex = '#5EAE87' }
    @{ k = 'Advertencia'; hex = '#C79C53' }
    @{ k = 'Error';       hex = '#C77539' }
    @{ k = 'Crítico';     hex = '#DA6A72' }
    @{ k = 'N/A';         hex = '#71837A' }
  )
  foreach ($d in $defs) {
    $n = [int]$Resumen[$d.k]
    if ($n -gt 0) { [void]$pills.Add([pscustomobject]@{ Color = $d.hex; Texto = "$n $($d.k)" }) }
  }
  if ([int]$Resumen.AMarcar -gt 0) {
    [void]$pills.Add([pscustomobject]@{ Color = '#C79C53'; Texto = "$([int]$Resumen.AMarcar) a marcar (técnico)" })
  }
  $resCtl = $Window.FindName('MantResumen')
  if ($resCtl) { $resCtl.ItemsSource = $pills }

  $catCtl = $Window.FindName('MantCategorias')
  if (-not $catCtl) { return }
  $catCtl.Children.Clear()

  foreach ($cat in (Get-MantCategorias -Tipo $Tipo)) {
    $filasCat = @($Filas | Where-Object { $_.categoria -eq $cat })
    if (-not $filasCat.Count) { continue }

    [void]$catCtl.Children.Add((New-MantCatHeader -Categoria $cat -Count $filasCat.Count))

    foreach ($f in $filasCat) {
      [void]$catCtl.Children.Add((New-MantFilaControl -Window $Window -Fila $f))
    }
  }

  Update-MantResumenUI -Window $Window
}

# Helper UI: pinta un SolidColorBrush desde un hex (centraliza el ColorConverter).
function New-MantBrush { param([string]$Hex) New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Hex)) }

# Construye el header visual de una categoria: barra de acento verde a la izquierda, titulo en
# mayusculas y un badge con el conteo. Mas escaneable que una linea de texto suelta.
function New-MantCatHeader {
  param([string]$Categoria, [int]$Count)
  $hdr = New-Object System.Windows.Controls.Grid
  $hdr.Margin = '0,12,0,6'
  $cA = New-Object System.Windows.Controls.ColumnDefinition; $cA.Width = 'Auto'; $hdr.ColumnDefinitions.Add($cA)
  $cB = New-Object System.Windows.Controls.ColumnDefinition; $cB.Width = New-Object System.Windows.GridLength(1,'Star'); $hdr.ColumnDefinitions.Add($cB)
  $cC = New-Object System.Windows.Controls.ColumnDefinition; $cC.Width = 'Auto'; $hdr.ColumnDefinitions.Add($cC)

  # Barra de acento.
  $bar = New-Object System.Windows.Controls.Border
  $bar.Width = 3; $bar.Height = 13; $bar.CornerRadius = 2; $bar.Background = (New-MantBrush '#5EAE87')
  $bar.VerticalAlignment = 'Center'; $bar.Margin = '2,0,9,0'
  [System.Windows.Controls.Grid]::SetColumn($bar, 0)
  [void]$hdr.Children.Add($bar)

  $hcat = New-Object System.Windows.Controls.TextBlock
  $hcat.Text = $Categoria.ToUpper(); $hcat.Foreground = (New-MantBrush '#7DA792'); $hcat.FontFamily = 'Space Grotesk, Segoe UI'
  $hcat.FontSize = 11; $hcat.FontWeight = 'Bold'; $hcat.VerticalAlignment = 'Center'
  [System.Windows.Controls.Grid]::SetColumn($hcat, 1)
  [void]$hdr.Children.Add($hcat)

  # Badge de conteo.
  $cnt = New-Object System.Windows.Controls.Border
  $cnt.Background = (New-MantBrush '#182E23'); $cnt.BorderBrush = (New-MantBrush '#2D473A'); $cnt.BorderThickness = 1
  $cnt.CornerRadius = 9; $cnt.Padding = '8,1'; $cnt.VerticalAlignment = 'Center'
  $cntT = New-Object System.Windows.Controls.TextBlock
  $cntT.Text = "$Count"; $cntT.Foreground = (New-MantBrush '#8BAC9C'); $cntT.FontFamily = 'DM Mono, Consolas'; $cntT.FontSize = 9.5
  $cnt.Child = $cntT
  [System.Windows.Controls.Grid]::SetColumn($cnt, 2)
  [void]$hdr.Children.Add($cnt)
  $hdr
}

# Construye la CARD de un check con todos sus controles interactivos. $Fila es la fila VIVA
# (se muta in-place). Layout: una linea principal horizontal donde el DETALLE ocupa la columna
# elastica central (llena el hueco que antes quedaba muerto), con el nombre del check jerarquizado
# a la izquierda, badge de estado, tag de naturaleza, accion contextual y selector a la derecha.
# Debajo, en linea propia ancho completo, la observacion del tecnico. Devuelve el Border.
function New-MantFilaControl {
  param($Window, $Fila)
  $f = $Fila
  $eff = Resolve-MantEstadoEfectivo $f

  $outer = New-Object System.Windows.Controls.Border
  $outer.Background = (New-MantBrush '#16211C'); $outer.BorderThickness = '1,1,1,1'
  $outer.CornerRadius = 8; $outer.Padding = '0'; $outer.Margin = '0,0,0,6'
  # Acento de borde izquierdo en el color del estado (semaforo). El resto del borde, sutil.
  $outer.BorderBrush = (New-MantBrush '#293831')

  # Grid: barra de acento (col 0) + contenido (col 1).
  $shell = New-Object System.Windows.Controls.Grid
  $sa = New-Object System.Windows.Controls.ColumnDefinition; $sa.Width = 'Auto'; $shell.ColumnDefinitions.Add($sa)
  $sb = New-Object System.Windows.Controls.ColumnDefinition; $sb.Width = New-Object System.Windows.GridLength(1,'Star'); $shell.ColumnDefinitions.Add($sb)
  $outer.Child = $shell

  $accentBar = New-Object System.Windows.Controls.Border
  $accentBar.Width = 4; $accentBar.CornerRadius = '8,0,0,8'
  $accentBar.Background = (New-MantBrush (Get-SemHex $eff))
  [System.Windows.Controls.Grid]::SetColumn($accentBar, 0)
  [void]$shell.Children.Add($accentBar)

  $stack = New-Object System.Windows.Controls.StackPanel
  $stack.Margin = '13,9,12,10'
  [System.Windows.Controls.Grid]::SetColumn($stack, 1)
  [void]$shell.Children.Add($stack)

  # ---- Linea principal horizontal: badge | label | DETALLE (col elastica) | tag | accion | selector.
  # El detalle ocupa la columna '*' del medio: usa el ancho y elimina el hueco muerto. ----
  $grid = New-Object System.Windows.Controls.Grid
  # Cols: 0 badge, 1 label(min), 2 detalle(*), 3 tag, 4 accion, 5 selector.
  foreach ($w in @('Auto','Auto','*','Auto','Auto','Auto')) {
    $cd = New-Object System.Windows.Controls.ColumnDefinition
    $cd.Width = if ($w -eq '*') { New-Object System.Windows.GridLength(1, 'Star') } else { 'Auto' }
    $grid.ColumnDefinitions.Add($cd)
  }

  # Badge de estado (pill con tinte del color + label). Lectura del semaforo de un vistazo.
  $badge = New-Object System.Windows.Controls.Border
  $badge.CornerRadius = 11; $badge.Padding = '9,3'; $badge.VerticalAlignment = 'Center'; $badge.Margin = '0,0,11,0'
  $badge.MinWidth = 92
  $badge.Background = (New-MantBrush (Get-SemBadgeBg $eff))
  $badge.BorderBrush = (New-MantBrush (Get-SemHex $eff)); $badge.BorderThickness = 1
  $badgeRow = New-Object System.Windows.Controls.StackPanel; $badgeRow.Orientation = 'Horizontal'
  $bdot = New-Object System.Windows.Shapes.Ellipse
  $bdot.Width = 8; $bdot.Height = 8; $bdot.VerticalAlignment = 'Center'; $bdot.Margin = '0,0,6,0'
  $bdot.Fill = (New-MantBrush (Get-SemHex $eff))
  [void]$badgeRow.Children.Add($bdot)
  $bTxt = New-Object System.Windows.Controls.TextBlock
  $bTxt.Text = Get-SemBadgeLabel $eff; $bTxt.Foreground = (New-MantBrush (Get-SemHex $eff))
  $bTxt.FontFamily = 'Space Grotesk, Segoe UI'; $bTxt.FontSize = 11; $bTxt.FontWeight = 'SemiBold'; $bTxt.VerticalAlignment = 'Center'
  [void]$badgeRow.Children.Add($bTxt)
  $badge.Child = $badgeRow
  [System.Windows.Controls.Grid]::SetColumn($badge, 0)
  [void]$grid.Children.Add($badge)

  # Label (nombre del check, jerarquizado: mayor tamaño y peso). Ancho minimo para alinear los detalles.
  $lbl = New-Object System.Windows.Controls.TextBlock
  $lbl.Text = $f.label; $lbl.Foreground = (New-MantBrush '#ffffff'); $lbl.FontFamily = 'Space Grotesk, Segoe UI'
  $lbl.FontSize = 14.5; $lbl.FontWeight = 'SemiBold'; $lbl.VerticalAlignment = 'Center'
  $lbl.MinWidth = 178; $lbl.Margin = '0,0,14,0'; $lbl.TextTrimming = 'CharacterEllipsis'
  [System.Windows.Controls.Grid]::SetColumn($lbl, 1)
  [void]$grid.Children.Add($lbl)

  # Detalle (dato crudo del AUTO en mono, o hint a marcar para el MANUAL sin estado). Ocupa la columna
  # elastica del medio: este es el contenido que llena el hueco que antes quedaba vacio.
  $det = New-Object System.Windows.Controls.TextBlock
  $detTxt = if ($null -eq $eff -and -not $f.detalle) { 'Marcá el estado en el selector.' } elseif ($f.detalle) { $f.detalle } else { $eff }
  $det.Text = $detTxt; $det.FontFamily = 'DM Mono, Consolas'; $det.FontSize = 12.5
  $det.Foreground = if ($null -eq $eff -and -not $f.detalle) { New-MantBrush '#879F93' } else { New-MantBrush '#B3C9BE' }
  $det.VerticalAlignment = 'Center'; $det.Margin = '0,0,12,0'; $det.TextTrimming = 'CharacterEllipsis'
  $det.ToolTip = $detTxt
  [System.Windows.Controls.Grid]::SetColumn($det, 2)
  [void]$grid.Children.Add($det)

  # Tag de naturaleza (auto / técnico).
  $tag = New-Object System.Windows.Controls.Border
  $tag.CornerRadius = 8; $tag.Padding = '7,2'; $tag.VerticalAlignment = 'Center'; $tag.Margin = '0,0,8,0'
  $tag.Background = if ($f.automated) { New-MantBrush '#1C2D25' } else { New-MantBrush '#2E2414' }
  $tagT = New-Object System.Windows.Controls.TextBlock
  $tagT.Text = if ($f.automated) { 'auto' } else { 'técnico' }
  $tagT.Foreground = if ($f.automated) { New-MantBrush '#77BC9A' } else { New-MantBrush '#D1AA66' }
  $tagT.FontFamily = 'Space Grotesk, Segoe UI'; $tagT.FontSize = 9.5; $tagT.FontWeight = 'SemiBold'
  $tag.Child = $tagT
  [System.Windows.Controls.Grid]::SetColumn($tag, 3)
  [void]$grid.Children.Add($tag)

  # Selector de estado (ComboBox con los 5 EST_SEM). AUTO permite override; MANUAL es la unica via.
  # Colores via el estilo default de ComboBox del theme (fondo oscuro + texto claro, popup incluido).
  $sel = New-Object System.Windows.Controls.ComboBox
  $sel.Width = 118; $sel.Margin = '8,0,0,0'; $sel.VerticalAlignment = 'Center'; $sel.FontSize = 11.5
  $placeholder = if ($f.automated) { '(auto)' } else { 'Marcar estado' }
  [void]$sel.Items.Add($placeholder)
  foreach ($e in $script:MANT_EST_SEM) { [void]$sel.Items.Add($e) }
  # Seleccion inicial: el manual si esta, si no el placeholder.
  $sel.SelectedIndex = 0
  if ($f.estadoManual) { $idx = $sel.Items.IndexOf([string]$f.estadoManual); if ($idx -ge 0) { $sel.SelectedIndex = $idx } }
  $sel.Tag = $f.name
  # Refs capturadas en el closure para repintar el badge + el acento al cambiar el estado.
  $badgeRef = $badge; $bdotRef = $bdot; $bTxtRef = $bTxt; $accentRef = $accentBar
  $sel.Add_SelectionChanged([System.Windows.Controls.SelectionChangedEventHandler]{
    param($s, $e)
    $name = $s.Tag
    $val = [string]$s.SelectedItem
    $filas = Get-MantPanelFilas -Window $Window
    if ($val -eq '(auto)' -or $val -eq 'Marcar estado') {
      Set-MantEstadoManual -Filas $filas -Name $name -Estado $null | Out-Null
    } else {
      Set-MantEstadoManual -Filas $filas -Name $name -Estado $val | Out-Null
    }
    # Repintar badge + acento de esta card con el estado efectivo nuevo.
    $fila = $filas | Where-Object { $_.name -eq $name }
    $ef = Resolve-MantEstadoEfectivo $fila
    $hex = Get-SemHex $ef
    $accentRef.Background = New-MantBrush $hex
    $badgeRef.Background  = New-MantBrush (Get-SemBadgeBg $ef)
    $badgeRef.BorderBrush = New-MantBrush $hex
    $bdotRef.Fill         = New-MantBrush $hex
    $bTxtRef.Foreground   = New-MantBrush $hex
    $bTxtRef.Text         = Get-SemBadgeLabel $ef
    Update-MantResumenUI -Window $Window
  }.GetNewClosure())
  # El selector de estado va a la DERECHA (columna 5); la accion contextual a su IZQUIERDA (columna 4).
  [System.Windows.Controls.Grid]::SetColumn($sel, 5)
  [void]$grid.Children.Add($sel)

  # Accion contextual (proceso de Windows o popover de lista). Solo si el check la tiene.
  # Va a la IZQUIERDA del selector de estado (columna 4).
  $accion = Get-MantAccion $f.name
  if ($accion) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $accion.etiqueta; $btn.Foreground = '#ABD0BE'; $btn.Background = '#1C2D25'
    $btn.BorderBrush = '#375144'; $btn.FontSize = 10.5; $btn.Padding = '9,4'; $btn.Margin = '0,0,4,0'
    $btn.Cursor = 'Hand'; $btn.VerticalAlignment = 'Center'
    if ($accion.tipo -eq 'popover') {
      $pop = New-MantPopover -Anchor $btn -Titulo $accion.titulo -Raw $f.raw
      $btn.Add_Click({ param($s, $e) $pop.IsOpen = -not $pop.IsOpen }.GetNewClosure())
      # Borde verde cuando hay datos en raw.
      if ($f.raw) { $btn.BorderBrush = '#5EAE87' }
    } elseif ($accion.tipo -eq 'popover_backup') {
      # FIX 2: "Ver logs" del backup MUESTRA el estado real (Cobian/Acronis) desde detalle+raw,
      # no abre el Explorador. El popover ofrece "Abrir carpeta" como accion secundaria.
      $pop = New-MantBackupPopover -Anchor $btn -Titulo $accion.titulo -Detalle ([string]$f.detalle) -Raw $f.raw
      $btn.Add_Click({ param($s, $e) $pop.IsOpen = -not $pop.IsOpen }.GetNewClosure())
      # Borde verde cuando hay datos de backup (detalle o raw).
      if ($f.raw -or $f.detalle) { $btn.BorderBrush = '#5EAE87' }
    } else {
      $acc = $accion; $fila0 = $f
      $btn.Add_Click({
        param($s, $e)
        try {
          $cmd = $acc.comando
          if ($acc.argFromRaw -and $fila0.raw) {
            $path = Resolve-MantAccionPath -Name $fila0.name -Raw $fila0.raw
            if ($path) { Start-Process $cmd $path } else { Start-Process $cmd }
          } elseif ($acc.args) {
            Start-Process $cmd $acc.args
          } else {
            Start-Process $cmd
          }
        } catch { [System.Windows.MessageBox]::Show("No se pudo abrir: $($_.Exception.Message)", 'Fleet Toolkit') }
      }.GetNewClosure())
    }
    [System.Windows.Controls.Grid]::SetColumn($btn, 4)
    [void]$grid.Children.Add($btn)
  }

  [void]$stack.Children.Add($grid)

  # ---- Observacion (spec 6.8): input ancho completo, resaltado verde cuando tiene contenido. ----
  $obs = New-Object System.Windows.Controls.TextBox
  $obs.Margin = '0,9,0,0'; $obs.FontSize = 11.5; $obs.FontFamily = 'Space Grotesk, Segoe UI'
  $obs.Background = (New-MantBrush '#0F1914'); $obs.Foreground = (New-MantBrush '#ECF0EE'); $obs.BorderThickness = 1
  $obs.Padding = '8,5'
  $obs.Text = [string]$f.observacion
  $obs.BorderBrush = if ($f.observacion) { New-MantBrush '#5EAE87' } else { New-MantBrush '#24372E' }
  $obs.Tag = $f.name
  $obs.Add_TextChanged({
    param($s, $e)
    $filas = Get-MantPanelFilas -Window $Window
    Set-MantObservacion -Filas $filas -Name $s.Tag -Texto $s.Text | Out-Null
    $s.BorderBrush = if ($s.Text) { New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#5EAE87')) }
                     else { New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#24372E')) }
  }.GetNewClosure())
  [void]$stack.Children.Add($obs)

  $outer
}

# PURO. Resuelve la carpeta/target del Start-Process desde el raw del check (spec 6.9/6.10).
# Backup: carpeta de logs de la fuente detectada. Disco: deja que explorer abra (sin path util) => null.
function Resolve-MantAccionPath {
  param([string]$Name, $Raw)
  if ($null -eq $Raw) { return $null }
  # Backup: el raw puede traer la carpeta de logs (string) o un objeto con .logsDir.
  if ($Name -like '*backup*') {
    if ($Raw -is [string] -and (Test-Path -LiteralPath $Raw -ErrorAction SilentlyContinue)) { return $Raw }
    if ($Raw.logsDir) { return [string]$Raw.logsDir }
    if ($Raw.installDir) { return [string]$Raw.installDir }
  }
  $null
}

# PURO. Arma las lineas legibles del estado de backup para el popover "Ver logs", consumiendo el
# detalle del check (texto del relevamiento) + el rawData (fuente/logsDir/tasks que produce
# lib/cobian.ps1 Get-BackupCheckItem). NO toca el collector: muestra lo que llega tal cual.
# Devuelve @{ lineas = @(strings); logsDir = string|$null }. Si no hay nada relevado, lineas vacio.
function ConvertTo-MantBackupInfo {
  param([string]$Detalle, $Raw)
  $lineas = New-Object System.Collections.ArrayList
  $logsDir = $null

  # Fuente detectada (Cobian / Acronis / servicio).
  $fuente = $null
  if ($Raw) {
    if ($Raw.fuente)  { $fuente = [string]$Raw.fuente }
    if ($Raw.logsDir) { $logsDir = [string]$Raw.logsDir }
  }
  if ($fuente) { [void]$lineas.Add("Fuente: $fuente") }

  # Detalle principal: el del raw si existe (mas completo), si no el del check.
  $det = $null
  if ($Raw -and $Raw.detalle) { $det = [string]$Raw.detalle }
  elseif ($Detalle)           { $det = [string]$Detalle }
  if ($det) {
    # El detalle de Cobian junta tareas con "; " (una por cadencia). Una linea por tarea, mas legible.
    foreach ($p in ($det -split '\s*;\s*')) {
      $t = ([string]$p).Trim()
      if ($t) { [void]$lineas.Add($t) }
    }
  }

  # Tareas crudas del history.db, si el raw las trae (taskId / last / next / sched).
  if ($Raw -and $Raw.tasks) {
    foreach ($tk in @($Raw.tasks)) {
      if ($null -eq $tk) { continue }
      $tid  = if ($tk.taskId) { [string]$tk.taskId } else { 'tarea' }
      $ult  = if ($tk.last) { try { ([datetime]$tk.last).ToString('dd/MM HH:mm') } catch { [string]$tk.last } } else { 'nunca' }
      $prox = if ($tk.next) { try { ([datetime]$tk.next).ToString('dd/MM HH:mm') } catch { [string]$tk.next } } else { $null }
      $l = "Tarea $tid · últ $ult"
      if ($prox) { $l += " · próx $prox" }
      [void]$lineas.Add($l)
    }
  }

  if ($logsDir) { [void]$lineas.Add("Carpeta de logs: $logsDir") }

  @{ lineas = @($lineas); logsDir = $logsDir }
}

# Construye el popover de backup (FIX 2): muestra el estado/logs reales del backup (Cobian/Acronis)
# desde detalle+raw, en vez de solo abrir el Explorador. Si el raw trae carpeta de logs, ofrece un
# boton secundario "Abrir carpeta". Si no hay datos, deja un mensaje claro.
function New-MantBackupPopover {
  param($Anchor, [string]$Titulo, [string]$Detalle, $Raw)
  $info = ConvertTo-MantBackupInfo -Detalle $Detalle -Raw $Raw

  $pop = New-Object System.Windows.Controls.Primitives.Popup
  $pop.PlacementTarget = $Anchor
  $pop.Placement = 'Bottom'
  $pop.StaysOpen = $false
  $pop.AllowsTransparency = $true
  $pop.MaxWidth = 460

  $card = New-Object System.Windows.Controls.Border
  $card.Background = '#101814'; $card.BorderBrush = '#30433A'; $card.BorderThickness = 1
  $card.CornerRadius = 8; $card.Padding = '10,8'
  $card.Effect = (New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 14; ShadowDepth = 2; Opacity = 0.5; Color = ([System.Windows.Media.ColorConverter]::ConvertFromString('#000000')) })
  $pop.Child = $card

  $col = New-Object System.Windows.Controls.StackPanel
  $card.Child = $col

  $h = New-Object System.Windows.Controls.TextBlock
  $h.Text = $Titulo; $h.Foreground = '#7DA792'; $h.FontFamily = 'Space Grotesk, Segoe UI'
  $h.FontWeight = 'Bold'; $h.FontSize = 11; $h.Margin = '0,0,0,6'
  [void]$col.Children.Add($h)

  $sv = New-Object System.Windows.Controls.ScrollViewer
  $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 320
  $list = New-Object System.Windows.Controls.StackPanel
  $sv.Content = $list
  [void]$col.Children.Add($sv)

  if (-not @($info.lineas).Count) {
    $empty = New-Object System.Windows.Controls.TextBlock
    $empty.Text = 'Sin datos de backup en el último relevamiento.'; $empty.Foreground = '#A4BBB0'; $empty.FontSize = 11
    $empty.TextWrapping = 'Wrap'
    [void]$list.Children.Add($empty)
  } else {
    foreach ($ln in @($info.lineas)) {
      $r = New-Object System.Windows.Controls.TextBlock
      $r.Text = [string]$ln; $r.Foreground = '#ECF0EE'; $r.FontFamily = 'DM Mono, Consolas'; $r.FontSize = 11
      $r.Margin = '0,1,0,1'; $r.TextWrapping = 'Wrap'
      [void]$list.Children.Add($r)
    }
  }

  # Boton secundario "Abrir carpeta" solo si el raw trae una carpeta de logs valida.
  if ($info.logsDir) {
    $open = New-Object System.Windows.Controls.Button
    $open.Content = 'Abrir carpeta'; $open.Foreground = '#ABD0BE'; $open.Background = '#1C2D25'
    $open.BorderBrush = '#375144'; $open.FontSize = 10; $open.Padding = '8,3'; $open.Margin = '0,8,0,0'
    $open.Cursor = 'Hand'; $open.HorizontalAlignment = 'Left'
    $dir0 = [string]$info.logsDir
    $open.Add_Click({
      param($s, $e)
      try { Start-Process 'explorer.exe' $dir0 } catch { [System.Windows.MessageBox]::Show("No se pudo abrir: $($_.Exception.Message)", 'Fleet Toolkit') }
    }.GetNewClosure())
    [void]$col.Children.Add($open)
  }
  $pop
}

# Construye un WPF Popup anclado al boton con la lista del raw (spec 6.9, posicionamiento 3.6).
# Placement relativo al anchor con StaysOpen=false (cierra al click afuera, no saca de la tab).
# El flip/shift completo (CustomPopupPlacementCallback) queda como mejora; esta iteracion usa
# Placement=Bottom + MaxHeight scrolleable, que cubre el caso comun sin cortar la lista.
function New-MantPopover {
  param($Anchor, [string]$Titulo, $Raw)
  $pop = New-Object System.Windows.Controls.Primitives.Popup
  $pop.PlacementTarget = $Anchor
  $pop.Placement = 'Bottom'
  $pop.StaysOpen = $false
  $pop.AllowsTransparency = $true
  $pop.MaxWidth = 420

  $card = New-Object System.Windows.Controls.Border
  $card.Background = '#101814'; $card.BorderBrush = '#30433A'; $card.BorderThickness = 1
  $card.CornerRadius = 8; $card.Padding = '10,8'
  $card.Effect = (New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 14; ShadowDepth = 2; Opacity = 0.5; Color = ([System.Windows.Media.ColorConverter]::ConvertFromString('#000000')) })
  $pop.Child = $card

  $col = New-Object System.Windows.Controls.StackPanel
  $card.Child = $col

  $h = New-Object System.Windows.Controls.TextBlock
  $items = @(ConvertTo-MantPopoverItems -Raw $Raw)
  $h.Text = "$Titulo · $($items.Count)"; $h.Foreground = '#7DA792'; $h.FontFamily = 'Space Grotesk, Segoe UI'
  $h.FontWeight = 'Bold'; $h.FontSize = 11; $h.Margin = '0,0,0,6'
  [void]$col.Children.Add($h)

  $sv = New-Object System.Windows.Controls.ScrollViewer
  $sv.VerticalScrollBarVisibility = 'Auto'; $sv.MaxHeight = 320
  $list = New-Object System.Windows.Controls.StackPanel
  $sv.Content = $list
  [void]$col.Children.Add($sv)

  if (-not $items.Count) {
    $empty = New-Object System.Windows.Controls.TextBlock
    $empty.Text = 'Sin datos relevados.'; $empty.Foreground = '#A4BBB0'; $empty.FontSize = 11
    [void]$list.Children.Add($empty)
  } else {
    foreach ($it in $items) {
      $r = New-Object System.Windows.Controls.TextBlock
      $r.Text = $it; $r.Foreground = '#ECF0EE'; $r.FontFamily = 'DM Mono, Consolas'; $r.FontSize = 11
      $r.Margin = '0,1,0,1'; $r.TextWrapping = 'Wrap'
      [void]$list.Children.Add($r)
    }
  }
  $pop
}

# PURO. Aplana el raw de un check de listado a strings legibles para el popover. Tolera string,
# array de strings, array de hashtables {nombre/ubicacion/impacto} o un objeto con .items.
function ConvertTo-MantPopoverItems {
  param($Raw)
  if ($null -eq $Raw) { return @() }
  $src = if ($Raw -is [string]) { @($Raw) }
         elseif ($Raw.items) { @($Raw.items) }
         elseif ($Raw -is [System.Collections.IEnumerable]) { @($Raw) }
         else { @($Raw) }
  $out = foreach ($e in $src) {
    if ($null -eq $e) { continue }
    if ($e -is [string]) { $e; continue }
    $nombre = if ($e.nombre) { $e.nombre } elseif ($e.name) { $e.name } else { $null }
    $ubic   = if ($e.ubicacion) { $e.ubicacion } elseif ($e.location) { $e.location } else { $null }
    $imp    = if ($e.impacto) { $e.impacto } elseif ($e.impact) { $e.impact } else { $null }
    $parts = @($nombre, $ubic) | Where-Object { $_ }
    $line = ($parts -join '  ·  ')
    if ($imp) { $line += "  [$imp]" }
    if (-not $line) { $line = [string]$e }
    $line
  }
  @($out)
}
