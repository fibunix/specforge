#!/usr/bin/env bash
# Contract tests for:
#  G2 — abandon path (archive-reset --abandon skips done-check, marks abandoned)
#  G4 — REQ-ID reuse across archived iterations fails lint

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PROJECT="$TMP/project"
failures=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_exists() {
  local path="$1"
  [ -e "$path" ] || fail "$path should exist"
}

assert_missing() {
  local path="$1"
  [ ! -e "$path" ] || fail "$path should be missing"
}

assert_contains() {
  local label="$1" pattern="$2" content="$3"
  grep -Eq "$pattern" <<<"$content" || fail "$label should match: $pattern"
}

assert_not_contains() {
  local label="$1" pattern="$2" content="$3"
  ! grep -Eq "$pattern" <<<"$content" || fail "$label should NOT match: $pattern"
}

run_iteration() {
  (cd "$PROJECT" && bash .specforge/scripts/sf-iteration.sh "$@")
}

run_lint() {
  (cd "$PROJECT" && bash .specforge/scripts/sf-lint-specs.sh 2>&1)
}

# ── Bootstrap ─────────────────────────────────────────────────────────────────
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide claude-code >/dev/null

cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: contracts-test
test_command: true
lint_command: true
build_command: true
source_dir: src
EOF

write_plan() {
  local iter="${1:-ITER-001-contracts}"
  mkdir -p "$PROJECT/.specforge/specs"
  cat > "$PROJECT/.specforge/ALIGN.md" <<EOF
# Contracts — Shared understanding
**Last updated:** 2026-06-10
**Status:** approved
**Iteration:** $iter
EOF
  cat > "$PROJECT/.specforge/DESIGN.md" <<EOF
# Contracts — Design
**Last updated:** 2026-06-10
**Status:** approved
**Iteration:** $iter

## SPECS produced

| ID | Title | Depends on |
|----|-------|-----------|
| SPEC-001 | one | — |
EOF
}

write_spec() {
  local n="$1" state="$2" tick="$3" req="$4" iter="${5:-ITER-001-contracts}"
  cat > "$PROJECT/.specforge/specs/SPEC-00$n-thing.md" <<EOF
# SPEC-00$n: Thing $n

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** $state
**Iteration:** $iter

## Description

Thing $n.

## Acceptance criteria

- [$tick] $req: does thing $n

## Tests

- [$tick] tests/t$n.sh  (covers $req)

## Implementation

- [$tick] src/a$n.sh
EOF
}

# ── G2 — abandon path ─────────────────────────────────────────────────────────

# Set up an active iteration with one unfinished spec
write_plan "ITER-001-contracts"
write_spec 1 approved " " "REQ-C01-001" "ITER-001-contracts"

# Normal archive-reset must refuse unfinished specs
if run_iteration archive-reset --dry-run 2>/dev/null; then
  fail "archive-reset must refuse unfinished specs"
fi

# abandon should succeed even with unfinished specs
run_iteration archive-reset --abandon >/dev/null

# Artifacts archived
assert_exists "$PROJECT/.specforge/iterations/ITER-001-contracts/ALIGN.md"
assert_exists "$PROJECT/.specforge/iterations/ITER-001-contracts/DESIGN.md"
assert_exists "$PROJECT/.specforge/iterations/ITER-001-contracts/specs/SPEC-001-thing.md"
assert_exists "$PROJECT/.specforge/iterations/ITER-001-contracts/SUMMARY.md"

# Active plan artifacts reset
assert_missing "$PROJECT/.specforge/ALIGN.md"
assert_missing "$PROJECT/.specforge/DESIGN.md"
assert_missing "$PROJECT/.specforge/specs/SPEC-001-thing.md"

# Abandon with no agent-authored SUMMARY.md gets a one-line stub
summary_content="$(cat "$PROJECT/.specforge/iterations/ITER-001-contracts/SUMMARY.md")"
assert_contains "SUMMARY.md abandoned stub" 'abandoned .* before all specs were complete' "$summary_content"

# NEXT.md survives (if present)
cat > "$PROJECT/.specforge/NEXT.md" <<'EOF'
# Next
- add auth
EOF
write_plan "ITER-002-contracts"
write_spec 1 approved " " "REQ-C02-001" "ITER-002-contracts"
run_iteration archive-reset --abandon >/dev/null
assert_exists "$PROJECT/.specforge/NEXT.md"
assert_missing "$PROJECT/.specforge/iterations/ITER-002-contracts/NEXT.md"

# ── G4 — REQ-ID reuse across archived iterations fails lint ──────────────────

# Set up a new iteration that reuses a REQ ID from the archived iteration
write_plan "ITER-003-contracts"
# REQ-C01-001 was in ITER-001 (now archived). Reusing it should fail lint.
write_spec 1 approved " " "REQ-C01-001" "ITER-003-contracts"
git -C "$PROJECT" -c user.name=sf-test -c user.email=sf@test add -A
git -C "$PROJECT" -c user.name=sf-test -c user.email=sf@test commit -qm "setup"

lint_out="$(run_lint 2>&1 || true)"
assert_contains "lint must fail on reused archived REQ ID" \
  'REQ-C01-001 reuses an archived requirement' "$lint_out"

# Using a fresh REQ ID must pass lint
rm -f "$PROJECT/.specforge/specs/SPEC-001-thing.md"
write_spec 1 approved " " "REQ-C03-001" "ITER-003-contracts"
lint_out2="$(run_lint 2>&1 || true)"
assert_not_contains "lint must pass for fresh REQ ID" \
  'reuses an archived' "$lint_out2"

# ── Active SPECs must carry Iteration metadata (lint) ────────────────────────
sed '/^\*\*Iteration:\*\*/d' "$PROJECT/.specforge/specs/SPEC-001-thing.md" > "$PROJECT/.specforge/specs/SPEC-001-thing.tmp"
mv "$PROJECT/.specforge/specs/SPEC-001-thing.tmp" "$PROJECT/.specforge/specs/SPEC-001-thing.md"
if run_lint >/dev/null 2>&1; then
  fail "lint should require active SPEC iteration metadata"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures iteration-contracts assertion(s) failed." >&2
  exit 1
fi

echo "iteration-contracts contract passed"
