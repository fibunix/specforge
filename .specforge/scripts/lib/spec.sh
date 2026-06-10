#!/usr/bin/env bash
# Helpers for parsing SpecForge SPEC markdown files.

sf_spec_files() {
  local root="$1"
  local dir="$root/.specforge/specs"
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f -name 'SPEC-*.md' | sort
}

sf_spec_basename() {
  local spec="$1"
  spec="${spec##*/}"
  spec="${spec%.md}"
  echo "$spec"
}

sf_spec_id_from_name() {
  local spec
  spec="$(sf_spec_basename "$1")"
  if [[ "$spec" =~ ^(SPEC-[0-9]+)-.+$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$spec" =~ ^(SPEC-[A-Z0-9][A-Z0-9-]*-[0-9]+)-.+$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "$spec"
  fi
}

sf_resolve_spec_file() {
  local root="$1"
  local spec_or_file="$2"
  local dir="$root/.specforge/specs"
  local base
  local exact
  local matches=()
  local file

  base="$(sf_spec_basename "$spec_or_file")"

  if [ ! -d "$dir" ]; then
    sf_fail "SPEC directory missing: $dir"
    return 1
  fi

  exact="$dir/$base.md"
  if [ -f "$exact" ]; then
    echo "$exact"
    return 0
  fi

  while IFS= read -r file; do
    matches+=("$file")
  done < <(find "$dir" -maxdepth 1 -type f -name "$base-*.md" | sort)

  case "${#matches[@]}" in
    1)
      echo "${matches[0]}"
      return 0
      ;;
    0)
      sf_fail "SPEC file missing for $spec_or_file. Accepted forms: .specforge/specs/$base.md or .specforge/specs/$base-<slug>.md"
      return 1
      ;;
    *)
      sf_fail "SPEC file is ambiguous for $spec_or_file. Matching files:"
      for file in "${matches[@]}"; do
        echo "  $(basename "$file")" >&2
      done
      echo "Pass the full spec basename, for example: $(basename "${matches[0]}" .md)" >&2
      return 1
      ;;
  esac
}

sf_spec_state() {
  local file="$1"
  local state status build_state
  state="$(sf_spec_field "$file" "State")"
  if [ -n "$state" ]; then
    echo "$state"
    return 0
  fi
  # Legacy fallback: derive from Status + Build state
  build_state="$(sf_spec_field "$file" "Build state")"
  status="$(sf_spec_field "$file" "Status")"
  if [ -n "$build_state" ] && [ "$build_state" != "not-started" ]; then
    echo "$build_state"
  elif [ -n "$status" ]; then
    echo "$status"
  else
    echo ""
  fi
}

sf_status_line() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "missing"
    return
  fi
  awk '
    /^\*\*Status:\*\*/ {
      sub(/^\*\*Status:\*\*[[:space:]]*/, "")
      print
      found=1
      exit
    }
    END { if (!found) print "unknown" }
  ' "$file"
}

sf_spec_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    index($0, "**" field ":**") == 1 {
      sub("^\\*\\*" field ":\\*\\*[[:space:]]*", "")
      print
      exit
    }
  ' "$file" 2>/dev/null
}

sf_active_iteration() {
  local root="$1"
  local value=""

  # NEXT.md is intentionally excluded: it describes the *next* iteration and
  # carries no Iteration field (see templates/NEXT.md).
  for file in "$root/.specforge/ALIGN.md" "$root/.specforge/DESIGN.md"; do
    if [ -f "$file" ]; then
      value="$(sf_spec_field "$file" "Iteration")"
      if [ -n "$value" ]; then
        echo "$value"
        return 0
      fi
    fi
  done

  if [ -d "$root/.specforge/specs" ]; then
    while IFS= read -r file; do
      value="$(sf_spec_field "$file" "Iteration")"
      if [ -n "$value" ]; then
        echo "$value"
        return 0
      fi
    done < <(sf_spec_files "$root")
  fi

  echo "none"
}

sf_spec_count_section() {
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    $0 ~ "^## " h "$" { section=1; next }
    /^## / { section=0 }
    section && /^- \[[ x]\]/ {
      total++
      if (/^- \[x\]/) done++
    }
    END { printf "%d/%d", done+0, total+0 }
  ' "$file"
}

sf_spec_count_all() {
  local file="$1"
  awk '
    /^## Acceptance criteria$/ { section="ac"; next }
    /^## Tests$/ { section="tests"; next }
    /^## Implementation$/ { section="impl"; next }
    /^## / { section=""; next }
    section && /^- \[[ x]\]/ {
      total++
      if (/^- \[x\]/) done++
    }
    END { printf "%d %d", done+0, total+0 }
  ' "$file"
}

sf_spec_count_unchecked() {
  local file="$1"
  awk '
    /^## Acceptance criteria$/ { section="ac"; next }
    /^## Tests$/ { section="tests"; next }
    /^## Implementation$/ { section="impl"; next }
    /^## / { section=""; next }
    section && /^- \[ \]/ { unchecked++ }
    END { print unchecked+0 }
  ' "$file"
}

sf_spec_display_file() {
  local root="$1"
  local spec="$2"
  local stable_spec
  local display_file
  local wt_dir

  stable_spec="$(sf_spec_id_from_name "$spec")"

  for wt_dir in "$root/.worktrees/$stable_spec" "$root/.worktrees/$(sf_spec_basename "$spec")"; do
    if [ -d "$wt_dir" ] && display_file="$(sf_resolve_spec_file "$wt_dir" "$spec" 2>/dev/null)"; then
      echo "$display_file"
      return 0
    fi
  done

  if display_file="$(sf_resolve_spec_file "$root" "$spec" 2>/dev/null)"; then
    echo "$display_file"
  else
    echo "$root/.specforge/specs/$(sf_spec_basename "$spec").md"
  fi
}

