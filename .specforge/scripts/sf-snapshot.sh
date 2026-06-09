#!/usr/bin/env bash
# sf-snapshot.sh - Phase and per-SPEC status from disk artifacts.
#
# State is read from the most-advanced copy of each spec: worktree copy,
# feature-branch blob, or checkout copy — so the table is truthful even when
# work is in flight on a feature branch and the checkout is on the base branch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

ROOT="$(sf_root)"

TMPDIR_SNAP="$(mktemp -d "${TMPDIR:-/tmp}/sf-snapshot.XXXXXX")"
cleanup() { rm -rf "$TMPDIR_SNAP"; }
trap cleanup EXIT

align_status="$(sf_status_line "$ROOT/.specforge/ALIGN.md")"
design_status="$(sf_status_line "$ROOT/.specforge/DESIGN.md")"

echo "ALIGN.md: $align_status"
echo "DESIGN.md: $design_status"
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

next_line() {
  echo ""
  echo "Next: $1"
}

if [ "$align_status" = "missing" ]; then
  echo "(no specs yet - run /sf-plan)"
  next_line "/sf-plan"
  exit 0
fi
if [ "$align_status" != "approved" ]; then
  echo "(plan in progress)"
  next_line "/sf-plan (ALIGN.md needs approval)"
  exit 0
fi
if [ "$design_status" = "missing" ]; then
  echo "(design not started)"
  next_line "/sf-plan (continue to design)"
  exit 0
fi
if [ "$design_status" != "approved" ]; then
  echo "(design in progress)"
  next_line "/sf-plan (DESIGN.md and SPECs need approval)"
  exit 0
fi

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(sf_spec_files "$ROOT")
if [ "${#files[@]}" -eq 0 ]; then
  echo "(no specs yet - run /sf-plan)"
  next_line "/sf-plan (design approved but no SPEC files exist)"
  exit 0
fi

# ── Order specs by the DESIGN.md SPECS table when available ─────────────────
ordered_ids=()
while IFS= read -r id; do
  [ -n "$id" ] && ordered_ids+=("$id")
done < <(sf_design_spec_order "$ROOT")

spec_ids=()
for f in "${files[@]}"; do
  spec_ids+=("$(sf_spec_id_from_name "$f")")
done

in_list() {
  local want="$1" item
  shift
  for item in "$@"; do
    [ "$item" = "$want" ] && return 0
  done
  return 1
}

# Dependency-table order first, then any specs the table missed (file order).
display_ids=()
for id in ${ordered_ids[@]+"${ordered_ids[@]}"}; do
  in_list "$id" "${spec_ids[@]}" && display_ids+=("$id")
done
for id in "${spec_ids[@]}"; do
  in_list "$id" ${display_ids[@]+"${display_ids[@]}"} || display_ids+=("$id")
done

printf "%-22s %-14s %-12s %-12s %-12s %s\n" "SPEC" "STATE" "TESTS" "IMPL" "AC" "BRANCH"
printf "%-22s %-14s %-12s %-12s %-12s %s\n" "----" "-----" "-----" "----" "--" "------"

done_count=0
progress_count=0
not_started_count=0

all_states=()
all_branch_exists=()

for id in "${display_ids[@]}"; do
  display_file="$(sf_spec_effective_file "$ROOT" "$id" "$TMPDIR_SNAP")"
  state="$(sf_spec_state "$display_file" 2>/dev/null)"
  branch="$(sf_branch_for_spec "$id")"
  [ -n "$state" ] || state="-"

  if sf_branch_exists "$ROOT" "$branch"; then
    all_branch_exists+=("yes")
  else
    all_branch_exists+=("no")
  fi
  all_states+=("$state")

  tests="$(sf_spec_count_section "$display_file" "Tests")"
  impl="$(sf_spec_count_section "$display_file" "Implementation")"
  ac="$(sf_spec_count_section "$display_file" "Acceptance criteria")"

  printf "%-22s %-14s %-12s %-12s %-12s %s\n" "$id" "$state" "$tests" "$impl" "$ac" "$branch"

  counts="$(sf_spec_count_all "$display_file")"
  checked="${counts%% *}"
  total="${counts##* }"
  if [ "$state" = "done" ] || { [ "$total" -gt 0 ] && [ "$checked" -eq "$total" ]; }; then
    done_count=$((done_count + 1))
  elif { [ "$state" != "-" ] && [ "$state" != "draft" ] && [ "$state" != "approved" ]; } || [ "$checked" -gt 0 ]; then
    progress_count=$((progress_count + 1))
  else
    not_started_count=$((not_started_count + 1))
  fi
done

echo ""
echo "Summary: $done_count done, $progress_count in progress, $not_started_count not started"

# ── Next action, in priority order ───────────────────────────────────────────
# 1. red tests awaiting review/implementation
# 2. done specs awaiting finalize (feature branch still exists)
# 3. first approved spec whose dependencies are done (checkout copy)
# 4. draft specs → plan approval pending
# 5. everything done → next iteration
checkout_state_done() {
  local id="$1" file
  if file="$(sf_resolve_spec_file "$ROOT" "$id" 2>/dev/null)"; then
    [ "$(sf_spec_state "$file")" = "done" ]
  else
    return 1
  fi
}

next=""
for ((i = 0; i < ${#display_ids[@]}; i++)); do
  if [ "${all_states[$i]}" = "tests-red" ]; then
    next="/sf-review ${display_ids[$i]} then /sf-ship ${display_ids[$i]} (red tests await your approval)"
    break
  fi
done

if [ -z "$next" ]; then
  for ((i = 0; i < ${#display_ids[@]}; i++)); do
    if [ "${all_states[$i]}" = "done" ] && [ "${all_branch_exists[$i]}" = "yes" ]; then
      next="/sf-review ${display_ids[$i]} then /sf-finalize ${display_ids[$i]} (implementation awaits final review)"
      break
    fi
  done
fi

if [ -z "$next" ]; then
  for ((i = 0; i < ${#display_ids[@]}; i++)); do
    [ "${all_states[$i]}" = "approved" ] || continue
    deps_ok=1
    for dep in $(sf_design_spec_deps "$ROOT" "${display_ids[$i]}"); do
      checkout_state_done "$dep" || { deps_ok=0; break; }
    done
    if [ "$deps_ok" -eq 1 ]; then
      next="/sf-test ${display_ids[$i]} (approved, dependencies satisfied)"
      break
    fi
  done
fi

if [ -z "$next" ]; then
  for ((i = 0; i < ${#display_ids[@]}; i++)); do
    if [ "${all_states[$i]}" = "draft" ] || [ "${all_states[$i]}" = "-" ]; then
      next="/sf-plan (SPECs exist but the design bundle is not approved yet)"
      break
    fi
  done
fi

if [ -z "$next" ]; then
  if [ "$done_count" -eq "${#display_ids[@]}" ]; then
    if [ -f "$ROOT/.specforge/NEXT.md" ]; then
      next="all done — run /sf-plan to start the queued next iteration"
    else
      next="all done — run /sf-plan to frame the next iteration"
    fi
  else
    next="run /sf-status after resolving in-progress work, or /sf-plan if the state above looks wrong"
  fi
fi

next_line "$next"
