#!/usr/bin/env bash
# sf-test.sh - Run configured project test command(s).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

ROOT="$(sf_root)"
CFG="$ROOT/.specforge/config.yaml"
PROJECT="${1:-}"

[ -f "$CFG" ] || sf_die "$CFG not found. Run: bash .specforge/scripts/sf-init.sh"

run_command() {
  local label="$1"
  local dir="$2"
  local cmd="$3"

  [ -d "$dir" ] || sf_die "$label path does not exist: $dir"

  echo "-> [$label] (cd $(sf_relpath "$ROOT" "$dir") && $cmd)"
  ( cd "$dir" && bash -lc "$cmd" )
}

run_root() {
  local cmd
  cmd="$(sf_config_top_value "$CFG" test_command)"
  [ -n "$cmd" ] || sf_die "test_command not set in $CFG"
  run_command root "$ROOT" "$cmd"
}

run_project() {
  local project_id="$1"
  local path
  local cmd
  local dir

  path="$(sf_config_project_value "$CFG" "$project_id" path)"
  cmd="$(sf_config_project_value "$CFG" "$project_id" test_command)"
  [ -n "$cmd" ] || sf_die "project '$project_id' has no test_command in $CFG"

  dir="$(sf_config_project_dir "$ROOT" "$path")"
  run_command "$project_id" "$dir" "$cmd"
}

IDS="$(sf_config_project_ids "$CFG")"

if [ "$PROJECT" = "--list" ]; then
  if [ -n "$IDS" ]; then
    printf '%s\n' "$IDS"
  else
    echo "root"
  fi
  exit 0
fi

if [ -n "$PROJECT" ]; then
  if [ -n "$IDS" ]; then
    printf '%s\n' "$IDS" | grep -qxF "$PROJECT" || {
      sf_fail "unknown project '$PROJECT' in $CFG"
      echo "known projects:" >&2
      printf '  %s\n' $IDS >&2
      exit 1
    }
    run_project "$PROJECT"
  elif [ "$PROJECT" = "root" ]; then
    run_root
  else
    sf_die "no projects configured in $CFG; omit the project id or use 'root'"
  fi
  exit $?
fi

if [ -z "$IDS" ]; then
  run_root
  exit $?
fi

FAILED=0
for project_id in $IDS; do
  run_project "$project_id" || FAILED=1
done

[ "$FAILED" -eq 0 ] || sf_die "one or more project test commands failed"
