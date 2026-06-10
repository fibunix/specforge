#!/usr/bin/env bash
# sf-wave.sh - Compute which active SPECs can be implemented in parallel.
#
# A "wave" is a set of ready SPECs whose declared test and implementation file
# lists are pairwise disjoint. Within a wave every spec can be built in an
# independent worktree without file conflicts. SPECs that share a file with
# another ready spec are serialized after the conflicting one.
#
# Ready = State approved (most-advanced copy across checkout, worktree, and
# feature branch) with all dependencies done or merged.
#
# Usage:
#   sf-wave.sh          Print the wave plan for the current iteration
#   sf-wave.sh finalize Finalize all done specs of the current iteration in order
#
# Compatible with bash 3.2 (macOS default) — no associative arrays.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"
# shellcheck source=lib/git.sh
source "$SCRIPT_DIR/lib/git.sh"

ROOT="$(sf_root)"
SUBCOMMAND="${1:-}"

TMPDIR_WAVE="$(mktemp -d "${TMPDIR:-/tmp}/sf-wave.XXXXXX")"
cleanup() { rm -rf "$TMPDIR_WAVE"; }
trap cleanup EXIT

# ── Collect declared file paths for a spec ──────────────────────────────────
spec_files_declared() {
  local file="$1"
  awk '
    /^## Tests$/ { section=1; next }
    /^## Implementation$/ { section=1; next }
    /^## / { section=0; next }
    section && /^- \[[ x]\]/ {
      line=$0
      sub(/^- \[[ x]\][[:space:]]*/, "", line)
      split(line, parts, /[[:space:]]/)
      if (parts[1] != "") print parts[1]
    }
  ' "$file"
}

# ── Read all active specs (bash-3.2: parallel indexed arrays) ────────────────
all_ids=()
all_states=()
all_files=()

while IFS= read -r f; do
  id="$(sf_spec_id_from_name "$f")"
  all_ids+=("$id")
  all_states+=("$(sf_spec_effective_state "$ROOT" "$id" "$TMPDIR_WAVE")")
  all_files+=("$(sf_spec_effective_file "$ROOT" "$id" "$TMPDIR_WAVE")")
done < <(sf_spec_files "$ROOT")

if [ "${#all_ids[@]}" -eq 0 ]; then
  echo "(no active specs)"
  exit 0
fi

