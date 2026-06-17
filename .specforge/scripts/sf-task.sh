#!/usr/bin/env bash
# sf-task.sh - Task ID generation and listing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

ROOT="$(sf_root)"
ACTION="${1:-}"

task_next_id() {
  local dir="$ROOT/.specforge/tasks"
  local max=0
  local base n f
  if [ -d "$dir" ]; then
    while IFS= read -r f; do
      base="$(basename "$f")"
      if [[ "$base" =~ ^TASK-([0-9]+) ]]; then
        n="${BASH_REMATCH[1]}"
        n=$((10#$n))
        [ "$n" -gt "$max" ] && max="$n"
      fi
    done < <(find "$dir" -maxdepth 1 -type f -name 'TASK-*.md' 2>/dev/null | sort || true)
  fi
  printf 'TASK-%03d' $((max + 1))
}

task_list() {
  local f id state branch branch_status
  local tasks=()
  while IFS= read -r f; do
    tasks+=("$f")
  done < <(sf_task_files "$ROOT")

  if [ "${#tasks[@]}" -eq 0 ]; then
    echo "(no tasks)"
    return 0
  fi

  for f in "${tasks[@]}"; do
    id="$(sf_task_id_from_name "$f")"
    state="$(sf_spec_field "$f" "State" 2>/dev/null || true)"
    [ -n "$state" ] || state="-"
    branch="feature/$id"
    if sf_branch_exists "$ROOT" "$branch"; then
      branch_status="exists"
    else
      branch_status="missing"
    fi
    printf '%-18s state=%-8s branch=%s\n' "$id" "$state" "$branch_status"
  done
}

case "$ACTION" in
  next-id) task_next_id ;;
  list)    task_list ;;
  *) sf_usage "sf-task.sh <next-id|list>" ;;
esac
