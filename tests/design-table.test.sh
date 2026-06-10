#!/usr/bin/env bash
# Contract for DESIGN.md SPECS-table parsing, dependency-aware Next: line,
# and sf wave dependency gating (B1 + B2 regression guards).

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

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" != "$expected" ]; then
    fail "$label: expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local label="$1" pattern="$2" content="$3"
  if ! grep -Eq "$pattern" <<<"$content"; then
    fail "$label should match: $pattern"
  fi
}

assert_not_contains() {
  local label="$1" pattern="$2" content="$3"
  if grep -Eq "$pattern" <<<"$content"; then
    fail "$label should NOT match: $pattern"
  fi
}

git_p() {
  git -C "$PROJECT" -c user.name=sf-test -c user.email=sf@test "$@"
}

snapshot() {
  (cd "$PROJECT" && bash .specforge/scripts/sf-snapshot.sh)
}

wave() {
  (cd "$PROJECT" && bash .specforge/scripts/sf-wave.sh "$@")
}

# ── Bootstrap a minimal project ───────────────────────────────────────────────
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide claude-code >/dev/null

cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: table-test
test_command: true
lint_command: true
build_command: true
source_dir: src
EOF

cat > "$PROJECT/.specforge/ALIGN.md" <<'EOF'
# Table test — Shared understanding
**Last updated:** 2026-06-10
**Status:** approved
**Iteration:** ITER-001-table

## Problem
x
EOF

# DESIGN.md with the documented header format and a real dependency chain:
#   SPEC-001 has no deps
#   SPEC-002 depends on SPEC-001
#   SPEC-003 has no deps
cat > "$PROJECT/.specforge/DESIGN.md" <<'EOF'
# Table test — Design
**Last updated:** 2026-06-10
**Status:** approved
**Iteration:** ITER-001-table

## SPECS produced

| ID | Title | Depends on |
|----|-------|-----------|
| SPEC-001 | one | — |
| SPEC-002 | two | SPEC-001 |
| SPEC-003 | three | — |
EOF

write_spec() {
  local n="$1" state="$2" tick="$3" test_file="$4" impl_file="$5"
  cat > "$PROJECT/.specforge/specs/SPEC-00$n-thing.md" <<EOF
# SPEC-00$n: Thing $n

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** $state
**Iteration:** ITER-001-table

## Description

Thing $n.

## Acceptance criteria

- [$tick] REQ-T0$n-001: does thing $n

## Tests

- [$tick] $test_file  (covers REQ-T0$n-001)

## Implementation

- [$tick] $impl_file
EOF
}

# Start with all three specs approved and no deps satisfied
write_spec 1 approved " " tests/t1.sh src/a.sh
write_spec 2 approved " " tests/t2.sh src/b.sh
write_spec 3 approved " " tests/t3.sh src/c.sh
git_p add -A
git_p commit -qm "plan: ITER-001-table"

# ── B1: sf_design_spec_order returns IDs in table order ──────────────────────
source "$PROJECT/.specforge/scripts/lib/spec.sh"
source "$PROJECT/.specforge/scripts/lib/common.sh"
source "$PROJECT/.specforge/scripts/lib/git.sh"

order="$(sf_design_spec_order "$PROJECT")"
assert_eq "spec order line 1" "SPEC-001" "$(echo "$order" | sed -n '1p')"
assert_eq "spec order line 2" "SPEC-002" "$(echo "$order" | sed -n '2p')"
assert_eq "spec order line 3" "SPEC-003" "$(echo "$order" | sed -n '3p')"
assert_eq "spec order count" "3" "$(echo "$order" | wc -l | tr -d ' ')"

# ── B1: sf_design_spec_deps returns correct deps ──────────────────────────────
deps_001="$(sf_design_spec_deps "$PROJECT" "SPEC-001")"
assert_eq "SPEC-001 has no deps" "" "$deps_001"

deps_002="$(sf_design_spec_deps "$PROJECT" "SPEC-002")"
assert_eq "SPEC-002 depends on SPEC-001" "SPEC-001" "$deps_002"

