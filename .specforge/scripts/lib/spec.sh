#!/usr/bin/env bash
# Helpers for parsing SpecForge SPEC markdown files.

sf_spec_files() {
  local root="$1"
  local dir="$root/.specforge/specs"
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -type f -name 'SPEC-*.md' ! -name 'SPEC-TEMPLATE.md' | sort
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
  done < <(find "$dir" -maxdepth 1 -type f -name "$base-*.md" ! -name 'SPEC-TEMPLATE.md' | sort)

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

  for file in "$root/.specforge/NEXT.md" "$root/.specforge/ALIGN.md" "$root/.specforge/DESIGN.md"; do
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
