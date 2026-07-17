# Pester 5. Logica pura de la tab Inventario (gui/lib/gui-tab-inventario.ps1) con fixtures
# (sin WMI ni WPF) + carga WPF real (STA) de la ventana entera con el panel integrado.
BeforeAll {
  . "$PSScriptRoot/../gui/lib/gui-tab-inventario.ps1"
  . "$PSScriptRoot/../gui/lib/gui-theme.ps1"
  . "$PSScriptRoot/../gui/lib/gui-branding.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-utilidades.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-generar.ps1"
  . "$PSScriptRoot/../gui/lib/gui-tab-mantenimiento.ps1"
  . "$PSScriptRoot/../gui/lib/gui-xaml.ps1"

  # Fixture completo: un modelo de inventario tipico (forma de New-InventarioModel).
  $script:invFull = @{
    so = @{ caption = 'Windows 11 Pro'; version = '10.0.26100'; build = '26100'; arch = '64-bit';
            instalado = (Get-Date).AddYears(-2); ultimoBoot = (Get-Date).AddDays(-3).AddHours(-5) }
    equipo = @{ fabricante = 'Dell Inc.'; modelo = 'OptiPlex 3080' }
    cpu = @{ modelo = 'Intel Core i5-10400'; nucleos = 6; logicos = 12; mhz = 4300 }
    ram = @{ totalGB = 16; modulos = @(
      @{ gb = 8; mhz = 2666; slot = 'DIMM A1'; fabricante = 'Kingston' },
      @{ gb = 8; mhz = 2666; slot = 'DIMM B1'; fabricante = 'Kingston' }
    )}
    discos = @(
      @{ modelo = 'Samsung SSD 870'; gb = 500; tipo = 'SSD' },
      @{ modelo = 'WDC WD10EZEX'; gb = 1000; tipo = 'HDD' }
    )
    obsolescencia = @{
      soFinSoporte = @{ etiqueta = 'Windows 11 24H2'; eol = $null }
      bios = @{ version = '2.4.1'; fecha = '03/2021'; antiguedadAnios = 5 }
      tpm = @{ presente = $true; version = '2.0' }
      secureBoot = $false
      win11Apto = @{ apto = $true; faltan = @() }
    }
    contexto = @{
      red = @(@{ adaptador = 'Ethernet'; ip = '192.0.2.10'; gateway = '192.0.2.1'; dns = '8.8.8.8'; velocidad = '1 Gbps'; dhcp = $true })
      dominio = @{ dominio = 'WORKGROUP'; enDominio = $false }
      ultimoUpdate = @{ id = 'KB5044284'; fecha = (Get-Date).AddDays(-6) }
    }
    salud = @{ bsod = @{ minidumps = 0; ultimo = $null }; apagadosInesperados30d = 0 }
    hardwareIds = @{ mac = @('AA-BB-CC-DD-EE-FF'); disk_serial = @('S1','S2') }
  }
  # Fixture parcial: secciones nuevas en null (defensivo, como cuando un collector falla).
  $script:invMin = @{
    so = @{ caption = 'Windows 10 Pro'; version = '10.0.19045'; build = '19045'; arch = '64-bit'; ultimoBoot = $null }
    equipo = @{ fabricante = ''; modelo = '' }
    cpu = @{ modelo = 'AMD Ryzen 5'; nucleos = 6; logicos = 12; mhz = $null }
    ram = @{ totalGB = 8; modulos = @() }
    discos = @()
    obsolescencia = $null; contexto = $null; salud = $null
    hardwareIds = @{ mac = @(); disk_serial = @() }
  }
}

Describe "Get-InvDato" {
  It "null -> s/d" { Get-InvDato $null | Should -Be 's/d' }
  It "vacio -> s/d" { Get-InvDato '   ' | Should -Be 's/d' }
  It "valor con sufijo" { Get-InvDato 16 ' GB' | Should -Be '16 GB' }
}

Describe "Get-InvUptime" {
  It "boot null -> s/d" { Get-InvUptime $null | Should -Be 's/d' }
  It "boot hace 3 dias incluye 'd'" {
    Get-InvUptime ((Get-Date).AddDays(-3)) | Should -Match 'd'
  }
}

