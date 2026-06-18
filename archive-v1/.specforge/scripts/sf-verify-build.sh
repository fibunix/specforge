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
    [ -n "$build_cmd" ] && run_config_command build "$target" "$build_cmd"
    [ -n "$lint_cmd" ]  && run_config_command lint  "$target" "$lint_cmd"
  else
    for project_id in $ids; do
      local path dir
      path="$(sf_config_project_value "$cfg" "$project_id" path 2>/dev/null || true)"
      dir="$(sf_config_project_dir "$target" "$path")" || return 1
      build_cmd="$(sf_config_project_value "$cfg" "$project_id" build_command 2>/dev/null || true)"
      lint_cmd="$(sf_config_project_value  "$cfg" "$project_id" lint_command  2>/dev/null || true)"
      [ -n "$build_cmd" ] && run_config_command "build/$project_id" "$dir" "$build_cmd"
      [ -n "$lint_cmd" ]  && run_config_command "lint/$project_id"  "$dir" "$lint_cmd"
    done
  fi
}

verify_red_tests_commit() {
  local target="$1"
  local spec_file="$2"
  local spec_rel base_branch base commit

  spec_rel="${spec_file#$target/}"
  base_branch="$(sf_base_branch "$ROOT" "$EXPECTED_BRANCH" 2>/dev/null || true)"
  [ -n "$base_branch" ] || { fail_check "could not find base branch for history verification"; return 0; }
  base="$(git -C "$target" merge-base "$base_branch" HEAD 2>/dev/null || true)"
  [ -n "$base" ] || { fail_check "could not find merge-base with $base_branch"; return 0; }

  while IFS= read -r commit; do
    if git -C "$target" show "$commit:$spec_rel" 2>/dev/null | grep -q '^\*\*State:\*\*[[:space:]]*tests-red[[:space:]]*$'; then
      return 0
    fi
  done < <(git -C "$target" log --format=%H "$base..HEAD" -- "$spec_rel")

  fail_check "branch history must include a committed State: tests-red before done"
}

verify_declared_scope() {
  local target="$1"
  local spec_file="$2"
  local spec_rel base_branch base changed declared_file changed_file declared_path
  local declared_tmp changed_tmp

  spec_rel="${spec_file#$target/}"
  base_branch="$(sf_base_branch "$ROOT" "$EXPECTED_BRANCH" 2>/dev/null || true)"
  [ -n "$base_branch" ] || { fail_check "could not find base branch for scope verification"; return 0; }
  base="$(git -C "$target" merge-base "$base_branch" HEAD 2>/dev/null || true)"
  [ -n "$base" ] || { fail_check "could not find merge-base with $base_branch"; return 0; }

  declared_tmp="$(mktemp "${TMPDIR:-/tmp}/sf-declared.XXXXXX")"
  changed_tmp="$(mktemp "${TMPDIR:-/tmp}/sf-changed.XXXXXX")"
  trap 'rm -f "$declared_tmp" "$changed_tmp"' RETURN

  sf_spec_checklist_paths "$spec_file" all | sort -u > "$declared_tmp"
  git -C "$target" diff --name-only "$base..HEAD" | sort -u > "$changed_tmp"

  while IFS= read -r declared_path; do
    [ -n "$declared_path" ] || continue
    sf_spec_path_is_normalized_relative "$declared_path" || fail_check "declared path must be normalized and relative: $declared_path"
  done < "$declared_tmp"

  while IFS= read -r changed_file; do
    [ -n "$changed_file" ] || continue
    sf_spec_path_is_normalized_relative "$changed_file" || fail_check "changed path must be normalized and relative: $changed_file"
    case "$changed_file" in
      "$spec_rel"|.specforge/specs/*|.specforge/LEARNINGS.md|.specforge/CONTEXT.md|docs/adr/*)
        continue
        ;;
    esac
    if ! grep -qxF "$changed_file" "$declared_tmp"; then
      fail_check "changed file is not declared in SPEC Tests or Implementation: $changed_file"
    fi
  done < "$changed_tmp"

  while IFS= read -r declared_file; do
    [ -n "$declared_file" ] || continue
    [ -f "$target/$declared_file" ] || fail_check "$SPEC: ticked checkbox references missing file: $declared_file"
  done < <(sf_spec_checklist_paths "$spec_file" checked)

  rm -f "$declared_tmp" "$changed_tmp"
  trap - RETURN
}

if [ "$ERRORS" -eq 0 ]; then
  ( cd "$TARGET" && bash .specforge/scripts/sf-lint-specs.sh )
  ( cd "$TARGET" && bash .specforge/scripts/sf-test.sh )
  run_build_lint "$ROOT/.specforge/config.yaml" "$TARGET"

  if [ -n "$SPEC_FILE" ]; then
    verify_red_tests_commit "$TARGET" "$SPEC_FILE"
    verify_declared_scope "$TARGET" "$SPEC_FILE"
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "Build verification failed with $ERRORS error(s)." >&2
  exit 1
fi

echo "Build verification passed for $SPEC."
