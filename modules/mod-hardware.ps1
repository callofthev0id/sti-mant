# mod-hardware.ps1 - disco SMART, espacio C:, RAM, batería (laptop), periféricos (manual), UPS (semi).
function Invoke-ModHardware {
  param($Ctx)
  $items = @(); $errs = @()
  $isLaptop = ($Ctx.formFactor -eq 'laptop')

  # chk_disco_smart: salud de discos físicos.
  try {
    $pd = @(Get-PhysicalDisk -ErrorAction Stop)
    $bad = $pd | Where-Object { $_.HealthStatus -ne 'Healthy' }
    $st = if (-not $pd) { 'N/A' } elseif (-not $bad) { 'Ok' } elseif ($bad | Where-Object { $_.HealthStatus -eq 'Unhealthy' }) { 'Crítico' } else { 'Advertencia' }
    $items += New-CheckItem 'chk_disco_smart' 'Estado disco (SMART)' $st $true (($pd | ForEach-Object { "$($_.FriendlyName):$($_.HealthStatus)" }) -join ' | ')
  } catch { $items += New-CheckItem 'chk_disco_smart' 'Estado disco (SMART)' 'N/A' $true ''; $errs += "smart: $($_.Exception.Message)" }

  # chk_espacio_disco: % usado de C:.
  try {
    $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
    $pct = [int]((($c.Size - $c.FreeSpace) / $c.Size) * 100)
    $freeGb = [math]::Round($c.FreeSpace/1GB,1)
    $items += New-CheckItem 'chk_espacio_disco' 'Espacio en disco C:' (Get-StatusByPct $pct $THR.disco.okMax $THR.disco.advMax) $true "$pct% usado (${freeGb}GB libres)" @{ pctUsado = $pct; libreGb = $freeGb; totalGb = [math]::Round($c.Size/1GB,1) }
  } catch { $items += New-CheckItem 'chk_espacio_disco' 'Espacio en disco C:' 'N/A' $true ''; $errs += "espacio: $($_.Exception.Message)" }

  # chk_ram: presencia de módulos + sin errores WHEA recientes (best-effort, proxy de eventos).
  try {
    $totGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)
    $providerExists = [bool](Get-WinEvent -ListProvider 'Microsoft-Windows-WHEA-Logger' -ErrorAction SilentlyContinue)
    if (-not $providerExists) {
      $items += New-CheckItem 'chk_ram' 'Estado RAM' 'Ok' $true "$totGb GB; WHEA: sin provider (no concluyente, proxy de eventos)"
    } else {
      $whea = @(Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=(Get-Date).AddDays(-30) } -ErrorAction SilentlyContinue).Count
      $items += New-CheckItem 'chk_ram' 'Estado RAM' (Get-StatusBool ($whea -eq 0)) $true "$totGb GB; WHEA 30d: $whea (proxy de eventos)"
    }
  } catch { $items += New-CheckItem 'chk_ram' 'Estado RAM' 'N/A' $true ''; $errs += "ram: $($_.Exception.Message)" }

  # chk_bateria (laptop): salud aprox (full vs design). N/A si no es laptop.
  if ($isLaptop) {
    try {
      $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
      if ($bat) {
        $items += New-CheckItem 'chk_bateria' 'Batería (laptop)' 'Ok' $true "estado $($bat.BatteryStatus); carga $($bat.EstimatedChargeRemaining)%"
      } else { $items += New-CheckItem 'chk_bateria' 'Batería (laptop)' 'N/A' $true 'sin batería detectada' }
    } catch { $items += New-CheckItem 'chk_bateria' 'Batería (laptop)' 'N/A' $true ''; $errs += "bateria: $($_.Exception.Message)" }
  } else { $items += New-CheckItem 'chk_bateria' 'Batería (laptop)' 'N/A' $true 'no laptop' }

  # chk_hardware_visual (MANUAL) y chk_perifericos (MANUAL): técnico completa.
  $items += New-CheckItem 'chk_hardware_visual' 'Check hardware (visual)' 'N/A' $false 'inspección manual'
  $items += New-CheckItem 'chk_perifericos' 'Estado periféricos' 'N/A' $false 'inspección manual'

  # chk_ups (SEMI): detecta software UPS conocido; si no, N/A.
  try {
    $ups = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'APC|PowerChute|UPS|Network Shutdown' }
    if ($ups) { $items += New-CheckItem 'chk_ups' 'UPS' 'N/A' $false ("software UPS: " + (($ups | ForEach-Object { $_.DisplayName }) -join ', ')) }
    else { $items += New-CheckItem 'chk_ups' 'UPS' 'N/A' $false 'sin software UPS detectado' }
  } catch { $items += New-CheckItem 'chk_ups' 'UPS' 'N/A' $false ''; $errs += "ups: $($_.Exception.Message)" }

  @{ category = 'Hardware'; items = $items; errors = $errs }
}
