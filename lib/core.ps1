# lib/core.ps1 - nucleo reutilizable de relevamiento (contexto + orquestacion de modulos).
# Lo comparten el entry CLI (sti-mant.ps1) y la GUI (gui/sti-gui.ps1). NO ejecuta nada al cargar:
# solo define $MOD_FNS, New-MantContext e Invoke-Relevamiento. Depende de common.ps1 (Get-OsInfo,
# Get-FormFactor, Get-HardwareIds, $FLEET_CUENTAS_ADMIN) y runspace.ps1 (Invoke-ModulesParallel).

# Funciones de modulo por tipo.
$script:MOD_FNS = @{
  terminales = @('Invoke-ModSeguridad','Invoke-ModSistema','Invoke-ModHardware','Invoke-ModRed','Invoke-ModHerramientas')
  servidores = @('Invoke-SrvSeguridad','Invoke-SrvSistema','Invoke-SrvAlmacenamiento','Invoke-SrvServicios','Invoke-SrvRed')
}

function New-MantContext {
  param([string]$Tag, [string]$Cliente, [bool]$InstallOcs, [string]$ScriptDir, [string]$Usuario, [string]$Nota, [string]$Tecnico)
  $os = Get-OsInfo; $ff = Get-FormFactor
  @{ os = $os; formFactor = $ff.formFactor; isVm = $ff.isVm; hypervHost = $ff.hypervHost;
     tag = $Tag; cliente = $(if ($Cliente) { $Cliente } else { $Tag });
     installOcs = $InstallOcs; scriptDir = $ScriptDir; usuario = $Usuario; nota = $Nota;
     tecnico = $Tecnico; cuentasAdmin = $FLEET_CUENTAS_ADMIN }
}

function Invoke-Relevamiento {
  param($Ctx, [string]$Tipo = 'terminales', [switch]$Sequential)
  $fns = $MOD_FNS[$Tipo]
  $modules = @()
  if ($Sequential) {
    foreach ($fn in $fns) { try { $modules += & $fn -Ctx $Ctx } catch { Write-Warning "Modulo $fn fallo: $($_.Exception.Message)" } }
  } else {
    # paralelo (Runspace Pool); si algo falla, fallback a secuencia
    try { $modules = @(Invoke-ModulesParallel -Ctx $Ctx -FnNames $fns) }
    catch { Write-Warning "Runspace fallo ($($_.Exception.Message)); corriendo en secuencia."; foreach ($fn in $fns) { try { $modules += & $fn -Ctx $Ctx } catch {} } }
  }
  $items = @($modules | ForEach-Object { $_.items } | Where-Object { $_ })
  $errs  = @($modules | ForEach-Object { $_.errors } | Where-Object { $_ })
  @{ modules = $modules; items = $items; errors = $errs; hw = (Get-HardwareIds) }
}
