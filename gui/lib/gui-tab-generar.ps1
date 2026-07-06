# gui/lib/gui-tab-generar.ps1 - tab Generar: consolidacion local de JSONs de relevamiento.
# Funciones puras de shaping (testeables con fixtures, sin WMI ni WPF) + New-PanelGenerarXaml
# (reemplaza el placeholder) + Update-GenerarPanel (pobla chips de equipo en runtime).
# El informe que produce esta tab es LOCAL y deterministico, NO el informe oficial mensual del cliente.

# Orden canonico de keys de check por unidad. Mirror PS de planilla-builder/src/column-spec.mjs
# (CHK_ORDER_TERM 26, CHK_ORDER_SRV 19). No se lee el .mjs en runtime: no hay Node garantizado en
# la maquina del tecnico. El test de conteo (26/19) detecta drift si cambia el spec.
$script:CHK_ORDER_TERM = @(
  @{ key='chk_cuentas_sti';          label='Cuentas STI (admin)' }
  @{ key='chk_firewall';             label='Firewall' }
  @{ key='chk_antivirus_eset';       label='Antivirus ESET' }
  @{ key='chk_updates';              label='Updates Windows' }
  @{ key='chk_reinicio_pendiente';   label='Reinicio pendiente' }
  @{ key='chk_visor_eventos';        label='Visor de eventos' }
  @{ key='chk_ultimo_reinicio';      label='Último reinicio' }
  @{ key='chk_restaurar_vss';        label='Restaurar sistema / VSS' }
  @{ key='chk_inicio_no_deseado';    label='Inicio no deseado' }
  @{ key='chk_software_terceros';    label='Softwares de terceros' }
  @{ key='chk_disco_smart';          label='Estado disco (SMART)' }
  @{ key='chk_espacio_disco';        label='Espacio en disco C:' }
  @{ key='chk_ram';                  label='Estado RAM' }
  @{ key='chk_hardware_visual';      label='Check hardware (visual)' }
  @{ key='chk_perifericos';          label='Estado periféricos' }
  @{ key='chk_ups';                  label='UPS' }
  @{ key='chk_bateria';              label='Batería (laptop)' }
  @{ key='chk_conectividad';         label='Conectividad (gateway+DNS)' }
  @{ key='chk_teamviewer';           label='TeamViewer Host STI' }
  @{ key='chk_recursos_compartidos'; label='Recursos compartidos' }
  @{ key='chk_rdp';                  label='Configuración RDP' }
  @{ key='chk_wifi';                 label='Adaptador WiFi (laptop)' }
  @{ key='chk_ocs';                  label='OCS Agent + inventario' }
  @{ key='chk_backup_cobian';        label='Backup Cobian' }
  @{ key='chk_cloud_sync';           label='Google Drive / OneDrive' }
  @{ key='chk_limpieza_temp';        label='Limpieza temporales' }
)
$script:CHK_ORDER_SRV = @(
  @{ key='srv_cuentas_sti';          label='Cuentas STI (admin)' }
  @{ key='srv_firewall';             label='Firewall' }
  @{ key='srv_antivirus_eset';       label='Antivirus ESET' }
  @{ key='srv_updates';              label='Updates Windows Server' }
  @{ key='srv_rdp';                  label='RDP hardening (NLA)' }
  @{ key='srv_visor_eventos';        label='Visor de eventos' }
  @{ key='srv_ultimo_reinicio';      label='Último reinicio' }
  @{ key='srv_vss';                  label='Versiones anteriores / VSS' }
  @{ key='srv_disco_smart';          label='Estado discos (SMART)' }
  @{ key='srv_espacio_disco';        label='Espacio en disco' }
  @{ key='srv_backup';               label='Backup (Acronis/Cobian)' }
  @{ key='srv_ocs';                  label='OCS Agent + inventario' }
  @{ key='srv_teamviewer';           label='TeamViewer Host STI' }
  @{ key='srv_encendido_auto';       label='Encendido automático' }
  @{ key='srv_apagado_auto';         label='Apagado automático' }
  @{ key='srv_servicios_rol';        label='Servicios por rol' }
  @{ key='srv_vms';                  label='Estado VMs (host Hyper-V)' }
  @{ key='srv_conectividad';         label='Conectividad (gateway+DNS)' }
  @{ key='srv_recursos_compartidos'; label='Recursos compartidos' }
)

# Orden canonico de checks (key+label) por unidad. Tipo = terminales|servidores (meta.tipo).
function Get-ChkOrder {
  param([string]$Tipo)
  if ($Tipo -eq 'servidores') { return $script:CHK_ORDER_SRV }
  $script:CHK_ORDER_TERM
}

# Mapea el vocabulario del segmented control (term|srv|both) a valores de meta.tipo.
# El mapeo vive aca, en un solo punto. La lectura del JSON nunca traduce.
function Get-GenerarVocab {
  param([string]$Seg)
  switch ($Seg) {
    'term' { ,@('terminales') }
    'srv'  { ,@('servidores') }
    'both' { ,@('terminales','servidores') }
    default { ,@('terminales') }
  }
}

# Lee y normaliza un JSON de relevamiento. Nunca tira: un archivo ilegible o sin meta.tipo
# devuelve ok=$false con el motivo, para marcarlo como invalido y excluirlo del conteo valido.
function Read-RelevamientoJson {
  param([string]$Path)
  $file = Split-Path -Leaf $Path
  $base = [ordered]@{ ok=$false; tipo=$null; hostname=$null; usuario=$null; cliente=$null; esVm=$false; hypervHost=$false; tecnico=$null; checks=@(); errores=@(); file=$file; error=$null }
  if (-not (Test-Path -LiteralPath $Path)) { $base.error = 'archivo inexistente'; return [pscustomobject]$base }
  try {
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $obj = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $base.error = 'JSON ilegible'; return [pscustomobject]$base
  }
  $tipo = $null
  if ($obj.meta -and $obj.meta.tipo) { $tipo = [string]$obj.meta.tipo }
  if ([string]::IsNullOrWhiteSpace($tipo)) { $base.error = 'sin meta.tipo'; return [pscustomobject]$base }
  if ($tipo -ne 'terminales' -and $tipo -ne 'servidores') { $base.error = "meta.tipo desconocido: $tipo"; return [pscustomobject]$base }
  $base.ok = $true
  $base.tipo = $tipo
  $base.hostname = if ($obj.meta.hostname) { [string]$obj.meta.hostname } else { ($file -split '_')[0] }
  $base.usuario  = if ($obj.meta.usuario)  { [string]$obj.meta.usuario }  else { $null }
  $base.cliente  = if ($obj.meta.cliente)  { [string]$obj.meta.cliente }  else { $null }
  $base.esVm     = [bool]$obj.meta.esVm
  $base.hypervHost = [bool]$obj.meta.hypervHost
  $base.tecnico  = if ($obj.meta.tecnico)  { [string]$obj.meta.tecnico }  else { $null }
  $base.checks   = @($obj.checks)
  $base.errores  = @($obj.errores)
  [pscustomobject]$base
}

