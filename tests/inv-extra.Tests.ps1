# Pester 5. Lógica pura de las secciones extra del relevamiento (obsolescencia/seguridad/contexto/salud).
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
  . "$PSScriptRoot/../lib/inv-obsolescencia.ps1"
  . "$PSScriptRoot/../lib/inv-seguridad.ps1"
  . "$PSScriptRoot/../lib/inv-contexto.ps1"
  . "$PSScriptRoot/../lib/inv-salud.ps1"
  $script:NOW = [datetime]'2026-06-09T12:00:00'
}

Describe "Get-OsEol" {
  It "Windows 10 está fuera de soporte (EOL 2025-10-14)" {
    $r = Get-OsEol -Caption 'Microsoft Windows 10 Pro' -Now $NOW
    $r.soportado | Should -BeFalse
    $r.etiqueta  | Should -Be 'FUERA DE SOPORTE'
  }
  It "Server 2022 soportado" { (Get-OsEol -Caption 'Microsoft Windows Server 2022 Standard' -Now $NOW).soportado | Should -BeTrue }
  It "Server 2012 R2 fuera de soporte" { (Get-OsEol -Caption 'Microsoft Windows Server 2012 R2' -Now $NOW).soportado | Should -BeFalse }
  It "Windows 11 soportado" { (Get-OsEol -Caption 'Microsoft Windows 11 Pro' -Now $NOW).soportado | Should -BeTrue }
  It "SO desconocido → etiqueta desconocido" { (Get-OsEol -Caption 'Algun Linux' -Now $NOW).etiqueta | Should -Be 'desconocido' }
}

Describe "Test-Win11Apto" {
  It "cumple todo → apto" {
    $r = Test-Win11Apto -TpmVersion '2.0' -SecureBoot $true -Arch64 $true -RamGB 8 -DiskGB 256
    $r.apto | Should -BeTrue
    $r.faltan.Count | Should -Be 0
  }
  It "TPM 1.2 + sin Secure Boot → no apto, lista lo que falta" {
    $r = Test-Win11Apto -TpmVersion '1.2' -SecureBoot $false -Arch64 $true -RamGB 8 -DiskGB 256
    $r.apto | Should -BeFalse
    $r.faltan | Should -Contain 'TPM 2.0'
    $r.faltan | Should -Contain 'Secure Boot'
  }
  It "RAM insuficiente → falta RAM" { (Test-Win11Apto -TpmVersion '2.0' -SecureBoot $true -Arch64 $true -RamGB 2 -DiskGB 256).faltan | Should -Contain 'RAM >= 4 GB' }
}

Describe "Get-BitLockerEstado" {
  It "1=Cifrado, 0=SIN cifrar, otro=desconocido" {
    Get-BitLockerEstado 1 | Should -Be 'Cifrado'
    Get-BitLockerEstado 0 | Should -Be 'SIN cifrar'
    Get-BitLockerEstado 2 | Should -Be 'desconocido'
  }
}

Describe "ConvertFrom-MonitorBytes" {
  It "decodifica uint16 a ASCII e ignora ceros" { ConvertFrom-MonitorBytes @(68,69,76,76,0,0) | Should -Be 'DELL' }
  It "null → vacío" { ConvertFrom-MonitorBytes $null | Should -Be '' }
}

Describe "Get-BateriaSaludPct" {
  It "full/design" { Get-BateriaSaludPct 50000 40000 | Should -Be 80 }
  It "design 0 → null" { Get-BateriaSaludPct 0 40000 | Should -BeNullOrEmpty }
  It "full null → null" { Get-BateriaSaludPct 50000 $null | Should -BeNullOrEmpty }
}
