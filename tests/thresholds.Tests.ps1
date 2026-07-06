# Pester 5. Evaluadores puros de thresholds.ps1.
BeforeAll { . "$PSScriptRoot/../lib/thresholds.ps1" }

Describe "Get-StatusByDays" {
  It "updates 30/60" {
    Get-StatusByDays 10 30 60 | Should -Be "Ok"
    Get-StatusByDays 30 30 60 | Should -Be "Ok"
    Get-StatusByDays 45 30 60 | Should -Be "Advertencia"
    Get-StatusByDays 90 30 60 | Should -Be "Error"
  }
}

Describe "Get-StatusByPct disco" {
  It "80/90" {
    Get-StatusByPct 70 80 90 | Should -Be "Ok"
    Get-StatusByPct 85 80 90 | Should -Be "Advertencia"
    Get-StatusByPct 95 80 90 | Should -Be "Error"
  }
}

Describe "Get-StatusBool" {
  It "ok/error" {
    Get-StatusBool $true  | Should -Be "Ok"
    Get-StatusBool $false | Should -Be "Error"
  }
}

Describe "Get-StatusVss" {
  It "punto reciente/viejo/ninguno" {
    Get-StatusVss 3 $true   | Should -Be "Ok"
    Get-StatusVss 20 $true  | Should -Be "Advertencia"
    Get-StatusVss 40 $true  | Should -Be "Error"
    Get-StatusVss 0 $false  | Should -Be "Error"
  }
}
