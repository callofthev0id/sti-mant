# lib/informe-html.ps1 - render del informe consolidado. Requiere Get-SemColor (output.ps1).
# New-InformeHtml -Modelos @($mTerm[,$mSrv]) -Variante full|terminales|servidores
# Matriz: filas = equipos/servidores, columnas = checks agrupados por categoría (headers verticales, celdas semáforo)
#         + columna Usuario + Observaciones.

function _Esc { param([string]$s) ConvertTo-HtmlSafe $s }

function _MatrizHtml {
  param($Model)
  if (-not $Model -or -not $Model.equipos -or $Model.equipos.Count -eq 0) { return '<p style="color:#999;padding:8px">Sin equipos.</p>' }
  # columnas = checks del primer equipo (todos comparten estructura)
  $cats = $Model.equipos[0].checks   # ordered: categoria -> [{label,estado,detalle}]
  # header de grupos + labels
  $grpRow = "<tr class='grp'><th class='eqh' rowspan='2'>Equipo</th><th class='eqh' rowspan='2'>Usuario</th>"
  $lblRow = "<tr class='chk'>"
  foreach ($cat in $cats.Keys) {
    $n = @($cats[$cat]).Count
    $grpRow += "<th colspan='$n'>$(_Esc $cat)</th>"
    foreach ($c in $cats[$cat]) { $lblRow += "<th><span class='v'>$(_Esc $c.label)</span></th>" }
  }
  $grpRow += "<th class='eqh' rowspan='2'>Score</th><th class='eqh' rowspan='2'>Observaciones</th></tr>"
  $lblRow += "</tr>"
  # filas
  $body = ''
  foreach ($e in $Model.equipos) {
    $body += "<tr><td class='eq'>$(_Esc $e.hostname)</td><td class='usr'>$(_Esc $e.usuario)</td>"
    foreach ($cat in $e.checks.Keys) {
      foreach ($c in $e.checks[$cat]) {
        $col = Get-SemColor $c.estado
        $txt = switch ($c.estado) { 'Ok'{'✓'} 'Advertencia'{'!'} 'Error'{'✕'} 'Crítico'{'✕'} default{'–'} }
        $body += "<td class='c' style='background:$col'>$txt</td>"
      }
    }
    $body += "<td class='sc'>$($e.score)</td><td class='obs'>$(_Esc $e.observaciones)</td></tr>"
  }
  "<table class='mtx'><thead>$grpRow$lblRow</thead><tbody>$body</tbody></table>"
}

function New-InformeHtml {
  param([object[]]$Modelos, [ValidateSet('full','terminales','servidores')][string]$Variante, [string]$LogoPath)
  $modelos = @($Modelos | Where-Object { $_ })
  $logoB64 = ''
  if ($LogoPath -and (Test-Path $LogoPath)) { try { $logoB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($LogoPath)) } catch {} }

  # KPIs combinados
  $total = ($modelos | ForEach-Object { $_.kpis.total } | Measure-Object -Sum).Sum
  $err   = ($modelos | ForEach-Object { $_.kpis.errores } | Measure-Object -Sum).Sum
  $adv   = ($modelos | ForEach-Object { $_.kpis.advertencias } | Measure-Object -Sum).Sum
  $scores = @($modelos | ForEach-Object { $_.kpis.score } | Where-Object { $_ -ne $null })
  $score = if ($scores.Count) { [int][Math]::Round(($scores | Measure-Object -Average).Average) } else { 0 }
  $cliente = ($modelos | ForEach-Object { $_.cliente } | Where-Object { $_ } | Select-Object -First 1)
  $periodo = ($modelos | ForEach-Object { $_.periodo } | Where-Object { $_ } | Select-Object -First 1)

  $kpiHtml = @"
