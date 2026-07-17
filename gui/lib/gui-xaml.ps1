# gui/lib/gui-xaml.ps1 - ensambla el XAML completo de la ventana y lo parsea.
function New-AppWindowXaml {
  param([string]$Hostname, [string]$Version)
  $theme  = New-AppTheme
  $header = New-AppHeaderXaml -Hostname $Hostname -Version $Version
  $panelInventario = New-PanelInventarioXaml
  $panelGenerar = New-PanelGenerarXaml
  $panelMant = New-PanelMantenimientoXaml
  @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Fleet Maintenance Toolkit - Relevamiento y Mantenimiento"
        Width="900" Height="640" WindowStartupLocation="CenterScreen"
        Background="{DynamicResource AppWindow}" FontFamily="Space Grotesk, Segoe UI">
$theme
  <DockPanel>
$header
    <Border DockPanel.Dock="Top" Background="{StaticResource AppChipBar}" BorderBrush="{StaticResource AppBordeSutil}" BorderThickness="0,0,0,1" Padding="16,9">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <RadioButton x:Name="ChipPrincipal"     Style="{StaticResource AppChip}" Content="Principal" IsChecked="True" GroupName="tabs"/>
        <RadioButton x:Name="ChipInventario"    Style="{StaticResource AppChip}" Content="Inventario" GroupName="tabs"/>
        <RadioButton x:Name="ChipMantenimiento" Style="{StaticResource AppChip}" Content="Mantenimiento" GroupName="tabs"/>
        <RadioButton x:Name="ChipUtilidades"    Style="{StaticResource AppChip}" Content="Utilidades" GroupName="tabs"/>
        <RadioButton x:Name="ChipGenerar"       Style="{StaticResource AppChip}" Content="Generar" GroupName="tabs"/>
      </StackPanel>
    </Border>
    <Grid Margin="18">
      <ScrollViewer x:Name="PanelPrincipal" VerticalScrollBarVisibility="Auto">
        <StackPanel>

          <!-- Paso 1: identificacion minima que carga el tecnico. Hostname es auto (solo lectura);
               el resto son los unicos campos editables del paso-a-paso. -->
          <TextBlock Style="{StaticResource AppSecHeader}" Text="1 · IDENTIFICACIÓN"/>
          <UniformGrid Columns="3">
            <StackPanel Margin="0,0,9,9">
              <TextBlock Style="{StaticResource AppLabel}" Text="HOSTNAME (AUTO)"/>
              <TextBox x:Name="TxtHostname" Style="{StaticResource AppInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,9,9">
              <TextBlock Style="{StaticResource AppLabel}" Text="EMPRESA / CLIENTE"/>
              <TextBox x:Name="TxtCliente" Style="{StaticResource AppInputBox}"/>
            </StackPanel>
            <StackPanel Margin="0,0,0,9">
              <TextBlock Style="{StaticResource AppLabel}" Text="TAG OCS (OBLIGATORIO)"/>
              <TextBox x:Name="TxtTag" Style="{StaticResource AppInputBox}"/>
            </StackPanel>
            <StackPanel Margin="0,0,9,0">
              <TextBlock Style="{StaticResource AppLabel}" Text="TÉCNICO"/>
              <TextBox x:Name="TxtTecnico" Style="{StaticResource AppInputBox}"/>
            </StackPanel>
            <!-- Usuario/Sector solo aplica a terminales; en servidores se oculta desde el wiring. -->
            <StackPanel x:Name="PanelUsuario" Margin="0,0,9,0">
              <TextBlock Style="{StaticResource AppLabel}" Text="USUARIO REAL / SECTOR (TERMINAL)"/>
              <TextBox x:Name="TxtUsuario" Style="{StaticResource AppInputBox}"/>
            </StackPanel>
          </UniformGrid>

          <!-- Paso 2: tipo auto-detectado (con "cambiar") + carpeta de salida. -->
          <TextBlock Style="{StaticResource AppSecHeader}" Text="2 · CONFIGURACIÓN"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="{StaticResource AppChipBg}" BorderBrush="{StaticResource AppBorde}"
                    BorderThickness="1" CornerRadius="7" Padding="12,8" Margin="0,0,18,0" VerticalAlignment="Top">
              <StackPanel Orientation="Horizontal">
                <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,9,0" VerticalAlignment="Center"
                      Stroke="{StaticResource AppAccent}" StrokeThickness="2" Fill="Transparent"
                      Data="M3,4 H21 V16 H3 Z M8,20 H16 M12,16 V20"/>
                <StackPanel>
                  <TextBlock x:Name="LblTipo" Foreground="White" FontWeight="700" FontSize="14" Text="Terminal"/>
                  <TextBlock x:Name="LblTipoDetalle" Foreground="{StaticResource AppAccentClaro}" FontFamily="DM Mono, Consolas" FontSize="10" Text="detectado"/>
                </StackPanel>
                <TextBlock x:Name="LnkCambiarTipo" Foreground="#ABD0BE" FontSize="10" Text="cambiar" Margin="14,0,0,0"
                           VerticalAlignment="Center" Cursor="Hand" TextDecorations="Underline"/>
              </StackPanel>
            </Border>
            <StackPanel Grid.Column="1" VerticalAlignment="Top">
              <TextBlock Style="{StaticResource AppLabel}" Text="CARPETA DE SALIDA"/>
              <StackPanel Orientation="Horizontal">
                <TextBox x:Name="TxtSalida" Style="{StaticResource AppInputMono}" Width="320" Text="C:\zback"/>
                <Button x:Name="BtnExaminar" Content="Examinar…" Margin="6,0,0,0" Padding="10,4"/>
              </StackPanel>
            </StackPanel>
          </Grid>

          <!-- Identificadores auto-detectados (lectura). Se conserva tal cual. -->
          <TextBlock Style="{StaticResource AppSecHeader}" Text="IDENTIFICADORES DEL EQUIPO (AUTO)"/>
          <UniformGrid Columns="2">
            <StackPanel Margin="0,0,8,8">
              <TextBlock Style="{StaticResource AppLabel}" Text="UUID DE SO (MachineGuid)"/>
              <TextBox x:Name="TxtIdOsUuid" Style="{StaticResource AppInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,0,8">
              <TextBlock Style="{StaticResource AppLabel}" Text="UUID DE HARDWARE"/>
              <TextBox x:Name="TxtIdHwUuid" Style="{StaticResource AppInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,8,8">
              <TextBlock Style="{StaticResource AppLabel}" Text="SERIAL DE DISCO"/>
              <TextBox x:Name="TxtIdDiskSerial" Style="{StaticResource AppInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,0,8">
              <TextBlock Style="{StaticResource AppLabel}" Text="SERIAL DE BIOS / MOTHER"/>
              <TextBox x:Name="TxtIdBiosSerial" Style="{StaticResource AppInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,8,0">
              <TextBlock Style="{StaticResource AppLabel}" Text="MAC (WIFI / ETHERNET)"/>
              <TextBox x:Name="TxtIdMac" Style="{StaticResource AppInputMono}" IsReadOnly="True"/>
            </StackPanel>
          </UniformGrid>

          <!-- Notas libres del equipo durante la visita -> meta.nota en el JSON. -->
          <TextBlock Style="{StaticResource AppSecHeader}" Text="OBSERVACIONES DEL EQUIPO"/>
          <TextBox x:Name="TxtObservaciones" Style="{StaticResource AppInputBox}"
                   AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                   MinHeight="58" VerticalContentAlignment="Top"/>

          <!-- Paso 3: Relevar es la accion principal. OCS / Informe / Salidas son secundarias. -->
          <TextBlock Style="{StaticResource AppSecHeader}" Text="3 · ACCIONES"/>
          <Button x:Name="BtnRelevar" Style="{StaticResource AppBtnPrimary}" Padding="10,13" FontSize="15">
            <StackPanel Orientation="Horizontal">
              <Path Width="20" Height="20" Stretch="Uniform" Margin="0,0,9,0" VerticalAlignment="Center"
                    Stroke="{StaticResource AppAccentDeep}" StrokeThickness="2.2" Fill="Transparent"
                    StrokeLineJoin="Round" Data="M3,12 H7 L9,17 L13,5 L15,12 H21"/>
              <TextBlock x:Name="LblRelevar" Text="Relevar terminal" VerticalAlignment="Center"/>
            </StackPanel>
          </Button>

          <Border Margin="0,12,0,0" BorderBrush="{StaticResource AppBordeSutil}" BorderThickness="0,1,0,0" Padding="0,11,0,0">
            <UniformGrid Columns="3">
              <Button x:Name="BtnInstalarOcs" Margin="0,0,9,0" Padding="11" Cursor="Hand"
                      Background="#19231E" BorderBrush="{StaticResource AppBorde}" BorderThickness="1" Foreground="{StaticResource AppTexto}">
                <StackPanel Orientation="Horizontal">
                  <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,10,0" VerticalAlignment="Center"
                        Stroke="{StaticResource AppAccentClaro}" StrokeThickness="2" Fill="Transparent" StrokeLineJoin="Round"
                        Data="M12,3 V15 M12,15 L8,11 M12,15 L16,11 M4,17 V19 A2,2 0 0 0 6,21 H18 A2,2 0 0 0 20,19 V17"/>
                  <StackPanel>
                    <TextBlock Text="Instalar OCS" Foreground="White" FontWeight="600" FontSize="13"/>
                    <TextBlock Text="Registra el equipo" Foreground="{StaticResource AppTexto2}" FontSize="10"/>
                  </StackPanel>
                </StackPanel>
              </Button>
              <Button x:Name="BtnInforme" Margin="0,0,9,0" Padding="11" Cursor="Hand"
                      Background="#19231E" BorderBrush="{StaticResource AppBorde}" BorderThickness="1" Foreground="{StaticResource AppTexto}">
                <StackPanel Orientation="Horizontal">
                  <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,10,0" VerticalAlignment="Center"
                        Stroke="{StaticResource AppAccentClaro}" StrokeThickness="2" Fill="Transparent" StrokeLineJoin="Round"
                        Data="M4,3 H20 V21 H4 Z M9,8 H11 M9,12 H15 M9,16 H15"/>
                  <StackPanel>
                    <TextBlock Text="Informe local" Foreground="White" FontWeight="600" FontSize="13"/>
                    <TextBlock Text="Consolida en HTML" Foreground="{StaticResource AppTexto2}" FontSize="10"/>
                  </StackPanel>
                </StackPanel>
              </Button>
              <Button x:Name="BtnAbrirSalidas" Padding="11" Cursor="Hand"
                      Background="#19231E" BorderBrush="{StaticResource AppBorde}" BorderThickness="1" Foreground="{StaticResource AppTexto}">
                <StackPanel Orientation="Horizontal">
                  <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,10,0" VerticalAlignment="Center"
                        Stroke="{StaticResource AppAccentClaro}" StrokeThickness="2" Fill="Transparent" StrokeLineJoin="Round"
                        Data="M3,7 A2,2 0 0 1 5,5 H9 L11,7 H19 A2,2 0 0 1 21,9 V17 A2,2 0 0 1 19,19 H5 A2,2 0 0 1 3,17 Z"/>
                  <StackPanel>
                    <TextBlock Text="Abrir salidas" Foreground="White" FontWeight="600" FontSize="13"/>
                    <TextBlock Text="JSON y HTML" Foreground="{StaticResource AppTexto2}" FontSize="10"/>
                  </StackPanel>
                </StackPanel>
              </Button>
            </UniformGrid>
          </Border>
        </StackPanel>
      </ScrollViewer>

$panelInventario
$panelMant
$(New-PanelUtilidadesXaml)
$panelGenerar

      <StackPanel x:Name="PanelEjecucion" Visibility="Collapsed">
        <TextBlock Foreground="White" FontWeight="700" FontSize="15" Text="Relevando equipo"/>
        <TextBlock Foreground="#A4BBB0" FontSize="11" Text="Todo local. No modifica el equipo."/>
        <ProgressBar x:Name="ProgRelev" Height="10" Margin="0,10" IsIndeterminate="True" Foreground="#5EAE87" Background="#0F1914"/>
        <TextBlock x:Name="TxtEstadoRelev" Foreground="#77BC9A" FontFamily="DM Mono, Consolas" FontSize="12" Text="en cola"/>
        <ItemsControl x:Name="ListaModulos" Margin="0,8,0,0"/>
      </StackPanel>
    </Grid>
  </DockPanel>
</Window>
"@
}

# Parsea el XAML y devuelve el objeto Window. Solo Windows con WPF cargado.
function Get-AppWindow {
  param([string]$Xaml)
  $reader = New-Object System.Xml.XmlNodeReader ([xml]$Xaml)
  [Windows.Markup.XamlReader]::Load($reader)
}
