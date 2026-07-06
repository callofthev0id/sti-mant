# lib/runspace.ps1 - corre las funciones de módulo en paralelo (Runspace Pool).
# Inyecta en cada runspace las funciones helper + de módulo + la variable $THR
# desde la sesión actual (funciona igual con módulos dot-sourced o con el dist single-file).

function Invoke-ModulesParallel {
  param([hashtable]$Ctx, [string[]]$FnNames, [int]$MaxThreads = 5)

  $helpers = @('New-CheckItem','Get-NormalizedMac','Get-CleanSerial','Get-OsClass',
               'Get-StatusByDays','Get-StatusByPct','Get-StatusBool','Get-StatusVss',
               'Find-CobianInstall','Get-CobianRank','Get-CobianCadencia','ConvertTo-CobianEstado',
               'Get-PeorCobianEstado','Get-CobianHistoryDb','Get-CobianLogStatus','Get-CobianBackupStatus',
               'ConvertTo-AcronisEstado','Find-AcronisInstall','Get-AcronisLastBackupEvent','Get-AcronisBackupStatus',
               'Get-BackupCheckItem',
               'Get-OcsLastInventoryFromLog','Get-OcsInventoryStatus')
  $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

  foreach ($n in ($helpers + $FnNames)) {
    $cmd = Get-Command $n -CommandType Function -ErrorAction SilentlyContinue
    if ($cmd) {
      $iss.Commands.Add(
        (New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($n, $cmd.Definition)))
    }
  }
  foreach ($vn in @('THR')) {
    $v = Get-Variable $vn -ErrorAction SilentlyContinue
    if ($v) {
      $iss.Variables.Add(
        (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry($vn, $v.Value, '')))
    }
  }

  $pool = [runspacefactory]::CreateRunspacePool(1, [Math]::Max(1, [Math]::Min($MaxThreads, $FnNames.Count)), $iss, $Host)
  $pool.Open()
  try {
    $jobs = foreach ($fn in $FnNames) {
      $ps = [powershell]::Create()
      $ps.RunspacePool = $pool
      [void]$ps.AddScript('param($fn,$ctx) & $fn -Ctx $ctx').AddArgument($fn).AddArgument($Ctx)
      @{ ps = $ps; handle = $ps.BeginInvoke(); fn = $fn }
    }
    $results = @()
    foreach ($j in $jobs) {
      try { $results += $j.ps.EndInvoke($j.handle) }
      catch { Write-Warning "Runspace $($j.fn) fallo: $($_.Exception.Message)" }
      finally { $j.ps.Dispose() }
    }
    $results
  } finally { $pool.Close(); $pool.Dispose() }
}
