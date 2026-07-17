# sti-mant.ps1 - relevamiento de mantenimiento (terminales + servidores).
# Uso directo:  PowerShell -ExecutionPolicy Bypass -File sti-mant.ps1 -Tag <nc> [-Tipo terminales|servidores] [-Cliente "X"] [-InstallOCS]
# Menú interactivo: ... -Menu     (o lanzar sti-mant.bat)
# Salidas: ① TSV (orden column-spec) al portapapeles · ② HTML + ③ JSON de relevamiento en C:\zback.
# Módulos en paralelo (Runspace Pool, fallback a secuencia). Versión: $SCRIPT_VERSION (lib/common.ps1).
[CmdletBinding()]
param(
  [string]$Tag,
  [string]$Cliente,
  [string]$Usuario,
  [string]$Nota,
  [ValidateSet('terminales','servidores')][string]$Tipo = 'terminales',
  [string]$Tecnico = '',
  [switch]$InstallOCS,
  [switch]$Inventario,
  [switch]$Menu
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\lib\common.ps1"
. "$scriptDir\lib\thresholds.ps1"
. "$scriptDir\lib\runspace.ps1"
. "$scriptDir\lib\output.ps1"
. "$scriptDir\lib\manual.ps1"
. "$scriptDir\lib\cobian.ps1"
. "$scriptDir\lib\inv-obsolescencia.ps1"
. "$scriptDir\lib\inv-seguridad.ps1"
. "$scriptDir\lib\inv-contexto.ps1"
. "$scriptDir\lib\inv-salud.ps1"
. "$scriptDir\lib\inventario.ps1"
Get-ChildItem "$scriptDir\modules\*.ps1" | ForEach-Object { . $_.FullName }
. "$scriptDir\lib\core.ps1"
. "$scriptDir\lib\audit.ps1"

# ---- núcleo reutilizable ($MOD_FNS, New-MantContext, Invoke-Relevamiento) vive en lib/core.ps1
# (lo comparte la GUI). El resto de funciones de presentación/menú son específicas del CLI. ----

function Show-MantSummary {
  param($Rel)
  Write-Host "`n--- RESUMEN (estado + detalle) ---" -ForegroundColor White
  foreach ($m in $Rel.modules) {
    Write-Host (" {0}" -f $m.category) -ForegroundColor Cyan
    foreach ($it in $m.items) {
      $col = switch ($it.status) { 'Ok'{'Green'} 'Advertencia'{'Yellow'} 'Error'{'DarkYellow'} 'Crítico'{'Red'} default{'Gray'} }
      $st = if ($it.status) { $it.status } else { '-' }
      Write-Host ("   {0,-28} " -f $it.label) -NoNewline
      Write-Host ("{0,-12}" -f $st) -ForegroundColor $col -NoNewline
      $d = [string]$it.detail
      if ($d) { if ($d.Length -gt 72) { $d = $d.Substring(0,69) + '...' }; Write-Host (" $d") -ForegroundColor DarkGray }
      else { Write-Host '' }
    }
  }
  # Lista focalizada: lo que NO está Ok → qué mirar para Observaciones.
  $atender = @($Rel.items | Where-Object { $_.status -in 'Advertencia','Error','Crítico' })
  if ($atender.Count -gt 0) {
    Write-Host "`n--- ATENCION (para completar Observaciones) ---" -ForegroundColor White
    foreach ($it in $atender) {
      $col = switch ($it.status) { 'Advertencia'{'Yellow'} 'Error'{'DarkYellow'} 'Crítico'{'Red'} default{'Gray'} }
      Write-Host ("  [{0}] " -f $it.status) -ForegroundColor $col -NoNewline
      Write-Host ("{0}: " -f $it.label) -NoNewline
      Write-Host ([string]$it.detail) -ForegroundColor Gray
    }
  }
  # Semi/Manual que el tecnico debe revisar y cargar el estado a mano.
  $manual = @($Rel.items | Where-Object { -not $_.automated })
  if ($manual.Count -gt 0) {
    Write-Host "`n--- REVISAR Y CARGAR A MANO (Semi/Manual) ---" -ForegroundColor White
    foreach ($it in $manual) {
      Write-Host ("  {0}: " -f $it.label) -NoNewline
      Write-Host ([string]$it.detail) -ForegroundColor DarkGray
    }
  }
}

function Export-MantTsv {
  param($Rel, [string]$Tipo)
  if ($Tipo -eq 'servidores') {
    $tsv = ConvertTo-MantTsv -Items $Rel.items -Order $CHK_ORDER_SRV -AsColumn
    $dest = "Pegar en la COLUMNA Estado del servidor (de arriba hacia abajo)."
  } else {
    $tsv = ConvertTo-MantTsv -Items $Rel.items -Order $CHK_ORDER_TERM
    $dest = "Pegar en la celda del primer check (col B) de la fila del equipo."
  }
  $clip = 'clipboard no disponible'
  try { Set-Clipboard -Value $tsv -ErrorAction Stop; $clip = 'copiado al portapapeles' } catch {}
  $n = @($Rel.items).Count
  Write-Host "TSV: $clip - $n checks. $dest" -ForegroundColor Cyan
  $tsv
}

function Export-MantHtml {
  param($Rel, $Ctx, [string]$Tipo = 'terminales')
  $p = New-HtmlReport -Ctx $Ctx -Modules $Rel.modules -HwIds $Rel.hw -LogoPath "$($Ctx.scriptDir)\assets\logo.png" -Tipo $Tipo
  Write-Host "HTML relevamiento: $p" -ForegroundColor Cyan
  $p
}

function Export-MantMeta {
  param($Rel, $Ctx, [string]$Tipo = 'terminales')
  $p = New-MetaExport -Ctx $Ctx -Rel $Rel -Tipo $Tipo
  Write-Host "Metadata (JSON, el porqué de cada check): $p" -ForegroundColor Cyan
  $p
}

function Show-HardwareIds {
  param($Hw)
  Write-Host "`n--- HARDWARE IDs (cruce: disk-serial > UUID > MAC > bios) ---" -ForegroundColor White
  Write-Host ("  hostname    : {0}" -f $Hw.hostname)
  Write-Host ("  os_uuid     : {0}" -f $Hw.os_uuid)
  Write-Host ("  disk_serial : {0}" -f $Hw.disk_serial)
  Write-Host ("  hw_uuid     : {0}" -f $Hw.hw_uuid)
  Write-Host ("  bios_serial : {0}" -f $Hw.bios_serial)
  Write-Host ("  mac         : {0}" -f ($Hw.mac -join ', '))
}

# ---- modo one-shot ----
function Invoke-OneShot {
  param([string]$Tag, [string]$Cliente, [string]$Tipo, [bool]$InstallOcs, [string]$ScriptDir, [string]$Usuario, [string]$Nota, [string]$Tecnico = '')
  $ctx = New-MantContext -Tag $Tag -Cliente $Cliente -InstallOcs $InstallOcs -ScriptDir $ScriptDir -Usuario $Usuario -Nota $Nota -Tecnico $Tecnico
  Write-Host "Fleet Maintenance Toolkit - $($ctx.cliente) - $($ctx.os.class)/$($ctx.formFactor) - $Tipo" -ForegroundColor Green
  $rel = Invoke-Relevamiento -Ctx $ctx -Tipo $Tipo
  Show-MantSummary -Rel $rel
  Invoke-ManualCapture -Rel $rel       # cuestionario de checks manuales (skip si no-interactivo)
  $tsv = Export-MantTsv -Rel $rel -Tipo $Tipo
  [void](Export-MantHtml -Rel $rel -Ctx $ctx -Tipo $Tipo)
  [void](Export-MantMeta -Rel $rel -Ctx $ctx -Tipo $Tipo)
  Write-Output "TSV_LINE>>$tsv"
}

# ---- menú ASCII ----
function Show-Banner {
  param($Ctx)
  Write-Host ""
  Write-Host "  ============================================================" -ForegroundColor DarkGreen
  Write-Host "    [ FLEET ]  FLEET TOOLKIT  -  Mantenimiento de equipos" -ForegroundColor Green
  Write-Host "  ============================================================" -ForegroundColor DarkGreen
  if ($Ctx) {
    $hostname = if ($Ctx.hw -and $Ctx.hw.hostname) { $Ctx.hw.hostname } else { $env:COMPUTERNAME }
    Write-Host ("    Equipo: {0}   Cliente: {1}   SO: {2}/{3}" -f $hostname, $Ctx.cliente, $Ctx.os.class, $Ctx.formFactor) -ForegroundColor Gray
  }
}

function Start-MantMenu {
  param([string]$ScriptDir, [string]$Tag, [string]$Cliente, [string]$Usuario, [string]$Nota, [string]$Tipo = 'terminales', [string]$Tecnico = '')
  if (-not $Tag) { $Tag = Read-Host "  nombreCorto del cliente (TAG)" }
  if (-not $Usuario) { $Usuario = Read-Host "  Usuario del equipo (enter para omitir)" }
  if (-not $Tecnico) { $Tecnico = Read-Host "  Técnico que realiza el relevamiento (enter para omitir)" }
  $ctx = New-MantContext -Tag $Tag -Cliente $Cliente -InstallOcs $false -ScriptDir $ScriptDir -Usuario $Usuario -Nota $Nota -Tecnico $Tecnico
  $rel = $null
  while ($true) {
    Show-Banner -Ctx $ctx
    Write-Host ("   Tipo de equipo: {0}  (auto por SO; forzar con -Tipo terminales|servidores)" -f $Tipo) -ForegroundColor DarkCyan
    Write-Host "  ------------------------------------------------------------"
    Write-Host ("   1) Mantenimiento de equipo ({0})" -f $Tipo)
    Write-Host "   2) Relevamiento de equipo (inventario HW/SW/SO)"
    Write-Host "   3) Ver Hardware IDs"
    Write-Host "   4) OCS  -  verificar / instalar"
    Write-Host "   0) Salir"
    Write-Host "  ------------------------------------------------------------"
    $op = Read-Host "  Opcion"
    switch ($op) {
      '1' {
        if (-not $rel) { Write-Host "  Ejecutando mantenimiento..." -ForegroundColor DarkGray; $rel = Invoke-Relevamiento -Ctx $ctx -Tipo $Tipo }
        Invoke-ManualCapture -Rel $rel   # carga manuales (self-skip si ya cargados)
        while ($true) {
          Write-Host "`n   [Mantenimiento]" -ForegroundColor Cyan
          Write-Host "     1) Ver resumen en consola"
          Write-Host "     2) Copiar TSV para la planilla"
          Write-Host "     3) Generar HTML de relevamiento"
          Write-Host "     4) Exportar metadata (JSON, el porque de cada check)"
          Write-Host "     5) Todo (resumen + TSV + HTML + metadata)"
          Write-Host "     6) Cargar/editar checks manuales"
          Write-Host "     9) Re-relevar"
          Write-Host "     0) Volver"
          $s = Read-Host "   Opcion"
          switch ($s) {
            '1' { Show-MantSummary -Rel $rel }
            '2' { [void](Export-MantTsv -Rel $rel -Tipo $Tipo) }
            '3' { [void](Export-MantHtml -Rel $rel -Ctx $ctx -Tipo $Tipo) }
            '4' { [void](Export-MantMeta -Rel $rel -Ctx $ctx -Tipo $Tipo) }
            '5' { Show-MantSummary -Rel $rel; [void](Export-MantTsv -Rel $rel -Tipo $Tipo); [void](Export-MantHtml -Rel $rel -Ctx $ctx -Tipo $Tipo); [void](Export-MantMeta -Rel $rel -Ctx $ctx -Tipo $Tipo) }
            '6' { Invoke-ManualCapture -Rel $rel -Force }
            '9' { Write-Host "  Re-relevando..." -ForegroundColor DarkGray; $rel = Invoke-Relevamiento -Ctx $ctx -Tipo $Tipo; Invoke-ManualCapture -Rel $rel }
            '0' { break }
            default { Write-Host "  opcion invalida" -ForegroundColor Red }
          }
          if ($s -eq '0') { break }
        }
      }
      '2' { [void](Invoke-InventarioEquipo -Ctx $ctx) }
      '3' { if (-not $rel) { $rel = Invoke-Relevamiento -Ctx $ctx -Tipo $Tipo }; Show-HardwareIds -Hw $rel.hw }
      '4' {
        $ctx.installOcs = $true
        $h = Invoke-ModHerramientas -Ctx $ctx
        $ocs = $h.items | Where-Object { $_.key -eq 'chk_ocs' }
        Write-Host ("  OCS: {0} - {1}" -f $ocs.status, $ocs.detail) -ForegroundColor Cyan
        $ctx.installOcs = $false
      }
      '0' { Write-Host "  Saliendo." -ForegroundColor DarkGray; return }
      default { Write-Host "  opcion invalida" -ForegroundColor Red }
    }
  }
}

# ---- dispatch ----
# Auto-detección: si no se pasó -Tipo explícito y el SO es Windows Server → servidores.
if (-not $PSBoundParameters.ContainsKey('Tipo')) {
  try { if ((Get-OsInfo).class -eq 'Server') { $Tipo = 'servidores' } } catch {}
}
if ($Menu) {
  Start-MantMenu -ScriptDir $scriptDir -Tag $Tag -Cliente $Cliente -Usuario $Usuario -Nota $Nota -Tipo $Tipo -Tecnico $Tecnico
} elseif ($Inventario -and -not $Tag) {
  # solo relevamiento (inventario), sin mantenimiento
  $ctxInv = New-MantContext -Tag $Tag -Cliente $Cliente -InstallOcs $false -ScriptDir $scriptDir -Usuario $Usuario -Nota $Nota -Tecnico $Tecnico
  [void](Invoke-InventarioEquipo -Ctx $ctxInv)
} elseif ($Tag) {
  Invoke-OneShot -Tag $Tag -Cliente $Cliente -Tipo $Tipo -InstallOcs ([bool]$InstallOCS) -ScriptDir $scriptDir -Usuario $Usuario -Nota $Nota -Tecnico $Tecnico
  if ($Inventario) {   # mantenimiento + relevamiento juntos
    $ctxInv = New-MantContext -Tag $Tag -Cliente $Cliente -InstallOcs $false -ScriptDir $scriptDir -Usuario $Usuario -Nota $Nota -Tecnico $Tecnico
    [void](Invoke-InventarioEquipo -Ctx $ctxInv)
  }
} else {
  Start-MantMenu -ScriptDir $scriptDir -Tag $Tag -Cliente $Cliente -Usuario $Usuario -Nota $Nota -Tipo $Tipo -Tecnico $Tecnico
}
