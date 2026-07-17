# gui/lib/gui-branding.ps1 - header WPF: icono (Path) + wordmark + host.
# Icono propio: circulo + check, generico. Geometria distinta del isologo original (no es un logo de marca).
$script:ICON_RING  = 'M50 12 A38 38 0 1 1 49.9 12 Z'
$script:ICON_CHECK = 'M30 52 L45 67 L72 34'

function New-AppHeaderXaml {
  param([string]$Hostname, [string]$Version)
  $hn = [System.Security.SecurityElement]::Escape($Hostname)
  @"
<Border DockPanel.Dock="Top" Background="{StaticResource AppAccentDeep}" BorderBrush="{StaticResource AppAccent}" BorderThickness="0,0,0,2" Padding="14,8">
  <Grid>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
      <Viewbox Width="28" Height="28" Stretch="Uniform">
        <Canvas Width="100" Height="100">
          <Path Data="$ICON_RING"  Stroke="#5EAE87" StrokeThickness="5" Fill="Transparent"/>
          <Path Data="$ICON_CHECK" Stroke="#5EAE87" StrokeThickness="6" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Fill="Transparent"/>
        </Canvas>
      </Viewbox>
      <StackPanel Margin="10,0,0,0" VerticalAlignment="Center">
        <TextBlock Text="FLEET" Foreground="White" FontFamily="Consolas, Segoe UI" FontSize="16" FontWeight="700" LineHeight="16"/>
        <TextBlock Text="MAINTENANCE TOOLKIT" Foreground="#5EAE87" FontFamily="Consolas, Segoe UI" FontSize="7" Margin="0,2,0,0"/>
      </StackPanel>
    </StackPanel>
    <StackPanel HorizontalAlignment="Right" VerticalAlignment="Center">
      <TextBlock Text="$hn" Foreground="White" FontWeight="700" FontFamily="DM Mono, Consolas" FontSize="13" HorizontalAlignment="Right"/>
      <TextBlock Text="v$Version · relevamiento + mantenimiento" Foreground="#A4BBB0" FontFamily="DM Mono, Consolas" FontSize="10" HorizontalAlignment="Right"/>
    </StackPanel>
  </Grid>
</Border>
"@
}
