#!/usr/bin/env bash
# sf-verify-build.sh - Verify a SPEC branch is ready for review/merge.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

ROOT="$(sf_root)"
SPEC="${1:-}"
[ -n "$SPEC" ] || sf_usage "sf-verify-build.sh SPEC-ID"

SPEC_ID="$(sf_spec_id_from_name "$SPEC")"
EXPECTED_BRANCH="$(sf_branch_for_spec "$SPEC_ID")"
TARGET="$(sf_worktree_for_branch "$ROOT" "$EXPECTED_BRANCH" 2>/dev/null || true)"
SPEC_FILE=""
ERRORS=0

fail_check() {
  sf_fail "$1"
  ERRORS=$((ERRORS + 1))
}

echo "Verifying $SPEC"

if [ -z "$TARGET" ]; then
  fail_check "no worktree found for $SPEC. Create one: sf worktree create $SPEC"
elif [ ! -d "$TARGET" ]; then
  fail_check "checkout missing: $TARGET"
elif ! SPEC_FILE="$(sf_resolve_spec_file "$TARGET" "$SPEC")"; then
  ERRORS=$((ERRORS + 1))
else
  state="$(sf_spec_state "$SPEC_FILE")"

  if [ "$state" = "done" ]; then
    unchecked="$(sf_spec_count_unchecked "$SPEC_FILE")"
    [ "$unchecked" -eq 0 ] || fail_check "State is done but $unchecked checkbox(es) are unchecked"
  else
    fail_check "State must be done before handoff, found '${state:-missing}'"
  fi

  current_branch="$(sf_current_branch "$TARGET")"
  [ "$current_branch" = "$EXPECTED_BRANCH" ] || fail_check "checkout branch must be $EXPECTED_BRANCH, found '${current_branch:-missing}'"

  if ! git -C "$TARGET" diff --quiet || ! git -C "$TARGET" diff --cached --quiet; then
    fail_check "checkout has pending changes; commit before handoff"
  fi
fi

run_config_command() {
  local label="$1" dir="$2" cmd="$3"
  echo "-> [$label] (cd $(sf_relpath "$ROOT" "$dir") && $cmd)"
  ( cd "$dir" && bash -lc "$cmd" )
}

run_build_lint() {
  local cfg="$1" target="$2"
  local ids build_cmd lint_cmd

  [ -f "$cfg" ] || return 0
  ids="$(sf_config_project_ids "$cfg")"

  if [ -z "$ids" ]; then
    build_cmd="$(sf_config_top_value "$cfg" build_command 2>/dev/null || true)"
    lint_cmd="$(sf_config_top_value "$cfg" lint_command 2>/dev/null || true)"
    [ -n "$build_cmd" ] && run_config_command build "$target" "$build_cmd" || true
    [ -n "$lint_cmd" ]  && run_config_command lint  "$target" "$lint_cmd"  || true
  else
    for project_id in $ids; do
      local path dir
      path="$(sf_config_project_value "$cfg" "$project_id" path 2>/dev/null || true)"
      dir="$(sf_config_project_dir "$target" "$path")"
      build_cmd="$(sf_config_project_value "$cfg" "$project_id" build_command 2>/dev/null || true)"
      lint_cmd="$(sf_config_project_value  "$cfg" "$project_id" lint_command  2>/dev/null || true)"
      [ -n "$build_cmd" ] && run_config_command "build/$project_id" "$dir" "$build_cmd" || true
      [ -n "$lint_cmd" ]  && run_config_command "lint/$project_id"  "$dir" "$lint_cmd"  || true
    done
  fi
}

if [ "$ERRORS" -eq 0 ]; then
  ( cd "$TARGET" && bash .specforge/scripts/sf-lint-specs.sh )
  ( cd "$TARGET" && bash .specforge/scripts/sf-test.sh )
  run_build_lint "$ROOT/.specforge/config.yaml" "$TARGET"

  # Scope review (undeclared changed files) is the review skill's judgment.
  # This backstop only catches the error-shaped lie: a ticked checkbox whose
  # file does not exist in TARGET.
  if [ -n "$SPEC_FILE" ]; then
    while IFS= read -r fp; do
      [ -n "$fp" ] || continue
      [ -f "$TARGET/$fp" ] || sf_warn "$SPEC: ticked checkbox references missing file: $fp"
    done < <(awk '
      /^## Tests$/ { section=1; next }
      /^## Implementation$/ { section=1; next }
      /^## / { section=0; next }
      section && /^- \[x\]/ {
        line=$0
        sub(/^- \[x\][[:space:]]*/, "", line)
        split(line, parts, " ")
        if (parts[1] != "") print parts[1]
      }
    ' "$SPEC_FILE")
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "Build verification failed with $ERRORS error(s)." >&2
  exit 1
fi

echo "Build verification passed for $SPEC."
