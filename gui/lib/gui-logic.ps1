# gui/lib/gui-logic.ps1 - logica pura de la GUI (sin WPF, sin WMI). Testeable con Pester.

# Deriva el tipo de equipo (terminales|servidores) desde el form factor y la clase de SO.
# Logica NUEVA de la GUI: el core (Get-FormFactor) NO hace esta traduccion.
# Regla: chassis de servidor manda; una VM se desempata por la clase de SO.
function Get-EquipoTipo {
  param([string]$FormFactor, [string]$SoClase)
  if ($FormFactor -eq 'server') { return 'servidores' }
  if ($FormFactor -eq 'vm' -and $SoClase -eq 'Server') { return 'servidores' }
  if ($SoClase -eq 'Server') { return 'servidores' }
  'terminales'
}

# Valida los campos minimos de identificacion antes de relevar. El TAG OCS es obligatorio
# (es la etiqueta de OCS y, si falta Cliente, New-MantContext usa el TAG como cliente).
function Test-IdentificacionValida {
  param([string]$Tag, [string]$Cliente)
  if ([string]::IsNullOrWhiteSpace($Tag)) {
    return @{ ok = $false; mensaje = 'Falta el TAG OCS (obligatorio).' }
  }
  @{ ok = $true; mensaje = '' }
}

# Label dinamico del boton primario segun el tipo detectado.
function Get-RelevarLabel {
  param([string]$Tipo)
  if ($Tipo -eq 'servidores') { 'Relevar servidor' } else { 'Relevar terminal' }
}

# Arma el hashtable de parametros para splatting a New-MantContext desde los campos de la GUI.
# Relevar nunca instala OCS (es accion aparte), por eso InstallOcs = $false fijo.
function New-GuiMantArgs {
  param([string]$Tag, [string]$Cliente, [string]$Usuario, [string]$Nota, [string]$ScriptDir)
  @{
    Tag = $Tag; Cliente = $Cliente; InstallOcs = $false;
    ScriptDir = $ScriptDir; Usuario = $Usuario; Nota = $Nota
  }
}
