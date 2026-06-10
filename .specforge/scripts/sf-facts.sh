#!/usr/bin/env bash
# sf-facts.sh - Dump SpecForge facts from disk. Facts only, no reasoning.
#
# Prints plan-artifact status plus one line per SPEC, each read from its
# most-advanced copy (worktree, feature-branch blob, or checkout) so the
# facts are truthful even when work is in flight on a feature branch.
#
# Interpretation — ordering, dependency analysis, the next action — is the
# agent's job (see the sf-status skill). Scripts enforce, agents interpret.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

ROOT="$(sf_root)"

TMPDIR_FACTS="$(mktemp -d "${TMPDIR:-/tmp}/sf-facts.XXXXXX")"
cleanup() { rm -rf "$TMPDIR_FACTS"; }
trap cleanup EXIT

align_status="$(sf_status_line "$ROOT/.specforge/ALIGN.md")"
design_status="$(sf_status_line "$ROOT/.specforge/DESIGN.md")"
if [ -f "$ROOT/.specforge/NEXT.md" ]; then
  next_status="queued"
else
  next_status="missing"
fi

echo "ALIGN: $align_status   DESIGN: $design_status   ITERATION: $(sf_active_iteration "$ROOT")   NEXT.md: $next_status"

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(sf_spec_files "$ROOT")

if [ "${#files[@]}" -eq 0 ]; then
  echo "(no specs)"
  exit 0
fi

for f in "${files[@]}"; do
  id="$(sf_spec_id_from_name "$f")"
  effective="$(sf_spec_effective_file "$ROOT" "$id" "$TMPDIR_FACTS")"
  state="$(sf_spec_state "$effective" 2>/dev/null)"
  [ -n "$state" ] || state="-"

  case "$effective" in
    "$TMPDIR_FACTS"/*) source_kind="branch" ;;
    "$ROOT/.specforge/specs/"*) source_kind="checkout" ;;
    *) source_kind="worktree" ;;
  esac

  branch="$(sf_branch_for_spec "$id")"
  if sf_branch_exists "$ROOT" "$branch"; then
    branch_status="exists"
  else
    branch_status="missing"
  fi

  ac="$(sf_spec_count_section "$effective" "Acceptance criteria")"
  tests="$(sf_spec_count_section "$effective" "Tests")"
  impl="$(sf_spec_count_section "$effective" "Implementation")"

  printf '%-22s state=%-10s source=%-9s branch=%-8s ac=%s tests=%s impl=%s\n' \
    "$id" "$state" "$source_kind" "$branch_status" "$ac" "$tests" "$impl"
done
