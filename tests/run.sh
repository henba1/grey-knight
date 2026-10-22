#!/usr/bin/env bash
# Runs the Grey Knight test suites headless. Exit status 1 when any test failed.
#   tests/run.sh               all suites
#   tests/run.sh devsuite      only tests/devsuite_test.lua
set -u
cd "$(dirname "$0")/.."
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH" # tree-sitter, qwen: as in an interactive shell

suites=(tests/smoke_test.lua tests/devsuite_test.lua)
[ $# -gt 0 ] && suites=("${@/#/tests/}") && suites=("${suites[@]/%/_test.lua}")

status=0
for suite in "${suites[@]}"; do
  trace=$(mktemp) # each test's name as it starts: after a crash the last one is where it happened
  # temp, state and cache folders of the run's own, deleted after it: what language servers and plugins leave
  # there - pyright's and tsserver's temp folders, lsp.log, dap.log, histories - is not the user's (2026-10-22)
  run=$(mktemp -d)
  mkdir -p "$run/tmp" "$run/state" "$run/cache"
  # report() exits; "cquit 2" only runs when the suite crashed before it (a crash is not a pass).
  # -i NONE: the user's ShaDa (history, recent files) neither read nor written (tests/harness.lua)
  GK_TEST_TRACE="$trace" GK_TEST_RUN_DIR="$run" TMPDIR="$run/tmp" XDG_STATE_HOME="$run/state" XDG_CACHE_HOME="$run/cache" \
    timeout 900 nvim -i NONE --headless -c "luafile $suite" -c 'cquit 2'
  rc=$?
  rm -rf "$run"
  if [ $rc -ne 0 ]; then
    status=1
    # not a failed test (1): it crashed or ran out of time
    [ $rc -ne 1 ] && [ -s "$trace" ] && echo "$suite: exit $rc - the last test that started: $(tail -n 1 "$trace")"
  fi
  rm -f "$trace"
done
echo
[ $status -eq 0 ] && echo "ALL SUITES PASSED" || echo "SOME TESTS FAILED"
exit $status
