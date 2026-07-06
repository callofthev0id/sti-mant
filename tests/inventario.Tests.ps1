# Pester 5. Lógica pura del relevamiento/inventario (lib/inventario.ps1).
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
  . "$PSScriptRoot/../lib/inventario.ps1"
}

Describe "Get-DiskTipo" {
  It "NVMe por BusType 17" { Get-DiskTipo 4 17 $null | Should -Be 'NVMe' }
  It "SSD por MediaType 4" { Get-DiskTipo 4 0  $null | Should -Be 'SSD' }
  It "HDD por MediaType 3" { Get-DiskTipo 3 0  5400 | Should -Be 'HDD' }
  It "SSD por SpindleSpeed 0 cuando MediaType desconocido" { Get-DiskTipo 0 0 0 | Should -Be 'SSD' }
  It "desconocido → ?" { Get-DiskTipo 0 0 $null | Should -Be '?' }
}

Describe "Test-AppRelevante (filtro de software)" {
  It "app real → true" { Test-AppRelevante -Name 'Google Chrome' -SystemComponent $false -Publisher 'Google LLC' | Should -BeTrue }
  It "SystemComponent → false" { Test-AppRelevante -Name 'Algo' -SystemComponent $true -Publisher '' | Should -BeFalse }
  It "sin nombre → false" { Test-AppRelevante -Name '' -SystemComponent $false -Publisher '' | Should -BeFalse }
  It "update KB → false" { Test-AppRelevante -Name 'KB5034123' -SystemComponent $false -Publisher 'Microsoft' | Should -BeFalse }
  It "redistributable VC++ → false" { Test-AppRelevante -Name 'Microsoft Visual C++ 2015-2022 Redistributable (x64)' -SystemComponent $false -Publisher 'Microsoft' | Should -BeFalse }
  It ".NET runtime → false" { Test-AppRelevante -Name 'Microsoft .NET Runtime - 8.0.1 (x64)' -SystemComponent $false -Publisher 'Microsoft' | Should -BeFalse }
  It "Office (app real) → true" { Test-AppRelevante -Name 'Microsoft 365 Apps para empresas' -SystemComponent $false -Publisher 'Microsoft' | Should -BeTrue }
}
