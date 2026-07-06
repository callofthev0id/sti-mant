# Pester 5. ConvertTo-MantTsv (puro) + Get-SemColor.
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
  . "$PSScriptRoot/../lib/output.ps1"
}

Describe "ConvertTo-MantTsv" {
  It "emite en el orden del column-spec, semi/faltante vacío" {
    $items = @(
      (New-CheckItem -Key "chk_firewall" -Label "f" -Status "Ok"),
      (New-CheckItem -Key "chk_cuentas_sti" -Label "c" -Status "Error"),
      (New-CheckItem -Key "chk_visor_eventos" -Label "v" -Status $null)
    )
    $tsv = ConvertTo-MantTsv -Items $items -Order $CHK_ORDER_TERM
    $cells = $tsv -split "`t"
    $cells.Count | Should -Be 26
    $cells[0] | Should -Be "Error"   # chk_cuentas_sti (idx 0)
    $cells[1] | Should -Be "Ok"      # chk_firewall (idx 1)
    $cells[5] | Should -Be ""        # chk_visor_eventos (idx 5, semi → vacío)
  }
  It "servidores usa su propio orden de 19" {
    $items = @( (New-CheckItem -Key "srv_firewall" -Label "f" -Status "Crítico") )
    $cells = (ConvertTo-MantTsv -Items $items -Order $CHK_ORDER_SRV) -split "`t"
    $cells.Count | Should -Be 19
    $cells[1] | Should -Be "Crítico"   # srv_firewall (idx 1)
  }
}

Describe "Get-SemColor" {
  It "mapea estados a paleta STI" {
    Get-SemColor "Ok"          | Should -Be "#43C961"
    Get-SemColor "Advertencia" | Should -Be "#F2C03D"
    Get-SemColor "Error"       | Should -Be "#E07820"
    Get-SemColor "Crítico"     | Should -Be "#F05754"
    Get-SemColor "N/A"         | Should -Be "#C8C8C8"
    Get-SemColor ""            | Should -Be "#C8C8C8"
  }
}

Describe "New-HtmlReport escapa datos del equipo (XSS)" {
  It "escapa caracteres especiales en hostname, contexto y checks" {
    $ctx = @{
      cliente = "ACME <b>&""'"  # cliente con < > & " '
      os = @{ caption = 'Win <11>' }
      formFactor = 'desktop'
    }
    $hw = @{
      hostname = 'PC-<script>alert(1)</script>'
      os_uuid = 'u&u'; disk_serial = @('SN<"1>'); hw_uuid = 'h"u'
      mac = @('AA:BB'); bios_serial = "b'ios"
    }
    $modules = @(
      @{ category = 'Cat & <x>'; items = @(
          (New-CheckItem -Key 'k1' -Label 'Label <i>' -Status 'Ok' -Detail "obs con <script> & ""comillas"" 'simple'")
      )}
    )
    $out = New-HtmlReport -Ctx $ctx -Modules $modules -HwIds $hw -Tipo 'terminales'
    try {
      $html = Get-Content -LiteralPath $out -Raw

      # Ningún metacaracter crudo proveniente de datos: no debe existir <script> literal del payload
      $html | Should -Not -Match '<script>alert\(1\)</script>'
      # El payload aparece escapado
      $html | Should -Match '&lt;script&gt;alert\(1\)&lt;/script&gt;'
      # Comilla simple del bios_serial escapada
      $html | Should -Match "b&#39;ios"
      # Ampersand del cliente escapado
      $html | Should -Match 'ACME &lt;b&gt;&amp;'
      # Categoría escapada
      $html | Should -Match 'Cat &amp; &lt;x&gt;'
    } finally { if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force } }
  }
}
