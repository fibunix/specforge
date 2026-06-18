#!/usr/bin/env bash
# Regression tests for verifier/finalize enforcement.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
failures=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_fails_with() {
  local label="$1" pattern="$2"
  shift 2
  local out
  if out="$("$@" 2>&1)"; then
    fail "$label should fail"
  elif ! grep -Eq "$pattern" <<<"$out"; then
    fail "$label should match '$pattern', got: $out"
  fi
}

git_p() {
  local project="$1"
  shift
  git -C "$project" -c user.name=sf-test -c user.email=sf@test "$@"
}

install_project() {
  local project="$1"
  mkdir -p "$project"
  git init -q -b main "$project"
  bash "$ROOT/install.sh" --source "$ROOT" --dir "$project" --ide opencode >/dev/null
}

write_config() {
  local project="$1" build="${2:-true}" lint="${3:-true}"
  cat > "$project/.specforge/config.yaml" <<EOF
project_name: enforcement
test_command: for t in tests/sandbox-*.sh; do bash "\$t" || exit 1; done
lint_command: $lint
build_command: $build
source_dir: src
EOF
}

write_plan() {
  local project="$1"
  mkdir -p "$project/.specforge/specs"
  cat > "$project/.specforge/ALIGN.md" <<'EOF'
# Enforcement
**Status:** approved
**Iteration:** ITER-001-enforcement
EOF
  cat > "$project/.specforge/DESIGN.md" <<'EOF'
# Enforcement
**Status:** approved
**Iteration:** ITER-001-enforcement

## SPECS produced

| ID | Title | Depends on |
|----|-------|-----------|
| SPEC-001 | one | — |
EOF
}

write_spec() {
  local project="$1" state="$2" tick="$3" impl_path="${4:-src/app.sh}"
  cat > "$project/.specforge/specs/SPEC-001-one.md" <<EOF
# SPEC-001: One

**Traces to:** .specforge/ALIGN.md § "Problem" | .specforge/DESIGN.md § "SPECS produced"
**State:** $state
**Iteration:** ITER-001-enforcement

## Description

One.

## Acceptance criteria

- [$tick] REQ-ENF-001: one works

## Tests

- [$tick] tests/sandbox-one.sh  (covers REQ-ENF-001)

## Implementation

- [$tick] $impl_path
EOF
}

commit_plan() {
  local project="$1"
  write_plan "$project"
  mkdir -p "$project/tests" "$project/src"
  write_spec "$project" approved " "
  git_p "$project" add -A
  git_p "$project" commit -qm "plan"
}

commit_red() {
  local project="$1"
  echo 'exit 1' > "$project/tests/sandbox-one.sh"
  write_spec "$project" tests-red " "
  git_p "$project" add -A
  git_p "$project" commit -qm "SPEC-001: red tests"
}

commit_done() {
  local project="$1" impl_path="${2:-src/app.sh}"
  mkdir -p "$project/tests" "$project/src"
  echo 'exit 0' > "$project/tests/sandbox-one.sh"
  mkdir -p "$project/$(dirname "$impl_path")"
  echo 'ok' > "$project/$impl_path"
  write_spec "$project" done x "$impl_path"
  git_p "$project" add -A
  git_p "$project" commit -qm "SPEC-001: implement"
}

setup_good_branch() {
  local project="$1" build="${2:-true}" lint="${3:-true}"
  install_project "$project"
  write_config "$project" "$build" "$lint"
  commit_plan "$project"
  git_p "$project" switch -qc feature/SPEC-001
  commit_red "$project"
  commit_done "$project"
}

# Build/lint failures block verify and finalize.
PROJECT="$TMP/build-fail"
setup_good_branch "$PROJECT" false true
assert_fails_with "verify build failure" 'build' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-verify-build.sh SPEC-001"
assert_fails_with "finalize build failure" 'build' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-finalize.sh SPEC-001"

PROJECT="$TMP/lint-fail"
setup_good_branch "$PROJECT" true false
assert_fails_with "verify lint failure" 'lint' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-verify-build.sh SPEC-001"

# Direct approved -> done bypass is rejected.
PROJECT="$TMP/no-red-history"
install_project "$PROJECT"
write_config "$PROJECT"
commit_plan "$PROJECT"
git_p "$PROJECT" switch -qc feature/SPEC-001
commit_done "$PROJECT"
assert_fails_with "red history required" 'tests-red' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-verify-build.sh SPEC-001"