Describe "Get-InvSemBrush" {
  It "Ok -> AppAccent" { Get-InvSemBrush 'Ok' | Should -Be 'AppAccent' }
  It "Advertencia -> AppAmbar" { Get-InvSemBrush 'Advertencia' | Should -Be 'AppAmbar' }
  It "Critico -> AppRojo" { Get-InvSemBrush 'Critico' | Should -Be 'AppRojo' }
  It "desconocido -> AppNa" { Get-InvSemBrush 'X' | Should -Be 'AppNa' }
}

Describe "Get-InvEolEstado" {
  It "soportado con EOL lejano (2031) -> Ok, no Critico" {
    $r = Get-InvEolEstado @{ eol = '2031-10-14'; soportado = $true } -Ahora ([datetime]'2026-06-22')
    $r.estado | Should -Be 'Ok'
    $r.tono   | Should -Be 'good'
  }
  It "fuera de soporte -> Critico" {
    $r = Get-InvEolEstado @{ eol = '2025-10-14'; soportado = $false } -Ahora ([datetime]'2026-06-22')
    $r.estado | Should -Be 'Critico'
    $r.tono   | Should -Be 'bad'
  }
  It "EOL dentro de ~6 meses -> Advertencia" {
    $r = Get-InvEolEstado @{ eol = '2026-10-14'; soportado = $true } -Ahora ([datetime]'2026-06-22')
    $r.estado | Should -Be 'Advertencia'
    $r.tono   | Should -Be 'warn'
  }
  It "soportado=null (sin mapeo) -> Ok neutro" {
    $r = Get-InvEolEstado @{ eol = $null; soportado = $null }
    $r.estado | Should -Be 'Ok'
    $r.tono   | Should -Be ''
  }
  It "soFinSoporte null -> Ok neutro, no rompe" {
    $r = Get-InvEolEstado $null
    $r.estado | Should -Be 'Ok'
  }
}

Describe "Get-InvCardSistema fin de soporte" {
  It "SO soportado con EOL 2031 no marca la card Critico" {
    $inv = @{
      so = @{ caption = 'Windows 11 Pro'; version = '10.0.26100'; build = '26100'; arch = '64-bit'; ultimoBoot = $null }
      equipo = @{}; cpu = @{}; ram = @{ modulos = @() }; discos = @()
      obsolescencia = @{ soFinSoporte = @{ etiqueta = 'soportado'; eol = '2031-10-14'; soportado = $true } }
      contexto = $null; salud = $null
    }
    (Get-InvCardSistema $inv).estado | Should -Not -Be 'Critico'
  }
  It "SO fuera de soporte marca la card Critico" {
    $inv = @{
      so = @{ caption = 'Windows 7'; version = '6.1'; build = '7601'; arch = '64-bit'; ultimoBoot = $null }
      equipo = @{}; cpu = @{}; ram = @{ modulos = @() }; discos = @()
      obsolescencia = @{ soFinSoporte = @{ etiqueta = 'FUERA DE SOPORTE'; eol = '2020-01-14'; soportado = $false } }
      contexto = $null; salud = $null
    }
    (Get-InvCardSistema $inv).estado | Should -Be 'Critico'
  }
}

Describe "Get-InvCardSistema" {
  It "arma titulo y dos columnas" {
    $c = Get-InvCardSistema $script:invFull
    $c.titulo | Should -Be 'Windows 11 Pro'
    @($c.cols).Count | Should -Be 2
  }
  It "expone build y arquitectura crudos" {
    $c = Get-InvCardSistema $script:invFull
    $kv = @($c.cols[0].kv)
    ($kv | Where-Object { $_.k -eq 'Build' }).v | Should -Be '26100'
    ($kv | Where-Object { $_.k -eq 'Arquitectura' }).v | Should -Be '64-bit'
  }
  It "campos pendientes de collector quedan s/d" {
    $c = Get-InvCardSistema $script:invFull
    $kv = @($c.cols[0].kv)
    ($kv | Where-Object { $_.k -eq 'Activación' }).v | Should -Be 's/d'
  }
  It "con obsolescencia null no rompe" {
    { Get-InvCardSistema $script:invMin } | Should -Not -Throw
  }
}

