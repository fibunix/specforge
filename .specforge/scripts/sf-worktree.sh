#!/usr/bin/env bash
# sf-worktree.sh - Isolated worktree lifecycle for one work item (slug-based).
#
#   sf-worktree.sh create <slug>              create .worktrees/<slug> on feature/<slug>
#   sf-worktree.sh merge  <slug> [--dry-run]  guardrail-checked ff-merge into base, then archive
#
# Merge guardrail (the ONE surviving enforcement, on the single irreversible op):
#   1. the project test command is green at the branch HEAD, and
#   2. HEAD carries a `Verified-by:` git trailer (the fresh-eyes verifier signed off).

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

ACTION="${1:-}"
SLUG="${2:-}"
MODE="${3:-}"

[ -n "$ACTION" ] && [ -n "$SLUG" ] || sf_usage "sf-worktree.sh <create|merge> <slug> [--dry-run]"
SLUG="$(sf_validate_slug "$SLUG")" || exit 1
case "$MODE" in
  ""|--dry-run) ;;
  *) sf_usage "sf-worktree.sh <create|merge> <slug> [--dry-run]" ;;
esac

BRANCH="$(sf_branch_for_slug "$SLUG")"
WT="$(sf_worktree_for_slug "$ROOT" "$SLUG")"
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
  git worktree add "$WT" "$BRANCH" >/dev/null
  echo "worktree ready: $WT (branch: $BRANCH)"
}

run_tests_at() {
  # Run the configured test command from within the given directory.
  local dir="$1"
  ( cd "$dir" && bash "$SCRIPT_DIR/sf-test.sh" )
}

check_guardrail() {
  local head
  head="$(git -C "$ROOT" rev-parse "$BRANCH")"

  echo "guardrail 1/2: running tests on $BRANCH ..."
  if [ -d "$WT" ]; then
    run_tests_at "$WT" || sf_die "merge refused: tests are not green on $BRANCH"
  else
    run_tests_at "$ROOT" || sf_die "merge refused: tests are not green on $BRANCH"
  fi

  echo "guardrail 2/2: checking Verified-by trailer on HEAD ($head) ..."
  sf_has_verified_trailer "$ROOT" "$BRANCH" \
    || sf_die "merge refused: HEAD of $BRANCH has no 'Verified-by:' trailer (no verifier sign-off)"
  echo "guardrail passed"
}

# Archive the work item on the base branch AFTER the ff-merge, then commit.
archive_work_item() {
  local active="$ROOT/work/active/$SLUG"
  local stamp dest
  [ -d "$active" ] || { echo "note: no work/active/$SLUG dir to archive"; return 0; }
  stamp="$(git -C "$ROOT" show -s --format=%cs HEAD 2>/dev/null || echo undated)"
  dest="work/archive/${stamp}-${SLUG}"
  mkdir -p "$ROOT/work/archive"
  git -C "$ROOT" mv "work/active/$SLUG" "$dest" 2>/dev/null \
    || mv "$active" "$ROOT/$dest"
  git -C "$ROOT" add -A "work/active/$SLUG" "$dest" 2>/dev/null || true
  git -C "$ROOT" commit -q -m "$SLUG: archive work item" 2>/dev/null || true
  echo "archived work item -> $dest/"
}

merge_worktree() {
  [ -n "$BASE_BRANCH" ] || sf_die "could not find base branch. Set base_branch in project.yaml or create main/master/trunk/develop."
  sf_branch_exists "$ROOT" "$BRANCH" || sf_die "branch missing: $BRANCH"

  # Commit any pending work in the worktree before inspecting HEAD.
  if [ -d "$WT" ]; then
    cd "$WT"
    if ! git diff --quiet || ! git diff --cached --quiet; then
      sf_die "worktree has uncommitted changes; commit them first ($WT)"
    fi
  fi

  cd "$ROOT"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    sf_die "base checkout has pending changes; commit or discard them before merging"
  fi

  if [ "$MODE" = "--dry-run" ]; then
    git merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" \
      || sf_die "dry run: $BRANCH cannot fast-forward into $BASE_BRANCH"
    echo "dry run passed: $BRANCH can fast-forward into $BASE_BRANCH"
    return 0
  fi

  check_guardrail

  git merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH" \
    || sf_die "$BRANCH cannot fast-forward into $BASE_BRANCH (base moved; rebase the feature branch and retry)"

  [ "$(sf_current_branch "$ROOT")" = "$BASE_BRANCH" ] || git switch "$BASE_BRANCH" >/dev/null
  git merge --ff-only "$BRANCH" >/dev/null 2>&1 \
    || sf_die "fast-forward merge into $BASE_BRANCH failed; resolve manually"
  [ -n "$WT" ] && [ -d "$WT" ] && git worktree remove --force "$WT"
  git branch -d "$BRANCH" 2>/dev/null || git branch -D "$BRANCH"

  # Now that base == feature head, archive the work item on base.
  archive_work_item
  echo "merged $BRANCH into $BASE_BRANCH and cleaned up."
}

case "$ACTION" in
  create) create_worktree ;;
  merge)  merge_worktree ;;
  *) sf_usage "sf-worktree.sh <create|merge> <slug> [--dry-run]" ;;
esac
