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

# Branch-blob spec resolution lives in lib/spec.sh (sf_resolve_branch_spec_path).

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

state="$(sf_spec_state "$DISPLAY_SPEC")"

if [ "$DISPLAY_SPEC" = "$TEMP_SPEC" ]; then
  display_label="$BRANCH:$branch_spec_path"
else
  display_label="$(sf_relpath "$ROOT" "$DISPLAY_SPEC")"
fi

echo "SPEC file: $display_label"
echo "State: ${state:-missing}"
echo "Branch: $BRANCH"
echo ""

echo "Checklist"
echo "  AC:    $(sf_spec_count_section "$DISPLAY_SPEC" "Acceptance criteria")"
echo "  Tests: $(sf_spec_count_section "$DISPLAY_SPEC" "Tests")"
echo "  Impl:  $(sf_spec_count_section "$DISPLAY_SPEC" "Implementation")"
echo ""

echo "Requirements coverage"
awk '
  /^## Acceptance criteria$/ { section="ac"; next }
  /^## Tests$/ { section="tests"; next }
  /^## / { section=""; next }
  section == "ac" && /^- \[[ x]\]/ {
    line=$0
    sub(/^- \[[ x]\][[:space:]]*/, "", line)
    id=line; sub(/:.*/, "", id)
    if (id ~ /^REQ-[A-Z0-9][A-Z0-9-]*-[0-9]+$/) {
      ac_count++
      ac_ids[ac_count]=id
      ac_checked[ac_count]=($0 ~ /^- \[x\]/)
    }
  }
  section == "tests" && /^- \[[ x]\]/ {
    test_count++
    test_lines[test_count]=$0
    test_checked[test_count]=($0 ~ /^- \[x\]/)
  }
  END {
    function covers(line, req,    rest, n, parts, i) {
      if (line !~ /\(covers /) return 0
      rest=line
      sub(/^.*\(covers[[:space:]]*/, "", rest)
      sub(/\).*$/, "", rest)
      gsub(/,/, " ", rest)
      n=split(rest, parts, /[[:space:]]+/)
      for (i=1; i<=n; i++) if (parts[i] == req) return 1
      return 0
    }
    for (i=1; i<=ac_count; i++) {
      done=0; total=0
      for (j=1; j<=test_count; j++) {
        if (covers(test_lines[j], ac_ids[i])) {
          total++
          if (test_checked[j]) done++
        }
      }
      ac_mark = ac_checked[i] ? "[x]" : "[ ]"
      if (total == 0)           note="no test lines"
      else if (done == total)   note=done "/" total " tests ticked"
      else                      note=done "/" total " tests ticked (partial)"
      printf "  %s %-24s %s\n", ac_mark, ac_ids[i], note
    }
    if (ac_count == 0) print "  (no REQ-* IDs found in Acceptance criteria)"
  }
' "$DISPLAY_SPEC"
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

echo "Diffstat"
if [ "$BRANCH_EXISTS" -eq 1 ]; then
  committed_stat="$(git -C "$ROOT" diff --stat "$BASE..$BRANCH" -- || true)"
else
  committed_stat=""
fi
[ -n "$committed_stat" ] && printf '%s\n' "$committed_stat" || echo "  (none)"
echo ""

if [ "$BRANCH_EXISTS" -eq 1 ] && [ -f "$DISPLAY_SPEC" ]; then
  declared_files="$(awk '
    /^## Tests$/ { section=1; next }
    /^## Implementation$/ { section=1; next }
    /^## / { section=0; next }
    section && /^- \[[ x]\]/ {
      line=$0
      sub(/^- \[[ x]\][[:space:]]*/, "", line)
      split(line, parts, " ")
      if (parts[1] != "") print parts[1]
    }
  ' "$DISPLAY_SPEC")"
  changed_files="$(git -C "$ROOT" diff --name-only "$BASE..$BRANCH" -- 2>/dev/null || true)"
  if [ -n "$changed_files" ]; then
    undeclared=""
    while IFS= read -r cf; do
      [ -n "$cf" ] || continue
      case "$cf" in
        .specforge/specs/*|.specforge/LEARNINGS.md|.specforge/CONTEXT.md|docs/adr/*) continue ;;
      esac
      if ! printf '%s\n' "$declared_files" | grep -qxF "$cf"; then
        undeclared="${undeclared}  ${cf}
"
      fi
    done <<< "$changed_files"
    if [ -n "$undeclared" ]; then
      echo "Warning: files changed but not declared in the SPEC (scope creep or missing declaration):"
      printf '%s' "$undeclared"
      echo ""
    fi
  fi
fi

# Show pending (uncommitted) changes when on the feature branch or in a worktree.
if [ "$CURRENT_BRANCH" = "$BRANCH" ] || [ -n "$PARALLEL_CHECKOUT" ]; then
  staged_stat="$(git -C "$TARGET" diff --cached --stat -- || true)"
  unstaged_stat="$(git -C "$TARGET" diff --stat -- || true)"
  if [ -n "$staged_stat" ] || [ -n "$unstaged_stat" ]; then
    echo "Pending changes"
    [ -n "$staged_stat" ] && printf '%s\n' "$staged_stat" || true
    [ -n "$unstaged_stat" ] && printf '%s\n' "$unstaged_stat" || true
    echo ""
  fi
fi

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

case "$state" in
  draft|"")
    echo "Next: approve the design bundle during /sf-plan (the Designer sets State: approved), then run /sf-test $SPEC_ID."
    ;;
  approved)
    echo "Next: run /sf-test $SPEC_ID to write reviewable red tests."
    ;;
  tests-red)
    echo "Next: review the red tests. If they are right, run /sf-ship $SPEC_ID."
    ;;
  implemented)
    echo "Next: legacy State 'implemented' — a ship session stopped mid-handoff. Tick SPEC checkboxes, set State: done, and commit."
    ;;
  done)
    echo "Next: review the final diff. If it is right, run /sf-finalize $SPEC_ID."
    ;;
  *)
    echo "Next: resolve unknown State '$state'."
    ;;
esac
