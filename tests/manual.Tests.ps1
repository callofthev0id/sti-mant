# Pester 5. Carga de checks manuales (lib/manual.ps1).
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
  . "$PSScriptRoot/../lib/output.ps1"
  . "$PSScriptRoot/../lib/manual.ps1"
}

Describe "ConvertTo-ManualEstado" {
  It "mapea teclas a estados" {
    ConvertTo-ManualEstado "O" | Should -Be "Ok"
    ConvertTo-ManualEstado "a" | Should -Be "Advertencia"   # case-insensitive
    ConvertTo-ManualEstado "E" | Should -Be "Error"
    ConvertTo-ManualEstado "C" | Should -Be "Crítico"
    ConvertTo-ManualEstado "N" | Should -Be "N/A"
  }
  It "Enter o tecla inválida → null (no cambia)" {
    ConvertTo-ManualEstado ""  | Should -BeNullOrEmpty
    ConvertTo-ManualEstado "x" | Should -BeNullOrEmpty
  }
}

Describe "Invoke-ManualCapture (no interactivo via -Answers)" {
  It "carga estado+nota en los checks manuales y deja los auto intactos" {
    $rel = @{
      items = @(
        (New-CheckItem -Key "chk_firewall"        -Label "Firewall"        -Status "Ok"  -Automated $true),
        (New-CheckItem -Key "chk_hardware_visual" -Label "Hardware visual" -Status "N/A" -Automated $false -Detail "inspección manual"),
        (New-CheckItem -Key "chk_ups"             -Label "UPS"             -Status "N/A" -Automated $false)
      )
    }
    $answers = @{
      chk_hardware_visual = @{ estado = "Ok";          nota = "sin daños visibles" }
      chk_ups             = @{ estado = "Advertencia"; nota = "UPS sin batería de respaldo" }
    }
    Invoke-ManualCapture -Rel $rel -Answers $answers

    $hv  = $rel.items | Where-Object { $_.key -eq "chk_hardware_visual" }
    $ups = $rel.items | Where-Object { $_.key -eq "chk_ups" }
    $fw  = $rel.items | Where-Object { $_.key -eq "chk_firewall" }
    $hv.status  | Should -Be "Ok"
    $hv.detail  | Should -Be "sin daños visibles"
    $ups.status | Should -Be "Advertencia"
    $fw.status  | Should -Be "Ok"          # auto intacto
  }

  It "el TSV refleja el veredicto manual cargado" {
    $rel = @{
      items = @(
        (New-CheckItem -Key "chk_hardware_visual" -Label "Hardware visual" -Status "N/A" -Automated $false)
      )
    }
    Invoke-ManualCapture -Rel $rel -Answers @{ chk_hardware_visual = @{ estado = "Error" } }
    $cells = (ConvertTo-MantTsv -Items $rel.items -Order $CHK_ORDER_TERM) -split "`t"
    # chk_hardware_visual está en el orden de CHK_ORDER_TERM
    $idx = [array]::IndexOf($CHK_ORDER_TERM, "chk_hardware_visual")
    $cells[$idx] | Should -Be "Error"
  }
}
