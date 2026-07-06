# lib/informe-model.ps1 - JSONs de relevamiento → modelo del informe. Requiere score.ps1.
function Read-Relevamientos {
  param([string]$Carpeta, [string]$Tipo)
  $out = @()
  foreach ($f in (Get-ChildItem -Path $Carpeta -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
    try {
      $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($o.meta -and (-not $Tipo -or $o.meta.tipo -eq $Tipo)) { $out += $o }
    } catch { Write-Warning "JSON ilegible: $($f.Name)" }
  }
  # Dedup por hostname: si hay varios JSON del mismo equipo (relevado en dias distintos),
  # se queda con la corrida mas reciente. Evita filas y KPIs duplicados en el informe.
  $out = $out | Group-Object { [string]$_.meta.hostname } | ForEach-Object {
    $_.Group | Sort-Object { [string]$_.meta.fecha } -Descending | Select-Object -First 1
  }
  @($out)
}

function Build-InformeModel {
  param([object[]]$Equipos, [string]$Tipo)
  $eqModel = @(); $atencion = @(); $scores = @()
  $errores = 0; $advert = 0
  foreach ($e in $Equipos) {
    $estados = @($e.checks | ForEach-Object { $_.estado })
    $sc = Get-EquipoScore $estados; $scores += $sc
    $errores += @($estados | Where-Object { $_ -in 'Error','Crítico' }).Count
    $advert  += @($estados | Where-Object { $_ -eq 'Advertencia' }).Count
    # checks por categoria (preserva orden de aparición)
    $porCat = [ordered]@{}
    foreach ($c in $e.checks) {
      if (-not $porCat.Contains($c.categoria)) { $porCat[$c.categoria] = @() }
      $porCat[$c.categoria] += @{ label = $c.label; estado = $c.estado; detalle = $c.detalle }
    }
    # atencion: Error/Crítico
    foreach ($c in ($e.checks | Where-Object { $_.estado -in 'Error','Crítico' })) {
      $atencion += @{ hostname = $e.meta.hostname; label = $c.label; estado = $c.estado; detalle = $c.detalle }
    }
    # observaciones = nota + porque de no-Ok
    $porque = @($e.checks | Where-Object { $_.estado -in 'Advertencia','Error','Crítico' } | ForEach-Object { "$($_.label): $($_.detalle)" })
    $obs = @(); if ($e.meta.nota) { $obs += $e.meta.nota }; $obs += $porque
    $eqModel += @{
      hostname = $e.meta.hostname; usuario = $e.meta.usuario; so = $e.meta.so;
      checks = $porCat; observaciones = ($obs -join '; '); score = $sc; hwIds = $e.hardwareIds
    }
  }
  $cli = if ($Equipos) { $Equipos[0].meta.cliente } else { '' }
  # Periodo = yyyy-MM del primer equipo. Defensivo: si meta.fecha falta o es corta, queda vacio
  # (un JSON viejo/corrupto no debe abortar todo el informe).
  $per = ''
  if ($Equipos) {
    $f = ([string]$Equipos[0].meta.fecha -split 'T')[0]
    if ($f.Length -ge 7) { $per = $f.Substring(0, 7) }
  }
  @{
    cliente = $cli; periodo = $per; tipo = $Tipo; equipos = $eqModel; atencion = $atencion;
    kpis = @{ total = $eqModel.Count; mantRealizados = $eqModel.Count; errores = $errores; advertencias = $advert; score = (Get-ClienteScore $scores) }
  }
}
