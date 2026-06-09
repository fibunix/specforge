#!/usr/bin/env bash
# Contract tests for resolving SPEC IDs to slugged SPEC filenames.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PROJECT="$TMP/project"
failures=0

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

# shellcheck source=.specforge/scripts/lib/common.sh
source "$ROOT/.specforge/scripts/lib/common.sh"
# shellcheck source=.specforge/scripts/lib/spec.sh
source "$ROOT/.specforge/scripts/lib/spec.sh"
# shellcheck source=.specforge/scripts/lib/git.sh
source "$ROOT/.specforge/scripts/lib/git.sh"

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

reset_specs() {
  rm -rf "$PROJECT/.specforge/specs"
  mkdir -p "$PROJECT/.specforge/specs"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [ "$actual" != "$expected" ]; then
    fail "$label: expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local text="$1"
  local pattern="$2"
  local label="$3"

  if ! grep -Eq "$pattern" <<<"$text"; then
    fail "$label: expected pattern '$pattern' in: $text"
  fi
}

reset_specs
: > "$PROJECT/.specforge/specs/SPEC-009.md"
resolved="$(sf_resolve_spec_file "$PROJECT" "SPEC-009.md")"
assert_eq "$PROJECT/.specforge/specs/SPEC-009.md" "$resolved" "exact SPEC filename resolves"

reset_specs
: > "$PROJECT/.specforge/specs/SPEC-009-frequency-record.md"
resolved="$(sf_resolve_spec_file "$PROJECT" "SPEC-009")"
assert_eq "$PROJECT/.specforge/specs/SPEC-009-frequency-record.md" "$resolved" "slugged SPEC resolves from stable ID"

resolved="$(sf_resolve_spec_file "$PROJECT" "SPEC-009-frequency-record")"
assert_eq "$PROJECT/.specforge/specs/SPEC-009-frequency-record.md" "$resolved" "full slug basename resolves"

reset_specs
if missing_output="$(sf_resolve_spec_file "$PROJECT" "SPEC-009" 2>&1)"; then
  fail "missing SPEC should fail"
else
  assert_contains "$missing_output" "Accepted forms: \\.specforge/specs/SPEC-009\\.md or \\.specforge/specs/SPEC-009-<slug>\\.md" "missing SPEC error"
fi

reset_specs
: > "$PROJECT/.specforge/specs/SPEC-009-frequency-record.md"
: > "$PROJECT/.specforge/specs/SPEC-009-timing-report.md"
if ambiguous_output="$(sf_resolve_spec_file "$PROJECT" "SPEC-009" 2>&1)"; then
  fail "ambiguous SPEC should fail"
else
  assert_contains "$ambiguous_output" "ambiguous" "ambiguous SPEC error"
  assert_contains "$ambiguous_output" "SPEC-009-frequency-record\\.md" "ambiguous SPEC lists first match"
  assert_contains "$ambiguous_output" "SPEC-009-timing-report\\.md" "ambiguous SPEC lists second match"
  assert_contains "$ambiguous_output" "Pass the full spec basename" "ambiguous SPEC asks for full basename"
fi

assert_eq "feature/SPEC-009" "$(sf_branch_for_spec "SPEC-009")" "stable ID branch"
assert_eq "feature/SPEC-009" "$(sf_branch_for_spec "SPEC-009-frequency-record")" "slugged basename branch"
assert_eq "feature/SPEC-009" "$(sf_branch_for_spec "SPEC-009-frequency-record.md")" "slugged filename branch"
assert_eq "feature/SPEC-AUTH-001" "$(sf_branch_for_spec "SPEC-AUTH-001")" "non-numeric SPEC ID branch"
assert_eq "feature/SPEC-AUTH-001" "$(sf_branch_for_spec "SPEC-AUTH-001-login-flow")" "non-numeric slugged basename branch"

if [ "$failures" -gt 0 ]; then
  echo "$failures SPEC resolver assertion(s) failed." >&2
  exit 1
fi

echo "SPEC resolver contract passed"
