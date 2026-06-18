#!/usr/bin/env bash
# sf-status.sh - Read-only facts about active work items, derived from git + fs.
# Enforces nothing; safe to be stale. The coordinator reads this to decide next action.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/../lib"
# shellcheck source=../lib/common.sh
source "$LIB/common.sh"
# shellcheck source=../lib/config.sh
source "$LIB/config.sh"
# shellcheck source=../lib/git.sh
source "$LIB/git.sh"
# shellcheck source=../lib/work.sh
source "$LIB/work.sh"

ROOT="$(sf_root)"
sf_apply_config_base_branch "$ROOT"
BASE_BRANCH="$(sf_base_branch "$ROOT" "" 2>/dev/null || echo '(none)')"

echo "base branch: $BASE_BRANCH"

# NEXT.md backlog presence.
if [ -f "$ROOT/NEXT.md" ] && grep -q '[^[:space:]]' "$ROOT/NEXT.md" 2>/dev/null; then
  echo "backlog: NEXT.md present"
else
  echo "backlog: NEXT.md empty/absent"
fi

echo ""
echo "active work items:"
found=0
for d in "$ROOT"/work/active/*/; do
  [ -d "$d" ] || continue
  found=1
  slug="$(basename "$d")"
  state="$(sf_work_state "$ROOT" "$slug")"
  branch="$(sf_branch_for_slug "$slug")"
  br="no-branch"; sf_branch_exists "$ROOT" "$branch" && br="$branch"
  wt="$(sf_existing_worktree "$ROOT" "$slug")"; [ -n "$wt" ] && wt="worktree" || wt="-"
  arts=""
  for a in WORK ALIGN DESIGN SPEC; do
    [ -f "$d/$a.md" ] && arts="$arts $a"
  done
  printf '  %-28s state=%-13s branch=%-22s wt=%-9s artifacts=%s\n' \
    "$slug" "$state" "$br" "$wt" "${arts# }"
done
[ "$found" -eq 1 ] || echo "  (none)"

echo ""
echo "recently archived:"
arch=0
for d in "$ROOT"/work/archive/*/; do
  [ -d "$d" ] || continue
  arch=1
  echo "  $(basename "$d")"
done
[ "$arch" -eq 1 ] || echo "  (none)"
