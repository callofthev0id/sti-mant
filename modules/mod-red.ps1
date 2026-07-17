# mod-red.ps1 - conectividad, TeamViewer, recursos compartidos (semi), RDP, WiFi (laptop).
function Invoke-ModRed {
  param($Ctx)
  $items = @(); $errs = @()
  $isLaptop = ($Ctx.formFactor -eq 'laptop')

  # chk_conectividad: gateway responde + DNS resuelve.
  try {
    $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
    $pingGw = if ($gw) { Test-Connection -ComputerName $gw -Count 1 -Quiet -ErrorAction SilentlyContinue } else { $false }
    $dns = $false
    try { $dns = [bool](Resolve-DnsName 'google.com' -ErrorAction Stop) } catch {}
    $items += New-CheckItem 'chk_conectividad' 'Conectividad (gateway+DNS)' (Get-StatusBool ($pingGw -and $dns)) $true "gw:$gw ping:$pingGw dns:$dns"
  } catch { $items += New-CheckItem 'chk_conectividad' 'Conectividad (gateway+DNS)' 'N/A' $true ''; $errs += "conectividad: $($_.Exception.Message)" }

  # chk_teamviewer: servicio TeamViewer corriendo.
  try {
    $tv = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'TeamViewer' } | Select-Object -First 1
    if ($tv) { $items += New-CheckItem 'chk_teamviewer' 'TeamViewer Host' (Get-StatusBool ($tv.Status -eq 'Running')) $true "servicio:$($tv.Status)" }
    else { $items += New-CheckItem 'chk_teamviewer' 'TeamViewer Host' 'Error' $true 'no instalado' }
  } catch { $items += New-CheckItem 'chk_teamviewer' 'TeamViewer Host' 'N/A' $true ''; $errs += "teamviewer: $($_.Exception.Message)" }

  # chk_recursos_compartidos (SEMI): shares no-administrativos → detalle; técnico decide.
  try {
    $sh = @(Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '\$$' } | ForEach-Object { $_.Name })
    $items += New-CheckItem 'chk_recursos_compartidos' 'Recursos compartidos' 'N/A' $false ("$($sh.Count): " + ($sh -join ', '))
  } catch { $items += New-CheckItem 'chk_recursos_compartidos' 'Recursos compartidos' 'N/A' $false ''; $errs += "shares: $($_.Exception.Message)" }

  # chk_rdp: habilitado + NLA.
  try {
    $deny = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections
    $nla  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -ErrorAction SilentlyContinue).UserAuthentication
    $enabled = ($deny -eq 0)
    $st = if (-not $enabled) { 'N/A' } elseif ($nla -eq 1) { 'Ok' } else { 'Advertencia' }   # habilitado sin NLA → advertencia
    $items += New-CheckItem 'chk_rdp' 'Configuración RDP' $st $true "habilitado:$enabled NLA:$($nla -eq 1)"
  } catch { $items += New-CheckItem 'chk_rdp' 'Configuración RDP' 'N/A' $true ''; $errs += "rdp: $($_.Exception.Message)" }

  # chk_wifi (laptop): adaptador WiFi presente/up. N/A si no laptop.
  if ($isLaptop) {
    try {
      $wifi = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.MediaType -match '802.11' -or $_.Name -match 'Wi-?Fi|Wireless' } | Select-Object -First 1
      if ($wifi) { $items += New-CheckItem 'chk_wifi' 'Adaptador WiFi (laptop)' (Get-StatusBool ($wifi.Status -eq 'Up')) $true "$($wifi.Name):$($wifi.Status)" }
      else { $items += New-CheckItem 'chk_wifi' 'Adaptador WiFi (laptop)' 'Advertencia' $true 'sin adaptador WiFi' }
    } catch { $items += New-CheckItem 'chk_wifi' 'Adaptador WiFi (laptop)' 'N/A' $true ''; $errs += "wifi: $($_.Exception.Message)" }
  } else { $items += New-CheckItem 'chk_wifi' 'Adaptador WiFi (laptop)' 'N/A' $true 'no laptop' }

  @{ category = 'Red'; items = $items; errors = $errs }
}