# Undeclared changed files and missing checked files are rejected.
PROJECT="$TMP/undeclared"
setup_good_branch "$PROJECT"
echo 'extra' > "$PROJECT/src/extra.sh"
git_p "$PROJECT" add -A
git_p "$PROJECT" commit -qm "scope creep"
assert_fails_with "undeclared file" 'not declared' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-verify-build.sh SPEC-001"

PROJECT="$TMP/missing"
setup_good_branch "$PROJECT" true true
rm "$PROJECT/src/app.sh"
write_spec "$PROJECT" done x "src/app.sh"
git_p "$PROJECT" add -A
git_p "$PROJECT" commit -qm "missing checked file"
assert_fails_with "missing checked file" 'missing file' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-verify-build.sh SPEC-001"

# Absolute and parent-traversal project paths are rejected.
PROJECT="$TMP/bad-path"
install_project "$PROJECT"
cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: bad-path
projects:
  - id: bad
    path: ../outside
    test_command: true
EOF
assert_fails_with "parent path rejected" "must not contain '..'" bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-test.sh"

cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: bad-path
projects:
  - id: bad
    path: /tmp
    test_command: true
EOF
assert_fails_with "absolute path rejected" 'must be relative' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-test.sh"

# Worktree merge lands only on the resolved base branch, even if root is elsewhere.
PROJECT="$TMP/wrong-root-branch"
install_project "$PROJECT"
write_config "$PROJECT"
commit_plan "$PROJECT"
(cd "$PROJECT" && bash .specforge/scripts/sf-worktree.sh create SPEC-001 >/dev/null)
WT="$PROJECT/.worktrees/SPEC-001"
mkdir -p "$WT/src"
echo 'worktree' > "$WT/src/worktree.sh"
git -C "$WT" -c user.name=sf-test -c user.email=sf@test add -A
git -C "$WT" -c user.name=sf-test -c user.email=sf@test commit -qm "SPEC-001: worktree change"
git_p "$PROJECT" switch -qc topic
(cd "$PROJECT" && bash .specforge/scripts/sf-worktree.sh merge SPEC-001 >/dev/null)
[ "$(git -C "$PROJECT" symbolic-ref --short HEAD)" = "main" ] || fail "worktree merge should switch to main"
[ -f "$PROJECT/src/worktree.sh" ] || fail "worktree merge should merge into main"
if git -C "$PROJECT" ls-tree -r --name-only topic | grep -qx 'src/worktree.sh'; then
  fail "worktree merge should not merge into non-base branch"
fi

# Autonomous finalize requires matching PASS receipts.
PROJECT="$TMP/autonomous"
setup_good_branch "$PROJECT"
HEAD_COMMIT="$(git -C "$PROJECT" rev-parse HEAD)"
RED_COMMIT="$(git -C "$PROJECT" rev-parse HEAD^)"
BASE_COMMIT="$(git -C "$PROJECT" merge-base main HEAD)"
assert_fails_with "autonomous missing receipts" 'PASS receipt' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-finalize.sh SPEC-001 --autonomous"
mkdir -p "$PROJECT/.specforge/reviews/SPEC-001"
cat > "$PROJECT/.specforge/reviews/SPEC-001/tests-red-red.md" <<'EOF'
spec_id: SPEC-001
phase: tests-red
base: base
head: red
reviewer: sf-reviewer
verdict: PASS
commands run:
- bash .specforge/scripts/sf-test.sh
findings: none
VERDICT: PASS
EOF
cat > "$PROJECT/.specforge/reviews/SPEC-001/done-stale.md" <<'EOF'
spec_id: SPEC-001
phase: done
base: base
head: stale
reviewer: sf-reviewer
verdict: PASS
commands run:
- bash .specforge/scripts/sf-verify-build.sh SPEC-001
findings: none
VERDICT: PASS
EOF
assert_fails_with "autonomous stale receipt" 'PASS receipt' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-finalize.sh SPEC-001 --autonomous"
cat > "$PROJECT/.specforge/reviews/SPEC-001/tests-red-$RED_COMMIT.md" <<EOF
spec_id: SPEC-001
phase: tests-red
base: $BASE_COMMIT
head: stale
reviewer: sf-reviewer
verdict: PASS
commands run:
- bash .specforge/scripts/sf-test.sh
findings: none
VERDICT: PASS
EOF
assert_fails_with "autonomous red receipt internal head" 'head does not match' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-finalize.sh SPEC-001 --autonomous"
cat > "$PROJECT/.specforge/reviews/SPEC-001/tests-red-$RED_COMMIT.md" <<EOF
spec_id: SPEC-001
phase: tests-red
base: $BASE_COMMIT
head: $RED_COMMIT
reviewer: sf-reviewer
verdict: PASS
commands run:
- bash .specforge/scripts/sf-test.sh
findings: none
VERDICT: PASS
EOF
cat > "$PROJECT/.specforge/reviews/SPEC-001/done-$HEAD_COMMIT.md" <<EOF
spec_id: SPEC-001
phase: done
base: $BASE_COMMIT
head: $HEAD_COMMIT
reviewer: test
verdict: PASS
commands run:
- bash .specforge/scripts/sf-verify-build.sh SPEC-001
findings: none
VERDICT: PASS
EOF
assert_fails_with "autonomous done receipt reviewer" 'reviewer must be sf-reviewer' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-finalize.sh SPEC-001 --autonomous"
cat > "$PROJECT/.specforge/reviews/SPEC-001/done-$HEAD_COMMIT.md" <<EOF
spec_id: SPEC-001
phase: done
base: $BASE_COMMIT
head: $HEAD_COMMIT
reviewer: sf-reviewer
verdict: PASS
commands run:
- bash .specforge/scripts/sf-verify-build.sh SPEC-001
findings: none
VERDICT: PASS
EOF
(cd "$PROJECT" && bash .specforge/scripts/sf-finalize.sh SPEC-001 --autonomous >/dev/null)
[ "$(git -C "$PROJECT" symbolic-ref --short HEAD)" = "main" ] || fail "autonomous finalize should land on main"

