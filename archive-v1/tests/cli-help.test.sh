#!/usr/bin/env bash
# Contract tests for the public sf CLI help surface.

set -euo pipefail

help_output="$(bin/sf help)"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_help_contains() {
  local pattern="$1"
  if ! grep -Eq "$pattern" <<<"$help_output"; then
    fail "sf help should contain pattern: $pattern"
  fi
}

assert_help_not_contains() {
  local pattern="$1"
  if grep -Eq "$pattern" <<<"$help_output"; then
    fail "sf help should not contain pattern: $pattern"
  fi
}

for command in \
  "sf init" \
  "sf update" \
  "sf doctor" \
  "sf status" \
  "sf facts" \
  "sf lint" \
  "sf test" \
  "sf verify" \
  "sf finalize" \
  "sf task" \
  "sf worktree" \
  "sf help"
do
  assert_help_contains "$command"
done

# Interpretation moved agent-side: these commands are gone from the CLI.
assert_help_not_contains "sf snapshot"
assert_help_not_contains "sf requirements"
assert_help_not_contains "sf wave"
assert_help_not_contains "sf trace"
assert_help_not_contains "sf review"
assert_help_not_contains "sf registry"

for command in /sf-plan /sf-quickspec /sf-test /sf-ship /sf-review /sf-finalize /sf-status /sf-loop /sf-task; do
  assert_help_contains "$command"
done

for command in /sf-align /sf-design /sf-build /sf-trace /sf-next; do
  assert_help_not_contains "$command"
done

if [ "$failures" -gt 0 ]; then
  echo "$failures CLI help assertion(s) failed." >&2
  exit 1
fi

echo "CLI help contract passed"
