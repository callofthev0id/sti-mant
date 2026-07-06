# Pester 5. Puente UI<->background del relevamiento (gui/lib/gui-runspace.ps1).
# El runspace de fondo arranca con un InitialSessionState que captura las funciones del proceso
# (New-CoreInitialSessionState). Por eso NO dot-sourcea por ruta: funciona igual en dev y en el
# dist single-file. Estos tests definen un Invoke-Relevamiento fake en la sesion para que el ISS
# lo capture y verifican que los argumentos (Ctx, Tipo) cruzan el limite del runspace.
BeforeAll {
  . "$PSScriptRoot/../gui/lib/gui-runspace.ps1"
}
Describe "Start/Receive RelevamientoAsync (con fake)" {
  It "corre en background con el core inyectado por ISS y los argumentos (Ctx, Tipo) cruzan el runspace" {
    # Fake en la sesion actual: New-CoreInitialSessionState lo captura y lo inyecta al runspace
    # de fondo. Si la inyeccion por ISS no funcionara, Invoke-Relevamiento no existiria adentro.
    function Invoke-Relevamiento {
      param($Ctx, [string]$Tipo = 'terminales', [switch]$Sequential)
      @{ modules = @(); items = @(@{ key='k'; status='Ok' }); errors = @();
         hw = @{ hostname = $Ctx.tag }; ecoTipo = $Tipo }
    }
    $job = Start-RelevamientoAsync -Ctx @{ tag = 'CLAUDE' } -Tipo 'terminales' -ScriptDir 'C:\probe'
    $r = $null
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
      $r = Receive-RelevamientoResult -Job $job
      if ($r.done) { break }
      Start-Sleep -Milliseconds 100
    }
    $r.done | Should -BeTrue
    $r.rel.items[0].status | Should -Be 'Ok'
    $r.rel.hw.hostname | Should -Be 'CLAUDE'      # $Ctx cruzo
    $r.rel.ecoTipo | Should -Be 'terminales'      # $Tipo cruzo
  }
  It "devuelve error cuando el relevamiento tira excepcion" {
    function Invoke-Relevamiento {
      param($Ctx, [string]$Tipo = 'terminales', [switch]$Sequential)
      throw 'boom'
    }
    $job = Start-RelevamientoAsync -Ctx @{ x = 1 } -Tipo 'terminales' -ScriptDir 'C:\x'
    $r = $null
    $deadline = (Get-Date).AddSeconds(15)
    while ((Get-Date) -lt $deadline) {
      $r = Receive-RelevamientoResult -Job $job
      if ($r.done) { break }
      Start-Sleep -Milliseconds 100
    }
    $r.done | Should -BeTrue
    $r.error | Should -Match 'boom'
    $r.rel | Should -BeNullOrEmpty
  }
}
