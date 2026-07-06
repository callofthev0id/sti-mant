# mod-sistema.ps1 - visor de eventos (semi), último reinicio, VSS, inicio (semi), software terceros (semi).
function Invoke-STIModSistema {
  param($Ctx)
  $items = @(); $errs = @()

  # chk_visor_eventos (SEMI): cuenta errores/críticos System+Application últimos 7 días → detalle; status lo decide el técnico (N/A).
  try {
    $since = (Get-Date).AddDays(-7)
    $n = 0
    foreach ($log in 'System','Application') {
      $n += @(Get-WinEvent -FilterHashtable @{ LogName=$log; Level=1,2; StartTime=$since } -ErrorAction SilentlyContinue).Count
    }
    $items += New-CheckItem 'chk_visor_eventos' 'Visor de eventos' 'N/A' $false "$n errores/críticos en 7 días (revisar)" @{ erroresCriticos7d = $n }
  } catch { $items += New-CheckItem 'chk_visor_eventos' 'Visor de eventos' 'N/A' $false ''; $errs += "eventos: $($_.Exception.Message)" }

  # chk_ultimo_reinicio: días desde LastBootUpTime.
  try {
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $days = [int]((Get-Date) - $boot).TotalDays
    $items += New-CheckItem 'chk_ultimo_reinicio' 'Último reinicio' (Get-StatusByDays $days $THR.reinicio.okMax $THR.reinicio.advMax) $true "hace $days días" @{ dias = $days; ultimoBoot = $boot.ToString('yyyy-MM-dd HH:mm') }
  } catch { $items += New-CheckItem 'chk_ultimo_reinicio' 'Último reinicio' 'N/A' $true ''; $errs += "reinicio: $($_.Exception.Message)" }

  # chk_restaurar_vss: días del último shadow copy.
  try {
    $sh = @(Get-CimInstance Win32_ShadowCopy -ErrorAction SilentlyContinue)
    if ($sh.Count -gt 0) {
      $latest = ($sh | ForEach-Object { $_.InstallDate } | Sort-Object -Descending | Select-Object -First 1)
      $days = [int]((Get-Date) - $latest).TotalDays
      $items += New-CheckItem 'chk_restaurar_vss' 'Restaurar sistema / VSS' (Get-StatusVss $days $true) $true "último punto hace $days días ($($sh.Count) copias)"
    } else {
      $items += New-CheckItem 'chk_restaurar_vss' 'Restaurar sistema / VSS' (Get-StatusVss 0 $false) $true 'sin shadow copies'
    }
  } catch { $items += New-CheckItem 'chk_restaurar_vss' 'Restaurar sistema / VSS' 'N/A' $true ''; $errs += "vss: $($_.Exception.Message)" }

  # chk_inicio_no_deseado (SEMI): lista de startup → detalle; técnico decide.
  try {
    $su = @(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $items += New-CheckItem 'chk_inicio_no_deseado' 'Inicio no deseado' 'N/A' $false ("$($su.Count) entradas: " + (($su | Select-Object -First 12) -join ', '))
  } catch { $items += New-CheckItem 'chk_inicio_no_deseado' 'Inicio no deseado' 'N/A' $false ''; $errs += "inicio: $($_.Exception.Message)" }

  # chk_software_terceros (SEMI): software instalado no-Microsoft → detalle; técnico decide.
  try {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $sw = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.Publisher -notmatch 'Microsoft' } | ForEach-Object { $_.DisplayName } | Sort-Object -Unique)
    $items += New-CheckItem 'chk_software_terceros' 'Softwares de terceros' 'N/A' $false ("$($sw.Count) apps no-MS (ver reporte)")
  } catch { $items += New-CheckItem 'chk_software_terceros' 'Softwares de terceros' 'N/A' $false ''; $errs += "software: $($_.Exception.Message)" }

  @{ category = 'Sistema'; items = $items; errors = $errs }
}
