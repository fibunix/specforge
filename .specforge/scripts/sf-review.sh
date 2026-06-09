#!/usr/bin/env bash
# sf-review.sh - Show what changed for one SPEC without changing state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

ROOT="$(sf_root)"
SPEC="${1:-}"
MODE="${2:-}"

[ -n "$SPEC" ] || sf_usage "sf-review.sh SPEC-ID [--patch]"
case "$MODE" in
  ""|--patch) ;;
  *) sf_usage "sf-review.sh SPEC-ID [--patch]" ;;
esac

SPEC_ID="$(sf_spec_id_from_name "$SPEC")"
BRANCH="$(sf_branch_for_spec "$SPEC_ID")"
CURRENT_BRANCH="$(sf_current_branch "$ROOT")"
BRANCH_EXISTS=0
TARGET="$ROOT"
PARALLEL_CHECKOUT=""
TEMP_SPEC=""
TEMP_RESOLVE_ERR=""

cleanup() {
  [ -z "$TEMP_SPEC" ] || rm -f "$TEMP_SPEC"
  [ -z "$TEMP_RESOLVE_ERR" ] || rm -f "$TEMP_RESOLVE_ERR"
}
trap cleanup EXIT

sf_resolve_branch_spec_path() {
  local root="$1"
  local branch="$2"
  local spec_or_file="$3"
  local base
  local exact
  local matches=()
  local path

  base="$(sf_spec_basename "$spec_or_file")"
  exact=".specforge/specs/$base.md"

  if git -C "$root" cat-file -e "$branch:$exact" 2>/dev/null; then
    echo "$exact"
    return 0
  fi

  while IFS= read -r path; do
    case "$path" in
      .specforge/specs/"$base"-*.md) matches+=("$path") ;;
    esac
  done < <(git -C "$root" ls-tree -r --name-only "$branch" .specforge/specs 2>/dev/null || true)

  case "${#matches[@]}" in
    1)
      echo "${matches[0]}"
      return 0
      ;;
    0)
      return 1
      ;;
    *)
      sf_fail "SPEC file is ambiguous for $spec_or_file on $branch. Matching files:"
      for path in "${matches[@]}"; do
        echo "  $(basename "$path")" >&2
      done
      echo "Pass the full spec basename, for example: $(basename "${matches[0]}" .md)" >&2
      return 2
      ;;
  esac
}

sf_branch_exists "$ROOT" "$BRANCH" && BRANCH_EXISTS=1

if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  PARALLEL_CHECKOUT="$(sf_worktree_for_branch "$ROOT" "$BRANCH" 2>/dev/null || true)"
  [ -n "$PARALLEL_CHECKOUT" ] && TARGET="$PARALLEL_CHECKOUT"
fi

TEMP_RESOLVE_ERR="$(mktemp "${TMPDIR:-/tmp}/sf-review-resolve.XXXXXX")"
DISPLAY_SPEC=""
if [ -n "$TARGET" ] && [ -d "$TARGET/.specforge/specs" ]; then
  if DISPLAY_SPEC="$(sf_resolve_spec_file "$TARGET" "$SPEC" 2>"$TEMP_RESOLVE_ERR")"; then
    :
  elif grep -q "ambiguous" "$TEMP_RESOLVE_ERR"; then
    cat "$TEMP_RESOLVE_ERR" >&2
    exit 1
  else
    DISPLAY_SPEC=""
  fi
fi

if [ "$BRANCH_EXISTS" -eq 1 ] && [ "$CURRENT_BRANCH" != "$BRANCH" ] && [ -z "$PARALLEL_CHECKOUT" ]; then
  if branch_spec_path="$(sf_resolve_branch_spec_path "$ROOT" "$BRANCH" "$SPEC")"; then
    TEMP_SPEC="$(mktemp "${TMPDIR:-/tmp}/sf-review-spec.XXXXXX")"
    git -C "$ROOT" show "$BRANCH:$branch_spec_path" > "$TEMP_SPEC"
    DISPLAY_SPEC="$TEMP_SPEC"
  else
    branch_resolve_status=$?
    if [ "$branch_resolve_status" -gt 1 ]; then
      exit 1
    fi
  fi
fi

echo "Review $SPEC"
echo ""

if [ ! -f "$DISPLAY_SPEC" ]; then
  echo "SPEC: missing (.specforge/specs/$(sf_spec_basename "$SPEC").md or .specforge/specs/$(sf_spec_basename "$SPEC")-<slug>.md)"
  echo "Branch: $BRANCH"
  echo ""
  echo "Next: create or approve the SPEC during Plan."
  exit 1