# Lee todos los *.json de una carpeta (no recursivo) y los normaliza. Ordena por hostname.
function Get-JsonsDeCarpeta {
  param([string]$Carpeta)
  if ([string]::IsNullOrWhiteSpace($Carpeta) -or -not (Test-Path -LiteralPath $Carpeta)) { return @() }
  $files = Get-ChildItem -LiteralPath $Carpeta -Filter '*.json' -File -ErrorAction SilentlyContinue
  $out = foreach ($f in $files) { Read-RelevamientoJson -Path $f.FullName }
  @($out) | Sort-Object @{ Expression = { $_.hostname } }
}

# Arma el resumen de deteccion para el bloque .detected. Discrimina por meta.tipo segun el
# segmented (term|srv|both): en both separa en dos grupos, nunca suma "N equipos".
function Resolve-DeteccionGenerar {
  param([object[]]$Items, [string]$Seg)
  $vocab = Get-GenerarVocab -Seg $Seg
  $validos = @($Items | Where-Object { $_.ok -and ($vocab -contains $_.tipo) })
  $invalidos = @($Items | Where-Object { -not $_.ok })
  $porTipo = [ordered]@{}
  foreach ($t in $vocab) { $porTipo[$t] = @($validos | Where-Object { $_.tipo -eq $t }).Count }
  $equipos = foreach ($it in $validos) {
    [pscustomobject]@{ hostname = $it.hostname; tipo = $it.tipo; srv = ($it.tipo -eq 'servidores') }
  }
  # Texto del pill: en both, desglose; si no, el nombre del tipo.
  $pill = if ($Seg -eq 'both') {
    (@($porTipo.Keys | ForEach-Object { "$($porTipo[$_]) $_" }) -join ' · ')
  } else {
    $vocab[0]
  }
  [pscustomobject]@{
    total     = $validos.Count
    porTipo   = $porTipo
    pill      = $pill
    equipos   = @($equipos)
    invalidos = @($invalidos)
  }
}

# Resuelve el periodo: acepta YYYY-MM o texto humano (Mmm YYYY, "Junio 2026") y deriva el faltante.
# Replica la intencion de agregador/src/periodo.mjs en PS puro (sin Node). Si no se reconoce el
# formato, ym queda $null y el label es el texto tal cual.
function Resolve-PeriodoGenerar {
  param([string]$Texto)
  $meses = @('Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic')
  $mesNombre = @{
    'enero'=1;'febrero'=2;'marzo'=3;'abril'=4;'mayo'=5;'junio'=6;'julio'=7;'agosto'=8;
    'septiembre'=9;'setiembre'=9;'octubre'=10;'noviembre'=11;'diciembre'=12
  }
  $t = if ($Texto) { $Texto.Trim() } else { '' }
  if ([string]::IsNullOrWhiteSpace($t)) { return [pscustomobject]@{ ym=$null; label='' } }
  # YYYY-MM
  if ($t -match '^(\d{4})-(\d{1,2})$') {
    $y = [int]$Matches[1]; $m = [int]$Matches[2]
    if ($m -ge 1 -and $m -le 12) {
      $ym = '{0:D4}-{1:D2}' -f $y, $m
      return [pscustomobject]@{ ym=$ym; label=("$($meses[$m-1]) $y") }
    }
  }
  # "Mes YYYY" en espanol
  if ($t -match '^([A-Za-zÁÉÍÓÚáéíóúñ]+)\s+(\d{4})$') {
    $mn = $Matches[1].ToLower(); $y = [int]$Matches[2]
    if ($mesNombre.ContainsKey($mn)) {
      $m = $mesNombre[$mn]
      $ym = '{0:D4}-{1:D2}' -f $y, $m
      return [pscustomobject]@{ ym=$ym; label=("$($meses[$m-1]) $y") }
    }
  }
  [pscustomobject]@{ ym=$null; label=$t }
}

# Mapa estado -> color. Reusa Get-SemColor del core (output.ps1) si esta cargado, para que el
# ambar de la planilla coincida con la del core. Fallback local si la funcion no esta presente.
function Get-GenerarSemColor {
  param([string]$Estado)
  if (Get-Command Get-SemColor -ErrorAction SilentlyContinue) { return (Get-SemColor $Estado) }
  switch ($Estado) {
    'Ok'          { '#43C961' }
    'Advertencia' { '#F2C03D' }
    'Error'       { '#E07820' }
    'Crítico'     { '#F05754' }
    default       { '#6a8a7b' }
  }
}

# Color de texto legible sobre el color de estado. El ambar (#F2C03D) lleva texto oscuro;
# el resto (verde/naranja/rojo/gris) lleva texto blanco. Asi la etiqueta se lee siempre.
function Get-GenerarSemTextColor {
  param([string]$Estado)
  if ($Estado -eq 'Advertencia') { return '#3a2c00' }
  '#ffffff'
}

# Celda de estado con label + color de fondo (texto legible). Estado vacio = celda N/A neutra.
# Reusada por terminales y servidores para que el semaforo sea consistente.
function Get-GenerarEstadoCell {
  param([string]$Estado, [string]$ExtraClass = '')
  $cls = if ($ExtraClass) { "st $ExtraClass" } else { 'st' }
  if ([string]::IsNullOrWhiteSpace($Estado)) {
    return "<td class='$cls na'>N/A</td>"
  }
  $bg  = Get-GenerarSemColor $Estado
  $fg  = Get-GenerarSemTextColor $Estado
  $lbl = Get-GenerarHtmlSafe $Estado
  "<td class='$cls' style='background:$bg;color:$fg'>$lbl</td>"
}

# Label compacto de estado para celdas estrechas (grilla apaisada de terminales). El label largo
# ("Advertencia"/"Crítico") se sale del recuadro; este abrevia manteniendo el color de fondo.
function Get-GenerarEstadoAbbr {
  param([string]$Estado)
  switch ($Estado) {
    'Ok'          { 'Ok' }
    'Advertencia' { 'Adv' }
    'Error'       { 'Err' }
    'Crítico'     { 'Crit' }
    'Critico'     { 'Crit' }
    default       { if ([string]::IsNullOrWhiteSpace($Estado)) { 'N/A' } else { $Estado } }
  }
}

# Celda de estado con LABEL COMPACTO + color de fondo. Para la grilla de terminales (celdas chicas).
# Mantiene el color del semaforo y un label que entra en el recuadro.
function Get-GenerarEstadoCellAbbr {
  param([string]$Estado)
  if ([string]::IsNullOrWhiteSpace($Estado)) {
    return "<td class='st na'>N/A</td>"
  }
  $bg  = Get-GenerarSemColor $Estado
  $fg  = Get-GenerarSemTextColor $Estado
  $lbl = Get-GenerarHtmlSafe (Get-GenerarEstadoAbbr $Estado)
  "<td class='st' style='background:$bg;color:$fg'>$lbl</td>"
}

