# lib/inventario.ps1 - RELEVAMIENTO de equipo (inventario exacto), distinto del mantenimiento.
# HW (CPU/RAM/discos+tipo), SO (versión/build/arch), software instalado (filtrado), hardware IDs.
# Salidas: <host>_RELEVAMIENTO_<fecha>.{html,json} en C:\zback (Get-MantDir).

# ---- PURAS (testeables) ----

# Tipo de disco desde MSFT_PhysicalDisk. MediaType 3=HDD 4=SSD; BusType 17=NVMe; SpindleSpeed 0=SSD.
function Get-DiskTipo {
  param($MediaType, $BusType, $SpindleSpeed)
  if ($null -ne $BusType -and [int]$BusType -eq 17) { return 'NVMe' }
  switch ([int]$MediaType) { 4 { return 'SSD' } 3 { return 'HDD' } }
  if ($null -ne $SpindleSpeed -and [int]$SpindleSpeed -eq 0) { return 'SSD' }
  '?'
}

# ¿La entrada de Uninstall es una app "real" (no update/redistributable/componente)?
function Test-AppRelevante {
  param([string]$Name, [bool]$SystemComponent, [string]$Publisher)
  if (-not $Name) { return $false }
  if ($SystemComponent) { return $false }
  $excl = @(
    '^KB\d+', 'Update for ', 'Security Update', 'Hotfix', 'Service Pack',
    'Microsoft Visual C\+\+ .*Redistributable', 'Microsoft .NET.*(Runtime|Host|Targeting|SDK)',
    'Windows .*SDK', 'Microsoft Windows Desktop Runtime', 'Microsoft ASP\.NET',
    'vcredist', 'Microsoft Visual Studio.*(Tools|Runtime)', 'Windows Software Development Kit'
  )
  foreach ($rx in $excl) { if ($Name -match $rx) { return $false } }
  $true
}

# ---- COLLECTORS (Windows-only) ----

function Get-InstalledApps {
  $paths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  $apps = [ordered]@{}
  foreach ($p in $paths) {
    Get-ItemProperty $p -ErrorAction SilentlyContinue | ForEach-Object {
      $name = [string]$_.DisplayName
      if (Test-AppRelevante -Name $name -SystemComponent ([bool]$_.SystemComponent) -Publisher ([string]$_.Publisher)) {
        $key = $name.Trim()
        if (-not $apps.Contains($key)) {
          $apps[$key] = [ordered]@{ nombre = $key; version = ([string]$_.DisplayVersion).Trim(); editor = ([string]$_.Publisher).Trim() }
        }
      }
    }
  }
  @($apps.Values | Sort-Object { $_.nombre })
}

function Get-InventarioDiscos {
  $out = @()
  try {
    $pd = Get-CimInstance -Namespace 'root/Microsoft/Windows/Storage' -ClassName MSFT_PhysicalDisk -ErrorAction Stop
    foreach ($d in $pd) {
      $out += [ordered]@{ modelo = ([string]$d.FriendlyName).Trim(); gb = [math]::Round($d.Size/1GB, 0); tipo = (Get-DiskTipo $d.MediaType $d.BusType $d.SpindleSpeed) }
    }
  } catch {
    try { foreach ($d in (Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)) { $out += [ordered]@{ modelo = ([string]$d.Model).Trim(); gb = [math]::Round($d.Size/1GB, 0); tipo = '?' } } } catch {}
  }
  $out
}

