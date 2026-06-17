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
  sf_usage "sf-iteration.sh status | next-id [slug] | archive-reset [--dry-run] [--abandon] [--id ITER-ID]"
}

spec_is_done() {
  local file="$1"
  local explicit_state counts checked total

  explicit_state="$(sf_spec_field "$file" "State")"
  counts="$(sf_spec_count_all "$file")"
  checked="${counts%% *}"
  total="${counts##* }"

  [ "$explicit_state" = "done" ] && [ "$total" -gt 0 ] && [ "$checked" -eq "$total" ]
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

# Sequential iteration ID for the next iteration: ITER-NNN or ITER-NNN-slug.
# NNN = number of archived iterations + 1.
next_id() {
  local slug="${1:-}"
  local count=0 n

  if [ -d "$ROOT/.specforge/iterations" ]; then
    count="$(find "$ROOT/.specforge/iterations" -mindepth 1 -maxdepth 1 -type d -name 'ITER-*' | wc -l | tr -d '[:space:]')"
  fi
  n=$((count + 1))

  if [ -n "$slug" ]; then
    printf 'ITER-%03d-%s\n' "$n" "$slug"
  else
    printf 'ITER-%03d\n' "$n"
  fi
}

# Minimal close-out stub for an abandoned iteration when the agent did not
# write one (abandons may run in a terse context). Normal archives require an
# agent-authored .specforge/SUMMARY.md — the agent that lived the iteration
# writes a better close-out than any generated checkbox list.
write_abandon_stub() {
  local archive_dir="$1"
  local id="$2"
  echo "# $id — abandoned $(date +%Y-%m-%d) before all specs were complete." > "$archive_dir/SUMMARY.md"
}

archive_reset() {
  local dry_run=false
  local abandon=false
  local id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      --abandon)
        abandon=true
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

  if [ "$abandon" = false ]; then
    [ "$(sf_status_line "$ROOT/.specforge/ALIGN.md")" = "approved" ] || sf_die "ALIGN.md must be approved before archiving"
    [ "$(sf_status_line "$ROOT/.specforge/DESIGN.md")" = "approved" ] || sf_die "DESIGN.md must be approved before archiving"
    all_specs_done || sf_die "all active SPEC files must be done before archiving"
    [ -f "$ROOT/.specforge/SUMMARY.md" ] || sf_die "write .specforge/SUMMARY.md (the iteration close-out) before archiving — see the sf-plan skill, State 1a"
  fi

  # Default to the iteration's own ID so the archive directory matches the
  # **Iteration:** field inside the archived artifacts.
  if [ -z "$id" ]; then
    if [ -f "$ROOT/.specforge/ALIGN.md" ]; then
      id="$(sf_spec_field "$ROOT/.specforge/ALIGN.md" "Iteration")"
    fi
  fi
  [ -n "$id" ] || id="ITER-$(date +%Y%m%d-%H%M%S)"
  case "$id" in
    ITER-*) ;;
    *) sf_die "iteration id must start with ITER-" ;;
  esac

  local archive_dir="$ROOT/.specforge/iterations/$id"
  [ ! -e "$archive_dir" ] || sf_die "iteration archive already exists: .specforge/iterations/$id"

  if [ "$dry_run" = true ]; then
    if [ "$abandon" = true ]; then
      echo "would abandon and archive active iteration to .specforge/iterations/$id"
    else
      echo "would archive active iteration to .specforge/iterations/$id"
    fi
    echo "would move .specforge/SUMMARY.md into the archive"
    echo "would reset .specforge/ALIGN.md, .specforge/DESIGN.md, and active SPEC files"
    echo "would keep .specforge/NEXT.md as the next iteration's brief"
    return 0
  fi

  mkdir -p "$archive_dir/specs"
  for artifact in ALIGN.md DESIGN.md; do
    if [ -f "$ROOT/.specforge/$artifact" ]; then
      cp "$ROOT/.specforge/$artifact" "$archive_dir/$artifact"
    fi
  done

  local spec
  while IFS= read -r spec; do
    cp "$spec" "$archive_dir/specs/$(basename "$spec")"
  done < <(sf_spec_files "$ROOT")

  # The agent authors the close-out; the script only enforces that it exists
  # (precondition above) and moves it. Abandons get a stub if none was written.
  if [ -f "$ROOT/.specforge/SUMMARY.md" ]; then
    mv "$ROOT/.specforge/SUMMARY.md" "$archive_dir/SUMMARY.md"
  else
    write_abandon_stub "$archive_dir" "$id"
  fi

  # NEXT.md is the *next* iteration's input — never archive-and-delete it.
  rm -f "$ROOT/.specforge/ALIGN.md" "$ROOT/.specforge/DESIGN.md"
  while IFS= read -r spec; do
    rm -f "$spec"
  done < <(sf_spec_files "$ROOT")

  if [ "$abandon" = true ]; then
    echo "Abandoned and archived active iteration to .specforge/iterations/$id"
  else
    echo "Archived active iteration to .specforge/iterations/$id"
  fi
  if [ -f "$ROOT/.specforge/NEXT.md" ]; then
    echo "Kept .specforge/NEXT.md as the next iteration's brief."
  fi
  echo "Reset active Plan artifacts. Next: /sf-plan to align the next iteration."
}

case "$COMMAND" in
  status)
    show_status
    ;;
  next-id)
    next_id "$@"
    ;;
  archive-reset)
    archive_reset "$@"
    ;;
  *)
    usage
    ;;
esac