Describe "Get-InvCardCpu" {
  It "deriva clock max en GHz" {
    $c = Get-InvCardCpu $script:invFull
    ($c.cols[0].kv | Where-Object { $_.k -eq 'Clock máx' }).v | Should -Be '4.3 GHz'
  }
  It "mhz null -> Clock max s/d" {
    $c = Get-InvCardCpu $script:invMin
    ($c.cols[0].kv | Where-Object { $_.k -eq 'Clock máx' }).v | Should -Be 's/d'
  }
}

Describe "Get-InvCardRam" {
  It "una fila por modulo presente" {
    $c = Get-InvCardRam $script:invFull
    @($c.modulos).Count | Should -Be 2
    $c.modulos[0].gb | Should -Be '8 GB'
  }
  It "sin modulos no rompe" {
    { Get-InvCardRam $script:invMin } | Should -Not -Throw
    @((Get-InvCardRam $script:invMin).modulos).Count | Should -Be 0
  }
}

Describe "Get-InvCardsDiscos" {
  It "una card por disco fisico" {
    $d = @(Get-InvCardsDiscos $script:invFull)
    $d.Count | Should -Be 2
    $d[0].titulo | Should -Be 'Samsung SSD 870'
  }
  It "SMART crudo queda s/d (collector pendiente)" {
    $d = @(Get-InvCardsDiscos $script:invFull)
    ($d[0].cols[1].kv | Where-Object { $_.k -eq 'Reallocated' }).v | Should -Be 's/d'
  }
  It "sin discos -> array vacio" {
    @(Get-InvCardsDiscos $script:invMin).Count | Should -Be 0
  }
}

Describe "Get-InvCardMboard" {
  It "secure boot off -> estado Advertencia y tono bad" {
    $c = Get-InvCardMboard $script:invFull
    $c.estado | Should -Be 'Advertencia'
    ($c.cols[1].kv | Where-Object { $_.k -eq 'Secure Boot' }).v | Should -Be 'desactivado'
  }
  It "obsolescencia null no rompe" {
    { Get-InvCardMboard $script:invMin } | Should -Not -Throw
  }
}

Describe "Get-InvCardsRed" {
  It "una card por adaptador" {
    $r = @(Get-InvCardsRed $script:invFull)
    $r.Count | Should -Be 1
    ($r[0].cols[1].kv | Where-Object { $_.k -eq 'IP' }).v | Should -Be '192.0.2.10'
  }
  It "dhcp se mapea a si/no" {
    $r = @(Get-InvCardsRed $script:invFull)
    ($r[0].cols[1].kv | Where-Object { $_.k -eq 'DHCP' }).v | Should -Be 'sí'
  }
  It "contexto null -> array vacio" {
    @(Get-InvCardsRed $script:invMin).Count | Should -Be 0
  }
}

Describe "Get-InvModel" {
  It "rollup con contador de discos real" {
    $m = Get-InvModel $script:invFull
    $m.nDiscos | Should -Be 2
    @($m.discos).Count | Should -Be 2
    $m.sistema | Should -Not -BeNullOrEmpty
    $m.cpu | Should -Not -BeNullOrEmpty
  }
}

# Carga WPF real: la ventana entera (con el panel Inventario integrado) carga y los x:Name
# del panel se encuentran. Solo Windows+WPF, en runspace STA.
Describe "PanelInventario (carga WPF real)" {
  $script:wpfOk = $false
  try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop; $script:wpfOk = $true } catch {}

  It "XamlReader.Load instancia la ventana y los hosts del panel se encuentran" -Skip:(-not $script:wpfOk) {
    $libDir = "$PSScriptRoot/../gui/lib"
    $xaml = New-AppWindowXaml -Hostname 'CLAUDE' -Version '1.0'
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript({
      param($x)
      Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
      $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
      $w = [Windows.Markup.XamlReader]::Load($r)
      $names = 'InvSistemaHost','InvCpuHost','InvRamHost','InvDiscosHost','InvMboardHost','InvRedHost','InvVacio','InvDiscosTitulo'
      [bool]($w -and -not (@($names | Where-Object { -not $w.FindName($_) })))
    }).AddArgument($xaml)
    $res = $ps.Invoke()
    $err = $ps.Streams.Error
    $ps.Dispose(); $rs.Close(); $rs.Dispose()
    $err.Count | Should -Be 0
    $res[0] | Should -BeTrue
  }
}
