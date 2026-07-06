# lib/score.ps1 - score de mantenimiento (puro). Ok=1 Adv=.6 Error=.2 Critico=0 N/A=excluido.
function Get-EstadoPeso {
  param([string]$Estado)
  switch ($Estado) {
    'Ok' { 1.0 } 'Advertencia' { 0.6 } 'Error' { 0.2 } 'Crítico' { 0.0 }
    default { $null }   # N/A o vacío: excluido del promedio
  }
}
function Get-EquipoScore {
  param([string[]]$Estados)
  $pesos = @($Estados | ForEach-Object { Get-EstadoPeso $_ } | Where-Object { $_ -ne $null })
  if ($pesos.Count -eq 0) { return $null }
  [int][Math]::Round((($pesos | Measure-Object -Sum).Sum / $pesos.Count) * 100)
}
function Get-ClienteScore {
  param([object[]]$Scores)
  $v = @($Scores | Where-Object { $_ -ne $null })
  if ($v.Count -eq 0) { return $null }
  [int][Math]::Round(($v | Measure-Object -Average).Average)
}
