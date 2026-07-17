# lib/output.ps1 - salidas del script.
#  ① ConvertTo-MantTsv (PURO): items agregados → 1 línea TSV en el orden del column-spec (para pegar en la planilla).
#  ② New-HtmlReport: relevamiento branded a archivo (semi-puro; escribe disco).

# Carpeta de trabajo local del mantenimiento: C:\zback (se crea si no existe).
# Acá quedan los JSON/HTML de relevamiento y desde acá los lee el informe.
# Si no se puede crear (sin permisos / no-Windows), cae al escritorio.
function Get-MantDir {
  param([string]$Path = 'C:\zback')
  if (-not (Test-Path -LiteralPath $Path)) {
    try { New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null }
    catch { return [Environment]::GetFolderPath('Desktop') }
  }
  $Path
}

# PURO: dado los items {key,status} y el orden canónico, devuelve UNA línea tab-separated.
# Solo el bloque de checks, en orden. Status faltante/Semi-vacío → celda vacía.
function ConvertTo-MantTsv {
  param([object[]]$Items, [string[]]$Order, [switch]$AsColumn)
  $byKey = @{}
  foreach ($i in $Items) { if ($i -and $i.key) { $byKey[$i.key] = $i.status } }
  $cells = foreach ($k in $Order) {
    $v = $byKey[$k]
    if ($null -eq $v) { '' } else { [string]$v }
  }
  # terminales = fila (tab); servidores = columna (newline, layout vertical de la planilla)
  if ($AsColumn) { ($cells -join "`r`n") } else { ($cells -join "`t") }
}

# PURO: sanea un componente de nombre de archivo (saca chars inválidos de path/Windows).
# El hostname llega de datos del equipo y podría traer caracteres que rompen Join-Path/Out-File.
function Get-SafeFileComponent {
  param([string]$Name)
  $s = [string]$Name
  if (-not $s) { return 'equipo' }
  $s = $s -replace '[\\/:*?"<>|]', '_' -replace '\s+', '_'
  $s = $s.Trim('._')
  if (-not $s) { 'equipo' } else { $s }
}

# Color semáforo para el HTML (igual paleta que las planillas).
function Get-SemColor {
  param([string]$Status)
  switch ($Status) {
    'Ok'          { '#5EAE87' }
    'Advertencia' { '#D7A858' }
    'Error'       { '#C77539' }
    'Crítico'     { '#DA6A72' }
    default       { '#C8C8C8' }   # N/A / vacío
  }
}

# HTML branded de relevamiento. $modules = array de objetos {category, items[]}.
# $hwIds = salida de Get-HardwareIds. $ctx = {cliente,tag,os,formFactor,...}. Escribe en C:\zback, devuelve la ruta.
function New-HtmlReport {
  param($Ctx, [object[]]$Modules, $HwIds, [string]$LogoPath, [string]$Tipo = 'terminales')
  $logoB64 = ''
  if ($LogoPath -and (Test-Path $LogoPath)) {
    try { $logoB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($LogoPath)) } catch {}
  }
  $hostName = $HwIds.hostname
  $stamp = Get-Date -Format 'yyyyMMdd'
  $fecha = Get-Date -Format 'dd/MM/yyyy HH:mm'

  $esc = { param($s) ConvertTo-HtmlSafe $s }

  $rowsHtml = "<tr class='hdr'><th style='text-align:left'>Ítem</th><th>Estado</th><th style='text-align:left'>Detalle / observación sugerida</th></tr>"
  foreach ($m in $Modules) {
    $rowsHtml += "<tr class='cat'><td colspan='3'>$(& $esc $m.category)</td></tr>"
    foreach ($it in $m.items) {
      $c = Get-SemColor $it.status
      $st = & $esc $(if ($it.status) { $it.status } else { '-' })
      $det = & $esc $it.detail
      $rowsHtml += "<tr><td>$(& $esc $it.label)</td><td style=`"background:$c;color:#fff;font-weight:600;text-align:center`">$st</td><td class='det'>$det</td></tr>"
    }
  }

  $idsHtml = @"
<div class='ids'>
<b>Hardware IDs</b> (cruce de consolas - prioridad UUID→disk-serial→bios→MAC):<br>
hostname: <code>$(& $esc $HwIds.hostname)</code> &nbsp; os_uuid: <code>$(& $esc $HwIds.os_uuid)</code><br>
disk_serial: <code>$(& $esc ($HwIds.disk_serial -join ', '))</code> &nbsp; hw_uuid: <code>$(& $esc $HwIds.hw_uuid)</code><br>
bios_serial: <code>$(& $esc $HwIds.bios_serial)</code> &nbsp; mac: <code>$(& $esc ($HwIds.mac -join ', '))</code>
</div>
"@

  $logoTag = if ($logoB64) { "<img src='data:image/png;base64,$logoB64' height='44'>" } else { '' }

  $html = @"