# Task worktree merge requires a current independent task-review receipt.
PROJECT="$TMP/task-review"
install_project "$PROJECT"
write_config "$PROJECT"
cat > "$PROJECT/.specforge/tasks/TASK-001-demo.md" <<'EOF'
# TASK-001: Demo

**State:** open
**Created:** 2026-06-17

## What
Create a demo task output.

## Why
Exercise task review gates.

## Changes
- [ ] task-output.txt
EOF
git_p "$PROJECT" add -A
git_p "$PROJECT" commit -qm "task setup"
(cd "$PROJECT" && bash .specforge/scripts/sf-worktree.sh create TASK-001 >/dev/null)
WT="$PROJECT/.worktrees/TASK-001"
cat > "$WT/task-output.txt" <<'EOF'
done
EOF
cat > "$WT/.specforge/tasks/TASK-001-demo.md" <<'EOF'
# TASK-001: Demo

**State:** done
**Created:** 2026-06-17

## What
Create a demo task output.

## Why
Exercise task review gates.

## Changes
- [x] task-output.txt
EOF
git -C "$WT" -c user.name=sf-test -c user.email=sf@test add -A
git -C "$WT" -c user.name=sf-test -c user.email=sf@test commit -qm "TASK-001: demo"
assert_fails_with "task merge missing receipt" 'task gate requires PASS receipt' bash -c "cd '$PROJECT' && bash .specforge/scripts/sf-worktree.sh merge TASK-001"
TASK_HEAD="$(git -C "$PROJECT" rev-parse feature/TASK-001)"
TASK_BASE="$(git -C "$PROJECT" merge-base main feature/TASK-001)"
mkdir -p "$PROJECT/.specforge/reviews/TASK-001"
cat > "$PROJECT/.specforge/reviews/TASK-001/task-$TASK_HEAD.md" <<EOF
spec_id: TASK-001
phase: task
base: $TASK_BASE
head: $TASK_HEAD
reviewer: sf-reviewer
verdict: PASS
commands run:
- bash .specforge/scripts/sf-test.sh
findings: none
VERDICT: PASS
EOF
(cd "$PROJECT" && bash .specforge/scripts/sf-worktree.sh merge TASK-001 >/dev/null)
[ -f "$PROJECT/task-output.txt" ] || fail "task merge should land reviewed task output"

# Rebase finalize must rerun full verify, not only tests.
grep -q 'sf-verify-build.sh "$SPEC"' "$ROOT/.specforge/scripts/sf-finalize.sh" \
  || fail "sf-finalize --rebase should rerun full verify for current checkout"
grep -q 'sf-verify-build.sh "$spec"' "$ROOT/.specforge/scripts/sf-finalize.sh" \
  || fail "sf-finalize --rebase should rerun full verify for worktree checkout"

if [ "$failures" -gt 0 ]; then
  echo "$failures enforcement assertion(s) failed." >&2
  exit 1
fi

echo "enforcement contract passed"
