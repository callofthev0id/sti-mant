BeforeAll {
  . "$PSScriptRoot/../lib/score.ps1"
  . "$PSScriptRoot/../lib/informe-model.ps1"
  $script:fx = "$PSScriptRoot/__fixtures__"
}
Describe "Read-Relevamientos" {
  It "lee los JSON terminales de la carpeta" {
    $r = Read-Relevamientos -Carpeta $fx -Tipo 'terminales'
    $r.Count | Should -Be 2
    (($r | ForEach-Object { $_.meta.hostname }) -contains 'PC-OK') | Should -BeTrue
  }
}
Describe "Build-InformeModel" {
  It "arma kpis, atencion y observaciones" {
    $eq = Read-Relevamientos -Carpeta $fx -Tipo 'terminales'
    $m = Build-InformeModel -Equipos $eq -Tipo 'terminales'
    $m.cliente | Should -Be 'DEMO'
    $m.kpis.total | Should -Be 2
    (($m.atencion | Where-Object { $_.estado -eq 'Crítico' }).label) | Should -Be 'Estado disco (SMART)'
    $err = $m.equipos | Where-Object { $_.hostname -eq 'PC-ERR' }
    $err.observaciones | Should -Match 'HDD en falla'
    $err.usuario | Should -Be 'Beto'
  }
}
