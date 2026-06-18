#!/usr/bin/env bash
# Helpers for preserving user-owned markdown while updating SpecForge-owned blocks.

SPECFORGE_MANAGED_BEGIN="<!-- BEGIN SPECFORGE MANAGED BLOCK v1 -->"
SPECFORGE_MANAGED_END="<!-- END SPECFORGE MANAGED BLOCK v1 -->"

sf_managed_block_file() {
  local template="$1"
  echo "$SPECFORGE_MANAGED_BEGIN"
  cat "$template"
  echo "$SPECFORGE_MANAGED_END"
}

sf_count_fixed_lines() {
  local file="$1"
  local needle="$2"
  grep -Fxc "$needle" "$file" 2>/dev/null || true
}

sf_update_managed_block() {
  local file="$1"
  local template="$2"
  local dry_run="${3:-false}"
  local label="${4:-$file}"
  local begin_count end_count block tmp

  [ -f "$template" ] || sf_die "managed block template missing at $template"

  block="$(mktemp)"
  tmp="$(mktemp)"
  sf_managed_block_file "$template" > "$block"

  if [ ! -e "$file" ] && [ ! -L "$file" ]; then
    cp "$block" "$tmp"
  elif [ -L "$file" ]; then
    sf_warn "$label is a symlink; preserving it"
    rm -f "$block" "$tmp"
    return 0
  else
    begin_count="$(sf_count_fixed_lines "$file" "$SPECFORGE_MANAGED_BEGIN")"
    end_count="$(sf_count_fixed_lines "$file" "$SPECFORGE_MANAGED_END")"

    if [ "$begin_count" -ne "$end_count" ]; then
      rm -f "$block" "$tmp"
      sf_die "$label has malformed SpecForge managed block markers"
    fi
    if [ "$begin_count" -gt 1 ]; then
      rm -f "$block" "$tmp"
      sf_die "$label has duplicate SpecForge managed blocks"
    fi

    if [ "$begin_count" -eq 1 ]; then
      awk -v begin="$SPECFORGE_MANAGED_BEGIN" -v end="$SPECFORGE_MANAGED_END" -v block_file="$block" '
        BEGIN {
          while ((getline line < block_file) > 0) {
            managed = managed line ORS
          }
        }
        $0 == begin {
          printf "%s", managed
          in_block = 1
          next
        }
        $0 == end {
          in_block = 0
          next
        }
        !in_block { print }
      ' "$file" > "$tmp"
    else
      cp "$file" "$tmp"
      {
        echo ""
        sf_managed_block_file "$template"
      } >> "$tmp"
    fi
  fi

  if [ -f "$file" ] && cmp -s "$file" "$tmp"; then
    echo "  ✓ $label managed block unchanged"
  elif [ "$dry_run" = true ]; then
    echo "  → would update $label managed block"
  else
    cp "$tmp" "$file"
    echo "  ✓ updated $label managed block"
  fi

  rm -f "$block" "$tmp"
}

sf_has_managed_block() {
  local file="$1"
  [ -f "$file" ] || return 1
  [ "$(sf_count_fixed_lines "$file" "$SPECFORGE_MANAGED_BEGIN")" -eq 1 ] &&
    [ "$(sf_count_fixed_lines "$file" "$SPECFORGE_MANAGED_END")" -eq 1 ]
}