<!DOCTYPE html><html lang='es'><head><meta charset='utf-8'>
<link rel='preconnect' href='https://fonts.googleapis.com'><link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>
<link href='https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap' rel='stylesheet'>
<style>
body{font-family:'Space Grotesk','Helvetica Neue',Arial,sans-serif;color:#111;margin:0;background:#fff}
.banner{background:#0E271B;color:#fff;padding:12px 18px;display:flex;align-items:center;gap:14px}
.banner h1{font-size:18px;margin:0;letter-spacing:.04em}
.meta{padding:10px 18px;background:#f4f4f4;font-size:13px;color:#333}
.meta b{color:#0E271B}
table{width:100%;border-collapse:collapse;font-size:12px}
td{border:1px solid #ddd;padding:5px 9px}
tr.cat td{background:#428564;color:#fff;font-weight:700;text-transform:uppercase;font-size:11px;letter-spacing:.05em}
tr.hdr th{background:#0E271B;color:#fff;font-size:11px;padding:6px 9px;text-align:center}
.det{color:#555;font-size:11px}
code{font-family:'DM Mono',Consolas,monospace;font-size:11px;color:#0E271B}
.ids{padding:10px 18px;font-size:12px;background:#EDF7F2;border-top:2px solid #5EAE87}
</style></head><body>
<div class='banner'>$logoTag<h1>FLEET TOOLKIT &nbsp;·&nbsp; RELEVAMIENTO DE EQUIPO</h1></div>
<div class='meta'><b>Cliente:</b> $(& $esc $Ctx.cliente) &nbsp;·&nbsp; <b>Equipo:</b> $(& $esc $hostName) &nbsp;·&nbsp; <b>SO:</b> $(& $esc $Ctx.os.caption) &nbsp;·&nbsp; <b>Tipo:</b> $(& $esc $Ctx.formFactor) &nbsp;·&nbsp; <b>Fecha:</b> $(& $esc $fecha)</div>
$idsHtml
<table>$rowsHtml</table>
</body></html>
"@

  $safeHost = Get-SafeFileComponent $hostName
  $out = Join-Path (Get-MantDir) "${safeHost}_FLEET_MANT_${Tipo}_${stamp}.html"
  $html | Out-File -FilePath $out -Encoding UTF8
  $out
}

# ③ META-DATA estructurada (JSON): por cada check estado + EL PORQUÉ (detail + rawData) + hardware-ids + meta.
# Es el relevamiento machine-readable (la planilla lleva solo el semáforo; acá queda el detalle).
function New-MetaExport {
  param($Ctx, $Rel, [string]$Tipo = 'terminales')
  $checks = @()
  foreach ($m in $Rel.modules) {
    foreach ($it in $m.items) {
      $checks += [ordered]@{
        categoria = $m.category; key = $it.key; label = $it.label;
        estado = $it.status; automatizado = [bool]$it.automated;
        detalle = $it.detail; raw = $it.rawData
      }
    }
  }
  $stampFile = Get-Date -Format 'yyyyMMdd'
  $obj = [ordered]@{
    meta = [ordered]@{
      cliente = $Ctx.cliente; tag = $Ctx.tag; hostname = $Rel.hw.hostname; tipo = $Tipo;
      so = $Ctx.os.caption; soClase = $Ctx.os.class; soVersion = $Ctx.os.version;
      formFactor = $Ctx.formFactor; esVm = [bool]$Ctx.isVm; hypervHost = [bool]$Ctx.hypervHost;
      fecha = (Get-Date -Format 'o'); scriptVersion = $SCRIPT_VERSION;
      usuario = $Ctx.usuario; nota = $Ctx.nota; tecnico = $Ctx.tecnico
    }
    hardwareIds = [ordered]@{
      os_uuid = $Rel.hw.os_uuid; disk_serial = @($Rel.hw.disk_serial); hw_uuid = $Rel.hw.hw_uuid;
      mac = @($Rel.hw.mac); bios_serial = $Rel.hw.bios_serial; hostname = $Rel.hw.hostname
    }
    checks = $checks
    errores = @($Rel.errors)
  }
  $json = $obj | ConvertTo-Json -Depth 8
  $out = Join-Path (Get-MantDir) "$(Get-SafeFileComponent $Rel.hw.hostname)_FLEET_MANT_${Tipo}_${stampFile}.json"
  $json | Out-File -FilePath $out -Encoding UTF8
  $out
}
