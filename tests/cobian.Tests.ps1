# Pester 5. Lógica pura de staleness de Cobian (lib/cobian.ps1). Now fijo.
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
  . "$PSScriptRoot/../lib/cobian.ps1"
  $script:NOW = [datetime]'2026-06-09T12:00:00'
}

Describe "ConvertTo-CobianEstado (staleness por frecuencia)" {
  It "diario al día (próximo en el futuro) → Ok" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-08T19:00:00') -NextDue ([datetime]'2026-06-09T19:00:00') -Sched 1 -HadErrors $false -Now $NOW | Should -Be 'Ok'
  }
  It "diario atrasado dentro de la tolerancia → Advertencia" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-07T19:00:00') -NextDue ([datetime]'2026-06-08T19:00:00') -Sched 1 -HadErrors $false -Now $NOW | Should -Be 'Advertencia'
  }
  It "diario vencido más de un ciclo → Crítico" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-06T19:00:00') -NextDue ([datetime]'2026-06-07T19:00:00') -Sched 1 -HadErrors $false -Now $NOW | Should -Be 'Crítico'
  }
  It "semanal vencido 3 días (grace 2, period 7) → Error" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-02T19:00:00') -NextDue ([datetime]'2026-06-06T12:00:00') -Sched 2 -HadErrors $false -Now $NOW | Should -Be 'Error'
  }
  It "semanal vencido 12 días → Crítico" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-05-21T19:00:00') -NextDue ([datetime]'2026-05-28T12:00:00') -Sched 2 -HadErrors $false -Now $NOW | Should -Be 'Crítico'
  }
  It "mensual con próximo en el futuro → Ok" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-01T19:00:00') -NextDue ([datetime]'2026-07-01T19:00:00') -Sched 3 -HadErrors $false -Now $NOW | Should -Be 'Ok'
  }
  It "sin corridas (LastRun null) → N/A" {
    ConvertTo-CobianEstado -LastRun $null -NextDue $null -Sched 1 -HadErrors $false -Now $NOW | Should -Be 'N/A'
  }
  It "errores en el log suben un Ok a Advertencia" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-08T19:00:00') -NextDue ([datetime]'2026-06-09T19:00:00') -Sched 1 -HadErrors $true -Now $NOW | Should -Be 'Advertencia'
  }
  It "sin NEXTBACKUP: último reciente → Ok; viejo → Error" {
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-08T00:00:00') -NextDue $null -Sched 1 -HadErrors $false -Now $NOW | Should -Be 'Ok'
    ConvertTo-CobianEstado -LastRun ([datetime]'2026-06-01T00:00:00') -NextDue $null -Sched 1 -HadErrors $false -Now $NOW | Should -Be 'Error'
  }
}

Describe "Get-PeorCobianEstado" {
  It "devuelve el peor de dos estados" {
    Get-PeorCobianEstado 'Ok' 'Error'          | Should -Be 'Error'
    Get-PeorCobianEstado 'Advertencia' 'Crítico'| Should -Be 'Crítico'
    Get-PeorCobianEstado $null 'Ok'             | Should -Be 'Ok'
  }
}

Describe "ConvertTo-AcronisEstado (staleness por antigüedad)" {
  It "backup de hoy → Ok" {
    ConvertTo-AcronisEstado -Last ([datetime]'2026-06-09T03:00:00') -Now $NOW | Should -Be 'Ok'
  }
  It "backup de hace 2 días (límite Ok) → Ok" {
    ConvertTo-AcronisEstado -Last ([datetime]'2026-06-07T12:00:00') -Now $NOW | Should -Be 'Ok'
  }
  It "backup de hace 4 días → Advertencia" {
    ConvertTo-AcronisEstado -Last ([datetime]'2026-06-05T12:00:00') -Now $NOW | Should -Be 'Advertencia'
  }
  It "backup de hace 10 días → Error" {
    ConvertTo-AcronisEstado -Last ([datetime]'2026-05-30T12:00:00') -Now $NOW | Should -Be 'Error'
  }
  It "sin fecha (null) → N/A" {
    ConvertTo-AcronisEstado -Last $null -Now $NOW | Should -Be 'N/A'
  }
  It "MinValue se trata como sin fecha → N/A" {
    ConvertTo-AcronisEstado -Last ([datetime]::MinValue) -Now $NOW | Should -Be 'N/A'
  }
  It "umbrales custom: OkMax=0 hace que ayer ya sea Advertencia" {
    ConvertTo-AcronisEstado -Last ([datetime]'2026-06-08T12:00:00') -Now $NOW -OkMax 0 -AdvMax 7 | Should -Be 'Advertencia'
  }
}

Describe "Find-AcronisInstall (detección sin falsos positivos)" {
  It "no confunde vmms (Hyper-V) con Acronis" {
    Mock Get-Service { @([pscustomobject]@{ Name='vmms'; DisplayName='Administración de máquinas virtuales de Hyper-V'; Status='Running' }) }
    Mock Test-Path { $false }
    (Find-AcronisInstall).installed | Should -Be $false
  }
  It "detecta el Managed Machine Service de Acronis" {
    Mock Get-Service { @([pscustomobject]@{ Name='mms'; DisplayName='Acronis Managed Machine Service'; Status='Running' }) }
    Mock Test-Path { $false }
    $r = Find-AcronisInstall
    $r.installed | Should -Be $true
    $r.service | Should -Match 'Acronis'
  }
  It "detecta por carpeta en Program Files aunque no haya servicio" {
    Mock Get-Service { @() }
    Mock Test-Path { param($LiteralPath) [bool]($LiteralPath -match 'Acronis') }
    (Find-AcronisInstall).installed | Should -Be $true
  }
}
