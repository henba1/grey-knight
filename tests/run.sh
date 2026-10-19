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
  # report() exits; "cquit 2" only runs when the suite crashed before it (a crash is not a pass)
  timeout 900 nvim --headless -c "luafile $suite" -c 'cquit 2' || status=1
done
echo
[ $status -eq 0 ] && echo "ALL SUITES PASSED" || echo "SOME TESTS FAILED"
exit $status
