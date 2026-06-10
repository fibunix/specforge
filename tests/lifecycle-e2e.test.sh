#!/usr/bin/env bash
# End-to-end lifecycle contract: plan -> test -> ship -> finalize -> archive,
# asserting that sf facts stays truthful from the base branch at every step.

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

git_p() {
  git -C "$PROJECT" -c user.name=sf-test -c user.email=sf@test "$@"
}

facts() {
  (cd "$PROJECT" && bash .specforge/scripts/sf-facts.sh)
}

write_spec() {
  local n="$1"
  local state="$2"
  local tick="$3"   # " " or "x"
  cat > "$PROJECT/.specforge/specs/SPEC-00$n-thing.md" <<EOF
# SPEC-00$n: Thing $n

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** $state
**Iteration:** ITER-001-lifecycle

## Description

Thing $n.

## Acceptance criteria

- [$tick] REQ-T0$n-001: does thing $n

## Tests

- [$tick] tests/sandbox-t$n.sh  (covers REQ-T0$n-001)

## Implementation

- [$tick] src/t$n.sh

## Design notes

See DESIGN.md.
EOF
}

# ── Set up a project with an approved plan ───────────────────────────────────
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide claude-code >/dev/null

cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: lifecycle-e2e
test_command: for t in tests/sandbox-*.sh; do bash "$t" || exit 1; done
lint_command: true
build_command: true
source_dir: src
EOF

cat > "$PROJECT/.specforge/ALIGN.md" <<'EOF'
# Lifecycle — Shared understanding
**Last updated:** 2026-06-09
**Status:** approved
**Iteration:** ITER-001-lifecycle

## Problem
x
EOF

cat > "$PROJECT/.specforge/DESIGN.md" <<'EOF'
# Lifecycle — Design
**Last updated:** 2026-06-09
**Status:** approved
**Iteration:** ITER-001-lifecycle

## SPECS produced

| ID | Title | Depends on |
|----|-------|-----------|
| SPEC-001 | one | — |
| SPEC-002 | two | SPEC-001 |
EOF

mkdir -p "$PROJECT/tests" "$PROJECT/src"
write_spec 1 approved " "
write_spec 2 approved " "
git_p add -A
git_p commit -qm "plan: ITER-001-lifecycle"

# ── Approved plan: facts show the approved specs from the checkout ───────────
out="$(facts)"
assert_contains "facts (approved plan)" 'ALIGN: approved +DESIGN: approved' "$out"
assert_contains "facts (approved plan)" 'SPEC-001 +state=approved +source=checkout' "$out"

# ── Red tests committed on the feature branch; checkout returns to main ──────
git_p switch -qc feature/SPEC-001
echo 'exit 1' > "$PROJECT/tests/sandbox-t1.sh"
write_spec 1 tests-red " "
git_p add -A
git_p commit -qm "SPEC-001: red tests"
git_p switch -q main

out="$(facts)"
assert_contains "facts from main (red on branch)" 'SPEC-001 +state=tests-red +source=branch +branch=exists' "$out"

# ── Implementation done on the branch; main still sees the truth ──────────────
git_p switch -q feature/SPEC-001
echo 'exit 0' > "$PROJECT/tests/sandbox-t1.sh"
echo 'ok' > "$PROJECT/src/t1.sh"
write_spec 1 done x
git_p add -A
git_p commit -qm "SPEC-001: implement"
git_p switch -q main

out="$(facts)"
assert_contains "facts from main (done on branch)" 'SPEC-001 +state=done +source=branch +branch=exists' "$out"

# Doctor flags the in-flight branch.
out="$( (cd "$PROJECT" && bash .specforge/scripts/sf-doctor.sh) 2>&1 || true)"
assert_contains "doctor" 'SPEC-001 is in flight on feature/SPEC-001' "$out"

# ── Finalize merges and deletes the branch ────────────────────────────────────
git_p switch -q feature/SPEC-001
(cd "$PROJECT" && GIT_AUTHOR_NAME=sf-test GIT_AUTHOR_EMAIL=sf@test \
  GIT_COMMITTER_NAME=sf-test GIT_COMMITTER_EMAIL=sf@test \
  bash .specforge/scripts/sf-finalize.sh SPEC-001 >/dev/null)

if git -C "$PROJECT" show-ref --verify --quiet refs/heads/feature/SPEC-001; then
  fail "feature/SPEC-001 should be deleted after finalize"
