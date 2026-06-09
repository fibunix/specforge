#!/usr/bin/env bash
# sf-update.sh - Preserve-first SpecForge framework updater.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/adapter.sh
source "$SCRIPT_DIR/lib/adapter.sh"
# shellcheck source=lib/managed-block.sh
source "$SCRIPT_DIR/lib/managed-block.sh"

ROOT="$(sf_root)"
SOURCE=""
IDE_ARG=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    --source)
      SOURCE="$(cd "$2" && pwd)"
      shift 2
      ;;
    --ide)
      IDE_ARG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      echo "usage: sf-update.sh [--root DIR] [--source SPECFORGE_REPO] [--ide IDE[,IDE]|all] [--dry-run]"
      exit 0
      ;;
    *)
      sf_usage "sf-update.sh [--root DIR] [--source SPECFORGE_REPO] [--ide IDE[,IDE]|all] [--dry-run]"
      ;;
  esac
done

SF="$ROOT/.specforge"
if [ -z "$SOURCE" ]; then
  SOURCE="$ROOT"
fi
SRC_SF="$SOURCE/.specforge"
SAME_SOURCE=false

[ -d "$SF" ] || sf_die ".specforge directory missing at $ROOT"
[ -d "$SRC_SF" ] || sf_die "SpecForge source missing at $SRC_SF"
[ -f "$SRC_SF/root/SPECFORGE.md" ] || sf_die "SpecForge source missing root/SPECFORGE.md"

if [ "$(cd "$SF" && pwd)" = "$(cd "$SRC_SF" && pwd)" ]; then
  SAME_SOURCE=true
fi

copy_path() {
  local rel="$1"
  local src="$SRC_SF/$rel"
  local dst="$SF/$rel"

  [ -e "$src" ] || return 0
  if [ "$SAME_SOURCE" = true ]; then
    echo "  ✓ .specforge/$rel already using source"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "  → would update .specforge/$rel"
    return 0
  fi

  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  echo "  ✓ updated .specforge/$rel"
}

copy_spec_template() {
  local src="$SRC_SF/specs/TEMPLATE.md"
  local dst="$SF/specs/TEMPLATE.md"

  [ -f "$src" ] || return 0
  if [ "$SAME_SOURCE" = true ]; then
    echo "  ✓ .specforge/specs/TEMPLATE.md already using source"
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    echo "  → would update .specforge/specs/TEMPLATE.md"
    return 0
  fi

  mkdir -p "$SF/specs"
  cp "$src" "$dst"
  [ -f "$SF/specs/.gitkeep" ] || touch "$SF/specs/.gitkeep"
  echo "  ✓ updated .specforge/specs/TEMPLATE.md"
}

run_adapters() {
  local ide_list ide adapter
  ide_list="$(sf_adapter_list_from_arg_or_install "$ROOT" "$IDE_ARG")"
  [ -n "$ide_list" ] || return 0

  for ide in $ide_list; do
    adapter="$SF/adapters/$ide/adapt.sh"
    if [ -f "$adapter" ]; then
      if [ "$DRY_RUN" = true ]; then
        echo "  → would run $ide adapter"
      else
        echo ""
        echo "Running $ide adapter..."
        (cd "$ROOT" && bash "$adapter")
      fi
    else
      sf_warn "no adapter found for $ide"
    fi
  done
}

echo "SpecForge update"
echo ""

for rel in scripts agents skills docs templates adapters root; do
  copy_path "$rel"
done
copy_spec_template

chmod +x "$SF/scripts/"*.sh 2>/dev/null || true
chmod +x "$SF/adapters/"*/adapt.sh 2>/dev/null || true

echo ""
echo "Updating managed root instructions..."
sf_update_managed_block "$ROOT/AGENTS.md" "$SRC_SF/root/SPECFORGE.md" "$DRY_RUN" "AGENTS.md"
if [ -d "$ROOT/.claude" ] || [ -f "$ROOT/CLAUDE.md" ] || [ -L "$ROOT/CLAUDE.md" ] || [ "$IDE_ARG" = "claude-code" ] || [ "$IDE_ARG" = "all" ]; then
  sf_update_managed_block "$ROOT/CLAUDE.md" "$SRC_SF/root/SPECFORGE.md" "$DRY_RUN" "CLAUDE.md"
fi

run_adapters

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "Dry run complete. No files were changed."
else
  echo "SpecForge update complete."
fi
