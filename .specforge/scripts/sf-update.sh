#!/usr/bin/env bash
# sf-update.sh - Re-copy framework internals from a source repo (preserving
# project-owned content) and re-project canon into installed IDEs.
#
#   sf-update.sh --root <project> [--source <specforge-repo>] [--dry-run] [--ide all|list]
#
# Project-owned (NEVER touched): project.yaml, .specforge/work/,
# .specforge/learnings/, NEXT.md, and user content in root AGENTS.md/CLAUDE.md
# outside the managed block — update only refreshes canon/profiles/lib/scripts.
# Generated IDE files are
# overwritten only when they carry the SpecForge marker; user files are preserved.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SF_SELF="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SF_SELF/lib"
# shellcheck source=../lib/common.sh
source "$LIB/common.sh"
# shellcheck source=../lib/managed-block.sh
source "$LIB/managed-block.sh"
# shellcheck source=../lib/frontmatter.sh
source "$LIB/frontmatter.sh"
# shellcheck source=../lib/project.sh
source "$LIB/project.sh"

ROOT=""; SOURCE=""; DRY=false; IDE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --source) SOURCE="${2:-}"; shift 2 ;;
    --dry-run) DRY=true; shift ;;
    --ide) IDE_ARG="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

[ -n "$ROOT" ] || ROOT="$(sf_root)"
ROOT="$(cd "$ROOT" && pwd)"

# 1. Re-copy framework internals (skip when updating in place / no source).
if [ -n "$SOURCE" ]; then
  SOURCE="$(cd "$SOURCE" && pwd)"
  if [ "$SOURCE" != "$ROOT" ] && [ -d "$SOURCE/.specforge" ]; then
    echo "Syncing framework internals from $SOURCE"
    for sub in canon profiles lib scripts; do
      [ -d "$SOURCE/.specforge/$sub" ] || continue
      if [ "$DRY" = true ]; then
        echo "  → would refresh .specforge/$sub"
      else
        rm -rf "$ROOT/.specforge/$sub"
        cp -R "$SOURCE/.specforge/$sub" "$ROOT/.specforge/$sub"
        echo "  ✓ refreshed .specforge/$sub"
      fi
    done
  fi
fi

# 2. Determine IDEs and re-project.
IDES=""
if [ -n "$IDE_ARG" ]; then
  [ "$IDE_ARG" = "all" ] && IDES="claude-code opencode codex pi antigravity" || IDES="$(echo "$IDE_ARG" | tr ',' ' ')"
else
  IDES="$(sf_detect_ides "$ROOT")"
fi
[ -n "$IDES" ] || { echo "No installed IDEs detected; nothing to project."; exit 0; }

echo ""
echo "Re-projecting canon for: $IDES"
for ide in $IDES; do
  sf_project_ide "$ROOT" "$ide" "$DRY"
done

echo ""
[ "$DRY" = true ] && echo "Dry run complete (no changes written)." || echo "Update complete."
