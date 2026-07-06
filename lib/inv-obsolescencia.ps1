# lib/inv-obsolescencia.ps1 - obsolescencia/renovación: fin de soporte del SO, TPM,
# Secure Boot, apto Win11, BIOS versión+fecha. Para la sección "qué renovar" del informe.

# ---- PURAS ----

# Fin de soporte (EOL) del SO por Caption. $Now inyectable. Devuelve @{ eol; soportado; etiqueta }.
function Get-OsEol {
  param([string]$Caption, [datetime]$Now = (Get-Date))
  $map = @(
    @{ rx = 'Windows 7';        eol = '2020-01-14' },
    @{ rx = 'Windows 8';        eol = '2023-01-10' },
    @{ rx = 'Windows 10';       eol = '2025-10-14' },
    @{ rx = 'Windows 11';       eol = '2031-10-14' },
    @{ rx = 'Server 2008';      eol = '2020-01-14' },
    @{ rx = 'Server 2012';      eol = '2023-10-10' },
    @{ rx = 'Server 2016';      eol = '2027-01-12' },
    @{ rx = 'Server 2019';      eol = '2029-01-09' },
    @{ rx = 'Server 2022';      eol = '2031-10-14' },
    @{ rx = 'Server 2025';      eol = '2034-10-10' }
  )
  foreach ($m in $map) {
    if ($Caption -match $m.rx) {
      $eol = [datetime]::ParseExact($m.eol, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      $sop = $Now -lt $eol
      $etq = if ($sop) { 'soportado' } else { 'FUERA DE SOPORTE' }
      return @{ eol = $m.eol; soportado = $sop; etiqueta = $etq }
    }
  }
  @{ eol = $null; soportado = $null; etiqueta = 'desconocido' }
}

# ¿Apto para Windows 11? Reglas mínimas. Devuelve @{ apto; faltan }.
function Test-Win11Apto {
  param([string]$TpmVersion, [bool]$SecureBoot, [bool]$Arch64, [double]$RamGB, [double]$DiskGB)
  $faltan = @()
  if (-not ($TpmVersion -match '^2')) { $faltan += 'TPM 2.0' }
  if (-not $SecureBoot) { $faltan += 'Secure Boot' }
  if (-not $Arch64) { $faltan += '64 bits' }
  if ($RamGB -lt 4) { $faltan += 'RAM >= 4 GB' }
  if ($DiskGB -lt 64) { $faltan += 'disco >= 64 GB' }
  @{ apto = ($faltan.Count -eq 0); faltan = $faltan }
}

# ---- COLLECTOR (Windows-only) ----
function Get-InvObsolescencia {
  param($So, $RamGB, $DiscoGB)
  # BIOS
  $bios = $null
  try {
    $b = Get-CimInstance Win32_BIOS -ErrorAction Stop
    $fecha = $null; try { $fecha = $b.ReleaseDate } catch {}
    $anios = $null; if ($fecha) { try { $anios = [math]::Round(((Get-Date) - $fecha).TotalDays / 365, 1) } catch {} }
    $bios = [ordered]@{ version = ([string]$b.SMBIOSBIOSVersion).Trim(); fecha = $fecha; antiguedadAnios = $anios }
  } catch {}
  # TPM
  $tpm = [ordered]@{ presente = $false; version = $null; listo = $false }
  try {
    $t = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop
    if ($t) {
      $tpm.presente = $true
      $tpm.listo = [bool]$t.IsEnabled_InitialValue
      try { $tpm.version = ($t.SpecVersion -split ',')[0].Trim() } catch {}
    }
  } catch {}
  # Secure Boot
  $sb = $null
  try { $sb = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $sb = $false }
  $arch64 = ($So.arch -match '64')
  $eol = Get-OsEol -Caption $So.caption
  $win11 = Test-Win11Apto -TpmVersion ([string]$tpm.version) -SecureBoot $sb -Arch64 $arch64 -RamGB ([double]$RamGB) -DiskGB ([double]$DiscoGB)
  [ordered]@{
    soFinSoporte = $eol
    bios = $bios
    tpm = $tpm
    secureBoot = $sb
    win11Apto = $win11
  }
}