<div class='kpis'>
<div class='kpi'><div class='n'>$score</div><div class='l'>Score salud</div></div>
<div class='kpi'><div class='n'>$total</div><div class='l'>Equipos</div></div>
<div class='kpi'><div class='n'>$err</div><div class='l'>Errores/Críticos</div></div>
<div class='kpi'><div class='n'>$adv</div><div class='l'>Advertencias</div></div>
</div>
"@
  # Atención combinada
  $at = @($modelos | ForEach-Object { $_.atencion } | Where-Object { $_ })
  $atHtml = ''
  if ($at.Count -gt 0) {
    $li = ($at | ForEach-Object { "<li><b>$(_Esc $_.hostname)</b> - $(_Esc $_.label) <b>$($_.estado)</b>: $(_Esc $_.detalle)</li>" }) -join ''
    $atHtml = "<div class='atender'><h4>Atención - para el informe / acción</h4><ul>$li</ul></div>"
  }
  # Secciones (matriz por modelo)
  $sec = ''
  foreach ($m in $modelos) {
    $t = if ($m.tipo -eq 'servidores') { 'Servidores' } else { 'Terminales' }
    $sec += "<div class='sec-t'>$t - detalle</div>" + (_MatrizHtml -Model $m)
  }

  $titulo = switch ($Variante) { 'terminales'{'Terminales'} 'servidores'{'Servidores'} default{'Mantenimiento'} }
  $logoTag = if ($logoB64) { "<img src='data:image/png;base64,$logoB64' height='40'>" } else { '' }
  @"
<!DOCTYPE html><html lang='es'><head><meta charset='utf-8'>
<link rel='preconnect' href='https://fonts.googleapis.com'><link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>
<link href='https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap' rel='stylesheet'>
<style>
body{font-family:'Space Grotesk','Helvetica Neue',Arial,sans-serif;color:#111;margin:0}
.banner{background:#0E271B;color:#fff;padding:13px 18px;display:flex;align-items:center;gap:12px;border-bottom:3px solid #5EAE87}
.banner h1{font-size:18px;margin:0}
.meta{padding:6px 18px;color:#4a4a4a;font-size:13px}
.kpis{display:flex;gap:10px;padding:6px 18px 14px}
.kpi{background:#F5F6F6;border:1px solid #E1E5E3;border-radius:8px;padding:10px 16px;text-align:center;flex:1}
.kpi .n{font-family:'DM Mono',monospace;font-size:24px;color:#0E271B}
.kpi .l{font-size:10px;color:#717171;text-transform:uppercase;letter-spacing:.05em}
.atender{margin:0 18px 14px;background:rgba(224,120,32,.06);border:1px solid rgba(224,120,32,.35);border-left:4px solid #C77539;border-radius:0 4px 4px 0;padding:8px 14px}
.atender h4{margin:0 0 5px;color:#C77539;font-size:12px;text-transform:uppercase;letter-spacing:.05em}
.atender li{font-size:12px;margin:2px 0}
.sec-t{font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:#0E271B;margin:14px 18px 6px;border-left:3px solid #5EAE87;padding-left:8px}
.mtx{border-collapse:collapse;font-size:12px;margin:0 18px 16px;width:calc(100% - 36px);table-layout:auto}
.mtx th,.mtx td{border:1px solid #cfcfcf;padding:4px 7px}
.mtx tr.grp th{background:#428564;color:#fff;font-size:11px;text-transform:uppercase}
.mtx tr.grp th.eqh{background:#0E271B}
.mtx tr.chk th{background:#0E271B;color:#fff;font-weight:500;font-size:10px;height:118px;vertical-align:bottom;padding-bottom:6px}
.mtx tr.chk th .v{writing-mode:vertical-rl;transform:rotate(180deg);white-space:nowrap;margin:0 auto}
.mtx td.eq{font-family:'DM Mono',monospace;font-size:12px;background:#f7f7f7;white-space:nowrap}
.mtx td.usr{font-size:12px;white-space:nowrap}
.mtx td.c{text-align:center;font-weight:700;font-size:15px;color:#0E271B;width:26px}
.mtx td.sc{text-align:center;font-family:'DM Mono',monospace;font-size:13px}
.mtx td.obs{font-size:12px;color:#4a4a4a;min-width:240px}
</style></head><body>
<div class='banner'>$logoTag<h1>FLEET TOOLKIT · Informe de Mantenimiento - $titulo</h1></div>
<div class='meta'>Cliente: <b>$(_Esc $cliente)</b> · Período: <b>$periodo</b></div>
$kpiHtml
$atHtml
$sec
</body></html>
"@
}