# Resumen ejecutivo deterministico: total de equipos + distribucion de estados sumando TODOS los
# checks de TODOS los equipos (Ok/Advertencia/Error/Critico/N/A) + cuantos equipos con problemas.
# Sin IA: solo conteo. Alimenta el encabezado del informe local.
function Get-GenerarResumen {
  param([object[]]$Equipos)
  $dist = [ordered]@{ 'Ok'=0; 'Advertencia'=0; 'Error'=0; 'Crítico'=0; 'N/A'=0 }
  $conProblemas = 0
  foreach ($eq in $Equipos) {
    $tieneProblema = $false
    foreach ($ch in @($eq.checks)) {
      $est = [string]$ch.estado
      switch ($est) {
        'Ok'          { $dist['Ok']++ }
        'Advertencia' { $dist['Advertencia']++; $tieneProblema = $true }
        'Error'       { $dist['Error']++; $tieneProblema = $true }
        'Crítico'     { $dist['Crítico']++; $tieneProblema = $true }
        'Critico'     { $dist['Crítico']++; $tieneProblema = $true }
        default       { $dist['N/A']++ }
      }
    }
    if ($tieneProblema) { $conProblemas++ }
  }
  [pscustomobject]@{
    totalEquipos = @($Equipos).Count
    conProblemas = $conProblemas
    dist         = $dist
  }
}

# Estado general (peor) de un equipo, mirando todos sus checks. Orden de severidad:
# Critico > Error > Advertencia > Ok. N/A no cuenta como problema.
function Get-GenerarEstadoEquipo {
  param($Eq)
  $sev = @{ 'Crítico'=4; 'Critico'=4; 'Error'=3; 'Advertencia'=2; 'Ok'=1 }
  $peor = 'Ok'; $peorN = 0
  foreach ($ch in @($Eq.checks)) {
    $est = [string]$ch.estado
    if ($sev.ContainsKey($est) -and $sev[$est] -gt $peorN) {
      $peorN = $sev[$est]
      $peor = if ($est -eq 'Critico') { 'Crítico' } else { $est }
    }
  }
  $peor
}

# Agrupa equipos de servidores en arbol VM -> host fisico. Devuelve una lista ordenada de nodos
# raiz; cada host fisico (hypervHost) es padre y las VMs (esVm) cuelgan indentadas. Mapeo: no hay
# link directo VM->host en el JSON. Heuristica: si hay un solo host fisico, todas las VMs cuelgan de
# el; si hay varios, las VMs van al primer host fisico (best-effort) y se marca limitacion. Equipos
# que no son ni host ni VM (fisicos sueltos) quedan como nodos raiz sin hijos.
function Get-GenerarArbolServidores {
  param([object[]]$Equipos)
  $hosts = @($Equipos | Where-Object { $_.hypervHost })
  $vms   = @($Equipos | Where-Object { $_.esVm -and -not $_.hypervHost })
  $sueltos = @($Equipos | Where-Object { -not $_.hypervHost -and -not $_.esVm })
  $nodos = New-Object System.Collections.ArrayList
  # Hosts fisicos primero, cada uno con sus VMs colgando (best-effort al primer host si hay varios).
  for ($i = 0; $i -lt $hosts.Count; $i++) {
    $hijos = if ($i -eq 0) { $vms } else { @() }
    [void]$nodos.Add([pscustomobject]@{ equipo = $hosts[$i]; rol = 'host'; hijos = @($hijos) })
  }
  # Si hay VMs pero ningun host fisico relevado, mostrarlas como raices huerfanas (sin padre).
  if ($hosts.Count -eq 0) {
    foreach ($vm in $vms) {
      [void]$nodos.Add([pscustomobject]@{ equipo = $vm; rol = 'vm-huerfana'; hijos = @() })
    }
  }
  foreach ($s in $sueltos) {
    [void]$nodos.Add([pscustomobject]@{ equipo = $s; rol = 'fisico'; hijos = @() })
  }
  @($nodos)
}