state_of() {
  local want="$1" i
  for ((i = 0; i < ${#all_ids[@]}; i++)); do
    if [ "${all_ids[$i]}" = "$want" ]; then
      echo "${all_states[$i]}"
      return 0
    fi
  done
  echo "unknown"
}

# A dependency is satisfied only when it is done in the checkout (merged), or
# when its feature branch is an ancestor of the base branch (merged but not yet
# pulled). A dep that is done on an *unmerged* feature branch does NOT count:
# sf-worktree.sh branches from the base, so the dependent worktree would lack
# the dep's implementation. (Mirrors the stricter semantics in sf-snapshot.sh.)
checkout_state_done() {
  local id="$1" file
  if file="$(sf_resolve_spec_file "$ROOT" "$id" 2>/dev/null)"; then
    [ "$(sf_spec_state "$file")" = "done" ]
  else
    return 1
  fi
}

deps_satisfied() {
  local id="$1" dep dep_branch base_branch
  for dep in $(sf_design_spec_deps "$ROOT" "$id"); do
    if checkout_state_done "$dep"; then
      : # done in checkout (merged) — ok
    else
      dep_branch="$(sf_branch_for_spec "$dep")"
      base_branch="$(sf_base_branch "$ROOT" "$dep_branch" 2>/dev/null || true)"
      if [ -n "$base_branch" ] && git -C "$ROOT" merge-base --is-ancestor "$dep_branch" "$base_branch" 2>/dev/null; then
        : # dep branch merged into base — ok
      else
        return 1
      fi
    fi
  done
  return 0
}

# ── finalize: merge every done spec of the iteration, in order ──────────────
# Selection is independent of the "ready" filter: a done spec lives at State
# done on its feature branch or worktree, never at approved.
# Iteration order: DESIGN-table order (deps before dependents), falling back
# to file order for any specs not listed in the table.
if [ "$SUBCOMMAND" = "finalize" ]; then
  finalized=0
  skipped=0

  # Build finalize_ids in DESIGN-table order, appending any extra specs.
  design_order=()
  while IFS= read -r did; do
    design_order+=("$did")
  done < <(sf_design_spec_order "$ROOT")

  finalize_ids=()
  for did in ${design_order[@]+"${design_order[@]}"}; do
    for id in ${all_ids[@]+"${all_ids[@]}"}; do
      [ "$id" = "$did" ] && { finalize_ids+=("$id"); break; }
    done
  done
  for id in ${all_ids[@]+"${all_ids[@]}"}; do
    found=0
    for fid in ${finalize_ids[@]+"${finalize_ids[@]}"}; do
      [ "$id" = "$fid" ] && { found=1; break; }
    done
    [ "$found" -eq 0 ] && finalize_ids+=("$id")
  done

  for id in ${finalize_ids[@]+"${finalize_ids[@]}"}; do
    state="$(state_of "$id")"
    branch="$(sf_branch_for_spec "$id")"
    if [ "$state" != "done" ]; then
      echo "  $id: State is '${state:-missing}' (not done) — skipping"
      skipped=$((skipped + 1))
      continue
    fi
    if ! sf_branch_exists "$ROOT" "$branch"; then
      echo "  $id: already merged ($branch gone) — skipping"
      skipped=$((skipped + 1))
      continue
    fi
    echo ""
    echo "Finalizing $id..."
    ( cd "$ROOT" && bash .specforge/scripts/sf-finalize.sh "$id" --rebase )
    finalized=$((finalized + 1))
  done
  echo ""
  echo "Wave finalize: $finalized merged, $skipped skipped."
  exit 0
fi

# ── Find ready specs (approved, deps all done/merged) ────────────────────────
ready_ids=()
ready_files=()
for ((i = 0; i < ${#all_ids[@]}; i++)); do
  [ "${all_states[$i]}" = "approved" ] || continue
  deps_satisfied "${all_ids[$i]}" || continue
  ready_ids+=("${all_ids[$i]}")
  ready_files+=("${all_files[$i]}")
done

if [ "${#ready_ids[@]}" -eq 0 ]; then
  echo "No specs are ready for implementation."
  echo "(Ready = State: approved with all dependencies done or merged)"
  exit 0
fi

# ── Compute file sets and detect overlaps ────────────────────────────────────
owned_files=()   # declared file paths claimed by wave members
owned_by=()      # owning spec id, same index
wave_specs=()
serialize_specs=()
serialize_reasons=()

owner_of() {
  local want="$1" i
  for ((i = 0; i < ${#owned_files[@]}; i++)); do
    if [ "${owned_files[$i]}" = "$want" ]; then
      echo "${owned_by[$i]}"
      return 0
    fi
  done
  return 1
}

for ((i = 0; i < ${#ready_ids[@]}; i++)); do
  id="${ready_ids[$i]}"
  conflict=""
  declared="$(spec_files_declared "${ready_files[$i]}")"

  while IFS= read -r fp; do
    [ -n "$fp" ] || continue
    if owner="$(owner_of "$fp")" && [ "$owner" != "$id" ]; then
      conflict="$owner"
      break
    fi
  done <<EOF
$declared
EOF

  if [ -n "$conflict" ]; then
    serialize_specs+=("$id")
    serialize_reasons+=("shares files with $conflict")
  else
    while IFS= read -r fp; do
      [ -n "$fp" ] || continue
      owned_files+=("$fp")
      owned_by+=("$id")
    done <<EOF
$declared
EOF
    wave_specs+=("$id")
  fi
done

# ── Print wave plan ───────────────────────────────────────────────────────────
echo "Wave (parallel-safe, no file overlap):"
if [ "${#wave_specs[@]}" -eq 0 ]; then
  echo "  (none — all ready specs share files with each other)"
else
  for id in "${wave_specs[@]}"; do
    branch="$(sf_branch_for_spec "$id")"
    echo "  $id  →  sf worktree create $id   then /sf-test $id in that checkout"
    echo "           branch: $branch"
  done
fi

if [ "${#serialize_specs[@]}" -gt 0 ]; then
  echo ""
  echo "Serialized (file overlap with wave member):"
  for ((i = 0; i < ${#serialize_specs[@]}; i++)); do
    echo "  ${serialize_specs[$i]}  →  start after ${serialize_reasons[$i]} is finalized"
  done
fi

echo ""
echo "To run the wave:"
for id in "${wave_specs[@]}"; do
  echo "  sf worktree create $id   # isolated checkout"
  echo "  # open a session in .worktrees/$id and run /sf-test $id"
done
echo ""
echo "To finalize the wave (after all specs are done and reviewed):"
echo "  sf wave finalize"
