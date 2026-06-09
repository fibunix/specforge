#!/usr/bin/env bash
# sf-worktree.sh - Optional parallel checkout lifecycle for one SPEC.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

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

create_worktree() {
  cd "$ROOT"
  [ ! -d "$WT" ] || sf_die "parallel checkout already exists at $WT"

  mkdir -p "$ROOT/.worktrees"
  touch "$ROOT/.gitignore"
  grep -qxF ".worktrees/" "$ROOT/.gitignore" || echo ".worktrees/" >> "$ROOT/.gitignore"

  git show-ref --verify --quiet "refs/heads/$BRANCH" || git branch "$BRANCH"
  git worktree add "$WT" "$BRANCH"

  echo "parallel checkout ready: $WT (branch: $BRANCH)"
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

  sf_die "parallel checkout has pending changes. Review and commit them first."
}

merge_worktree() {
  [ -d "$WT" ] || sf_die "no parallel checkout at $WT"

  cd "$WT"
  ensure_clean_or_commit

  cd "$ROOT"
  if [ "$MODE" = "--dry-run" ]; then
    git merge-base --is-ancestor HEAD "$BRANCH" || sf_die "dry run failed: $BRANCH cannot fast-forward into $(sf_current_branch "$ROOT")"
    echo "dry run passed: $BRANCH can fast-forward into $(sf_current_branch "$ROOT")"
    return 0
  fi

  git merge --ff-only "$BRANCH" >/dev/null 2>&1 || sf_die "fast-forward merge failed; resolve manually in $WT"
  git worktree remove --force "$WT"
  git branch -d "$BRANCH" 2>/dev/null || git branch -D "$BRANCH"
  echo "merged $BRANCH into $(sf_current_branch "$ROOT") and cleaned up the parallel checkout"
}

case "$ACTION" in
  create) create_worktree ;;
  merge) merge_worktree ;;
  *) sf_usage "sf-worktree.sh <create|merge> SPEC-ID [--dry-run|--auto-commit]" ;;
esac
