#!/usr/bin/env bash
# Golden contract for sf facts: facts only (no Next: line, no ordering),
# truthful state/source across checkout, feature-branch blob, and worktree,
# and the enforcement path (finalize) updating what the facts report.

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

facts() {
  (cd "$PROJECT" && bash .specforge/scripts/sf-facts.sh)
}

write_spec() {
  local n="$1" state="$2" tick="$3"
  cat > "$PROJECT/.specforge/specs/SPEC-00$n-thing.md" <<EOF
# SPEC-00$n: Thing $n

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** $state
**Iteration:** ITER-001-facts

## Description

Thing $n.

## Acceptance criteria

- [$tick] REQ-F0$n-001: does thing $n

## Tests

- [$tick] tests/sandbox-t$n.sh  (covers REQ-F0$n-001)

## Implementation

- [$tick] src/t$n.sh
EOF
}

# ── Bootstrap: approved plan, two approved specs ──────────────────────────────
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide claude-code >/dev/null

cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: facts-test
test_command: for t in tests/sandbox-*.sh; do bash "$t" || exit 1; done
lint_command: true
build_command: true
source_dir: src
EOF

cat > "$PROJECT/.specforge/ALIGN.md" <<'EOF'
# Facts — Shared understanding
**Last updated:** 2026-06-10
**Status:** approved
**Iteration:** ITER-001-facts

## Problem
x
EOF

cat > "$PROJECT/.specforge/DESIGN.md" <<'EOF'
# Facts — Design
**Last updated:** 2026-06-10
**Status:** approved
**Iteration:** ITER-001-facts

## SPECS produced

| ID | Title | Depends on |
|----|-------|-----------|
| SPEC-001 | one | — |
| SPEC-002 | two | — |
EOF

mkdir -p "$PROJECT/tests" "$PROJECT/src"
write_spec 1 approved " "
write_spec 2 approved " "
git_p add -A
git_p commit -qm "plan: ITER-001-facts"

# ── Golden header + per-spec lines from the checkout ─────────────────────────
out="$(facts)"
assert_contains "facts header" \
  '^ALIGN: approved +DESIGN: approved +ITERATION: ITER-001-facts +NEXT\.md: missing$' "$out"
assert_contains "facts SPEC-001 line" \
  'SPEC-001 +state=approved +source=checkout +branch=missing +ac=0/1 tests=0/1 impl=0/1' "$out"
assert_contains "facts SPEC-002 line" \
  'SPEC-002 +state=approved +source=checkout +branch=missing +ac=0/1 tests=0/1 impl=0/1' "$out"
# Facts only: interpretation (the Next: line) is the agent's job now.
assert_not_contains "facts has no Next: line" '^Next:' "$out"

# ── Red tests on the feature branch; facts from main reads the branch blob ───
git_p switch -qc feature/SPEC-001
echo 'exit 1' > "$PROJECT/tests/sandbox-t1.sh"
write_spec 1 tests-red " "
git_p add -A
git_p commit -qm "SPEC-001: red tests"
git_p switch -q main

out="$(facts)"
assert_contains "facts SPEC-001 in flight" \
  'SPEC-001 +state=tests-red +source=branch +branch=exists' "$out"

# ── Done in a worktree; facts reads the worktree copy ─────────────────────────
(cd "$PROJECT" && bash .specforge/scripts/sf-worktree.sh create SPEC-002 >/dev/null)
WT="$PROJECT/.worktrees/SPEC-002"
mkdir -p "$WT/tests" "$WT/src"
echo 'exit 0' > "$WT/tests/sandbox-t2.sh"
echo 'ok' > "$WT/src/t2.sh"
cat > "$WT/.specforge/specs/SPEC-002-thing.md" <<'EOF'
# SPEC-002: Thing 2

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** done
**Iteration:** ITER-001-facts

## Description

Thing 2.

## Acceptance criteria

- [x] REQ-F02-001: does thing 2

## Tests

- [x] tests/sandbox-t2.sh  (covers REQ-F02-001)

## Implementation

- [x] src/t2.sh
EOF
git -C "$WT" -c user.name=sf-test -c user.email=sf@test add -A
git -C "$WT" -c user.name=sf-test -c user.email=sf@test commit -qm "SPEC-002: implement"

out="$(facts)"
assert_contains "facts SPEC-002 done in worktree" \
  'SPEC-002 +state=done +source=worktree +branch=exists +ac=1/1 tests=1/1 impl=1/1' "$out"

# ── Finalize (enforcement) merges; facts reflects the checkout afterwards ────
(cd "$PROJECT" && GIT_AUTHOR_NAME=sf-test GIT_AUTHOR_EMAIL=sf@test \
  GIT_COMMITTER_NAME=sf-test GIT_COMMITTER_EMAIL=sf@test \
  bash .specforge/scripts/sf-finalize.sh SPEC-002 >/dev/null)

[ -f "$PROJECT/src/t2.sh" ] || fail "SPEC-002 implementation should be merged into main"
if git -C "$PROJECT" show-ref --verify --quiet refs/heads/feature/SPEC-002; then
  fail "feature/SPEC-002 should be deleted after finalize"
fi
[ ! -d "$WT" ] || fail "SPEC-002 worktree should be removed after finalize"

out="$(facts)"
assert_contains "facts SPEC-002 after finalize" \
  'SPEC-002 +state=done +source=checkout +branch=missing' "$out"

# ── Queued NEXT.md shows in the header ────────────────────────────────────────
cat > "$PROJECT/.specforge/NEXT.md" <<'EOF'
# Next iteration — queued requirements

**Queued:** 2026-06-10

## Requirements

- CSV export: needed for reporting, high priority
EOF

out="$(facts)"
assert_contains "facts header with queued NEXT.md" 'NEXT\.md: queued' "$out"

if [ "$failures" -gt 0 ]; then
  echo "$failures facts assertion(s) failed." >&2
  exit 1
fi

echo "facts contract passed"
