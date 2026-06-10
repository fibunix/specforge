#!/usr/bin/env bash
# Contract tests for next-iteration archive/reset state.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PROJECT="$TMP/project"
failures=0

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_exists() {
  local path="$1"
  if [ ! -e "$path" ]; then
    fail "$path should exist"
  fi
}

assert_missing() {
  local path="$1"
  if [ -e "$path" ]; then
    fail "$path should be missing"
  fi
}

write_plan() {
  mkdir -p "$PROJECT/.specforge/specs"

  cat > "$PROJECT/.specforge/ALIGN.md" <<'EOF'
# Alignment
**Status:** approved
**Iteration:** ITER-active
EOF

  cat > "$PROJECT/.specforge/DESIGN.md" <<'EOF'
# Design
**Status:** approved
**Iteration:** ITER-active
EOF
}

write_done_spec() {
  cat > "$PROJECT/.specforge/specs/SPEC-001.md" <<'EOF'
# SPEC-001

**Status:** approved
**Iteration:** ITER-active
**Build state:** done
**Branch:** feature/SPEC-001

## Acceptance criteria

- [x] REQ-ITER-001: Completed specs can be archived

## Tests

- [x] tests/iteration.test.sh (covers REQ-ITER-001)

## Implementation

- [x] src/iteration.sh
EOF
}

write_unfinished_spec() {
  cat > "$PROJECT/.specforge/specs/SPEC-001.md" <<'EOF'
# SPEC-001

**Status:** approved
**Iteration:** ITER-active
**Build state:** not-started
**Branch:** feature/SPEC-001

## Acceptance criteria

- [ ] REQ-ITER-001: Unfinished specs block archive reset

## Tests

- [ ] tests/iteration.test.sh (covers REQ-ITER-001)

## Implementation

- [ ] src/iteration.sh
EOF
}

run_iteration() {
  (cd "$PROJECT" && bash "$ROOT/.specforge/scripts/sf-iteration.sh" "$@")
}

mkdir -p "$PROJECT"
write_plan
write_unfinished_spec

if run_iteration archive-reset --dry-run >/dev/null 2>&1; then
  fail "archive-reset should refuse unfinished specs"
fi

rm -rf "$PROJECT/.specforge"
write_plan
write_done_spec
cat > "$PROJECT/.specforge/NEXT.md" <<'EOF'
# Next iteration

Focus: improve plan routing.
EOF

status_output="$(run_iteration status)"
if ! grep -Eq "NEXT.md: queued" <<<"$status_output"; then
  fail "iteration status should report queued NEXT.md"
fi

# The close-out is agent-authored: archive-reset refuses without it.
if archive_err="$(run_iteration archive-reset --id ITER-test 2>&1)"; then
  fail "archive-reset should refuse without .specforge/SUMMARY.md"
elif ! grep -q "SUMMARY.md" <<<"$archive_err"; then
  fail "missing-summary error should name SUMMARY.md"
fi

write_summary() {
  cat > "$PROJECT/.specforge/SUMMARY.md" <<'EOF'
# ITER-test — Iteration summary

## What shipped

- SPEC-001 — the archive contract itself
EOF
}

write_summary
run_iteration archive-reset --id ITER-test >/dev/null

assert_exists "$PROJECT/.specforge/iterations/ITER-test/ALIGN.md"
assert_exists "$PROJECT/.specforge/iterations/ITER-test/DESIGN.md"
assert_exists "$PROJECT/.specforge/iterations/ITER-test/specs/SPEC-001.md"
assert_missing "$PROJECT/.specforge/ALIGN.md"
assert_missing "$PROJECT/.specforge/DESIGN.md"
assert_missing "$PROJECT/.specforge/specs/SPEC-001.md"

# The agent-authored summary is moved into the archive verbatim.
assert_missing "$PROJECT/.specforge/SUMMARY.md"
if ! grep -q "the archive contract itself" "$PROJECT/.specforge/iterations/ITER-test/SUMMARY.md"; then
  fail "archived SUMMARY.md should be the agent-authored file"
fi

# NEXT.md is the next iteration's input: it must survive archive-reset and
# must not be filed into the completed iteration's archive.
assert_exists "$PROJECT/.specforge/NEXT.md"
assert_missing "$PROJECT/.specforge/iterations/ITER-test/NEXT.md"

write_plan
write_done_spec
write_summary
if run_iteration archive-reset --id ITER-test >/dev/null 2>&1; then
  fail "archive-reset should refuse to overwrite an existing archive"
fi

# Without --id, the archive is named after the completed iteration's own ID
# (read from ALIGN.md), not the archiving timestamp.
run_iteration archive-reset >/dev/null
assert_exists "$PROJECT/.specforge/iterations/ITER-active/ALIGN.md"
assert_exists "$PROJECT/.specforge/iterations/ITER-active/SUMMARY.md"

# next-id is sequential over archived iterations (2 archives -> ITER-003).
next_id_output="$(run_iteration next-id csv-export)"
if [ "$next_id_output" != "ITER-003-csv-export" ]; then
  fail "next-id should be ITER-003-csv-export with two archives, got '$next_id_output'"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures iteration-state assertion(s) failed." >&2
  exit 1
fi

echo "iteration-state contract passed"
