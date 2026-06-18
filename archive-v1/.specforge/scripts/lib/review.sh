#!/usr/bin/env bash
# Helpers for validating SpecForge review receipts.

sf_receipt_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    index($0, field ":") == 1 {
      sub("^" field ":[[:space:]]*", "")
      print
      exit
    }
  ' "$file" 2>/dev/null
}

sf_receipt_has_command() {
  local file="$1"
  awk '
    /^commands run:[[:space:]]*$/ { in_commands=1; next }
    in_commands && /^- / { found=1 }
    in_commands && /^[[:alnum:]_ -]+:[[:space:]]*/ { in_commands=0 }
    END { exit found ? 0 : 1 }
  ' "$file"
}

sf_expected_reviewer_for_phase() {
  # One fresh-eyes reviewer covers every phase. The phase still scopes what the
  # reviewer checks; the reviewer name is uniform so there is one concept, not
  # four near-identical ones.
  case "$1" in
    tests-red|done|task|plan) echo "sf-reviewer" ;;
    *)                        return 1 ;;
  esac
}

sf_require_pass_receipt() {
  local root="$1"
  local work_id="$2"
  local phase="$3"
  local head="$4"
  local expected_reviewer="${5:-}"
  local receipt receipt_rel base final_line verdict_count

  [ -n "$expected_reviewer" ] || expected_reviewer="$(sf_expected_reviewer_for_phase "$phase")" \
    || sf_die "no expected reviewer is defined for phase: $phase"

  receipt="$root/.specforge/reviews/$work_id/$phase-$head.md"
  receipt_rel=".specforge/reviews/$work_id/$phase-$head.md"
  [ -f "$receipt" ] || sf_die "$phase gate requires PASS receipt: $receipt_rel"

  [ "$(sf_receipt_field "$receipt" spec_id)" = "$work_id" ] \
    || sf_die "$phase receipt has wrong spec_id: $receipt_rel"
  [ "$(sf_receipt_field "$receipt" phase)" = "$phase" ] \
    || sf_die "$phase receipt has wrong phase: $receipt_rel"
  [ "$(sf_receipt_field "$receipt" head)" = "$head" ] \
    || sf_die "$phase receipt head does not match $head: $receipt_rel"
  [ "$(sf_receipt_field "$receipt" reviewer)" = "$expected_reviewer" ] \
    || sf_die "$phase receipt reviewer must be $expected_reviewer: $receipt_rel"
  [ "$(sf_receipt_field "$receipt" verdict)" = "PASS" ] \
    || sf_die "$phase receipt must have verdict: PASS: $receipt_rel"

  base="$(sf_receipt_field "$receipt" base)"
  [ -n "$base" ] || sf_die "$phase receipt missing base commit: $receipt_rel"
  git -C "$root" cat-file -e "$base^{commit}" 2>/dev/null \
    || sf_die "$phase receipt base is not a commit in this repo: $receipt_rel"

  sf_receipt_has_command "$receipt" \
    || sf_die "$phase receipt must list at least one command under 'commands run': $receipt_rel"

  verdict_count="$(grep -c '^VERDICT:' "$receipt" 2>/dev/null || true)"
  [ "$verdict_count" -eq 1 ] \
    || sf_die "$phase receipt must contain exactly one VERDICT line: $receipt_rel"
  final_line="$(tail -n 1 "$receipt" 2>/dev/null || true)"
  [ "$final_line" = "VERDICT: PASS" ] \
    || sf_die "$phase receipt final line must be exact VERDICT: PASS: $receipt_rel"
}

sf_tests_red_commit_for_branch() {
  local root="$1"
  local branch="$2"
  local spec_id="$3"
  local base_branch base spec_rel commit

  base_branch="$(sf_base_branch "$root" "$branch" 2>/dev/null || true)"
  [ -n "$base_branch" ] || return 1
  base="$(git -C "$root" merge-base "$base_branch" "$branch" 2>/dev/null || true)"
  [ -n "$base" ] || return 1
  spec_rel="$(sf_resolve_branch_spec_path "$root" "$branch" "$spec_id" 2>/dev/null || true)"
  [ -n "$spec_rel" ] || return 1

  while IFS= read -r commit; do
    if git -C "$root" show "$commit:$spec_rel" 2>/dev/null | grep -q '^\*\*State:\*\*[[:space:]]*tests-red[[:space:]]*$'; then
      echo "$commit"
      return 0
    fi
  done < <(git -C "$root" log --reverse --format=%H "$base..$branch" -- "$spec_rel")

  return 1
}
