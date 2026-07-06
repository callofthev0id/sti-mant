# mod-seguridad.ps1 - cuentas STI, firewall, antivirus ESET, updates, reinicio pendiente.
# Devuelve el contrato {category, items[], errors[]}. Cada check en try/catch → N/A + errors si falla.

function Invoke-STIModSeguridad {
  param($Ctx)
  $items = @(); $errs = @()

  # chk_cuentas_sti: cuentas admin gestionadas (definidas en STI_CUENTAS_ADMIN) activas; usuario actual NO admin.
  try {
    # SID well-known del grupo Administradores (locale-independent: "Administrators"/"Administradores").
    $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop | ForEach-Object { ($_.Name -split '\\')[-1].ToLower() })
    $esperadas = @($Ctx.cuentasAdmin | ForEach-Object { ([string]$_).ToLower() })
    $faltan = @($esperadas | Where-Object { $admins -notcontains $_ })
    $curUser = ($env:USERNAME).ToLower()
    $exentas = $esperadas + @('administrator', 'administrador')
    $curIsAdmin = ($admins -contains $curUser) -and ($exentas -notcontains $curUser)
    $ok = ($faltan.Count -eq 0) -and (-not $curIsAdmin)
    $detAdmin = if ($faltan.Count) { "faltan cuentas admin: $($faltan -join ', ')" } else { 'cuentas admin OK' }
    $items += New-CheckItem 'chk_cuentas_sti' 'Cuentas STI (admin)' (Get-StatusBool $ok) $true `
      "$detAdmin · usuario_local_admin:$(if($curIsAdmin){'SÍ(mal)'}else{'no'})" `
      @{ admins = $admins }
  } catch { $items += New-CheckItem 'chk_cuentas_sti' 'Cuentas STI (admin)' 'N/A' $true ''; $errs += "cuentas_sti: $($_.Exception.Message)" }

  # chk_firewall: todos los perfiles enabled.
  try {
    $fw = Get-NetFirewallProfile -ErrorAction Stop
    $allOn = -not ($fw | Where-Object { -not $_.Enabled })
    $items += New-CheckItem 'chk_firewall' 'Firewall' (Get-StatusBool $allOn) $true (($fw | ForEach-Object { "$($_.Name):$([bool]$_.Enabled)" }) -join ' ')
  } catch { $items += New-CheckItem 'chk_firewall' 'Firewall' 'N/A' $true ''; $errs += "firewall: $($_.Exception.Message)" }

  # chk_antivirus_eset: servicio ekrn corriendo. (Defs: si hay Defender, MpComputerStatus; ESET defs vía registro - best-effort.)
  try {
    $ekrn = Get-Service ekrn -ErrorAction SilentlyContinue
    if ($ekrn) {
      $st = if ($ekrn.Status -eq 'Running') { 'Ok' } else { 'Error' }
      $items += New-CheckItem 'chk_antivirus_eset' 'Antivirus ESET' $st $true "ekrn:$($ekrn.Status)"
    } else {
      $av = Get-CimInstance -Namespace root/SecurityCenter2 -Class AntiVirusProduct -ErrorAction SilentlyContinue
      $name = ($av | Select-Object -First 1 -ExpandProperty displayName -ErrorAction SilentlyContinue)
      $st = if ($name) { 'Advertencia' } else { 'Error' }   # AV presente pero no ESET → advertencia
      $items += New-CheckItem 'chk_antivirus_eset' 'Antivirus ESET' $st $true "ESET no detectado; AV: $name"
    }
  } catch { $items += New-CheckItem 'chk_antivirus_eset' 'Antivirus ESET' 'N/A' $true ''; $errs += "eset: $($_.Exception.Message)" }

  # chk_updates: días desde último KB.
  try {
    $last = (Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn | Select-Object -Last 1).InstalledOn
    if ($last) {
      $days = [int]((Get-Date) - $last).TotalDays
      $items += New-CheckItem 'chk_updates' 'Updates Windows' (Get-StatusByDays $days $THR.updates.okMax $THR.updates.advMax) $true "último KB hace $days días" @{ dias = $days; ultimoKb = $last.ToString('yyyy-MM-dd') }
    } else { $items += New-CheckItem 'chk_updates' 'Updates Windows' 'Error' $true 'sin fecha de KB' @{ dias = $null } }
  } catch { $items += New-CheckItem 'chk_updates' 'Updates Windows' 'N/A' $true ''; $errs += "updates: $($_.Exception.Message)" }

  # chk_reinicio_pendiente: claves CBS/WindowsUpdate/PendingFileRename.
  try {
    $p = $false
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $p = $true }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $p = $true }
    $pfr = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    if ($pfr.PendingFileRenameOperations) { $p = $true }
    $items += New-CheckItem 'chk_reinicio_pendiente' 'Reinicio pendiente' ($(if($p){'Advertencia'}else{'Ok'})) $true ($(if($p){'sí'}else{'no'}))
  } catch { $items += New-CheckItem 'chk_reinicio_pendiente' 'Reinicio pendiente' 'N/A' $true ''; $errs += "reinicio: $($_.Exception.Message)" }

  @{ category = 'Seguridad'; items = $items; errors = $errs }
}
