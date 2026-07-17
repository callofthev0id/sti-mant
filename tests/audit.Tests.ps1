# Pester 5. Subsistema de auditoria (lib/audit.ps1). Verifica el armado del registro, las tres
# salidas (Event Log + JSON-lines + texto) con cmdlets mockeados, la lectura de recientes y el
# formato de panel. No escribe al Event Log real ni al disco real en los tests unitarios (mocks).
BeforeAll {
  . "$PSScriptRoot/../lib/audit.ps1"
}

Describe "New-AuditRecord" {
  It "arma los campos estructurados con timestamp ISO y auto-detecta tecnico/host" {
    $r = New-AuditRecord -Accion 'apply' -UtilId 'faststartup' -UtilLabel 'Fast Startup' -Categoria 'tweaks' -EstadoAnterior 'activo' -EstadoNuevo 'apagado' -Resultado 'ok'
    $r.accion          | Should -Be 'apply'
    $r.util_id         | Should -Be 'faststartup'
    $r.util_label      | Should -Be 'Fast Startup'
    $r.categoria       | Should -Be 'tweaks'
    $r.estado_anterior | Should -Be 'activo'
    $r.estado_nuevo    | Should -Be 'apagado'
    $r.timestamp       | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'
    $r.tecnico         | Should -Not -BeNullOrEmpty
    $r.hostname        | Should -Not -BeNullOrEmpty
  }
  It "respeta tecnico/host explicitos" {
    $r = New-AuditRecord -Accion 'scan' -Tecnico 'jdoe' -Hostname 'PC01'
    $r.tecnico | Should -Be 'jdoe'; $r.hostname | Should -Be 'PC01'
  }
}

Describe "Get-AuditEventId / EntryType" {
  It "mapea accion -> eventId estable" {
    Get-AuditEventId -Accion 'scan'  | Should -Be 1001
    Get-AuditEventId -Accion 'apply' | Should -Be 1002
    Get-AuditEventId -Accion 'undo'  | Should -Be 1003
    Get-AuditEventId -Accion 'safety'| Should -Be 1004
  }
  It "mapea resultado -> EntryType" {
    Get-AuditEntryType -Resultado 'ok'            | Should -Be 'Information'
    Get-AuditEntryType -Resultado 'error: x'      | Should -Be 'Error'
    Get-AuditEntryType -Resultado 'aviso: revisar'| Should -Be 'Warning'
  }
}

Describe "Format-AuditTextLine" {
  It "arma una linea humana con util, transicion y resultado" {
    $rec = New-AuditRecord -Accion 'apply' -UtilId 'faststartup' -UtilLabel 'Fast Startup' -EstadoAnterior 'activo' -EstadoNuevo 'apagado' -Resultado 'ok' -Tecnico 't' -Hostname 'h'
    $line = Format-AuditTextLine -Record $rec
    $line | Should -Match 'APPLY'
    $line | Should -Match 'Fast Startup \[faststartup\]'
    $line | Should -Match 'activo -> apagado'
    $line | Should -Match 't@h'
  }
}

Describe "Write-Audit (tres salidas, mockeadas)" {
  It "escribe Event Log + JSON-lines + texto cuando todo esta disponible" {
    Mock Initialize-AuditEventSource { $true }
    Mock Write-EventLog {}
    Mock Initialize-AuditStore { $true }
    $script:__json = $null; $script:__text = $null
    Mock Add-Content {
      if ($Path -match 'jsonl') { $script:__json = $Value } else { $script:__text = $Value }
    }
    $out = Write-Audit -Accion 'apply' -UtilId 'telemetria' -UtilLabel 'Telemetria' -Categoria 'tweaks' -EstadoAnterior 'activa' -EstadoNuevo 'apagada' -Resultado 'ok'
    $out.eventlog | Should -BeTrue
    $out.json     | Should -BeTrue
    $out.texto    | Should -BeTrue
    Should -Invoke Write-EventLog -Times 1 -Exactly
    # el JSON-lines es un objeto JSON valido con los campos clave
    $obj = $script:__json | ConvertFrom-Json
    $obj.util_id | Should -Be 'telemetria'
    $obj.accion  | Should -Be 'apply'
    $script:__text | Should -Match 'telemetria'
  }
  It "degrada sin Event Log (no admin) pero igual escribe los archivos" {
    Mock Initialize-AuditEventSource { $false }
    Mock Write-EventLog { throw 'no source' }
    Mock Initialize-AuditStore { $true }
    Mock Add-Content {}
    $out = Write-Audit -Accion 'scan' -Resultado 'ok'
    $out.eventlog | Should -BeFalse
    $out.json     | Should -BeTrue
    $out.texto    | Should -BeTrue
  }
  It "no tira si los archivos fallan (best-effort)" {
    Mock Initialize-AuditEventSource { $false }
    Mock Initialize-AuditStore { $false }
    Mock Add-Content { throw 'sin permiso' }
    { Write-Audit -Accion 'apply' -UtilId 'x' } | Should -Not -Throw
  }
}

Describe "Get-AuditRecent" {
  It "devuelve array vacio si no hay archivo" {
    Mock Test-Path { $false }
    @(Get-AuditRecent).Count | Should -Be 0
  }
  It "lee las ultimas N entradas, mas recientes primero, salteando lineas corruptas" {
    Mock Test-Path { $true }
    $j1 = (New-AuditRecord -Accion 'apply' -UtilId 'a' | ConvertTo-Json -Compress)
    $j2 = (New-AuditRecord -Accion 'undo'  -UtilId 'b' | ConvertTo-Json -Compress)
    Mock Get-Content { @($j1, 'lineacorrupta{', $j2) }
    $r = @(Get-AuditRecent -Count 10)
    $r.Count | Should -Be 2          # la corrupta se saltea
    $r[0].util_id | Should -Be 'b'   # mas reciente primero
    $r[1].util_id | Should -Be 'a'
  }
}

Describe "Format-AuditPanelLine" {
  It "compacta el record a una linea legible" {
    $rec = [pscustomobject]@{ timestamp='2026-06-18T10:00:00-03:00'; accion='apply'; util_id='faststartup'; util_label='Fast Startup'; estado_anterior='activo'; estado_nuevo='apagado'; resultado='ok' }
    $line = Format-AuditPanelLine -Record $rec
    $line | Should -Match 'APPLY'
    $line | Should -Match 'Fast Startup'
    $line | Should -Match 'ok'
  }
}