function New-InventarioModel {
  param($Ctx)
  $hw = Get-HardwareIds
  $cpu = @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue) | Select-Object -First 1
  $cs  = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
  $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
  $ramMods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)

  $soSec = [ordered]@{
    caption = ([string]$os.Caption).Trim(); version = $os.Version; build = $os.BuildNumber;
    arch = $os.OSArchitecture; instalado = $os.InstallDate; ultimoBoot = $os.LastBootUpTime
  }
  $ramTotal = [math]::Round($cs.TotalPhysicalMemory/1GB, 1)
  $discos = @(Get-InventarioDiscos)
  $discoGB = 0; try { $discoGB = (@($discos) | ForEach-Object { [double]$_.gb } | Measure-Object -Sum).Sum } catch {}

  # secciones nuevas (cada una defensiva; si falla, queda $null)
  $obsol = $null; try { $obsol = Get-InvObsolescencia -So $soSec -RamGB $ramTotal -DiscoGB $discoGB } catch {}
  $seg   = $null; try { $seg   = Get-InvSeguridad } catch {}
  $ctxI  = $null; try { $ctxI  = Get-InvContexto } catch {}
  $salud = $null; try { $salud = Get-InvSalud } catch {}

  [ordered]@{
    meta = [ordered]@{
      cliente = $Ctx.cliente; tag = $Ctx.tag; hostname = $hw.hostname; tipoRegistro = 'relevamiento';
      fecha = (Get-Date -Format 'o'); scriptVersion = $SCRIPT_VERSION; usuario = $Ctx.usuario
    }
    so = $soSec
    equipo = [ordered]@{ fabricante = ([string]$cs.Manufacturer).Trim(); modelo = ([string]$cs.Model).Trim() }
    cpu = [ordered]@{ modelo = ([string]$cpu.Name).Trim(); nucleos = $cpu.NumberOfCores; logicos = $cpu.NumberOfLogicalProcessors; mhz = $cpu.MaxClockSpeed }
    ram = [ordered]@{
      totalGB = $ramTotal
      modulos = @($ramMods | ForEach-Object { [ordered]@{ gb = [math]::Round($_.Capacity/1GB, 1); mhz = $_.Speed; slot = $_.DeviceLocator; fabricante = ([string]$_.Manufacturer).Trim() } })
    }
    discos = $discos
    obsolescencia = $obsol
    seguridad = $seg
    contexto = $ctxI
    salud = $salud
    software = (Get-InstalledApps)
    hardwareIds = [ordered]@{
      os_uuid = $hw.os_uuid; disk_serial = $hw.disk_serial; hw_uuid = $hw.hw_uuid;
      mac = @($hw.mac); bios_serial = $hw.bios_serial; hostname = $hw.hostname
    }
  }
}

function New-InventarioJson {
  param($Ctx, $Inv)
  $stamp = Get-Date -Format 'yyyyMMdd'
  $out = Join-Path (Get-MantDir) "$($Inv.meta.hostname)_RELEVAMIENTO_${stamp}.json"
  ($Inv | ConvertTo-Json -Depth 8) | Out-File -FilePath $out -Encoding UTF8
  $out
}