# Lifecycle order used to pick the most-advanced copy of a spec.
sf_state_rank() {
  case "$1" in
    done) echo 5 ;;
    implemented) echo 4 ;;  # legacy state, treated as nearly done
    tests-red) echo 3 ;;
    approved) echo 2 ;;
    draft|not-started) echo 1 ;;
    *) echo 0 ;;
  esac
}

# Resolve a spec's path inside a git branch (no checkout needed).
# Prints the in-repo relative path. Returns 1 if missing, 2 if ambiguous.
sf_resolve_branch_spec_path() {
  local root="$1"
  local branch="$2"
  local spec_or_file="$3"
  local base
  local exact
  local matches=()
  local path

  base="$(sf_spec_basename "$spec_or_file")"
  exact=".specforge/specs/$base.md"

  if git -C "$root" cat-file -e "$branch:$exact" 2>/dev/null; then
    echo "$exact"
    return 0
  fi

  while IFS= read -r path; do
    case "$path" in
      .specforge/specs/"$base"-*.md) matches+=("$path") ;;
    esac
  done < <(git -C "$root" ls-tree -r --name-only "$branch" .specforge/specs 2>/dev/null || true)

  case "${#matches[@]}" in
    1)
      echo "${matches[0]}"
      return 0
      ;;
    0)
      return 1
      ;;
    *)
      sf_fail "SPEC file is ambiguous for $spec_or_file on $branch. Matching files:"
      for path in "${matches[@]}"; do
        echo "  $(basename "$path")" >&2
      done
      echo "Pass the full spec basename, for example: $(basename "${matches[0]}" .md)" >&2
      return 2
      ;;
  esac
}

# Most-advanced copy of a spec: worktree copy (at any path), feature-branch
# blob, or checkout copy — whichever carries the furthest **State:**. Branch
# blobs are extracted into the caller-provided tmpdir (caller owns cleanup).
# Requires lib/git.sh to be sourced.
sf_spec_effective_file() {
  local root="$1"
  local spec="$2"
  local tmpdir="$3"
  local best_file best_rank
  local branch branch_path branch_file branch_rank
  local wt_path wt_file wt_rank

  best_file="$(sf_spec_display_file "$root" "$spec")"
  best_rank="$(sf_state_rank "$(sf_spec_state "$best_file" 2>/dev/null)")"

  branch="$(sf_branch_for_spec "$spec")"
  if sf_branch_exists "$root" "$branch" && [ "$(sf_current_branch "$root")" != "$branch" ]; then
    if wt_path="$(sf_worktree_for_branch "$root" "$branch" 2>/dev/null)"; then
      # Worktree exists — read spec from it at its actual path (handles custom paths).
      if wt_file="$(sf_resolve_spec_file "$wt_path" "$spec" 2>/dev/null)"; then
        wt_rank="$(sf_state_rank "$(sf_spec_state "$wt_file" 2>/dev/null)")"
        if [ "$wt_rank" -gt "$best_rank" ]; then
          best_file="$wt_file"
          best_rank="$wt_rank"
        fi
      fi
    else
      # No worktree — read spec from branch blob instead.
      if branch_path="$(sf_resolve_branch_spec_path "$root" "$branch" "$spec" 2>/dev/null)"; then
        branch_file="$tmpdir/${branch//\//_}.$(sf_spec_basename "$branch_path").md"
        if git -C "$root" show "$branch:$branch_path" > "$branch_file" 2>/dev/null; then
          branch_rank="$(sf_state_rank "$(sf_spec_state "$branch_file" 2>/dev/null)")"
          if [ "$branch_rank" -gt "$best_rank" ]; then
            best_file="$branch_file"
            best_rank="$branch_rank"
          fi
        fi
      fi
    fi
  fi

  echo "$best_file"
}

# State of the most-advanced copy of a spec (see sf_spec_effective_file).
sf_spec_effective_state() {
  local root="$1"
  local spec="$2"
  local tmpdir="$3"
  sf_spec_state "$(sf_spec_effective_file "$root" "$spec" "$tmpdir")"
}

# SPEC IDs in DESIGN.md "SPECS produced" table order (build order).
sf_design_spec_order() {
  local root="$1"
  local design="$root/.specforge/DESIGN.md"
  [ -f "$design" ] || return 0
  awk '
    /^\| *SPEC-[A-Z0-9]/ {
      split($0, cols, "|")
      row_id=cols[2]; gsub(/[[:space:]]/, "", row_id)
      if (row_id ~ /^SPEC-/) print row_id
    }
  ' "$design"
}

# Dependencies of one SPEC from the DESIGN.md "SPECS produced" table.
sf_design_spec_deps() {
  local root="$1"
  local spec_id="$2"
  local design="$root/.specforge/DESIGN.md"
  [ -f "$design" ] || return 0
  awk -v id="$spec_id" '
    /^\| *SPEC-[A-Z0-9]/ {
      split($0, cols, "|")
      row_id=cols[2]; gsub(/[[:space:]]/, "", row_id)
      deps=cols[4];   gsub(/[[:space:]]/, "", deps)
      if (row_id == id && deps != "—" && deps != "-" && deps != "") {
        gsub(/,/, " ", deps)
        print deps
      }
    }
  ' "$design"
}
