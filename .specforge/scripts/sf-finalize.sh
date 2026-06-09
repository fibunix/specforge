#!/usr/bin/env bash
# sf-finalize.sh - Verify, fast-forward merge, and clean up one SPEC branch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

ROOT="$(sf_root)"
SPEC="${1:-}"
MODE="${2:-}"

[ -n "$SPEC" ] || sf_usage "sf-finalize.sh SPEC-ID [--dry-run]"
case "$MODE" in
  ""|--dry-run) ;;
  *) sf_usage "sf-finalize.sh SPEC-ID [--dry-run]" ;;
esac

BRANCH="$(sf_branch_for_spec "$SPEC")"
CURRENT_BRANCH="$(sf_current_branch "$ROOT")"
BASE_BRANCH="$(sf_base_branch "$ROOT" "$BRANCH" 2>/dev/null || true)"
PARALLEL_CHECKOUT="$(sf_worktree_for_branch "$ROOT" "$BRANCH" 2>/dev/null || true)"

sf_branch_exists "$ROOT" "$BRANCH" || sf_die "branch missing: $BRANCH"
[ -n "$BASE_BRANCH" ] || sf_die "could not find base branch. Set SPECFORGE_BASE_BRANCH or create main/master/trunk/develop."

if [ -n "$PARALLEL_CHECKOUT" ] && [ "$PARALLEL_CHECKOUT" != "$ROOT" ]; then
  echo "Finalizing $SPEC from optional parallel checkout"
  echo "1/2 Verifying completed branch..."
  ( cd "$ROOT" && bash .specforge/scripts/sf-verify-build.sh "$SPEC" )

  if [ "$MODE" = "--dry-run" ]; then
    echo "2/2 Checking fast-forward merge..."
    git -C "$ROOT" merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" || sf_die "$BRANCH cannot fast-forward into $BASE_BRANCH"
    echo "Dry run passed for $SPEC. No merge performed."
    exit 0
  fi

  echo "2/2 Merging and cleaning up optional parallel checkout..."
  ( cd "$ROOT" && bash .specforge/scripts/sf-worktree.sh merge "$SPEC" )
  echo ""
  ( cd "$ROOT" && bash .specforge/scripts/sf-snapshot.sh )
  exit 0
fi

[ "$CURRENT_BRANCH" = "$BRANCH" ] || sf_die "current branch must be $BRANCH. Run: git switch $BRANCH"

if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
  sf_die "checkout has pending changes; commit or discard them before finalizing"
fi

echo "Finalizing $SPEC"
echo "1/2 Verifying completed branch..."
( cd "$ROOT" && bash .specforge/scripts/sf-verify-build.sh "$SPEC" )

echo "2/2 Checking fast-forward merge into $BASE_BRANCH..."
git -C "$ROOT" merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" || sf_die "$BRANCH cannot fast-forward into $BASE_BRANCH"

if [ "$MODE" = "--dry-run" ]; then
  echo "Dry run passed for $SPEC. No merge performed."
  exit 0
fi

git -C "$ROOT" switch "$BASE_BRANCH" >/dev/null
git -C "$ROOT" merge --ff-only "$BRANCH" >/dev/null
git -C "$ROOT" branch -d "$BRANCH" >/dev/null

echo "Merged $BRANCH into $BASE_BRANCH and deleted the feature branch."
echo ""
( cd "$ROOT" && bash .specforge/scripts/sf-snapshot.sh )
