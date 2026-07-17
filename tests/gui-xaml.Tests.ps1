# Pester 5. Smoke de generacion + carga real de XAML. La carga WPF instancia la ventana
# en un runspace STA (XamlReader.Load exige STA); solo corre en Windows con WPF presente.
BeforeAll {
  . "$PSScriptRoot/../gui/lib/gui-tab-mantenimiento.ps1"
  . "$PSScriptRoot/../gui/lib/gui-theme.ps1"
  . "$PSScriptRoot/../gui/lib/gui-branding.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-inventario.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-utilidades.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-generar.ps1"
  . "$PSScriptRoot/../gui/lib/gui-xaml.ps1"
}
Describe "New-AppWindowXaml" {
  BeforeAll { $script:xaml = New-AppWindowXaml -Hostname 'CLAUDE' -Version '1.0' }
  It "es XML bien formado" {
    { [xml]$xaml } | Should -Not -Throw
  }
  It "contiene los controles nombrados que la GUI cablea" {
    foreach ($n in @('ChipPrincipal','ChipInventario','ChipMantenimiento','ChipUtilidades','ChipGenerar',
                     'PanelPrincipal','PanelInventario','PanelMantenimiento','PanelUtilidades','PanelGenerar',
                     'PanelEjecucion','TxtUsuario','TxtCliente','TxtTag','TxtSalida','TxtHostname',
                     'BtnRelevar','LblRelevar','BtnExaminar','BtnInstalarOcs','BtnInforme','BtnAbrirSalidas',
                     'TxtTecnico','PanelUsuario','TxtObservaciones',
                     'LblTipo','LblTipoDetalle','LnkCambiarTipo','ProgRelev','ListaModulos','TxtEstadoRelev',
                     'TxtIdOsUuid','TxtIdHwUuid','TxtIdDiskSerial','TxtIdBiosSerial','TxtIdMac')) {
      $xaml | Should -Match ([regex]::Escape("x:Name=`"$n`""))
    }
  }
  It "default de carpeta de salida es C:\zback" {
    $xaml | Should -Match 'C:\\zback'
  }
}

# Carga WPF real: detecta refs de StaticResource irresolubles (p. ej. el Background del
# Window root que apuntaba a un recurso de Window.Resources aun no parseado). Solo Windows+WPF.
Describe "Get-AppWindow (carga WPF real)" {
  $script:wpfOk = $false
  try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop; $script:wpfOk = $true } catch {}

  It "XamlReader.Load instancia la ventana y los controles nombrados se encuentran" -Skip:(-not $script:wpfOk) {
    $xaml = New-AppWindowXaml -Hostname 'CLAUDE' -Version '1.0'
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($x)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
      $w = [Windows.Markup.XamlReader]::Load($r)
      [bool]($w -and $w.FindName('TxtHostname') -and $w.FindName('BtnRelevar') -and
             $w.FindName('LblRelevar') -and $w.FindName('TxtObservaciones') -and $w.FindName('TxtTag') -and
             $w.FindName('PanelUsuario') -and
             $w.FindName('TxtIdOsUuid') -and $w.FindName('TxtIdHwUuid') -and
             $w.FindName('TxtIdDiskSerial') -and $w.FindName('TxtIdBiosSerial') -and $w.FindName('TxtIdMac'))
    }).AddArgument($xaml)
    $res = $ps.Invoke()
    $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }
}