# Escape HTML. Reusa ConvertTo-HtmlSafe del core si esta; fallback local minimo.
function Get-GenerarHtmlSafe {
  param([string]$S)
  if (Get-Command ConvertTo-HtmlSafe -ErrorAction SilentlyContinue) { return (ConvertTo-HtmlSafe $S) }
  if ($null -eq $S) { return '' }
  $S.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

# Devuelve el estado de un check (por key) en un item de equipo, o '' si no esta.
function Get-EstadoCheck {
  param($Item, [string]$Key)
  $c = @($Item.checks | Where-Object { $_.key -eq $Key })
  if ($c.Count -gt 0) {
    $val = $c[0].estado
    if ([string]::IsNullOrWhiteSpace($val)) { $val = $c[0].status }
    if ($val) { return [string]$val }
  }
  ''
}

# Bloque <head> compartido (fuentes Google + tokens de marca + reset). Las dos planillas y el
# informe local cuelgan del mismo head para ser consistentes entre si (mismo verde, misma fuente).
function Get-GenerarHtmlHead {
  param([string]$Title)
  @"
<!DOCTYPE html><html lang='es'><head><meta charset='utf-8'><title>$Title</title>
<link rel='preconnect' href='https://fonts.googleapis.com'><link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>
<link href='https://fonts.googleapis.com/css2?family=Audiowide&family=Space+Grotesk:wght@300;400;500;600;700;800&family=DM+Mono:wght@400;500&display=swap' rel='stylesheet'>
"@
}

# Logo isologo STI inline (monitor + check, paths canonicos de la guia interna de marca). $H = alto en px.
# Sobre fondo oscuro: stroke verde. Es el mismo SVG que usan los demas informes.
function Get-GenerarLogoSvg {
  param([int]$H = 34)
  @"
<svg width='$H' height='$H' viewBox='0 0 100 100' xmlns='http://www.w3.org/2000/svg'>
<path d='M14 20 H86 A6 6 0 0 1 92 26 V64 A6 6 0 0 1 86 70 H14 A6 6 0 0 1 8 64 V26 A6 6 0 0 1 14 20Z M42 82 H58 M50 70 V82' fill='none' stroke='#43C961' stroke-width='6' stroke-linejoin='round'/>
<path d='M28 46 L44 62 L74 30' fill='none' stroke='#43C961' stroke-width='6' stroke-linecap='round' stroke-linejoin='round'/>
</svg>
"@
}

# Banner STI superior (logo + STI MANTENIMIENTO + subtitulo de la pieza). Consistente en las 3 salidas.
function Get-GenerarBanner {
  param([string]$Subtitulo)
  $svg = Get-GenerarLogoSvg -H 38
  @"
<div class='banner'>
  <div class='banner-logo'>$svg<div class='wordmark'><span class='wm-a'>STI</span><span class='wm-b'>MANTENIMIENTO</span></div></div>
  <div class='banner-sub'>$Subtitulo</div>
</div>
"@
}

# CSS base de marca compartido por las 3 salidas: tokens, banner, header de datos, semaforo, firmas.
# Tamanos pensados para impresion (legibles, no diminutos). Print-first.
function Get-GenerarBaseCss {
  @"
 :root{--verde:#43C961;--verde-med:#2B9C70;--verde-deep:#053028;--negro:#111111;--rojo:#F05754;--naranja:#E07820;--amarillo:#F2C03D;--gris:#717171;--borde:#c9d6ce;
   --font-main:'Space Grotesk','Helvetica Neue',Arial,sans-serif;--font-mono:'DM Mono',Consolas,monospace;}
 *,*::before,*::after{box-sizing:border-box;}
 body{font-family:var(--font-main);color:#16261e;margin:0;background:#fff;}
 .banner{background:var(--verde-deep);color:#fff;padding:14px 22px;border-bottom:4px solid var(--verde);display:flex;align-items:center;justify-content:space-between;}
 .banner-logo{display:flex;align-items:center;gap:13px;}
 .wordmark{display:flex;flex-direction:column;line-height:.9;}
 .wm-a{font-family:'Audiowide',sans-serif;font-size:22px;color:#fff;letter-spacing:1px;}
 .wm-b{font-family:'Audiowide',sans-serif;font-size:10px;color:var(--verde);letter-spacing:.42em;margin-top:3px;}
 .banner-sub{font-size:12px;color:#9fdcc0;text-transform:uppercase;letter-spacing:.16em;font-weight:600;}
 .hdr{display:flex;flex-wrap:wrap;gap:10px 30px;padding:14px 22px;background:#f1f6f3;border-bottom:1px solid var(--borde);font-size:14px;}
 .hdr .f{display:flex;align-items:baseline;gap:7px;}
 .hdr b{color:var(--verde-deep);font-weight:700;text-transform:uppercase;font-size:11px;letter-spacing:.06em;}
 .hdr .v{font-weight:600;color:#16261e;}
 .hdr .edit{border-bottom:1.5px dashed var(--verde-med);min-width:140px;padding:1px 4px;background:rgba(67,201,97,.06);border-radius:3px;outline:none;}
 .firmas{display:flex;gap:50px;margin:34px 22px 18px;page-break-inside:avoid;}
 .firma-box{flex:1;}
 .firma-line{border-bottom:1.5px solid #16261e;height:46px;}
 .firma-lbl{margin-top:7px;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:var(--verde-deep);}
 .firma-sub{font-size:10px;color:var(--gris);}
 .doc{display:flex;flex-direction:column;min-height:100vh;}
 .doc-body{flex:1 0 auto;}
 .footer{flex-shrink:0;margin-top:auto;padding:11px 22px;border-top:1px solid var(--borde);background:#f1f6f3;font-size:10px;color:var(--gris);display:flex;justify-content:space-between;gap:18px;}
 .footer b{color:var(--verde-deep);}
 @media print{.footer{position:fixed;bottom:0;left:0;right:0;background:#fff;}}
"@
}

# Planilla print-first: banner STI + header una vez (con tecnico editable) + grilla equipos x checks
# (estado semaforo). Una grilla por tipo (en both, dos tablas). Orden de columnas = Get-ChkOrder.
# Terminales: 2 firmas al final, fila por equipo coloreada por fisico/VM, A4 landscape.
# Servidores: SIN firmas, A4 portrait. Columnas Obs/Detalle editables (contenteditable).
function New-PlanillaHtml {
  param([object[]]$Items, [string]$Cliente, [string]$Periodo, [string]$Seg = 'term', [string]$Tecnico)
  $vocab = Get-GenerarVocab -Seg $Seg
  $per = Resolve-PeriodoGenerar -Texto $Periodo
  $cli = Get-GenerarHtmlSafe $Cliente
  $fecha = Get-Date -Format 'dd/MM/yyyy'
  # Si no se paso tecnico, tomar el primero que venga en los JSON (meta.tecnico).
  if ([string]::IsNullOrWhiteSpace($Tecnico)) {
    $tj = @($Items | Where-Object { $_.ok -and $_.tecnico }) | Select-Object -First 1
    if ($tj) { $Tecnico = [string]$tj.tecnico }
  }
  $tec = Get-GenerarHtmlSafe $Tecnico
  # Orientacion de pagina: terminales apaisado (muchas columnas), servidores vertical.
  # Solo cuentan los tipos del vocab seleccionado (en 'srv' no mirar terminales ajenos).
  $hayTerminales = ($vocab -contains 'terminales') -and (@($Items | Where-Object { $_.ok -and $_.tipo -eq 'terminales' }).Count -gt 0)
  $orient = if ($hayTerminales) { 'landscape' } else { 'portrait' }
  $conFirmas = $hayTerminales   # firmas solo cuando hay terminales; servidores nunca lleva
  $tablas = ''
  foreach ($tipo in $vocab) {
    $equipos = @($Items | Where-Object { $_.ok -and $_.tipo -eq $tipo })
    if ($equipos.Count -eq 0) { continue }
    $orden = Get-ChkOrder -Tipo $tipo
    if ($tipo -eq 'servidores') {
      # Formato vertical real: un bloque por servidor, tabla 3 columnas
      # (Mantenimiento | Estado | Observaciones), una fila por check (checks hacia abajo).
      # Un bloque por servidor (flat, sin arbol/indentacion). Se mantiene el color por tipo
      # (fisico/VM) y el header centrado. SIN columna Usuario (cuentas de servicio no interesan).
      $tablas += "<h3>MANTENIMIENTO DE SERVIDORES</h3>"
      $tablas += "<div class='srv-blocks'>"
      $renderSrv = {
        param($eq)
        $cls = if ($eq.esVm) { 'vm' } else { 'fisico' }
        $marca = if ($eq.esVm) { "<span class='tag-vm'>VM</span>" } else { "<span class='tag-fis'>FÍSICO</span>" }
        $filas = ''
        foreach ($ch in $orden) {
          $est = Get-EstadoCheck -Item $eq -Key $ch.key
          $cell = Get-GenerarEstadoCell -Estado $est
          $filas += "<tr><td class='mnt'>$(Get-GenerarHtmlSafe $ch.label)</td>$cell<td class='obs' contenteditable='true'></td></tr>"
        }
        @"
<section class='srv-card $cls'>
 <div class='srv-hdr'><span class='srv-host'>$(Get-GenerarHtmlSafe $eq.hostname)</span>$marca</div>
 <table class='srv-grid'><thead><tr><th class='mnt'>Mantenimiento</th><th class='est'>Estado</th><th class='obs'>Observaciones</th></tr></thead><tbody>$filas</tbody></table>
</section>
"@
      }
      foreach ($eq in $equipos) {
        $tablas += (& $renderSrv $eq)
      }
      $tablas += "</div>"
      continue
    }
    # Terminales: grilla equipos x checks (apaisada). Columna Usuario junto a Equipo.
    # Celdas de estado con label + color.
    $thead = "<th class='eq'>Equipo</th><th class='usr'>Usuario</th>"
    foreach ($ch in $orden) { $thead += "<th class='vchk'><span>$(Get-GenerarHtmlSafe $ch.label)</span></th>" }
    $thead += "<th class='obs'>Obs.</th>"
    $rows = ''
    foreach ($eq in $equipos) {
      $cls = if ($eq.esVm) { 'vm' } else { 'fisico' }
      $marca = if ($eq.esVm) { "<span class='tag-vm'>VM</span>" } else { "<span class='tag-fis'>FÍSICO</span>" }
      $usr = if ($eq.usuario) { Get-GenerarHtmlSafe $eq.usuario } else { '' }
      $rows += "<tr class='$cls'><td class='eq'>$(Get-GenerarHtmlSafe $eq.hostname) $marca</td><td class='usr'>$usr</td>"
      foreach ($ch in $orden) {
        $est = Get-EstadoCheck -Item $eq -Key $ch.key
        $rows += Get-GenerarEstadoCellAbbr -Estado $est
      }
      $rows += "<td class='obs' contenteditable='true'></td></tr>"
    }
    $tablas += @"
<h3>MANTENIMIENTO DE TERMINALES</h3>
<table class='grid'><thead><tr>$thead</tr></thead><tbody>$rows</tbody></table>
"@
  }
  $firmas = ''
  if ($conFirmas) {
    $firmas = @"
<div class='firmas'>
  <div class='firma-box'><div class='firma-line'></div><div class='firma-lbl'>Técnico</div><div class='firma-sub'>STI Mantenimiento · firma y aclaración</div></div>
  <div class='firma-box'><div class='firma-line'></div><div class='firma-lbl'>Referente</div><div class='firma-sub'>Cliente · firma y aclaración</div></div>
</div>
"@
  }
  $banner = Get-GenerarBanner -Subtitulo 'Planilla de mantenimiento'
  $head = Get-GenerarHtmlHead -Title "Planilla de mantenimiento - $cli"
  $base = Get-GenerarBaseCss
  @"
$head<style>
 @page{size:A4 $orient;margin:9mm;}
$base
 .wrap{padding:0 22px 8px;}
 h3{font-size:15px;color:var(--verde-deep);margin:18px 0 8px;text-transform:uppercase;letter-spacing:.05em;border-left:4px solid var(--verde);padding-left:9px;}
 table.grid{border-collapse:collapse;width:100%;table-layout:fixed;font-size:11px;}
 table.grid th,table.grid td{border:1px solid var(--borde);}
 table.grid thead th{background:var(--verde-deep);color:#fff;font-weight:700;text-align:center;vertical-align:bottom;padding:4px 2px;}
 th.vchk{height:118px;width:30px;}
 th.vchk span{writing-mode:vertical-rl;transform:rotate(180deg);white-space:nowrap;font-size:11px;font-weight:700;}
 th.eq{width:140px;text-align:left;vertical-align:middle;padding:6px 8px;font-size:12px;}
 th.usr{width:96px;text-align:left;vertical-align:middle;padding:6px 8px;font-size:12px;}
 th.obs{width:110px;vertical-align:middle;}
 td.eq{text-align:left;font-weight:700;padding:6px 8px;font-size:11.5px;}
 td.usr{text-align:left;padding:6px 8px;font-size:11px;color:#16261e;}
 td.st{height:24px;padding:2px 1px;text-align:center;font-size:9.5px;font-weight:700;line-height:1.05;}
 td.st.na{background:#eef1ef;color:var(--gris);font-weight:600;}
 td.obs{background:rgba(67,201,97,.05);outline:none;}
 tr.fisico td.eq,tr.fisico td.usr{background:#e4f6ea;}
 tr.vm td.eq,tr.vm td.usr{background:#e0edfb;}
 .srv-blocks{display:flex;flex-direction:column;gap:14px;margin-top:6px;}
 .srv-card{page-break-inside:avoid;border:1px solid var(--borde);border-radius:8px;overflow:hidden;}
 .srv-card.fisico{border-left:5px solid var(--verde);}
 .srv-card.vm{border-left:5px solid #2f6bbf;}
 .srv-hdr{padding:10px 13px;display:flex;align-items:center;justify-content:center;gap:9px;border-bottom:1px solid var(--borde);}
 .srv-card.fisico .srv-hdr{background:#dff3e6;}
 .srv-card.vm .srv-hdr{background:#dce9fb;}
 .srv-host{font-size:15px;font-weight:700;color:var(--verde-deep);letter-spacing:.02em;}
 table.srv-grid{border-collapse:collapse;width:100%;table-layout:fixed;font-size:12px;}
 table.srv-grid th,table.srv-grid td{border:1px solid var(--borde);}
 table.srv-grid thead th{background:var(--verde-deep);color:#fff;font-weight:700;text-align:center;padding:7px 9px;font-size:12px;text-transform:uppercase;letter-spacing:.04em;}
 th.mnt,td.mnt{width:34%;text-align:left;}
 th.est{width:16%;}
 th.obs{width:50%;}
 td.mnt{font-weight:600;padding:6px 10px;}
 table.srv-grid td.st{text-align:center;white-space:nowrap;font-size:11px;}
 table.srv-grid td.obs{background:rgba(67,201,97,.05);padding:6px 10px;}
 .tag-fis{font-size:8px;font-weight:700;color:var(--verde-med);background:rgba(67,201,97,.16);padding:1px 5px;border-radius:8px;vertical-align:middle;}
 .tag-vm{font-size:8px;font-weight:700;color:#2f6bbf;background:rgba(47,107,191,.16);padding:1px 5px;border-radius:8px;vertical-align:middle;}
</style></head><body>
<div class='doc'>
<div class='doc-body'>
$banner
<div class='hdr'>
 <div class='f'><b>Cliente</b><span class='v'>$cli</span></div>
 <div class='f'><b>Período</b><span class='v'>$(Get-GenerarHtmlSafe $per.label)</span></div>
 <div class='f'><b>Técnico</b><span class='v edit' contenteditable='true'>$tec</span></div>
 <div class='f'><b>Fecha</b><span class='v'>$fecha</span></div>
</div>
<div class='wrap'>
$tablas
$firmas
</div>
</div>
<div class='footer'><span><b>STI Mantenimiento</b> &nbsp;·&nbsp; Soluciones IT de confianza</span><span>Las columnas Obs. y el campo Técnico son editables en pantalla antes de imprimir.</span></div>
</div>
</body></html>
"@
}

# Informe local de hallazgos: reporte deterministico (sin IA). Arriba un resumen ejecutivo (total
# de equipos, distribucion de estados sumando todos los checks, equipos con problemas). Por equipo
# muestra SOLO lo relevante: estado general + los checks que NO estan Ok con su detalle. Es un
# informe de hallazgos, distinto de la planilla (checklist completo para firmar). Lleva la leyenda
# de que NO es el informe oficial mensual del cliente. Print A4 portrait.
function New-InformeLocalHtml {
  param([object[]]$Items, [string]$Cliente, [string]$Periodo, [string]$Seg = 'term', [string]$Tecnico)
  $vocab = Get-GenerarVocab -Seg $Seg
  $per = Resolve-PeriodoGenerar -Texto $Periodo
  $cli = Get-GenerarHtmlSafe $Cliente
  $fecha = Get-Date -Format 'dd/MM/yyyy HH:mm'
  if ([string]::IsNullOrWhiteSpace($Tecnico)) {
    $tj = @($Items | Where-Object { $_.ok -and $_.tecnico }) | Select-Object -First 1
    if ($tj) { $Tecnico = [string]$tj.tecnico }
  }
  $tec = Get-GenerarHtmlSafe $Tecnico
  $equipos = @($Items | Where-Object { $_.ok -and ($vocab -contains $_.tipo) })
  $resumen = Get-GenerarResumen -Equipos $equipos

  # Tarjetas del resumen: una por estado, con su conteo y color de semaforo.
  $cards = ''
  foreach ($est in @('Ok','Advertencia','Error','Crítico','N/A')) {
    $n = $resumen.dist[$est]
    $abbr = if ($est -eq 'N/A') { 'N/A' } else { $est }
    if ($est -eq 'N/A') {
      $cards += "<div class='kpi kpi-na'><div class='kpi-n'>$n</div><div class='kpi-l'>$abbr</div></div>"
    } else {
      $bg = Get-GenerarSemColor $est
      $fg = Get-GenerarSemTextColor $est
      $cards += "<div class='kpi' style='background:$bg;color:$fg'><div class='kpi-n'>$n</div><div class='kpi-l'>$(Get-GenerarHtmlSafe $abbr)</div></div>"
    }
  }
  $okEquipos = $resumen.totalEquipos - $resumen.conProblemas

  # Secciones por equipo: solo checks no-Ok. Equipos sin hallazgos se listan compactos al final.
  $secs = ''
  $limpios = @()
  foreach ($eq in $equipos) {
    $estadoGen = Get-GenerarEstadoEquipo -Eq $eq
    $hallazgos = @($eq.checks | Where-Object {
      $e = [string]$_.estado
      $e -ne 'Ok' -and -not [string]::IsNullOrWhiteSpace($e)
    })
    $cls = if ($eq.esVm) { 'vm' } else { 'fisico' }
    $tipoLbl = if ($eq.tipo -eq 'servidores') { 'Servidor' } else { 'Terminal' }
    $marca = if ($eq.esVm) { "<span class='tag-vm'>VM</span>" } else { "<span class='tag-fis'>FÍSICO</span>" }
    if ($hallazgos.Count -eq 0) {
      $limpios += $eq.hostname
      continue
    }
    $genBg = Get-GenerarSemColor $estadoGen
    $genFg = Get-GenerarSemTextColor $estadoGen
    $badge = "<span class='gen' style='background:$genBg;color:$genFg'>$(Get-GenerarHtmlSafe $estadoGen)</span>"
    $filas = ''
    foreach ($ch in $hallazgos) {
      $cell = Get-GenerarEstadoCell -Estado ([string]$ch.estado)
      $det = Get-GenerarHtmlSafe ([string]$ch.detalle)
      $filas += "<tr><td class='item'>$(Get-GenerarHtmlSafe ([string]$ch.label))</td>$cell<td class='det'>$det</td></tr>"
    }
    $secs += @"
<section class='$cls'>
 <h3><span class='hn'>$(Get-GenerarHtmlSafe $eq.hostname)</span> <span class='tipo'>$tipoLbl</span> $marca $badge <span class='cnt'>$($hallazgos.Count) hallazgo(s)</span></h3>
 <table><thead><tr><th class='item'>Ítem</th><th class='est'>Estado</th><th class='det'>Detalle</th></tr></thead><tbody>$filas</tbody></table>
</section>
"@
  }
  $limpiosBlock = ''
  if ($limpios.Count -gt 0) {
    $chips = (@($limpios) | ForEach-Object { "<span class='ok-chip'>$(Get-GenerarHtmlSafe $_)</span>" }) -join ''
    $limpiosBlock = @"
<section class='limpios'>
 <h3>Sin hallazgos <span class='tipo'>$($limpios.Count) equipo(s) con todos los checks en Ok</span></h3>
 <div class='ok-chips'>$chips</div>
</section>
"@
  }
  if ([string]::IsNullOrWhiteSpace($secs) -and $limpios.Count -eq 0) {
    $secs = "<section><p class='vacio'>Sin equipos en el alcance seleccionado.</p></section>"
  }

  $banner = Get-GenerarBanner -Subtitulo 'Informe local de hallazgos'
  $head = Get-GenerarHtmlHead -Title "Informe local - $cli"
  $base = Get-GenerarBaseCss
  $tecHdr = if ($tec) { "<div class='f'><b>Técnico</b><span class='v'>$tec</span></div>" } else { '' }
  @"
$head<style>
 @page{size:A4 portrait;margin:11mm;}
$base
 .meta{padding:13px 22px;background:#f1f6f3;border-bottom:1px solid var(--borde);font-size:14px;display:flex;flex-wrap:wrap;gap:8px 28px;}
 .meta .f{display:flex;align-items:baseline;gap:7px;}
 .meta b{color:var(--verde-deep);font-weight:700;text-transform:uppercase;font-size:11px;letter-spacing:.06em;}
 .meta .v{font-weight:600;}
 .resumen{margin:18px 22px 6px;page-break-inside:avoid;}
 .resumen h2{font-size:15px;color:var(--verde-deep);margin:0 0 11px;text-transform:uppercase;letter-spacing:.05em;border-left:4px solid var(--verde);padding-left:9px;}
 .res-top{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:12px;}
 .stat{flex:1;min-width:120px;border:1px solid var(--borde);border-radius:9px;padding:11px 14px;background:#f7faf8;}
 .stat .sn{font-size:26px;font-weight:800;color:var(--verde-deep);line-height:1;}
 .stat .sl{font-size:11px;color:var(--gris);text-transform:uppercase;letter-spacing:.06em;margin-top:5px;font-weight:600;}
 .stat.warn .sn{color:var(--naranja);}
 .kpis{display:flex;gap:8px;flex-wrap:wrap;}
 .kpi{flex:1;min-width:78px;border-radius:8px;padding:9px 6px;text-align:center;}
 .kpi-na{background:#eef1ef;color:var(--gris);}
 .kpi-n{font-size:22px;font-weight:800;line-height:1;}
 .kpi-l{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;margin-top:4px;}
 section{margin:16px 22px;page-break-inside:avoid;}
 h3{font-size:15px;color:var(--verde-deep);margin:0 0 9px;display:flex;align-items:center;gap:9px;flex-wrap:wrap;}
 h3 .hn{font-weight:700;}
 h3 .tipo{font-size:12px;color:var(--gris);font-weight:500;}
 h3 .cnt{font-size:11px;color:var(--naranja);font-weight:600;}
 .gen{font-size:11px;font-weight:700;padding:2px 9px;border-radius:9px;}
 section.fisico h3{border-left:5px solid var(--verde);padding-left:10px;}
 section.vm h3{border-left:5px solid #2f6bbf;padding-left:10px;}
 section.limpios h3{border-left:5px solid var(--verde-med);padding-left:10px;}
 .tag-fis{font-size:9px;font-weight:700;color:var(--verde-med);background:rgba(67,201,97,.16);padding:2px 7px;border-radius:9px;}
 .tag-vm{font-size:9px;font-weight:700;color:#2f6bbf;background:rgba(47,107,191,.16);padding:2px 7px;border-radius:9px;}
 table{border-collapse:collapse;width:100%;font-size:13px;table-layout:fixed;}
 thead th{background:var(--verde-deep);color:#fff;font-weight:700;text-align:center;padding:8px 10px;font-size:12px;text-transform:uppercase;letter-spacing:.04em;}
 th.item,td.item{width:32%;text-align:left;}
 th.est{width:14%;}
 th.det,td.det{width:54%;text-align:left;}
 td{border:1px solid var(--borde);padding:7px 10px;vertical-align:top;}
 td.item{font-weight:600;}
 td.st{font-weight:700;text-align:center;white-space:nowrap;}
 td.st.na{background:#eef1ef;color:var(--gris);font-weight:600;}
 td.det{color:#2a3a33;}
 .ok-chips{display:flex;flex-wrap:wrap;gap:6px;}
 .ok-chip{font-size:11px;font-weight:600;color:var(--verde-med);background:rgba(67,201,97,.12);border:1px solid rgba(67,201,97,.3);padding:3px 9px;border-radius:9px;}
 .vacio{color:var(--gris);font-size:13px;}
</style></head><body>
<div class='doc'>
<div class='doc-body'>
$banner
<div class='meta'>
 <div class='f'><b>Cliente</b><span class='v'>$cli</span></div>
 <div class='f'><b>Período</b><span class='v'>$(Get-GenerarHtmlSafe $per.label)</span></div>
 $tecHdr
 <div class='f'><b>Generado</b><span class='v'>$fecha</span></div>
</div>
<div class='resumen'>
 <h2>Resumen ejecutivo</h2>
 <div class='res-top'>
  <div class='stat'><div class='sn'>$($resumen.totalEquipos)</div><div class='sl'>Equipos relevados</div></div>
  <div class='stat warn'><div class='sn'>$($resumen.conProblemas)</div><div class='sl'>Con hallazgos</div></div>
  <div class='stat'><div class='sn'>$okEquipos</div><div class='sl'>Sin hallazgos</div></div>
 </div>
 <div class='kpis'>$cards</div>
</div>
$secs
$limpiosBlock
</div>
<div class='footer'><span><b>STI Mantenimiento</b> &nbsp;·&nbsp; Informe local de hallazgos (no es el informe oficial mensual del cliente).</span><span>Resumen deterministico del relevamiento. Por equipo se listan solo los checks fuera de Ok.</span></div>
</div>
</body></html>
"@
}

# Escribe un HTML a disco (UTF-8) y devuelve la ruta. Efecto; en tests usar un temp dir.
function Save-GenerarHtml {
  param([string]$Html, [string]$Carpeta, [string]$Nombre)
  if (-not (Test-Path -LiteralPath $Carpeta)) { New-Item -ItemType Directory -Path $Carpeta -Force | Out-Null }
  $out = Join-Path $Carpeta $Nombre
  [IO.File]::WriteAllText($out, $Html, (New-Object System.Text.UTF8Encoding($false)))
  $out
}

# XAML del panel Generar (reemplaza el placeholder en gui-xaml.ps1). Solo brushes/estilos de
# New-StiTheme. Los chips de equipo del bloque .detected se pueblan en runtime (Update-GenerarPanel).
function New-PanelGenerarXaml {
  @'
<ScrollViewer x:Name="PanelGenerar" Visibility="Collapsed" VerticalScrollBarVisibility="Auto">
  <StackPanel>
    <TextBlock Style="{StaticResource StiSecHeader}" Text="PASO FINAL · CONSOLIDAR RELEVAMIENTO"/>
    <TextBlock Foreground="{StaticResource StiTexto2}" FontSize="11.5" TextWrapping="Wrap" Margin="0,0,0,4"
               Text="Apuntá a la carpeta con los JSON de todos los equipos. Reviso qué hay (terminales y servidores) y genero la planilla y el informe local del período."/>

    <Border Margin="0,8,0,0" Padding="13,11" CornerRadius="9"
            Background="{StaticResource StiCard}" BorderBrush="{StaticResource StiBorde}" BorderThickness="1">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="14"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="10"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="3">
          <TextBlock Style="{StaticResource StiLabel}" Text="CARPETA DE JSONS"/>
          <StackPanel Orientation="Horizontal">
            <TextBox x:Name="TxtGenCarpeta" Style="{StaticResource StiInputMono}" Width="380"/>
            <Button x:Name="BtnGenExaminar" Content="Examinar…" Margin="6,0,0,0" Padding="11,4"/>
          </StackPanel>
        </StackPanel>

        <StackPanel Grid.Row="2" Grid.Column="0">
          <TextBlock Style="{StaticResource StiLabel}" Text="EMPRESA / CLIENTE"/>
          <TextBox x:Name="TxtGenCliente" Style="{StaticResource StiInputBox}"/>
        </StackPanel>
        <StackPanel Grid.Row="2" Grid.Column="2">
          <TextBlock Style="{StaticResource StiLabel}" Text="PERÍODO"/>
          <TextBox x:Name="TxtGenPeriodo" Style="{StaticResource StiInputBox}"/>
        </StackPanel>
      </Grid>
    </Border>

    <StackPanel Orientation="Horizontal" Margin="2,12,0,6">
      <TextBlock Style="{StaticResource StiLabel}" VerticalAlignment="Center" Margin="0,0,10,0" Text="ALCANCE"/>
      <RadioButton x:Name="ChipGenTerm"  Style="{StaticResource StiChip}" Content="Terminales" IsChecked="True" GroupName="gentipo"/>
      <RadioButton x:Name="ChipGenSrv"   Style="{StaticResource StiChip}" Content="Servidores" GroupName="gentipo"/>
      <RadioButton x:Name="ChipGenBoth"  Style="{StaticResource StiChip}" Content="Ambos" GroupName="gentipo"/>
    </StackPanel>

    <Border Padding="0" CornerRadius="9" ClipToBounds="True"
            Background="{StaticResource StiCard}" BorderBrush="{StaticResource StiBorde}" BorderThickness="1">
      <StackPanel>
        <Border Background="{StaticResource StiChipBar}" Padding="13,10" BorderBrush="{StaticResource StiBordeSutil}" BorderThickness="0,0,0,1">
          <StackPanel Orientation="Horizontal">
            <Path Width="17" Height="17" Stretch="Uniform" VerticalAlignment="Center" Margin="0,0,9,0"
                  Stroke="{StaticResource StiVerde}" StrokeThickness="1.8" Fill="Transparent"
                  Data="M3 7 A2 2 0 0 1 5 5 L9 5 L11 7 L19 7 A2 2 0 0 1 21 9 L21 17 A2 2 0 0 1 19 19 L5 19 A2 2 0 0 1 3 17 Z"/>
            <TextBlock x:Name="TxtGenConteo" Foreground="{StaticResource StiTexto}" FontWeight="700" FontSize="13" VerticalAlignment="Center" Text="0 JSONs"/>
            <TextBlock Foreground="{StaticResource StiTexto2}" FontSize="12" VerticalAlignment="Center" Margin="6,0,0,0" Text="que voy a consolidar"/>
            <TextBlock x:Name="TxtGenPill" Foreground="{StaticResource StiVerdeClaro}" FontFamily="DM Mono, Consolas" FontSize="10.5" VerticalAlignment="Center" Margin="14,0,0,0" Text=""/>
          </StackPanel>
        </Border>
        <StackPanel Margin="13,11,13,12">
          <WrapPanel x:Name="PanelGenEquipos"/>
          <TextBlock x:Name="TxtGenVacio" Foreground="{StaticResource StiTexto3}" FontSize="11.5" Text="Elegí una carpeta para ver los equipos detectados."/>
          <TextBlock x:Name="TxtGenInvalidos" Foreground="{StaticResource StiNaranja}" FontFamily="DM Mono, Consolas" FontSize="10" Margin="0,8,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
        </StackPanel>
      </StackPanel>
    </Border>

    <TextBlock Style="{StaticResource StiSecHeader}" Text="GENERAR SALIDAS"/>
    <UniformGrid Columns="2">
      <Border Margin="0,0,6,0" Padding="15" CornerRadius="9"
              Background="{StaticResource StiCard}" BorderBrush="{StaticResource StiBorde}" BorderThickness="1">
        <StackPanel>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
            <Border Width="30" Height="30" CornerRadius="7" Margin="0,0,9,0"
                    Background="{StaticResource StiInput}" BorderBrush="{StaticResource StiBorde}" BorderThickness="1">
              <Path Width="16" Height="16" Stretch="Uniform" Stroke="{StaticResource StiVerde}" StrokeThickness="1.8" Fill="Transparent"
                    Data="M3 3 L21 3 L21 21 L3 21 Z M3 9 L21 9 M9 3 L9 21"/>
            </Border>
            <TextBlock Foreground="White" FontWeight="700" FontSize="13.5" VerticalAlignment="Center" Text="Planilla de mantenimiento"/>
          </StackPanel>
          <TextBlock Foreground="{StaticResource StiTexto2}" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,11"
                     Text="Grilla de equipos por checks, formato print-first para imprimir y firmar. Misma estructura que la planilla manual."/>
          <Button x:Name="BtnGenPlanilla" Style="{StaticResource StiBtnPrimary}" Content="Generar planilla"/>
        </StackPanel>
      </Border>
      <Border Margin="6,0,0,0" Padding="15" CornerRadius="9"
              Background="{StaticResource StiCard}" BorderBrush="{StaticResource StiBorde}" BorderThickness="1">
        <StackPanel>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,7">
            <Border Width="30" Height="30" CornerRadius="7" Margin="0,0,9,0"
                    Background="{StaticResource StiInput}" BorderBrush="{StaticResource StiBorde}" BorderThickness="1">
              <Path Width="16" Height="16" Stretch="Uniform" Stroke="{StaticResource StiVerdeClaro}" StrokeThickness="1.8" Fill="Transparent"
                    Data="M5 3 L19 3 L19 21 L5 21 Z M9 8 L15 8 M9 12 L15 12 M9 16 L13 16"/>
            </Border>
            <TextBlock Foreground="White" FontWeight="700" FontSize="13.5" VerticalAlignment="Center" Text="Informe local"/>
          </StackPanel>
          <TextBlock Foreground="{StaticResource StiTexto2}" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,11"
                     Text="HTML consolidado de hallazgos del relevamiento. No es el informe oficial mensual del cliente."/>
          <Button x:Name="BtnGenInforme" Content="Generar informe" Padding="10,8" BorderThickness="1"
                  Background="{StaticResource StiCard}" BorderBrush="{StaticResource StiVerde}" Foreground="{StaticResource StiVerdeClaro}" FontWeight="700"/>
        </StackPanel>
      </Border>
    </UniformGrid>
  </StackPanel>
</ScrollViewer>
'@
}

# Puebla en runtime el bloque .detected (conteo, pill, chips de equipo, invalidos) desde la
# deteccion ya calculada por Resolve-DeteccionGenerar. Recibe el Window y la deteccion; no toca WMI.
function Update-GenerarPanel {
  param($Window, $Deteccion)
  $find = { param($n) $Window.FindName($n) }
  $n = [int]$Deteccion.total
  (& $find 'TxtGenConteo').Text = if ($n -eq 1) { '1 JSON' } else { "$n JSONs" }
  (& $find 'TxtGenPill').Text = [string]$Deteccion.pill
  $wrap = & $find 'PanelGenEquipos'
  $wrap.Children.Clear()
  $vacio = & $find 'TxtGenVacio'
  if ($vacio) { $vacio.Visibility = if (@($Deteccion.equipos).Count -gt 0) { 'Collapsed' } else { 'Visible' } }
  foreach ($eq in @($Deteccion.equipos)) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $b.Padding = New-Object System.Windows.Thickness(9,4,9,4)
    $b.Margin = New-Object System.Windows.Thickness(0,0,5,5)
    $b.BorderThickness = New-Object System.Windows.Thickness(1)
    if ($eq.srv) {
      $b.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#3a5a8a'))
      $fg = [System.Windows.Media.ColorConverter]::ConvertFromString('#a9c8ee')
    } else {
      $b.BorderBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#2c5240'))
      $fg = [System.Windows.Media.ColorConverter]::ConvertFromString('#cfe3d8')
    }
    $b.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#16291f'))
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = [string]$eq.hostname
    $tb.FontFamily = New-Object System.Windows.Media.FontFamily('DM Mono, Consolas')
    $tb.FontSize = 10.5
    $tb.Foreground = New-Object System.Windows.Media.SolidColorBrush ($fg)
    $b.Child = $tb
    [void]$wrap.Children.Add($b)
  }
  $inv = & $find 'TxtGenInvalidos'
  if (@($Deteccion.invalidos).Count -gt 0) {
    $inv.Text = "$(@($Deteccion.invalidos).Count) archivo(s) ignorado(s): " + ((@($Deteccion.invalidos) | ForEach-Object { "$($_.file) ($($_.error))" }) -join ', ')
    $inv.Visibility = 'Visible'
  } else {
    $inv.Visibility = 'Collapsed'
  }
}

# Devuelve el codigo del segmented (term|srv|both) segun que chip esta marcado.
function Get-GenerarSegFromWindow {
  param($Window)
  if (($Window.FindName('ChipGenSrv')).IsChecked) { return 'srv' }
  if (($Window.FindName('ChipGenBoth')).IsChecked) { return 'both' }
  'term'
}
