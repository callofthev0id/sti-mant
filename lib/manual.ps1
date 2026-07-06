# lib/manual.ps1 - carga de los checks MANUALES (automated=$false) por el técnico.
# El relevamiento auto deja esos checks en N/A; acá el técnico carga su veredicto
# (estado + nota) → entra al mismo $Rel → TSV/HTML/JSON los incluyen.

# PURO: tecla → estado semáforo. Enter/letra inválida → $null (no cambia el check).
function ConvertTo-ManualEstado {
  param([string]$Key)
  switch (($Key).Trim().ToUpper()) {
    'O' { 'Ok' }
    'A' { 'Advertencia' }
    'E' { 'Error' }
    'C' { 'Crítico' }
    'N' { 'N/A' }
    default { $null }
  }
}

# Aplica un veredicto manual a un item del relevamiento (mutación por referencia).
# Devuelve $true si cambió algo. PURO respecto de IO (no pregunta).
function Set-ManualVerdict {
  param($Item, [string]$Estado, [string]$Nota)
  $changed = $false
  if ($Estado) { $Item.status = $Estado; $changed = $true }
  if ($PSBoundParameters.ContainsKey('Nota') -and $Nota -ne '') { $Item.detail = $Nota; $changed = $true }
  $changed
}

# Loop de carga. Interactivo (Read-Host) salvo que se pase -Answers (key -> @{estado;nota})
# para test/no-interactivo. Marca $Rel.manualDone para no re-preguntar (salvo -Force).
function Invoke-ManualCapture {
  param($Rel, [hashtable]$Answers, [switch]$Force)
  $manual = @($Rel.items | Where-Object { -not $_.automated })
  if ($manual.Count -eq 0) { return }
  if ($Rel.manualDone -and -not $Force -and -not $Answers) { return }
  if (-not $Answers -and -not [Environment]::UserInteractive) { return }   # automación sin answers → skip

  if (-not $Answers) {
    Write-Host "`n--- CARGA DE CHECKS MANUALES (los que no se pueden ver remoto) ---" -ForegroundColor White
    Write-Host "    Por cada uno: [O]k  [A]dvertencia  [E]rror  [C]ritico  [N]A   (Enter = dejar como esta)" -ForegroundColor DarkGray
  }
  foreach ($it in $manual) {
    if ($Answers) {
      $a = $Answers[$it.key]
      if ($a) { [void](Set-ManualVerdict -Item $it -Estado ([string]$a.estado) -Nota ([string]$a.nota)) }
      continue
    }
    Write-Host ("`n  {0}" -f $it.label) -ForegroundColor Cyan
    if ($it.detail) { Write-Host ("    (auto: {0})" -f $it.detail) -ForegroundColor DarkGray }
    $k = Read-Host "    estado"
    $e = ConvertTo-ManualEstado $k
    if ($e) { $it.status = $e }
    $n = Read-Host "    nota (Enter = ninguna)"
    if ($n) { $it.detail = $n }
  }
  $Rel.manualDone = $true
  if (-not $Answers) { Write-Host "`n  Checks manuales cargados." -ForegroundColor Green }
}
