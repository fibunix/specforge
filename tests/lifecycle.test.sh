#!/usr/bin/env bash
# Lifecycle: worktree -> red tests -> implement -> guardrail -> merge -> archive.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
chk() { if eval "$2"; then echo "  ok: $1"; else echo "  FAIL: $1"; FAIL=1; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T"; git init -q; git config user.email t@t; git config user.name t; git branch -m main
printf 'grep -q done feature.txt 2>/dev/null\n' > test.sh
git add test.sh; git commit -q -m init
bash "$REPO/install.sh" --source "$REPO" --dir "$T" --ide claude-code >/dev/null 2>&1
sed -i.bak 's#^test_command:.*#test_command: bash test.sh#' "$T/project.yaml"; rm -f "$T/project.yaml.bak"
git add -A; git commit -q -m install
export SPECFORGE_BASE_BRANCH=main
SF="$T/.specforge/scripts"; SLUG=add-feature

mkdir -p "$T/.specforge/work/active/$SLUG"; echo "# Spec" > "$T/.specforge/work/active/$SLUG/SPEC.md"
git add -A; git commit -q -m "$SLUG: plan"

( cd "$T" && bash "$SF/sf-worktree.sh" create "$SLUG" >/dev/null )
chk "branch created" 'git -C "$T" show-ref --verify --quiet refs/heads/feature/$SLUG'
WT="$T/.worktrees/$SLUG"

( cd "$WT" && git commit -q --allow-empty -m "$SLUG: red tests" )
chk "tests red before impl" '! ( cd "$WT" && bash test.sh )'
STATUS_OUT="$( cd "$T" && bash "$SF/sf-status.sh" )"
chk "state derives tests-red" 'case "$STATUS_OUT" in *state=tests-red*) true;; *) false;; esac'

( cd "$WT" && echo done > feature.txt && git add -A && git commit -q -m "$SLUG: implement" )
chk "tests green after impl" '( cd "$WT" && bash test.sh )'

chk "merge refused w/o trailer" '! ( cd "$T" && bash "$SF/sf-worktree.sh" merge "$SLUG" >/dev/null 2>&1 )'

( cd "$WT" && git commit -q --allow-empty -m "$SLUG: verified" --trailer "Verified-by: verifier (impl)" )
chk "merge succeeds w/ trailer" '( cd "$T" && bash "$SF/sf-worktree.sh" merge "$SLUG" >/dev/null 2>&1 )'
chk "branch deleted after merge" '! git -C "$T" show-ref --verify --quiet refs/heads/feature/$SLUG'
chk "work item archived" 'ls -d "$T"/.specforge/work/archive/*-$SLUG >/dev/null 2>&1'
chk "active dir cleared" '[ ! -d "$T/.specforge/work/active/$SLUG" ]'
chk "feature.txt on main" '[ -f "$T/feature.txt" ]'

[ "$FAIL" -eq 0 ] && echo "lifecycle.test.sh PASS" || { echo "lifecycle.test.sh FAIL"; exit 1; }
