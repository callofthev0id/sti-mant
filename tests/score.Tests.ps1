BeforeAll { . "$PSScriptRoot/../lib/score.ps1" }
Describe "Get-EstadoPeso" {
  It "pesos por estado" {
    Get-EstadoPeso "Ok" | Should -Be 1.0
    Get-EstadoPeso "Advertencia" | Should -Be 0.6
    Get-EstadoPeso "Error" | Should -Be 0.2
    Get-EstadoPeso "Crítico" | Should -Be 0.0
    Get-EstadoPeso "N/A" | Should -Be $null
    Get-EstadoPeso "" | Should -Be $null
  }
}
Describe "Get-EquipoScore" {
  It "promedia los no-N/A a 0..100" {
    Get-EquipoScore @('Ok','Ok','Error','N/A') | Should -Be 73
  }
  It "todo N/A => null" { Get-EquipoScore @('N/A','N/A') | Should -Be $null }
  It "todo Ok => 100" { Get-EquipoScore @('Ok','Ok') | Should -Be 100 }
}
Describe "Get-ClienteScore" {
  It "promedia scores de equipos (ignora null)" {
    Get-ClienteScore @(100, 50, $null) | Should -Be 75
  }
}
