# build.ps1 - fusiona lib + modules + cada entry-point en dist/<entry>-v<ver>.ps1 (UTF-8 BOM).
# Entry-points: fleet-mant (relevamiento) y fleet-informe (informe local). Cada uno reemplaza su
# bloque de dot-source por el contenido inline de lib+modules.
param([string]$Version = '0.1')

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Get-Body([string]$path) {
  $t = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $t.TrimStart([char]0xFEFF)
}

# lib en orden de dependencia (común primero). score/informe-* los usa fleet-informe; inocuos para fleet-mant.
$libOrder = @('lib\common.ps1','lib\thresholds.ps1','lib\runspace.ps1','lib\output.ps1',
              'lib\manual.ps1','lib\cobian.ps1','lib\inv-obsolescencia.ps1','lib\inv-seguridad.ps1',
              'lib\inv-contexto.ps1','lib\inv-salud.ps1','lib\inventario.ps1','lib\core.ps1',
              'lib\audit.ps1','lib\score.ps1','lib\informe-model.ps1','lib\informe-html.ps1')
$mods = Get-ChildItem (Join-Path $root 'modules\*.ps1') | Sort-Object Name

$inline = New-Object System.Text.StringBuilder
[void]$inline.AppendLine("# ====== lib + modules (inline, generado por build.ps1) ======")
foreach ($l in $libOrder) { [void]$inline.AppendLine((Get-Body (Join-Path $root $l))) }
foreach ($m in $mods)      { [void]$inline.AppendLine((Get-Body $m.FullName)) }
$guiLibs = @('gui\lib\gui-logic.ps1','gui\lib\gui-theme.ps1','gui\lib\gui-branding.ps1',
             'gui\lib\gui-tab-inventario.ps1','gui\lib\gui-tab-utilidades.ps1','gui\lib\gui-tab-generar.ps1','gui\lib\gui-tab-mantenimiento.ps1','gui\lib\gui-xaml.ps1','gui\lib\gui-runspace.ps1')
foreach ($g in $guiLibs) { [void]$inline.AppendLine((Get-Body (Join-Path $root $g))) }
$inlineStr = $inline.ToString()

function Build-Entry([string]$EntryFile, [string]$OutName) {
  $orq = (Get-Body (Join-Path $root $EntryFile)) -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $injected = $false
  foreach ($line in $orq) {
    if ($line -match '^\s*\.\s+"\$(scriptDir|coreDir)' -or $line -match 'Get-ChildItem.*modules.*ForEach') {
      if (-not $injected) { $out.Add($inlineStr); $injected = $true }
      continue
    }
    $out.Add($line)
  }
  $content = ($out -join "`r`n")
  $distDir = Join-Path $root 'dist'
  if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
  $dist = Join-Path $distDir $OutName
  [IO.File]::WriteAllText($dist, $content, (New-Object System.Text.UTF8Encoding($true)))
  Write-Host "Build OK: $dist ($($content.Length) chars)"
}

Build-Entry 'fleet-mant.ps1'    "fleet-mant-v$Version.ps1"
Build-Entry 'fleet-informe.ps1' "fleet-informe-v$Version.ps1"
Build-Entry 'gui\fleet-gui.ps1' "fleet-gui-v$Version.ps1"
