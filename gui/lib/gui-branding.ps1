# gui/lib/gui-branding.ps1 - header branded WPF: logo SVG (Path) + wordmark + host.
# Paths canonicos de la guia interna de marca (no versionada en este repo). NO redibujar.
$script:STI_MONITOR = 'M14 20 H86 A6 6 0 0 1 92 26 V64 A6 6 0 0 1 86 70 H14 A6 6 0 0 1 8 64 V26 A6 6 0 0 1 14 20Z M42 82 H58 M50 70 V82'
$script:STI_CHECK   = 'M28 46 L44 62 L74 30'

function New-StiHeaderXaml {
  param([string]$Hostname, [string]$Version)
  $hn = [System.Security.SecurityElement]::Escape($Hostname)
  @"
<Border DockPanel.Dock="Top" Background="{StaticResource StiVerdeDeep}" BorderBrush="{StaticResource StiVerde}" BorderThickness="0,0,0,2" Padding="14,8">
  <Grid>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
      <Viewbox Width="30" Height="30" Stretch="Uniform">
        <Canvas Width="100" Height="100">
          <Path Data="$STI_MONITOR" Stroke="#43C961" StrokeThickness="5" StrokeLineJoin="Round" Fill="Transparent"/>
          <Path Data="$STI_CHECK"   Stroke="#43C961" StrokeThickness="5" StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Fill="Transparent"/>
        </Canvas>
      </Viewbox>
      <StackPanel Margin="10,0,0,0" VerticalAlignment="Center">
        <TextBlock Text="STI" Foreground="White" FontFamily="Audiowide, Segoe UI" FontSize="17" LineHeight="17"/>
        <TextBlock Text="MANTENIMIENTO" Foreground="#43C961" FontFamily="Audiowide, Segoe UI" FontSize="7" Margin="0,2,0,0"/>
      </StackPanel>
    </StackPanel>
    <StackPanel HorizontalAlignment="Right" VerticalAlignment="Center">
      <TextBlock Text="$hn" Foreground="White" FontWeight="700" FontFamily="DM Mono, Consolas" FontSize="13" HorizontalAlignment="Right"/>
      <TextBlock Text="v$Version · relevamiento + mantenimiento" Foreground="#9cc3b2" FontFamily="DM Mono, Consolas" FontSize="10" HorizontalAlignment="Right"/>
    </StackPanel>
  </Grid>
</Border>
"@
}
