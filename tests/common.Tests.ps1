# Pester 5. Tests de las funciones PURAS de lib/common.ps1.
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
}

Describe "Get-NormalizedMac" {
  It "normaliza dash a colon uppercase" {
    Get-NormalizedMac "40-8d-5c-9d-15-ff" | Should -Be "40:8D:5C:9D:15:FF"
  }
  It "acepta ya-normalizada" {
    Get-NormalizedMac "F4:A8:0D:92:C0:55" | Should -Be "F4:A8:0D:92:C0:55"
  }
  It "filtra MAC virtual Hyper-V (00155D)" {
    Get-NormalizedMac "00:15:5D:01:02:03" | Should -BeNullOrEmpty
  }
  It "filtra basura corta" {
    Get-NormalizedMac "xx" | Should -BeNullOrEmpty
    Get-NormalizedMac "" | Should -BeNullOrEmpty
  }
}

Describe "Get-CleanSerial" {
  It "conserva serial real" {
    Get-CleanSerial "2NQR4Y2" | Should -Be "2NQR4Y2"
    Get-CleanSerial " pw06kyrp " | Should -Be "PW06KYRP"
  }
  It "descarta basura OEM y vacíos" {
    Get-CleanSerial "To Be Filled By O.E.M." | Should -BeNullOrEmpty
    Get-CleanSerial "-" | Should -BeNullOrEmpty
    Get-CleanSerial "" | Should -BeNullOrEmpty
  }
}

Describe "Get-OsClass" {
  It "clasifica versiones" {
    Get-OsClass "Microsoft Windows 11 Pro" | Should -Be "Win11"
    Get-OsClass "Microsoft Windows 10 Pro" | Should -Be "Win10"
    Get-OsClass "Microsoft Windows 7 Professional" | Should -Be "Win7"
    Get-OsClass "Microsoft Windows Server 2022 Standard" | Should -Be "Server"
    Get-OsClass "" | Should -Be "Otro"
  }
}

Describe "New-CheckItem" {
  It "arma el contrato" {
    $i = New-CheckItem -Key "chk_firewall" -Label "Firewall" -Status "Ok" -Automated $true -Detail "on"
    $i.key | Should -Be "chk_firewall"
    $i.status | Should -Be "Ok"
    $i.automated | Should -BeTrue
  }
}

Describe "CHK_ORDER" {
  It "terminales: 26 checks, orden correcto" {
    $CHK_ORDER_TERM.Count | Should -Be 26
    $CHK_ORDER_TERM[0]  | Should -Be "chk_cuentas_admin"
    $CHK_ORDER_TERM[-1] | Should -Be "chk_limpieza_temp"
  }
  It "servidores: 19 checks" {
    $CHK_ORDER_SRV.Count | Should -Be 19
    $CHK_ORDER_SRV[0]  | Should -Be "srv_cuentas_admin"
    $CHK_ORDER_SRV[-1] | Should -Be "srv_recursos_compartidos"
  }
}

Describe "ConvertTo-HtmlSafe" {
  It "escapa metacaracteres HTML (incluida comilla simple)" {
    ConvertTo-HtmlSafe '<script>alert(1)</script>' | Should -Be '&lt;script&gt;alert(1)&lt;/script&gt;'
    ConvertTo-HtmlSafe '&"' | Should -Be '&amp;&quot;'
    ConvertTo-HtmlSafe "a'b" | Should -Be 'a&#39;b'
  }
  It "escapa & antes que las entidades (no doble-escapa)" {
    ConvertTo-HtmlSafe '<' | Should -Be '&lt;'
    ConvertTo-HtmlSafe "PC&CO < ""x"" 'y'" | Should -Be 'PC&amp;CO &lt; &quot;x&quot; &#39;y&#39;'
  }
  It "no rompe texto normal" {
    ConvertTo-HtmlSafe 'Equipo-01' | Should -Be 'Equipo-01'
  }
}

Describe "FLEET_CUENTAS_ADMIN / Get-CuentasAdmin" {
  It "no trae nombres hardcodeados por default (sin entorno ni archivo)" {
    $old = $env:FLEET_CUENTAS_ADMIN
    $env:FLEET_CUENTAS_ADMIN = $null
    try {
      $r = Get-CuentasAdmin -LocalFile (Join-Path $TestDrive 'no-existe.local')
      @($r).Count | Should -Be 0
    } finally { $env:FLEET_CUENTAS_ADMIN = $old }
  }
  It "lee de la variable de entorno (coma/punto y coma)" {
    $old = $env:FLEET_CUENTAS_ADMIN
    $env:FLEET_CUENTAS_ADMIN = 'admin1, admin2;admin3'
    try {
      $r = @(Get-CuentasAdmin -LocalFile (Join-Path $TestDrive 'no-existe.local'))
      $r.Count | Should -Be 3
      $r[0] | Should -Be 'admin1'
      $r[2] | Should -Be 'admin3'
    } finally { $env:FLEET_CUENTAS_ADMIN = $old }
  }
  It "lee de archivo local (una por línea, ignora comentarios)" {
    $old = $env:FLEET_CUENTAS_ADMIN
    $env:FLEET_CUENTAS_ADMIN = $null
    $lf = Join-Path $TestDrive 'cuentas-admin.local'
    "# comentario`r`ncuentaA`r`n`r`ncuentaB" | Out-File -FilePath $lf -Encoding UTF8
    try {
      $r = @(Get-CuentasAdmin -LocalFile $lf)
      $r.Count | Should -Be 2
      $r[0] | Should -Be 'cuentaA'
      $r[1] | Should -Be 'cuentaB'
    } finally { $env:FLEET_CUENTAS_ADMIN = $old }
  }
}
