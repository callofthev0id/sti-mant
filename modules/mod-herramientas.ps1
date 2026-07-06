# mod-herramientas.ps1 - OCS (check-first, install opcional), Cobian (semi), cloud sync, limpieza temp.
function Invoke-STIModHerramientas {
  param($Ctx)
  $items = @(); $errs = @()

  # chk_ocs: COMPROBAR servicio + último inventario. Instala solo si $Ctx.installOcs y no está.
  try {
    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'OCS' -or $_.DisplayName -match 'OCS Inventory' } | Select-Object -First 1
    $installed = [bool]$svc
    if (-not $installed -and $Ctx.installOcs) {
      $exe = Join-Path $Ctx.scriptDir 'OcsPackage-x64.exe'
      if (Test-Path $exe) {
        Start-Process -FilePath $exe -ArgumentList "/FORCE","/TAG=`"$($Ctx.tag)`"" -Wait -ErrorAction Stop
        Start-Sleep -Seconds 3
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'OCS' } | Select-Object -First 1
        $installed = [bool]$svc
      } else { $errs += "ocs: OcsPackage-x64.exe no encontrado en $($Ctx.scriptDir)" }
    }
    if ($installed) {
      $st = if ($svc.Status -eq 'Running') { 'Ok' } else { 'Advertencia' }
      $items += New-CheckItem 'chk_ocs' 'OCS Agent + inventario' $st $true "servicio:$($svc.Status)"
    } else {
      $items += New-CheckItem 'chk_ocs' 'OCS Agent + inventario' 'Error' $true ($(if($Ctx.installOcs){'instalación falló'}else{'no instalado (usar -InstallOCS)'}))
    }
  } catch { $items += New-CheckItem 'chk_ocs' 'OCS Agent + inventario' 'N/A' $true ''; $errs += "ocs: $($_.Exception.Message)" }

  # chk_backup_cobian: AUTO desde Cobian (history.db/logs, staleness por frecuencia
  # configurada); MANUAL (N/A) si no hay Cobian. Get-BackupCheckItem no tira excepción.
  $items += Get-BackupCheckItem 'chk_backup_cobian' 'Backup Cobian'

  # chk_cloud_sync: Google Drive / OneDrive activo.
  try {
    $gd = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'GoogleDriveFS|OneDrive' } | Select-Object -First 1
    if ($gd) { $items += New-CheckItem 'chk_cloud_sync' 'Google Drive / OneDrive' 'Ok' $true "$($gd.Name) activo" }
    else { $items += New-CheckItem 'chk_cloud_sync' 'Google Drive / OneDrive' 'N/A' $true 'sin sync detectado' }
  } catch { $items += New-CheckItem 'chk_cloud_sync' 'Google Drive / OneDrive' 'N/A' $true ''; $errs += "cloud: $($_.Exception.Message)" }

  # chk_limpieza_temp: tamaño de TEMP. >1GB → Advertencia.
  try {
    $paths = @($env:TEMP, "$env:WINDIR\Temp") | Where-Object { Test-Path $_ } | Select-Object -Unique
    $bytes = 0
    foreach ($p in $paths) { $bytes += (Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
    $gb = [math]::Round($bytes/1GB,2)
    $st = if ($gb -lt $THR.tempGb) { 'Ok' } else { 'Advertencia' }
    $items += New-CheckItem 'chk_limpieza_temp' 'Limpieza temporales' $st $true "$gb GB en temp" @{ tempGb = $gb }
  } catch { $items += New-CheckItem 'chk_limpieza_temp' 'Limpieza temporales' 'N/A' $true ''; $errs += "temp: $($_.Exception.Message)" }

  @{ category = 'Herramientas'; items = $items; errors = $errs }
}
