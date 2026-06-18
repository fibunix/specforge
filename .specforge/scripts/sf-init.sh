#!/usr/bin/env bash
# sf-init.sh - Initialize SpecForge in a project: seed project files, project canon
# into the chosen IDE layouts.
#
#   sf-init.sh [--ide all|<comma-list>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SF="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SF/lib"
# shellcheck source=../lib/common.sh
source "$LIB/common.sh"
# shellcheck source=../lib/managed-block.sh
source "$LIB/managed-block.sh"
# shellcheck source=../lib/frontmatter.sh
source "$LIB/frontmatter.sh"
# shellcheck source=../lib/project.sh
source "$LIB/project.sh"

ROOT="$(sf_root)"

IDE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ide) IDE_ARG="${2:-}"; shift 2 ;;
    --ide=*) IDE_ARG="${1#--ide=}"; shift ;;
    *) shift ;;
  esac
done

echo "Initializing SpecForge in $ROOT"

# 1. Seed project.yaml (project-owned; never overwritten).
if [ ! -f "$ROOT/project.yaml" ]; then
  cp "$SF/canon/templates/project.yaml" "$ROOT/project.yaml"
  echo "  ✓ created project.yaml (edit test_command etc.)"
else
  echo "  ✓ project.yaml exists"
fi

# 2. Seed work dirs + NEXT.md backlog.
mkdir -p "$ROOT/work/active" "$ROOT/work/archive"
touch "$ROOT/work/active/.gitkeep" "$ROOT/work/archive/.gitkeep"
if [ ! -f "$ROOT/NEXT.md" ]; then
  cp "$SF/canon/templates/NEXT.md" "$ROOT/NEXT.md"
  echo "  ✓ created NEXT.md backlog"
fi

# 3. Determine IDE list.
IDES=""
if [ -n "$IDE_ARG" ]; then
  if [ "$IDE_ARG" = "all" ]; then
    IDES="claude-code opencode codex pi antigravity"
  else
    IDES="$(echo "$IDE_ARG" | tr ',' ' ')"
  fi
else
  IDES="$(sf_detect_ides "$ROOT")"
  [ -n "$IDES" ] || IDES="claude-code"
fi

echo "  IDEs: $IDES"
echo ""

# 4. Project canon into each IDE.
for ide in $IDES; do
  sf_project_ide "$ROOT" "$ide" false
done

echo ""
echo "SpecForge ready. Next:"
echo "  1. Edit project.yaml (test_command at minimum)."
echo "  2. In your editor, run /sf \"<your request>\" to route work, or /sf-loop to drive autonomously."
