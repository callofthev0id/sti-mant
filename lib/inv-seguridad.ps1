# lib/inv-seguridad.ps1 - postura de seguridad/hardening (complementa ESET, que es AV/EDR).
# Cifrado (BitLocker), cuentas admin locales, UAC, SMBv1, TLS viejo, Defender tamper.

# ---- PURA ----
# ProtectionStatus de Win32_EncryptableVolume → etiqueta.
function Get-BitLockerEstado { param([int]$Status) switch ($Status) { 1 { 'Cifrado' } 0 { 'SIN cifrar' } default { 'desconocido' } } }

# ---- COLLECTOR (Windows-only) ----
function Get-InvSeguridad {
  # BitLocker por volumen fijo
  $bl = @()
  try {
    Get-CimInstance -Namespace 'root\cimv2\security\MicrosoftVolumeEncryption' -Class Win32_EncryptableVolume -ErrorAction Stop |
      ForEach-Object { $bl += [ordered]@{ unidad = $_.DriveLetter; estado = (Get-BitLockerEstado ([int]$_.ProtectionStatus)) } }
  } catch {}

  # Admins locales (SID well-known; locale-safe)
  $admins = @()
  try { $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop | ForEach-Object { $_.Name }) }
  catch { try { $admins = @((net localgroup administradores 2>$null) + (net localgroup administrators 2>$null)) | Where-Object { $_ -and $_ -notmatch '----|comando|command|completado|completed|^Alias|^Miembros|^Members|^Comentario|^The ' } } catch {} }

  # UAC
  $uac = $null
  try { $uac = [bool](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction Stop).EnableLUA } catch {}

  # SMBv1
  $smb1 = $null
  try { $smb1 = [bool](Get-SmbServerConfiguration -ErrorAction Stop).EnableSMB1Protocol } catch {}

  # TLS viejo (1.0/1.1) habilitado a nivel SCHANNEL server
  function _TlsHab([string]$Ver) {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS $Ver\Server"
    try { $e = (Get-ItemProperty $k -Name Enabled -ErrorAction Stop).Enabled; if ($e -eq 0) { 'deshabilitado' } else { 'HABILITADO' } }
    catch { 'por defecto (no configurado)' }
  }
  $tls = [ordered]@{ tls10 = (_TlsHab '1.0'); tls11 = (_TlsHab '1.1') }

  # Defender tamper protection (si Defender presente)
  $tamper = $null
  try { $tamper = [bool](Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected } catch {}

  [ordered]@{
    bitlocker = $bl
    adminsLocales = $admins
    uacHabilitado = $uac
    smbv1Habilitado = $smb1
    tlsViejo = $tls
    defenderTamper = $tamper
  }
}