deps_003="$(sf_design_spec_deps "$PROJECT" "SPEC-003")"
assert_eq "SPEC-003 has no deps" "" "$deps_003"

# ── B1: sf status Next: line respects dependency order ───────────────────────
# SPEC-001 and SPEC-003 have no deps — both eligible.
# SPEC-002 depends on SPEC-001 (not done) — must NOT be the suggested next.
snap="$(snapshot)"
# The first approved spec with all deps satisfied should be offered, not SPEC-002.
assert_not_contains "Next line must not suggest SPEC-002 when dep unmet" \
  '/sf-test SPEC-002' "$snap"
# SPEC-001 or SPEC-003 should be suggested (one of the dep-free ones).
assert_contains "Next line suggests a dep-free spec" \
  '/sf-test SPEC-00[13]' "$snap"

# ── B2: sf wave does not show SPEC-002 as parallel-safe when dep unmet ────────
wout="$(wave)"
assert_contains "wave includes SPEC-001" 'SPEC-001 +→' "$wout"
assert_contains "wave includes SPEC-003" 'SPEC-003 +→' "$wout"
# SPEC-002 dep (SPEC-001) is not done/merged → must not appear in the parallel wave
assert_not_contains "wave must not offer SPEC-002 (dep unmet)" \
  'SPEC-002 +→ +sf worktree create SPEC-002' "$wout"

# ── B2: done-but-unmerged dep does NOT satisfy the dep check ─────────────────
# Create a worktree for SPEC-001, mark it done there (simulating a builder who
# finished but has not yet finalized/merged). SPEC-002 must still be blocked.
(cd "$PROJECT" && bash .specforge/scripts/sf-worktree.sh create SPEC-001 >/dev/null)
WT="$PROJECT/.worktrees/SPEC-001"
mkdir -p "$WT/tests" "$WT/src"
echo 'exit 0' > "$WT/tests/t1.sh"
echo 'ok' > "$WT/src/a.sh"
cat > "$WT/.specforge/specs/SPEC-001-thing.md" <<'SPECEOF'
# SPEC-001: Thing 1

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** done
**Iteration:** ITER-001-table

## Description

Thing 1.

## Acceptance criteria

- [x] REQ-T01-001: does thing 1

## Tests

- [x] tests/t1.sh  (covers REQ-T01-001)

## Implementation

- [x] src/a.sh
SPECEOF
git -C "$WT" -c user.name=sf-test -c user.email=sf@test add -A
git -C "$WT" -c user.name=sf-test -c user.email=sf@test commit -qm "SPEC-001: done (unmerged)"

# Effective state shows done (worktree) — snapshot sees it
snap2="$(snapshot)"
assert_contains "snapshot sees SPEC-001 done in worktree" 'SPEC-001 +done' "$snap2"

# Wave must still NOT offer SPEC-002 because SPEC-001 branch is not merged
wout2="$(wave)"
assert_not_contains "wave blocks SPEC-002 when dep done-but-unmerged" \
  'SPEC-002 +→ +sf worktree create SPEC-002' "$wout2"

# ── After merging SPEC-001, wave unblocks SPEC-002 ───────────────────────────
(cd "$PROJECT" && GIT_AUTHOR_NAME=sf-test GIT_AUTHOR_EMAIL=sf@test \
  GIT_COMMITTER_NAME=sf-test GIT_COMMITTER_EMAIL=sf@test \
  bash .specforge/scripts/sf-finalize.sh SPEC-001 >/dev/null)

wout3="$(wave)"
assert_contains "wave offers SPEC-002 after dep merged" \
  'SPEC-002 +→ +sf worktree create SPEC-002' "$wout3"

# Next: line should now offer SPEC-002 (dep merged into checkout)
snap3="$(snapshot)"
# After SPEC-001 is merged (done in checkout), SPEC-002's dep is satisfied
assert_contains "Next line offers SPEC-002 after dep merged" \
  '/sf-test SPEC-002' "$snap3"

if [ "$failures" -gt 0 ]; then
  echo "$failures design-table assertion(s) failed." >&2
  exit 1
fi

echo "design-table contract passed"
