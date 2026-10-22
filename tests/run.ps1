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
    # each test's name as it starts: when a suite ends without its report, the last one is where it happened
    $trace = Join-Path ([IO.Path]::GetTempPath()) "greyknight-$suite-trace.txt"
    Remove-Item $trace -ErrorAction SilentlyContinue
    $env:GK_TEST_TRACE = $trace
    $lastTest = { if (Test-Path $trace) { "  the last test that started: " + (Get-Content -Encoding UTF8 $trace -Tail 1) } }
    # -i NONE: the user's ShaDa (history, recent files) neither read nor written (tests/harness.lua)
    $nvimArgs = "-i NONE -c `"luafile tests/${suite}_test.lua`" -c `"cquit 2`""
    $p = Start-Process -FilePath $nvim -ArgumentList $nvimArgs -WorkingDirectory $root -WindowStyle Minimized -PassThru
    $null = $p.Handle # keeps the exit code readable after the process ended
    # The harness writes the report just before quitting: wait for it (at most 15 minutes), then for the exit
    $deadline = (Get-Date).AddMinutes(15)
    while (-not $p.HasExited -and -not (Test-Path $report) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    if (-not $p.WaitForExit(30000)) {
      # The whole tree: the window's Neovim and the --embed server it started (Kill() left those, 2026-10-21)
      & taskkill /T /F /PID $p.Id | Out-Null
      if (Test-Path $report) { Get-Content -Encoding UTF8 $report; Write-Output "${suite}: Neovim did not quit after its report" }
      else { Write-Output "${suite}: stopped after 15 minutes"; & $lastTest }
      $status = 1
      continue
    }
    if (Test-Path $report) { Get-Content -Encoding UTF8 $report }
    else { Write-Output "${suite}: no report (the suite crashed, exit $($p.ExitCode))"; & $lastTest }
    if ($p.ExitCode -ne 0) { $status = 1 }
  }
} finally {
  Remove-Item Env:GK_TEST_REPORT, Env:GK_TEST_TRACE -ErrorAction SilentlyContinue
  [Console]::OutputEncoding = $encoding
}
Write-Output ''
if ($status -eq 0) { Write-Output 'ALL SUITES PASSED' } else { Write-Output 'SOME TESTS FAILED' }
exit $status
