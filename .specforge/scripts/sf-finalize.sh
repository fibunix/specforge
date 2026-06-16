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

[ -n "$SPEC" ] || sf_usage "sf-finalize.sh SPEC-ID [--dry-run|--rebase]"
case "$MODE" in
  ""|--dry-run|--rebase) ;;
  *) sf_usage "sf-finalize.sh SPEC-ID [--dry-run|--rebase]" ;;
esac

BRANCH="$(sf_branch_for_spec "$SPEC")"
CURRENT_BRANCH="$(sf_current_branch "$ROOT")"
BASE_BRANCH="$(sf_base_branch "$ROOT" "$BRANCH" 2>/dev/null || true)"
PARALLEL_CHECKOUT="$(sf_worktree_for_branch "$ROOT" "$BRANCH" 2>/dev/null || true)"

# Rebase a branch living in a worktree onto the base branch, rerun
# tests there, then ff-merge into the base branch and clean up the worktree.
rebase_and_merge_parallel() {
  local root="$1"
  local branch="$2"
  local base="$3"
  local spec="$4"
  local wt="$5"

  if ! git -C "$root" merge-base --is-ancestor "$base" "$branch" 2>/dev/null; then
    if ! git -C "$wt" rebase "$base"; then
      git -C "$wt" rebase --abort 2>/dev/null || true
      sf_die "Rebase of $branch onto $base produced conflicts. Resolve manually in $wt:
  git rebase $base
  # fix conflicts
  git rebase --continue
Then re-run: sf finalize $spec --rebase"
    fi
    echo "Rebase successful. Rerunning tests in the worktree..."
    ( cd "$wt" && bash .specforge/scripts/sf-test.sh )
  fi

  git -C "$root" merge-base --is-ancestor "$base" "$branch" || sf_die "$branch still cannot fast-forward into $base after rebase"
  [ "$(sf_current_branch "$root")" = "$base" ] || git -C "$root" switch "$base" >/dev/null
  git -C "$root" merge --ff-only "$branch" >/dev/null
  git -C "$root" worktree remove --force "$wt"
  git -C "$root" branch -d "$branch" >/dev/null
  echo "Rebased and merged $branch into $base; removed the worktree."
}

sf_branch_exists "$ROOT" "$BRANCH" || sf_die "branch missing: $BRANCH"
[ -n "$BASE_BRANCH" ] || sf_die "could not find base branch. Set SPECFORGE_BASE_BRANCH or create main/master/trunk/develop."

if [ -n "$PARALLEL_CHECKOUT" ] && [ "$PARALLEL_CHECKOUT" != "$ROOT" ]; then
  echo "Finalizing $SPEC from worktree"
  echo "1/2 Verifying completed branch..."
  ( cd "$ROOT" && bash .specforge/scripts/sf-verify-build.sh "$SPEC" )

  if [ "$MODE" = "--dry-run" ]; then
    echo "2/2 Checking fast-forward merge..."
    git -C "$ROOT" merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" || sf_die "$BRANCH cannot fast-forward into $BASE_BRANCH"
    echo "Dry run passed for $SPEC. No merge performed."
    exit 0
  fi

  if [ "$MODE" = "--rebase" ]; then
    echo "2/2 Rebasing onto $BASE_BRANCH and merging worktree..."
    rebase_and_merge_parallel "$ROOT" "$BRANCH" "$BASE_BRANCH" "$SPEC" "$PARALLEL_CHECKOUT"
    echo ""
    ( cd "$ROOT" && bash .specforge/scripts/sf-facts.sh )
    exit 0
  fi

  echo "2/2 Merging and cleaning up worktree..."
  ( cd "$ROOT" && bash .specforge/scripts/sf-worktree.sh merge "$SPEC" )
  echo ""
  ( cd "$ROOT" && bash .specforge/scripts/sf-facts.sh )
  exit 0
fi

[ "$CURRENT_BRANCH" = "$BRANCH" ] || sf_die "no worktree found for $SPEC and current branch is not $BRANCH. Create a worktree: sf worktree create $SPEC"

if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
  sf_die "checkout has pending changes; commit or discard them before finalizing"
fi

echo "Finalizing $SPEC"
echo "1/2 Verifying completed branch..."
( cd "$ROOT" && bash .specforge/scripts/sf-verify-build.sh "$SPEC" )

if [ "$MODE" = "--rebase" ]; then
  echo "2/2 Rebasing $BRANCH onto $BASE_BRANCH..."
  if ! git -C "$ROOT" merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" 2>/dev/null; then
    # Base has moved; rebase needed
    if ! git -C "$ROOT" rebase "$BASE_BRANCH" "$BRANCH"; then
      git -C "$ROOT" rebase --abort 2>/dev/null || true
      sf_die "Rebase of $BRANCH onto $BASE_BRANCH produced conflicts. Resolve manually:
  git switch $BRANCH
  git rebase $BASE_BRANCH
  # fix conflicts
  git rebase --continue
Then re-run: sf finalize $SPEC"
    fi
    echo "Rebase successful. Rerunning tests..."
    ( cd "$ROOT" && bash .specforge/scripts/sf-test.sh )
  fi
  # After rebase (or if already up to date), ff-merge
  git -C "$ROOT" merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" || sf_die "$BRANCH still cannot fast-forward into $BASE_BRANCH after rebase"
  git -C "$ROOT" switch "$BASE_BRANCH" >/dev/null
  git -C "$ROOT" merge --ff-only "$BRANCH" >/dev/null
  git -C "$ROOT" branch -d "$BRANCH" >/dev/null
  echo "Rebased and merged $BRANCH into $BASE_BRANCH."
  echo ""
  ( cd "$ROOT" && bash .specforge/scripts/sf-facts.sh )
  exit 0
fi

echo "2/2 Checking fast-forward merge into $BASE_BRANCH..."
git -C "$ROOT" merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" || sf_die "$BRANCH cannot fast-forward into $BASE_BRANCH. Use --rebase if the base branch has moved."

if [ "$MODE" = "--dry-run" ]; then
  echo "Dry run passed for $SPEC. No merge performed."
  exit 0
fi

git -C "$ROOT" switch "$BASE_BRANCH" >/dev/null
git -C "$ROOT" merge --ff-only "$BRANCH" >/dev/null
git -C "$ROOT" branch -d "$BRANCH" >/dev/null

echo "Merged $BRANCH into $BASE_BRANCH and deleted the feature branch."
echo ""
( cd "$ROOT" && bash .specforge/scripts/sf-facts.sh )
