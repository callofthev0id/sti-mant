# Pester 5. Logica pura de la GUI (gui/lib/gui-logic.ps1).
BeforeAll {
  . "$PSScriptRoot/../lib/common.ps1"
  . "$PSScriptRoot/../gui/lib/gui-logic.ps1"
}

Describe "Get-EquipoTipo" {
  It "server chassis -> servidores" {
    Get-EquipoTipo -FormFactor 'server' -SoClase 'Server' | Should -Be 'servidores'
  }
  It "desktop -> terminales" {
    Get-EquipoTipo -FormFactor 'desktop' -SoClase 'Win11' | Should -Be 'terminales'
  }
  It "laptop -> terminales" {
    Get-EquipoTipo -FormFactor 'laptop' -SoClase 'Win10' | Should -Be 'terminales'
  }
  It "vm con Windows Server -> servidores" {
    Get-EquipoTipo -FormFactor 'vm' -SoClase 'Server' | Should -Be 'servidores'
  }
  It "vm con Windows de escritorio -> terminales" {
    Get-EquipoTipo -FormFactor 'vm' -SoClase 'Win11' | Should -Be 'terminales'
  }
  It "server chassis con SO de escritorio igual servidores (chassis manda)" {
    Get-EquipoTipo -FormFactor 'server' -SoClase 'Win10' | Should -Be 'servidores'
  }
}

Describe "Test-IdentificacionValida" {
  It "TAG vacio -> no valido" {
    (Test-IdentificacionValida -Tag '' -Cliente 'Empresa').ok | Should -BeFalse
  }
  It "TAG presente -> valido" {
    (Test-IdentificacionValida -Tag 'MULTI' -Cliente 'Empresa').ok | Should -BeTrue
  }
  It "TAG con solo espacios -> no valido" {
    (Test-IdentificacionValida -Tag '   ' -Cliente '').ok | Should -BeFalse
  }
}

Describe "Get-RelevarLabel" {
  It "terminales" { Get-RelevarLabel 'terminales' | Should -Be 'Relevar terminal' }
  It "servidores" { Get-RelevarLabel 'servidores' | Should -Be 'Relevar servidor' }
}

Describe "New-GuiMantArgs" {
  It "mapea los campos al contrato de New-MantContext" {
    $a = New-GuiMantArgs -Tag 'MULTI' -Cliente 'Empresa SA' -Usuario 'Carlos · Ventas' -Nota '' -ScriptDir 'C:\x'
    $a.Tag       | Should -Be 'MULTI'
    $a.Cliente   | Should -Be 'Empresa SA'
    $a.Usuario   | Should -Be 'Carlos · Ventas'
    $a.ScriptDir | Should -Be 'C:\x'
    $a.InstallOcs | Should -BeFalse
  }
  It "InstallOcs siempre false (Relevar no instala OCS)" {
    (New-GuiMantArgs -Tag 'X' -Cliente '' -Usuario '' -Nota '' -ScriptDir 'C:\x').InstallOcs | Should -BeFalse
  }
}
