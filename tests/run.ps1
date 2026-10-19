# Grey Knight tests on Windows (PowerShell 5.1+). Exit status 1 when a test failed.
#   tests\run.ps1                all suites
#   tests\run.ps1 devsuite       only tests\devsuite_test.lua
# Each suite runs in a real, minimized Neovim window: a headless Neovim on Windows shows no output of
# terminal jobs (ConPTY), so tasks, the REPL and debugging could not be tested there. The harness writes
# the report to $env:GK_TEST_REPORT instead of stdout.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Suites)
if (-not $Suites) { $Suites = @('smoke', 'devsuite') }

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$nvim = (Get-Command nvim).Source
$encoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$status = 0
try {
  foreach ($suite in $Suites) {
    $report = Join-Path ([IO.Path]::GetTempPath()) "greyknight-$suite-report.txt"
    Remove-Item $report -ErrorAction SilentlyContinue
    $env:GK_TEST_REPORT = $report
    $nvimArgs = "-c `"luafile tests/${suite}_test.lua`" -c `"cquit 2`""
    $p = Start-Process -FilePath $nvim -ArgumentList $nvimArgs -WorkingDirectory $root -WindowStyle Minimized -PassThru
    $null = $p.Handle # keeps the exit code readable after the process ended
    if (-not $p.WaitForExit(900000)) {
      $p.Kill()
      Write-Output "${suite}: stopped after 15 minutes"
      $status = 1
      continue
    }
    if (Test-Path $report) { Get-Content -Encoding UTF8 $report } else { Write-Output "${suite}: no report (the suite crashed)" }
    if ($p.ExitCode -ne 0) { $status = 1 }
  }
} finally {
  Remove-Item Env:GK_TEST_REPORT -ErrorAction SilentlyContinue
  [Console]::OutputEncoding = $encoding
}
Write-Output ''
if ($status -eq 0) { Write-Output 'ALL SUITES PASSED' } else { Write-Output 'SOME TESTS FAILED' }
exit $status