fi
[ "$(git -C "$PROJECT" symbolic-ref --short HEAD)" = "main" ] || fail "finalize should land on main"
[ -f "$PROJECT/src/t1.sh" ] || fail "implementation should be merged into main"

out="$(facts)"
assert_contains "facts after finalize" 'SPEC-001 +state=done +source=checkout +branch=missing' "$out"
assert_contains "facts after finalize" 'SPEC-002 +state=approved' "$out"

# ── Complete SPEC-002 directly (same flow, condensed) ─────────────────────────
git_p switch -qc feature/SPEC-002
echo 'exit 0' > "$PROJECT/tests/sandbox-t2.sh"
echo 'ok' > "$PROJECT/src/t2.sh"
write_spec 2 done x
git_p add -A
git_p commit -qm "SPEC-002: implement"
(cd "$PROJECT" && GIT_AUTHOR_NAME=sf-test GIT_AUTHOR_EMAIL=sf@test \
  GIT_COMMITTER_NAME=sf-test GIT_COMMITTER_EMAIL=sf@test \
  bash .specforge/scripts/sf-finalize.sh SPEC-002 >/dev/null)

# ── All done: facts report both specs done, queue state in the header ────────
out="$(facts)"
assert_contains "facts all done" 'SPEC-001 +state=done' "$out"
assert_contains "facts all done" 'SPEC-002 +state=done' "$out"
assert_contains "facts all done" 'NEXT\.md: missing' "$out"

cat > "$PROJECT/.specforge/NEXT.md" <<'EOF'
# Next iteration — queued requirements

**Queued:** 2026-06-09

## Requirements

- CSV export: needed for reporting, high priority
EOF

out="$(facts)"
assert_contains "facts with queued NEXT.md" 'NEXT\.md: queued' "$out"

# Queued NEXT.md must not poison lint (it has no Iteration field, and it is
# excluded from active-iteration resolution either way).
if ! (cd "$PROJECT" && bash .specforge/scripts/sf-lint-specs.sh >/dev/null 2>&1); then
  fail "lint should pass with a queued NEXT.md present"
fi

# Regression (B5): even a NEXT.md that wrongly carries its own Iteration stamp
# must not override the active iteration or fail the consistency lint.
printf '**Iteration:** ITER-999-future\n' >> "$PROJECT/.specforge/NEXT.md"
if ! (cd "$PROJECT" && bash .specforge/scripts/sf-lint-specs.sh >/dev/null 2>&1); then
  fail "lint should ignore an Iteration stamp inside NEXT.md"
fi
grep -v '^\*\*Iteration:\*\*' "$PROJECT/.specforge/NEXT.md" > "$PROJECT/.specforge/NEXT.md.tmp"
mv "$PROJECT/.specforge/NEXT.md.tmp" "$PROJECT/.specforge/NEXT.md"

# ── Archive: agent-authored SUMMARY.md is required and moved into the archive ─
if (cd "$PROJECT" && bash .specforge/scripts/sf-iteration.sh archive-reset >/dev/null 2>&1); then
  fail "archive-reset should refuse to run without .specforge/SUMMARY.md"
fi

cat > "$PROJECT/.specforge/SUMMARY.md" <<'EOF'
# ITER-001-lifecycle — Iteration summary

**Archived:** 2026-06-09

## What shipped

- SPEC-001 — thing one, end to end
- SPEC-002 — thing two

## What was learned

- nothing notable

## Deferred / follow-ups

- nothing deferred
EOF

(cd "$PROJECT" && bash .specforge/scripts/sf-iteration.sh archive-reset >/dev/null)

[ -f "$PROJECT/.specforge/NEXT.md" ] || fail "NEXT.md should survive archive-reset"
[ -d "$PROJECT/.specforge/iterations/ITER-001-lifecycle" ] || fail "archive should be named ITER-001-lifecycle"
[ ! -f "$PROJECT/.specforge/SUMMARY.md" ] || fail "SUMMARY.md should be moved out of the workspace"
grep -q 'thing one, end to end' "$PROJECT/.specforge/iterations/ITER-001-lifecycle/SUMMARY.md" \
  || fail "archive should contain the agent-authored SUMMARY.md verbatim"

out="$(facts)"
assert_contains "facts after archive" 'ALIGN: missing' "$out"

if [ "$failures" -gt 0 ]; then
  echo "$failures lifecycle-e2e assertion(s) failed." >&2
  exit 1
fi

echo "lifecycle-e2e contract passed"
