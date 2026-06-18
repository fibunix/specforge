#!/usr/bin/env bash
# Shared adapter helpers.

sf_safe_link() {
  local target="$1"
  local link="$2"
  local label="$3"
  local current=""

  if [ -e "$link" ] || [ -L "$link" ]; then
    current="$(readlink "$link" 2>/dev/null || true)"
    if [ "$current" = "$target" ]; then
      echo "  ✓ $label already linked"
    else
      echo "  ⚠ preserving existing $label at $link"
    fi
  else
    ln -s "$target" "$link"
    echo "  ✓ linked $label"
  fi
}

sf_remove_stale_specforge_links() {
  local dir="$1"
  local managed_fragment="$2"
  local label="$3"
  local link target resolved

  [ -d "$dir" ] || return 0
  for link in "$dir"/*; do
    [ -L "$link" ] || continue
    target="$(readlink "$link" 2>/dev/null || true)"
    case "$target" in
      *"$managed_fragment"*)
        resolved="$(cd "$(dirname "$link")" && cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")" || resolved=""
        if [ -z "$resolved" ] || [ ! -e "$resolved" ]; then
          rm "$link"
          echo "  ✓ removed stale $label symlink $(basename "$link")"
        fi
        ;;
    esac
  done
}

sf_adapter_list_from_arg_or_install() {
  local root="$1"
  local ide_arg="${2:-}"
  local valid_ides="opencode claude-code codex pi antigravity"
  local ide_list=""

  if [ -n "$ide_arg" ]; then
    if [ "$ide_arg" = "all" ]; then
      echo "$valid_ides"
    else
      echo "$ide_arg" | tr ',' ' '
    fi
    return 0
  fi

  [ -d "$root/.opencode" ] && ide_list="$ide_list opencode"
  [ -d "$root/.claude" ] && ide_list="$ide_list claude-code"
  [ -d "$root/.codex" ] && ide_list="$ide_list codex"
  [ -d "$root/.pi" ] && ide_list="$ide_list pi"
  [ -d "$root/.antigravity" ] && ide_list="$ide_list antigravity"

  echo "${ide_list# }"
}