fi

status="$(sf_spec_field "$DISPLAY_SPEC" "Status")"
build_state="$(sf_spec_field "$DISPLAY_SPEC" "Build state")"
branch_meta="$(sf_spec_field "$DISPLAY_SPEC" "Branch")"

if [ "$DISPLAY_SPEC" = "$TEMP_SPEC" ]; then
  display_label="$BRANCH:$branch_spec_path"
else
  display_label="$(sf_relpath "$ROOT" "$DISPLAY_SPEC")"
fi

echo "SPEC file: $display_label"
echo "Status: ${status:-missing}"
echo "Build state: ${build_state:-missing}"
echo "Branch: ${branch_meta:-$BRANCH}"
echo ""

echo "Checklist"
echo "  AC:    $(sf_spec_count_section "$DISPLAY_SPEC" "Acceptance criteria")"
echo "  Tests: $(sf_spec_count_section "$DISPLAY_SPEC" "Tests")"
echo "  Impl:  $(sf_spec_count_section "$DISPLAY_SPEC" "Implementation")"
echo ""

echo "Git"
if [ "$BRANCH_EXISTS" -eq 1 ]; then
  BASE="$(sf_review_base "$ROOT" "$BRANCH")"
  echo "  Base: $(git -C "$ROOT" rev-parse --short "$BASE")"
  echo "  Head: $(git -C "$ROOT" rev-parse --short "$BRANCH") ($BRANCH)"
else
  BASE=""
  echo "  Branch missing: $BRANCH"
fi

echo "  Current branch: ${CURRENT_BRANCH:-unknown}"
if [ -n "$PARALLEL_CHECKOUT" ]; then
  echo "  Parallel checkout: $(sf_relpath "$ROOT" "$PARALLEL_CHECKOUT")"
fi
echo ""

echo "Commits"
if [ "$BRANCH_EXISTS" -eq 1 ]; then
  commits="$(git -C "$ROOT" log --oneline "$BASE..$BRANCH" -- 2>/dev/null || true)"
else
  commits=""
fi
[ -n "$commits" ] && printf '%s\n' "$commits" || echo "  (none)"
echo ""

echo "Committed diffstat"
if [ "$BRANCH_EXISTS" -eq 1 ]; then
  committed_stat="$(git -C "$ROOT" diff --stat "$BASE..$BRANCH" -- || true)"
else
  committed_stat=""
fi
[ -n "$committed_stat" ] && printf '%s\n' "$committed_stat" || echo "  (none)"
echo ""

echo "Pending changes"
if [ "$CURRENT_BRANCH" = "$BRANCH" ] || [ -n "$PARALLEL_CHECKOUT" ]; then
  staged_stat="$(git -C "$TARGET" diff --cached --stat -- || true)"
  unstaged_stat="$(git -C "$TARGET" diff --stat -- || true)"

  if [ -n "$staged_stat" ]; then
    echo "  Staged:"
    printf '%s\n' "$staged_stat"
  else
    echo "  Staged: none"
  fi

  if [ -n "$unstaged_stat" ]; then
    echo "  Unstaged:"
    printf '%s\n' "$unstaged_stat"
  else
    echo "  Unstaged: none"
  fi
else
  echo "  Switch to $BRANCH to inspect pending changes."
fi
echo ""

if [ "$MODE" = "--patch" ]; then
  echo "Patch"
  if [ "$BRANCH_EXISTS" -eq 1 ]; then
    git -C "$ROOT" diff "$BASE..$BRANCH" --
  fi
  if [ "$CURRENT_BRANCH" = "$BRANCH" ] || [ -n "$PARALLEL_CHECKOUT" ]; then
    git -C "$TARGET" diff --cached --
    git -C "$TARGET" diff --
  fi
  echo ""
fi

case "$build_state" in
  not-started|"")
    echo "Next: run /sf-test $SPEC_ID to write reviewable red tests."
    ;;
  tests-red)
    echo "Next: review the red tests. If they are right, run /sf-ship $SPEC_ID."
    ;;
  implemented)
    echo "Next: finish verification, tick SPEC checkboxes, and commit before final review."
    ;;
  done)
    echo "Next: review the final diff. If it is right, run /sf-finalize $SPEC_ID."
    ;;
  *)
    echo "Next: resolve unknown Build state '$build_state'."
    ;;
esac
