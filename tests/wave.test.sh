#!/usr/bin/env bash
# Behavior contract for sf wave: parallel/serialized split on declared file
# overlap, bash-3.2 compatibility, and wave finalize actually merging done
# specs from their worktrees.

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

assert_contains() {
  local label="$1"
  local pattern="$2"
  local content="$3"
  if ! grep -Eq "$pattern" <<<"$content"; then
    fail "$label should match: $pattern"
  fi
}

assert_not_contains() {
  local label="$1"
  local pattern="$2"
  local content="$3"
  if grep -Eq "$pattern" <<<"$content"; then
    fail "$label should NOT match: $pattern"
  fi
}

git_p() {
  git -C "$PROJECT" -c user.name=sf-test -c user.email=sf@test "$@"
}

wave() {
  (cd "$PROJECT" && bash .specforge/scripts/sf-wave.sh "$@")
}

write_spec() {
  local n="$1" state="$2" tick="$3" test_file="$4" impl_file="$5"
  cat > "$PROJECT/.specforge/specs/SPEC-00$n-thing.md" <<EOF
# SPEC-00$n: Thing $n

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** $state
**Iteration:** ITER-001-wave

## Description

Thing $n.

## Acceptance criteria

- [$tick] REQ-W0$n-001: does thing $n

## Tests

- [$tick] $test_file  (covers REQ-W0$n-001)

## Implementation

- [$tick] $impl_file

## Design notes

See DESIGN.md.
EOF
}

# ── Set up: three approved specs, SPEC-003 shares a file with SPEC-001 ────────
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide claude-code >/dev/null

cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: wave-test
test_command: for t in tests/sandbox-*.sh; do bash "$t" || exit 1; done
lint_command: true
build_command: true
source_dir: src
EOF

cat > "$PROJECT/.specforge/ALIGN.md" <<'EOF'
# Wave — Shared understanding
**Last updated:** 2026-06-09
**Status:** approved
**Iteration:** ITER-001-wave

## Problem
x
EOF

cat > "$PROJECT/.specforge/DESIGN.md" <<'EOF'
# Wave — Design
**Last updated:** 2026-06-09
**Status:** approved
**Iteration:** ITER-001-wave

## SPECS produced

| ID | Title | Depends on |
|----|-------|-----------|
| SPEC-001 | one | — |
| SPEC-002 | two | — |
| SPEC-003 | three | — |
EOF

mkdir -p "$PROJECT/tests" "$PROJECT/src"
write_spec 1 approved " " tests/sandbox-a.sh src/a.sh
write_spec 2 approved " " tests/sandbox-b.sh src/b.sh
write_spec 3 approved " " tests/sandbox-a.sh src/c.sh
git_p add -A
git_p commit -qm "plan: ITER-001-wave"

# ── Wave plan: disjoint specs run, the overlapping one is serialized ─────────
# Run under plain `bash` so a bash-3.2 /bin/bash exercises compatibility.
out="$(wave)"
assert_contains "wave plan" 'SPEC-001 +→' "$out"
assert_contains "wave plan" 'SPEC-002 +→' "$out"
assert_contains "wave plan" 'SPEC-003 +→ +start after shares files with SPEC-001' "$out"

# ── Draft specs are not ready ─────────────────────────────────────────────────
write_spec 2 draft " " tests/sandbox-b.sh src/b.sh
out="$(wave)"
assert_not_contains "wave plan with draft SPEC-002" 'SPEC-002 +→ +sf worktree' "$out"
write_spec 2 approved " " tests/sandbox-b.sh src/b.sh   # back to committed content

# ── Complete SPEC-001 in its worktree ─────────────────────────────────────────
(cd "$PROJECT" && bash .specforge/scripts/sf-worktree.sh create SPEC-001 >/dev/null)
WT="$PROJECT/.worktrees/SPEC-001"
mkdir -p "$WT/tests" "$WT/src"
echo 'exit 0' > "$WT/tests/sandbox-a.sh"
echo 'ok' > "$WT/src/a.sh"
cat > "$WT/.specforge/specs/SPEC-001-thing.md" <<'EOF'
# SPEC-001: Thing 1

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** done
**Iteration:** ITER-001-wave

## Description

Thing 1.

## Acceptance criteria

- [x] REQ-W01-001: does thing 1

## Tests

- [x] tests/sandbox-a.sh  (covers REQ-W01-001)

## Implementation

- [x] src/a.sh

## Design notes

See DESIGN.md.
EOF
git -C "$WT" -c user.name=sf-test -c user.email=sf@test add -A
git -C "$WT" -c user.name=sf-test -c user.email=sf@test commit -qm "SPEC-001: implement"

# Effective state from the base checkout must show the worktree's done state.
snap="$( (cd "$PROJECT" && bash .specforge/scripts/sf-snapshot.sh) )"
assert_contains "snapshot with done worktree" 'SPEC-001 +done' "$snap"

# ── wave finalize merges the done spec and skips the rest ─────────────────────
out="$( (cd "$PROJECT" && GIT_AUTHOR_NAME=sf-test GIT_AUTHOR_EMAIL=sf@test \
  GIT_COMMITTER_NAME=sf-test GIT_COMMITTER_EMAIL=sf@test \
  bash .specforge/scripts/sf-wave.sh finalize) )"
assert_contains "wave finalize" 'Finalizing SPEC-001' "$out"
assert_contains "wave finalize" 'SPEC-002: State is .approved. \(not done\) — skipping' "$out"
assert_contains "wave finalize" '1 merged, 2 skipped' "$out"

[ -f "$PROJECT/src/a.sh" ] || fail "SPEC-001 implementation should be merged into main"
if git -C "$PROJECT" show-ref --verify --quiet refs/heads/feature/SPEC-001; then
  fail "feature/SPEC-001 should be deleted after wave finalize"
fi
[ ! -d "$WT" ] || fail "SPEC-001 worktree should be removed after wave finalize"

# ── SPEC-003 unblocks once its file-overlap partner is merged ─────────────────
out="$(wave)"
assert_contains "wave plan after merge" 'SPEC-003 +→ +sf worktree create SPEC-003' "$out"

if [ "$failures" -gt 0 ]; then
  echo "$failures wave assertion(s) failed." >&2
  exit 1
fi

echo "wave contract passed"
