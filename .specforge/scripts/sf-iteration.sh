#!/usr/bin/env bash
# sf-iteration.sh - Internal helpers for completed iteration archive/reset.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"

ROOT="$(sf_root)"
COMMAND="${1:-}"
shift || true

usage() {
  sf_usage "sf-iteration.sh status | archive-reset [--dry-run] [--id ITER-ID]"
}

spec_is_done() {
  local file="$1"
  local state counts checked total

  state="$(sf_spec_field "$file" "Build state")"
  counts="$(sf_spec_count_all "$file")"
  checked="${counts%% *}"
  total="${counts##* }"

  [ "$state" = "done" ] || { [ "$total" -gt 0 ] && [ "$checked" -eq "$total" ]; }
}

all_specs_done() {
  local files=()
  while IFS= read -r file; do
    files+=("$file")
  done < <(sf_spec_files "$ROOT")

  [ "${#files[@]}" -gt 0 ] || return 1

  for file in "${files[@]}"; do
    spec_is_done "$file" || return 1
  done

  return 0
}

show_status() {
  local align_status design_status next_status spec_state

  align_status="$(sf_status_line "$ROOT/.specforge/ALIGN.md")"
  design_status="$(sf_status_line "$ROOT/.specforge/DESIGN.md")"
  if [ -f "$ROOT/.specforge/NEXT.md" ]; then
    next_status="queued"
  else
    next_status="missing"
  fi

  if all_specs_done; then
    spec_state="complete"
  else
    spec_state="active-or-empty"
  fi

  echo "ALIGN.md: $align_status"
  echo "DESIGN.md: $design_status"
  echo "NEXT.md: $next_status"
  echo "Iteration: $spec_state"
}

archive_reset() {
  local dry_run=false
  local id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      --id)
        id="$2"
        shift 2
        ;;
      *)
        usage
        ;;
    esac
  done

  [ "$(sf_status_line "$ROOT/.specforge/ALIGN.md")" = "approved" ] || sf_die "ALIGN.md must be approved before archiving"
  [ "$(sf_status_line "$ROOT/.specforge/DESIGN.md")" = "approved" ] || sf_die "DESIGN.md must be approved before archiving"
  all_specs_done || sf_die "all active SPEC files must be done before archiving"

  [ -n "$id" ] || id="ITER-$(date +%Y%m%d-%H%M%S)"
  case "$id" in
    ITER-*) ;;
    *) sf_die "iteration id must start with ITER-" ;;
  esac

  local archive_dir="$ROOT/.specforge/iterations/$id"
  [ ! -e "$archive_dir" ] || sf_die "iteration archive already exists: .specforge/iterations/$id"

  if [ "$dry_run" = true ]; then
    echo "would archive active iteration to .specforge/iterations/$id"
    echo "would reset .specforge/ALIGN.md, .specforge/DESIGN.md, .specforge/NEXT.md, and active SPEC files"
    return 0
  fi

  mkdir -p "$archive_dir/specs"
  for artifact in ALIGN.md DESIGN.md NEXT.md; do
    if [ -f "$ROOT/.specforge/$artifact" ]; then
      cp "$ROOT/.specforge/$artifact" "$archive_dir/$artifact"
    fi
  done

  local spec
  while IFS= read -r spec; do
    cp "$spec" "$archive_dir/specs/$(basename "$spec")"
  done < <(sf_spec_files "$ROOT")

  rm -f "$ROOT/.specforge/ALIGN.md" "$ROOT/.specforge/DESIGN.md" "$ROOT/.specforge/NEXT.md"
  while IFS= read -r spec; do
    rm -f "$spec"
  done < <(sf_spec_files "$ROOT")

  if [ -f "$ROOT/.specforge/scripts/sf-registry.sh" ]; then
    ( cd "$ROOT" && bash .specforge/scripts/sf-registry.sh rebuild >/dev/null )
  elif [ -f "$SCRIPT_DIR/sf-registry.sh" ]; then
    ( cd "$ROOT" && bash "$SCRIPT_DIR/sf-registry.sh" rebuild >/dev/null )
  fi

  echo "Archived active iteration to .specforge/iterations/$id"
  echo "Reset active Plan artifacts. Next: /sf-plan to align the next iteration."
}

case "$COMMAND" in
  status)
    show_status
    ;;
  archive-reset)
    archive_reset "$@"
    ;;
  *)
    usage
    ;;
esac