function New-InventarioHtml {
  param($Ctx, $Inv, [string]$LogoPath)
  $esc = { param($s) ConvertTo-HtmlSafe $s }
  $logoB64 = ''
  if ($LogoPath -and (Test-Path $LogoPath)) { try { $logoB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($LogoPath)) } catch {} }
  $logoTag = if ($logoB64) { "<img src='data:image/png;base64,$logoB64' height='40'>" } else { '' }
  $fecha = Get-Date -Format 'dd/MM/yyyy HH:mm'

  $discosRows = ($Inv.discos | ForEach-Object { "<tr><td>$(& $esc $_.modelo)</td><td>$($_.gb) GB</td><td>$($_.tipo)</td></tr>" }) -join ''
  $ramRows = ($Inv.ram.modulos | ForEach-Object { "<tr><td>$(& $esc $_.slot)</td><td>$($_.gb) GB</td><td>$($_.mhz) MHz</td><td>$(& $esc $_.fabricante)</td></tr>" }) -join ''
  $swRows = ($Inv.software | ForEach-Object { "<tr><td>$(& $esc $_.nombre)</td><td>$(& $esc $_.version)</td><td>$(& $esc $_.editor)</td></tr>" }) -join ''
  $macs = ($Inv.hardwareIds.mac -join ', ')

  # ---- secciones nuevas (defensivas) ----
  $secObsol = ''
  $o = $Inv.obsolescencia
  if ($o) {
    $eolTxt = if ($o.soFinSoporte.eol) { "$($o.soFinSoporte.etiqueta) (fin de soporte $($o.soFinSoporte.eol))" } else { $o.soFinSoporte.etiqueta }
    $biosTxt = if ($o.bios) { "$($o.bios.version) · $($o.bios.fecha)" + $(if ($o.bios.antiguedadAnios) { " (~$($o.bios.antiguedadAnios) años)" } else { '' }) } else { 's/d' }
    $tpmTxt = if ($o.tpm -and $o.tpm.presente) { "presente (v$($o.tpm.version))" } else { 'ausente' }
    $win11 = if ($o.win11Apto.apto) { 'Sí' } else { "No - falta: $($o.win11Apto.faltan -join ', ')" }
    $secObsol = "<div class='sec'>Obsolescencia / renovación</div><div class='kv'><span>Fin de soporte SO</span> $(& $esc $eolTxt)<br><span>BIOS / firmware</span> $(& $esc $biosTxt)<br><span>TPM</span> $(& $esc $tpmTxt)<br><span>Secure Boot</span> $($o.secureBoot)<br><span>Apto Windows 11</span> $(& $esc $win11)</div>"
  }

  $secRed = ''
  $cx = $Inv.contexto
  if ($cx -and @($cx.red).Count) {
    $rows = ($cx.red | ForEach-Object { "<tr><td>$(& $esc $_.adaptador)</td><td>$(& $esc $_.ip)</td><td>$(& $esc $_.gateway)</td><td>$(& $esc $_.dns)</td><td>$(& $esc $_.velocidad)</td></tr>" }) -join ''
    $domTxt = if ($cx.dominio) { if ($cx.dominio.enDominio) { "dominio $($cx.dominio.dominio)" } else { "workgroup $($cx.dominio.dominio)" } } else { '' }
    $secRed = "<div class='sec'>Red <span class='cnt'>$(& $esc $domTxt)</span></div><table><tr><th>Adaptador</th><th>IP</th><th>Gateway</th><th>DNS</th><th>Enlace</th></tr>$rows</table>"
  }

  $secPerif = ''
  if ($cx) {
    $monTxt = (@($cx.monitores) | ForEach-Object { ("{0} {1} {2}" -f $_.fabricante, $_.modelo, $_.serie).Trim() }) -join '; '
    $impTxt = (@($cx.impresoras)) -join '; '
    $gpuTxt = (@($cx.gpu)) -join '; '
    $updTxt = if ($cx.ultimoUpdate) { "$($cx.ultimoUpdate.id) ($($cx.ultimoUpdate.fecha))" } else { 's/d' }
    $esetTxt = if ($cx.eset) { "$($cx.eset.producto) v$($cx.eset.version) · firmas $($cx.eset.firmas)" } else { 'no detectado' }
    $ocsTxt = if ($cx.ocs) { "servicio $($cx.ocs.servicio)" + $(if ($cx.ocs.ultimoReporte) { " · últ $($cx.ocs.ultimoReporte)" } else { '' }) } else { 'no detectado' }
    $secPerif = "<div class='sec'>Periféricos y agentes</div><div class='kv'><span>GPU</span> $(& $esc $gpuTxt)<br><span>Monitores</span> $(& $esc $monTxt)<br><span>Impresoras</span> $(& $esc $impTxt)<br><span>Último update</span> $(& $esc $updTxt)<br><span>ESET (local)</span> $(& $esc $esetTxt)<br><span>OCS (local)</span> $(& $esc $ocsTxt)</div>"
  }

  $secSeg = ''
  $sg = $Inv.seguridad
  if ($sg) {
    $blTxt = if (@($sg.bitlocker).Count) { (@($sg.bitlocker) | ForEach-Object { "$($_.unidad) $($_.estado)" }) -join '; ' } else { 's/d' }
    $admTxt = (@($sg.adminsLocales)) -join '; '
    $secSeg = "<div class='sec'>Seguridad / hardening</div><div class='kv'><span>Cifrado (BitLocker)</span> $(& $esc $blTxt)<br><span>Admins locales</span> $(& $esc $admTxt)<br><span>UAC</span> $($sg.uacHabilitado)<br><span>SMBv1</span> $($sg.smbv1Habilitado)<br><span>TLS 1.0 / 1.1</span> $(& $esc $sg.tlsViejo.tls10) / $(& $esc $sg.tlsViejo.tls11)<br><span>Defender tamper</span> $($sg.defenderTamper)</div>"
  }

  $secSalud = ''
  $sl = $Inv.salud
  if ($sl) {
    $bsodTxt = "$($sl.bsod.minidumps) minidump(s)" + $(if ($sl.bsod.ultimo) { " · último $($sl.bsod.ultimo)" } else { '' })
    $svcTxt = if (@($sl.serviciosAutoDetenidos).Count) { (@($sl.serviciosAutoDetenidos)) -join '; ' } else { 'ninguno' }
    $batTxt = if ($sl.bateria) { "salud $($sl.bateria.saludPct)%" } else { 'sin batería' }
    $secSalud = "<div class='sec'>Salud / estabilidad</div><div class='kv'><span>BSOD</span> $(& $esc $bsodTxt)<br><span>Apagados inesperados (30d)</span> $($sl.apagadosInesperados30d)<br><span>Servicios auto detenidos</span> $(& $esc $svcTxt)<br><span>Autoruns / tareas no-MS</span> $($sl.autoruns) / $($sl.tareasProgramadasNoMs)<br><span>Batería</span> $(& $esc $batTxt)</div>"
  }

  @"
