#!/usr/bin/env bash
# sf-snapshot.sh - Phase and per-SPEC status from disk artifacts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"

ROOT="$(sf_root)"

echo "ALIGN.md: $(sf_status_line "$ROOT/.specforge/ALIGN.md")"
echo "DESIGN.md: $(sf_status_line "$ROOT/.specforge/DESIGN.md")"
echo "Iteration: $(sf_active_iteration "$ROOT")"
if [ -f "$ROOT/.specforge/NEXT.md" ]; then
  echo "NEXT.md: queued"
else
  echo "NEXT.md: missing"
fi
if [ -f "$ROOT/.specforge/scripts/sf-registry.sh" ]; then
  bash "$ROOT/.specforge/scripts/sf-registry.sh" summary 2>/dev/null || true
fi
echo ""

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(sf_spec_files "$ROOT")
if [ "${#files[@]}" -eq 0 ]; then
  echo "(no specs yet - run /sf-plan)"
  exit 0
fi

printf "%-22s %-14s %-12s %-12s %-12s %s\n" "SPEC" "BUILD STATE" "TESTS" "IMPL" "AC" "BRANCH"
printf "%-22s %-14s %-12s %-12s %-12s %s\n" "----" "-----------" "-----" "----" "--" "------"

done_count=0
progress_count=0
not_started_count=0

for f in "${files[@]}"; do
  id="$(basename "$f" .md)"
  display_file="$(sf_spec_display_file "$ROOT" "$id")"
  [ -f "$display_file" ] || display_file="$f"

  branch="$(sf_spec_field "$display_file" "Branch")"
  build_state="$(sf_spec_field "$display_file" "Build state")"
  [ -n "$branch" ] || branch="-"
  [ -n "$build_state" ] || build_state="-"

  tests="$(sf_spec_count_section "$display_file" "Tests")"
  impl="$(sf_spec_count_section "$display_file" "Implementation")"
  ac="$(sf_spec_count_section "$display_file" "Acceptance criteria")"

  printf "%-22s %-14s %-12s %-12s %-12s %s\n" "$id" "$build_state" "$tests" "$impl" "$ac" "$branch"

  counts="$(sf_spec_count_all "$display_file")"
  checked="${counts%% *}"
  total="${counts##* }"
  if [ "$build_state" = "done" ] || { [ "$total" -gt 0 ] && [ "$checked" -eq "$total" ]; }; then
    done_count=$((done_count + 1))
  elif { [ "$build_state" != "" ] && [ "$build_state" != "not-started" ]; } || [ "$checked" -gt 0 ]; then
    progress_count=$((progress_count + 1))
  else
    not_started_count=$((not_started_count + 1))
  fi
done

echo ""
echo "Summary: $done_count done, $progress_count in progress, $not_started_count not started"
