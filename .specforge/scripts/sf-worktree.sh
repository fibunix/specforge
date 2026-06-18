#!/usr/bin/env bash
# sf-worktree.sh - Isolated worktree lifecycle for one SPEC.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"
# shellcheck source=lib/review.sh
source "$SCRIPT_DIR/lib/review.sh"

ROOT="$(sf_root)"
ACTION="${1:-}"
SPEC="${2:-}"
MODE="${3:-}"

[ -n "$ACTION" ] && [ -n "$SPEC" ] || sf_usage "sf-worktree.sh <create|merge> SPEC-ID [--dry-run|--auto-commit]"
case "$MODE" in
  ""|--dry-run|--auto-commit) ;;
  *) sf_usage "sf-worktree.sh <create|merge> SPEC-ID [--dry-run|--auto-commit]" ;;
esac

BRANCH="$(sf_branch_for_spec "$SPEC")"
SPEC_ID="${BRANCH#feature/}"
WT="$(sf_default_worktree_for_spec "$ROOT" "$SPEC")"
BASE_BRANCH="$(sf_base_branch "$ROOT" "$BRANCH" 2>/dev/null || true)"

create_worktree() {
  cd "$ROOT"
  if [ -d "$WT" ]; then
    echo "worktree already exists: $WT (branch: $BRANCH)"
    return 0
  fi

  mkdir -p "$ROOT/.worktrees"
  if [ -d "$ROOT/.git/info" ]; then
    touch "$ROOT/.git/info/exclude"
    grep -qxF ".worktrees/" "$ROOT/.git/info/exclude" || echo ".worktrees/" >> "$ROOT/.git/info/exclude"
  fi

  git show-ref --verify --quiet "refs/heads/$BRANCH" || git branch "$BRANCH"
  git worktree add "$WT" "$BRANCH"

  echo "worktree ready: $WT (branch: $BRANCH)"
  echo "next: /sf-test $SPEC_ID"
}

ensure_clean_or_commit() {
  if git diff --quiet && git diff --cached --quiet; then
    return 0
  fi

  if [ "$MODE" = "--auto-commit" ]; then
    git add -A
    git -c user.name="sf-worktree" -c user.email="sf@local" commit -m "$SPEC_ID: implement" >/dev/null
    echo "committed pending changes"
    return 0
  fi

  sf_die "worktree has pending changes. Review and commit them first."
}

merge_worktree() {
  local head

  [ -d "$WT" ] || sf_die "no worktree at $WT"
  [ -n "$BASE_BRANCH" ] || sf_die "could not find base branch. Set SPECFORGE_BASE_BRANCH or create main/master/trunk/develop."

  cd "$WT"
  ensure_clean_or_commit

  cd "$ROOT"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    sf_die "base checkout has pending changes; commit or discard them before merging"
  fi
  if [ "$(sf_current_branch "$ROOT")" != "$BASE_BRANCH" ]; then
    git switch "$BASE_BRANCH" >/dev/null
  fi

  if [ "$MODE" = "--dry-run" ]; then
    git merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" || sf_die "dry run failed: $BRANCH cannot fast-forward into $BASE_BRANCH"
    echo "dry run passed: $BRANCH can fast-forward into $BASE_BRANCH"
    return 0
  fi

  if [[ "$SPEC_ID" == TASK-* ]]; then
    head="$(git -C "$ROOT" rev-parse "$BRANCH")"
    sf_require_pass_receipt "$ROOT" "$SPEC_ID" task "$head" sf-task-reviewer
  fi

  git merge --ff-only "$BRANCH" >/dev/null 2>&1 || sf_die "fast-forward merge into $BASE_BRANCH failed; resolve manually in $WT"
  git worktree remove --force "$WT"
  git branch -d "$BRANCH" 2>/dev/null || git branch -D "$BRANCH"
  echo "merged $BRANCH into $BASE_BRANCH and cleaned up the worktree"
}

case "$ACTION" in
  create) create_worktree ;;
  merge) merge_worktree ;;
  *) sf_usage "sf-worktree.sh <create|merge> SPEC-ID [--dry-run|--auto-commit]" ;;
esac
