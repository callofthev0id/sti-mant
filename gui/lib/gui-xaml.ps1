# gui/lib/gui-xaml.ps1 - ensambla el XAML completo de la ventana y lo parsea.
function New-StiWindowXaml {
  param([string]$Hostname, [string]$Version)
  $theme  = New-StiTheme
  $header = New-StiHeaderXaml -Hostname $Hostname -Version $Version
  $panelInventario = New-PanelInventarioXaml
  $panelGenerar = New-PanelGenerarXaml
  $panelMant = New-PanelMantenimientoXaml
  @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="STI Mantenimiento - Relevamiento y Mantenimiento"
        Width="900" Height="640" WindowStartupLocation="CenterScreen"
        Background="{DynamicResource StiWindow}" FontFamily="Space Grotesk, Segoe UI">
$theme
  <DockPanel>
$header
    <Border DockPanel.Dock="Top" Background="{StaticResource StiChipBar}" BorderBrush="{StaticResource StiBordeSutil}" BorderThickness="0,0,0,1" Padding="16,9">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <RadioButton x:Name="ChipPrincipal"     Style="{StaticResource StiChip}" Content="Principal" IsChecked="True" GroupName="tabs"/>
        <RadioButton x:Name="ChipInventario"    Style="{StaticResource StiChip}" Content="Inventario" GroupName="tabs"/>
        <RadioButton x:Name="ChipMantenimiento" Style="{StaticResource StiChip}" Content="Mantenimiento" GroupName="tabs"/>
        <RadioButton x:Name="ChipUtilidades"    Style="{StaticResource StiChip}" Content="Utilidades" GroupName="tabs"/>
        <RadioButton x:Name="ChipGenerar"       Style="{StaticResource StiChip}" Content="Generar" GroupName="tabs"/>
      </StackPanel>
    </Border>
    <Grid Margin="18">
      <ScrollViewer x:Name="PanelPrincipal" VerticalScrollBarVisibility="Auto">
        <StackPanel>

          <!-- Paso 1: identificacion minima que carga el tecnico. Hostname es auto (solo lectura);
               el resto son los unicos campos editables del paso-a-paso. -->
          <TextBlock Style="{StaticResource StiSecHeader}" Text="1 · IDENTIFICACIÓN"/>
          <UniformGrid Columns="3">
            <StackPanel Margin="0,0,9,9">
              <TextBlock Style="{StaticResource StiLabel}" Text="HOSTNAME (AUTO)"/>
              <TextBox x:Name="TxtHostname" Style="{StaticResource StiInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,9,9">
              <TextBlock Style="{StaticResource StiLabel}" Text="EMPRESA / CLIENTE"/>
              <TextBox x:Name="TxtCliente" Style="{StaticResource StiInputBox}"/>
            </StackPanel>
            <StackPanel Margin="0,0,0,9">
              <TextBlock Style="{StaticResource StiLabel}" Text="TAG OCS (OBLIGATORIO)"/>
              <TextBox x:Name="TxtTag" Style="{StaticResource StiInputBox}"/>
            </StackPanel>
            <StackPanel Margin="0,0,9,0">
              <TextBlock Style="{StaticResource StiLabel}" Text="TÉCNICO"/>
              <TextBox x:Name="TxtTecnico" Style="{StaticResource StiInputBox}"/>
            </StackPanel>
            <!-- Usuario/Sector solo aplica a terminales; en servidores se oculta desde el wiring. -->
            <StackPanel x:Name="PanelUsuario" Margin="0,0,9,0">
              <TextBlock Style="{StaticResource StiLabel}" Text="USUARIO REAL / SECTOR (TERMINAL)"/>
              <TextBox x:Name="TxtUsuario" Style="{StaticResource StiInputBox}"/>
            </StackPanel>
          </UniformGrid>

          <!-- Paso 2: tipo auto-detectado (con "cambiar") + carpeta de salida. -->
          <TextBlock Style="{StaticResource StiSecHeader}" Text="2 · CONFIGURACIÓN"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="{StaticResource StiChipBg}" BorderBrush="{StaticResource StiBorde}"
                    BorderThickness="1" CornerRadius="7" Padding="12,8" Margin="0,0,18,0" VerticalAlignment="Top">
              <StackPanel Orientation="Horizontal">
                <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,9,0" VerticalAlignment="Center"
                      Stroke="{StaticResource StiVerde}" StrokeThickness="2" Fill="Transparent"
                      Data="M3,4 H21 V16 H3 Z M8,20 H16 M12,16 V20"/>
                <StackPanel>
                  <TextBlock x:Name="LblTipo" Foreground="White" FontWeight="700" FontSize="14" Text="Terminal"/>
                  <TextBlock x:Name="LblTipoDetalle" Foreground="{StaticResource StiVerdeClaro}" FontFamily="DM Mono, Consolas" FontSize="10" Text="detectado"/>
                </StackPanel>
                <TextBlock x:Name="LnkCambiarTipo" Foreground="#9fdcc0" FontSize="10" Text="cambiar" Margin="14,0,0,0"
                           VerticalAlignment="Center" Cursor="Hand" TextDecorations="Underline"/>
              </StackPanel>
            </Border>
            <StackPanel Grid.Column="1" VerticalAlignment="Top">
              <TextBlock Style="{StaticResource StiLabel}" Text="CARPETA DE SALIDA"/>
              <StackPanel Orientation="Horizontal">
                <TextBox x:Name="TxtSalida" Style="{StaticResource StiInputMono}" Width="320" Text="C:\zback"/>
                <Button x:Name="BtnExaminar" Content="Examinar…" Margin="6,0,0,0" Padding="10,4"/>
              </StackPanel>
            </StackPanel>
          </Grid>

          <!-- Identificadores auto-detectados (lectura). Se conserva tal cual. -->
          <TextBlock Style="{StaticResource StiSecHeader}" Text="IDENTIFICADORES DEL EQUIPO (AUTO)"/>
          <UniformGrid Columns="2">
            <StackPanel Margin="0,0,8,8">
              <TextBlock Style="{StaticResource StiLabel}" Text="UUID DE SO (MachineGuid)"/>
              <TextBox x:Name="TxtIdOsUuid" Style="{StaticResource StiInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,0,8">
              <TextBlock Style="{StaticResource StiLabel}" Text="UUID DE HARDWARE"/>
              <TextBox x:Name="TxtIdHwUuid" Style="{StaticResource StiInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,8,8">
              <TextBlock Style="{StaticResource StiLabel}" Text="SERIAL DE DISCO"/>
              <TextBox x:Name="TxtIdDiskSerial" Style="{StaticResource StiInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,0,8">
              <TextBlock Style="{StaticResource StiLabel}" Text="SERIAL DE BIOS / MOTHER"/>
              <TextBox x:Name="TxtIdBiosSerial" Style="{StaticResource StiInputMono}" IsReadOnly="True"/>
            </StackPanel>
            <StackPanel Margin="0,0,8,0">
              <TextBlock Style="{StaticResource StiLabel}" Text="MAC (WIFI / ETHERNET)"/>
              <TextBox x:Name="TxtIdMac" Style="{StaticResource StiInputMono}" IsReadOnly="True"/>
            </StackPanel>
          </UniformGrid>

          <!-- Notas libres del equipo durante la visita -> meta.nota en el JSON. -->
          <TextBlock Style="{StaticResource StiSecHeader}" Text="OBSERVACIONES DEL EQUIPO"/>
          <TextBox x:Name="TxtObservaciones" Style="{StaticResource StiInputBox}"
                   AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                   MinHeight="58" VerticalContentAlignment="Top"/>

          <!-- Paso 3: Relevar es la accion principal. OCS / Informe / Salidas son secundarias. -->
          <TextBlock Style="{StaticResource StiSecHeader}" Text="3 · ACCIONES"/>
          <Button x:Name="BtnRelevar" Style="{StaticResource StiBtnPrimary}" Padding="10,13" FontSize="15">
            <StackPanel Orientation="Horizontal">
              <Path Width="20" Height="20" Stretch="Uniform" Margin="0,0,9,0" VerticalAlignment="Center"
                    Stroke="{StaticResource StiVerdeDeep}" StrokeThickness="2.2" Fill="Transparent"
                    StrokeLineJoin="Round" Data="M3,12 H7 L9,17 L13,5 L15,12 H21"/>
              <TextBlock x:Name="LblRelevar" Text="Relevar terminal" VerticalAlignment="Center"/>
            </StackPanel>
          </Button>

          <Border Margin="0,12,0,0" BorderBrush="{StaticResource StiBordeSutil}" BorderThickness="0,1,0,0" Padding="0,11,0,0">
            <UniformGrid Columns="3">
              <Button x:Name="BtnInstalarOcs" Margin="0,0,9,0" Padding="11" Cursor="Hand"
                      Background="#15271f" BorderBrush="{StaticResource StiBorde}" BorderThickness="1" Foreground="{StaticResource StiTexto}">
                <StackPanel Orientation="Horizontal">
                  <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,10,0" VerticalAlignment="Center"
                        Stroke="{StaticResource StiVerdeClaro}" StrokeThickness="2" Fill="Transparent" StrokeLineJoin="Round"
                        Data="M12,3 V15 M12,15 L8,11 M12,15 L16,11 M4,17 V19 A2,2 0 0 0 6,21 H18 A2,2 0 0 0 20,19 V17"/>
                  <StackPanel>
                    <TextBlock Text="Instalar OCS" Foreground="White" FontWeight="600" FontSize="13"/>
                    <TextBlock Text="Registra el equipo" Foreground="{StaticResource StiTexto2}" FontSize="10"/>
                  </StackPanel>
                </StackPanel>
              </Button>
              <Button x:Name="BtnInforme" Margin="0,0,9,0" Padding="11" Cursor="Hand"
                      Background="#15271f" BorderBrush="{StaticResource StiBorde}" BorderThickness="1" Foreground="{StaticResource StiTexto}">
                <StackPanel Orientation="Horizontal">
                  <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,10,0" VerticalAlignment="Center"
                        Stroke="{StaticResource StiVerdeClaro}" StrokeThickness="2" Fill="Transparent" StrokeLineJoin="Round"
                        Data="M4,3 H20 V21 H4 Z M9,8 H11 M9,12 H15 M9,16 H15"/>
                  <StackPanel>
                    <TextBlock Text="Informe local" Foreground="White" FontWeight="600" FontSize="13"/>
                    <TextBlock Text="Consolida en HTML" Foreground="{StaticResource StiTexto2}" FontSize="10"/>
                  </StackPanel>
                </StackPanel>
              </Button>
              <Button x:Name="BtnAbrirSalidas" Padding="11" Cursor="Hand"
                      Background="#15271f" BorderBrush="{StaticResource StiBorde}" BorderThickness="1" Foreground="{StaticResource StiTexto}">
                <StackPanel Orientation="Horizontal">
                  <Path Width="18" Height="18" Stretch="Uniform" Margin="0,0,10,0" VerticalAlignment="Center"
                        Stroke="{StaticResource StiVerdeClaro}" StrokeThickness="2" Fill="Transparent" StrokeLineJoin="Round"
                        Data="M3,7 A2,2 0 0 1 5,5 H9 L11,7 H19 A2,2 0 0 1 21,9 V17 A2,2 0 0 1 19,19 H5 A2,2 0 0 1 3,17 Z"/>
                  <StackPanel>
                    <TextBlock Text="Abrir salidas" Foreground="White" FontWeight="600" FontSize="13"/>
                    <TextBlock Text="JSON y HTML" Foreground="{StaticResource StiTexto2}" FontSize="10"/>
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
        <TextBlock Foreground="#9cc3b2" FontSize="11" Text="Todo local. No modifica el equipo."/>
        <ProgressBar x:Name="ProgRelev" Height="10" Margin="0,10" IsIndeterminate="True" Foreground="#43C961" Background="#0c1c15"/>
        <TextBlock x:Name="TxtEstadoRelev" Foreground="#5fd47f" FontFamily="DM Mono, Consolas" FontSize="12" Text="en cola"/>
        <ItemsControl x:Name="ListaModulos" Margin="0,8,0,0"/>
      </StackPanel>
    </Grid>
  </DockPanel>
</Window>
"@
}

# Parsea el XAML y devuelve el objeto Window. Solo Windows con WPF cargado.
function Get-StiWindow {
  param([string]$Xaml)
  $reader = New-Object System.Xml.XmlNodeReader ([xml]$Xaml)
  [Windows.Markup.XamlReader]::Load($reader)
}
