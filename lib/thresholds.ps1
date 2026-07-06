# lib/thresholds.ps1 - evaluadores PUROS: valor crudo → estado semáforo. Sin WMI.
# Umbrales del spec §5.9. Estados: Ok | Advertencia | Error | Crítico | N/A.

# Días desde un evento → estado (más días = peor). Ej updates/reinicio.
function Get-StatusByDays {
  param([int]$Days, [int]$OkMax, [int]$AdvMax)
  if ($Days -le $OkMax)  { return 'Ok' }
  if ($Days -le $AdvMax) { return 'Advertencia' }
  return 'Error'
}

# % de uso → estado (más % = peor). Ej espacio en disco.
function Get-StatusByPct {
  param([int]$Pct, [int]$OkMax, [int]$AdvMax)
  if ($Pct -lt $OkMax)  { return 'Ok' }
  if ($Pct -lt $AdvMax) { return 'Advertencia' }
  return 'Error'
}

# Booleano simple → Ok/Error.
function Get-StatusBool {
  param([bool]$Ok)
  if ($Ok) { 'Ok' } else { 'Error' }
}

# VSS / punto de restauración: días del último punto. Sin puntos => Error.
function Get-StatusVss {
  param([int]$Days, [bool]$HasPoint)
  if (-not $HasPoint) { return 'Error' }
  if ($Days -le 7)  { return 'Ok' }
  if ($Days -le 30) { return 'Advertencia' }
  return 'Error'
}

# Umbrales nombrados (spec §5.9) - para uso de los módulos.
$script:THR = @{
  updates    = @{ okMax = 30; advMax = 60 }   # días desde último KB
  reinicio   = @{ okMax = 30; advMax = 60 }   # días desde último boot
  disco      = @{ okMax = 80; advMax = 90 }   # % usado
  tempGb     = 1                               # >1GB => Advertencia
}
