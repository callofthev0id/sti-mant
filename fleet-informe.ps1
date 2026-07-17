# sti-informe.ps1 - genera el informe consolidado (3 HTML) desde una carpeta de JSON de relevamiento.
# Uso: ... -Carpeta <path> [-Cliente "X"] [-Periodo 2026-06] [-Salida <path>]
# Salidas (en C:\zback): <host>_Informe_Mantenimiento_<Cliente>_<periodo>_{FULL,TERMINALES,SERVIDORES}.html
[CmdletBinding()]
param([string]$Carpeta, [string]$Cliente, [string]$Periodo, [string]$Salida)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\lib\common.ps1"; . "$scriptDir\lib\output.ps1"
. "$scriptDir\lib\score.ps1"; . "$scriptDir\lib\informe-model.ps1"; . "$scriptDir\lib\informe-html.ps1"

if (-not $Carpeta) { $Carpeta = Get-MantDir }
if (-not $Salida)  { $Salida = $Carpeta }
$logo = "$scriptDir\assets\logo.png"

$term = Read-Relevamientos -Carpeta $Carpeta -Tipo 'terminales'
$srv  = Read-Relevamientos -Carpeta $Carpeta -Tipo 'servidores'
$mT = if ($term) { Build-InformeModel -Equipos $term -Tipo 'terminales' } else { $null }
$mS = if ($srv)  { Build-InformeModel -Equipos $srv  -Tipo 'servidores' } else { $null }

if (-not $mT -and -not $mS) { Write-Warning "Sin JSON de relevamiento en: $Carpeta"; return }

$cli = if ($Cliente) { $Cliente } elseif ($mT) { $mT.cliente } elseif ($mS) { $mS.cliente } else { 'Cliente' }
$per = if ($Periodo) { $Periodo } elseif ($mT) { $mT.periodo } elseif ($mS) { $mS.periodo } else { '' }
$hostPfx = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { 'PC' }
$base = "${hostPfx}_Informe_Mantenimiento_${cli}_${per}".Replace(' ','_')

if ($mT) { (New-InformeHtml -Modelos @($mT) -Variante 'terminales' -LogoPath $logo) | Out-File "$Salida\${base}_TERMINALES.html" -Encoding UTF8 }
if ($mS) { (New-InformeHtml -Modelos @($mS) -Variante 'servidores' -LogoPath $logo) | Out-File "$Salida\${base}_SERVIDORES.html" -Encoding UTF8 }
$modelosFull = @($mT, $mS | Where-Object { $_ })
(New-InformeHtml -Modelos $modelosFull -Variante 'full' -LogoPath $logo) | Out-File "$Salida\${base}_FULL.html" -Encoding UTF8

Write-Host "Informes generados en: $Salida" -ForegroundColor Green
Get-ChildItem "$Salida\${base}_*.html" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Cyan }