<!DOCTYPE html><html lang='es'><head><meta charset='utf-8'>
<link rel='preconnect' href='https://fonts.googleapis.com'><link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>
<link href='https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap' rel='stylesheet'>
<style>
body{font-family:'Space Grotesk','Helvetica Neue',Arial,sans-serif;color:#111;margin:0}
.banner{background:#053028;color:#fff;padding:13px 18px;display:flex;align-items:center;gap:12px;border-bottom:3px solid #43C961}
.banner h1{font-size:18px;margin:0}
.meta{padding:8px 18px;color:#4a4a4a;font-size:13px}.meta b{color:#053028}
.sec{font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:#053028;margin:16px 18px 6px;border-left:3px solid #43C961;padding-left:8px}
.kv{margin:0 18px;font-size:13px}.kv span{display:inline-block;min-width:150px;color:#717171}
table{border-collapse:collapse;font-size:12px;margin:4px 18px 8px;width:calc(100% - 36px)}
th,td{border:1px solid #d8d8d8;padding:4px 8px;text-align:left}
th{background:#053028;color:#fff;font-size:11px;text-transform:uppercase}
code{font-family:'DM Mono','Courier New',monospace;font-size:12px;color:#053028}
.cnt{color:#717171;font-size:11px}
</style></head><body>
<div class='banner'>$logoTag<h1>STI MANTENIMIENTO · Relevamiento de equipo</h1></div>
<div class='meta'><b>Cliente:</b> $(& $esc $Inv.meta.cliente) &nbsp;·&nbsp; <b>Equipo:</b> $(& $esc $Inv.meta.hostname) &nbsp;·&nbsp; <b>Usuario:</b> $(& $esc $Inv.meta.usuario) &nbsp;·&nbsp; <b>Fecha:</b> $fecha</div>

<div class='sec'>Sistema operativo</div>
<div class='kv'><span>SO</span> $(& $esc $Inv.so.caption)<br><span>Versión / build</span> $($Inv.so.version) (build $($Inv.so.build)) · $($Inv.so.arch)<br><span>Equipo</span> $(& $esc $Inv.equipo.fabricante) $(& $esc $Inv.equipo.modelo)</div>

<div class='sec'>CPU y memoria</div>
<div class='kv'><span>CPU</span> $(& $esc $Inv.cpu.modelo)<br><span>Núcleos / lógicos</span> $($Inv.cpu.nucleos) / $($Inv.cpu.logicos) &nbsp; ($($Inv.cpu.mhz) MHz)<br><span>RAM total</span> $($Inv.ram.totalGB) GB</div>
<table><tr><th>Slot</th><th>Capacidad</th><th>Velocidad</th><th>Fabricante</th></tr>$ramRows</table>

<div class='sec'>Discos</div>
<table><tr><th>Modelo</th><th>Tamaño</th><th>Tipo</th></tr>$discosRows</table>

$secObsol
$secRed
$secPerif
$secSeg
$secSalud

<div class='sec'>Software instalado <span class='cnt'>($($Inv.software.Count) aplicaciones)</span></div>
<table><tr><th>Aplicación</th><th>Versión</th><th>Editor</th></tr>$swRows</table>

<div class='sec'>Hardware IDs</div>
<div class='kv'><span>disk_serial</span> <code>$(& $esc $Inv.hardwareIds.disk_serial)</code><br><span>hw_uuid</span> <code>$($Inv.hardwareIds.hw_uuid)</code><br><span>os_uuid</span> <code>$($Inv.hardwareIds.os_uuid)</code><br><span>bios_serial</span> <code>$(& $esc $Inv.hardwareIds.bios_serial)</code><br><span>MAC</span> <code>$(& $esc $macs)</code></div>
</body></html>
"@
}

# Orquesta: releva inventario + escribe HTML+JSON en C:\zback. Devuelve {html;json;inv}.
function Invoke-InventarioEquipo {
  param($Ctx)
  Write-Host "  Relevando inventario del equipo..." -ForegroundColor DarkGray
  $inv = New-InventarioModel -Ctx $Ctx
  $json = New-InventarioJson -Ctx $Ctx -Inv $inv
  $html = New-InventarioHtml -Ctx $Ctx -Inv $inv -LogoPath "$($Ctx.scriptDir)\assets\logo.png"
  $stamp = Get-Date -Format 'yyyyMMdd'
  $htmlPath = Join-Path (Get-MantDir) "$($inv.meta.hostname)_RELEVAMIENTO_${stamp}.html"
  $html | Out-File -FilePath $htmlPath -Encoding UTF8
  Write-Host "Relevamiento (inventario): $htmlPath" -ForegroundColor Cyan
  Write-Host "  + JSON: $json" -ForegroundColor Cyan
  Write-Host ("  CPU: {0} · RAM: {1} GB · discos: {2} · software: {3} apps" -f $inv.cpu.modelo, $inv.ram.totalGB, $inv.discos.Count, $inv.software.Count) -ForegroundColor Gray
  @{ html = $htmlPath; json = $json; inv = $inv }
}
