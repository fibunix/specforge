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

ROOT="$(sf_root)"
SPEC="${1:-}"
[ -n "$SPEC" ] || sf_usage "sf-verify-build.sh SPEC-ID"

SPEC_ID="$(sf_spec_id_from_name "$SPEC")"
EXPECTED_BRANCH="$(sf_branch_for_spec "$SPEC_ID")"
CURRENT_BRANCH="$(sf_current_branch "$ROOT")"
PARALLEL_CHECKOUT="$(sf_worktree_for_branch "$ROOT" "$EXPECTED_BRANCH" 2>/dev/null || true)"

if [ "$CURRENT_BRANCH" = "$EXPECTED_BRANCH" ]; then
  TARGET="$ROOT"
elif [ -n "$PARALLEL_CHECKOUT" ]; then
  TARGET="$PARALLEL_CHECKOUT"
else
  TARGET=""
fi
SPEC_FILE=""
ERRORS=0

fail_check() {
  sf_fail "$1"
  ERRORS=$((ERRORS + 1))
}

echo "Verifying $SPEC"

if [ -z "$TARGET" ]; then
  fail_check "checkout must be on $EXPECTED_BRANCH, or use an optional parallel checkout for that branch"
elif [ ! -d "$TARGET" ]; then
  fail_check "checkout missing: $TARGET"
elif ! SPEC_FILE="$(sf_resolve_spec_file "$TARGET" "$SPEC")"; then
  ERRORS=$((ERRORS + 1))
else
  status="$(sf_spec_field "$SPEC_FILE" "Status")"
  build_state="$(sf_spec_field "$SPEC_FILE" "Build state")"
  branch_meta="$(sf_spec_field "$SPEC_FILE" "Branch")"

  [ "$status" = "approved" ] || fail_check "SPEC status must be approved, found '${status:-missing}'"
  [ "$branch_meta" = "$EXPECTED_BRANCH" ] || fail_check "SPEC branch metadata must be $EXPECTED_BRANCH, found '${branch_meta:-missing}'"

  unchecked="$(sf_spec_count_unchecked "$SPEC_FILE")"
  if [ "$build_state" = "done" ]; then
    [ "$unchecked" -eq 0 ] || fail_check "Build state is done but $unchecked checkbox(es) are unchecked"
  else
    fail_check "Build state must be done before handoff, found '${build_state:-missing}'"
  fi

  current_branch="$(sf_current_branch "$TARGET")"
  [ "$current_branch" = "$EXPECTED_BRANCH" ] || fail_check "checkout branch must be $EXPECTED_BRANCH, found '${current_branch:-missing}'"

  if ! git -C "$TARGET" diff --quiet || ! git -C "$TARGET" diff --cached --quiet; then
    fail_check "checkout has pending changes; commit before handoff"
  fi
fi

if [ "$ERRORS" -eq 0 ]; then
  ( cd "$TARGET" && bash .specforge/scripts/sf-lint-specs.sh )
  ( cd "$TARGET" && bash .specforge/scripts/sf-test.sh )
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "Build verification failed with $ERRORS error(s)." >&2
  exit 1
fi

echo "Build verification passed for $SPEC."
