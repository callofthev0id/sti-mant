# Pester 5. Parseo puro del último inventario OCS desde el log del agente (lib/common.ps1).
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
}

Describe "Get-OcsLastInventoryFromLog (último inventario)" {
  It "log vacío o null → null" {
    Get-OcsLastInventoryFromLog $null | Should -Be $null
    Get-OcsLastInventoryFromLog ''    | Should -Be $null
  }
  It "formato ISO: toma el timestamp más reciente" {
    $txt = @"
2026-06-08 03:00:01 => Inventory built
2026-06-09 03:00:05 => Inventory sent to server
"@
    $r = Get-OcsLastInventoryFromLog $txt
    $r | Should -BeOfType ([datetime])
    $r.ToString('yyyy-MM-dd HH:mm:ss') | Should -Be '2026-06-09 03:00:05'
  }
  It "formato C runtime (Mon Jun 09 ...) se parsea" {
    $txt = "Mon Jun 09 03:00:01 2026 => Inventory sent"
    $r = Get-OcsLastInventoryFromLog $txt
    $r | Should -BeOfType ([datetime])
    $r.Year | Should -Be 2026
    $r.Month | Should -Be 6
    $r.Day | Should -Be 9
  }
  It "mezcla de formatos: devuelve el más reciente entre ambos" {
    $txt = @"
2026-06-01 03:00:00 => old
Mon Jun 09 03:00:01 2026 => Inventory sent
"@
    $r = Get-OcsLastInventoryFromLog $txt
    $r.Day | Should -Be 9
  }
  It "texto sin timestamps → null" {
    Get-OcsLastInventoryFromLog "Inventory sent, no date here" | Should -Be $null
  }
}
