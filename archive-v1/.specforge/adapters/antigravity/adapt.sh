#!/usr/bin/env bash
# antigravity adapter - set up workspace context for Antigravity.
#
# What this sets up:
#   1. Rules -> root AGENTS.md (created by sf-init.sh; Antigravity reads it)
#   2. Docs  -> .antigravity/instructions/ (symlinks for reference)
#
# Antigravity reads:
#   - root AGENTS.md or GEMINI.md from the active workspace
#   - No documented .antigravity/commands/ or .antigravity/agents/ directories
#
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SF="$ROOT/.specforge"
# shellcheck source=../../scripts/lib/common.sh
source "$SF/scripts/lib/common.sh"
# shellcheck source=../../scripts/lib/adapter.sh
source "$SF/scripts/lib/adapter.sh"
# shellcheck source=../../scripts/lib/managed-block.sh
source "$SF/scripts/lib/managed-block.sh"

echo "Setting up Antigravity..."

mkdir -p "$ROOT/.antigravity"
sf_update_managed_block "$ROOT/AGENTS.md" "$SF/root/SPECFORGE.md" false "AGENTS.md"

# 2. Symlink docs for easy reference
mkdir -p "$ROOT/.antigravity/instructions"
for doc in "$SF"/docs/*.md; do
  [ -f "$doc" ] || continue
  name=$(basename "$doc")
  sf_safe_link "../../.specforge/docs/$name" "$ROOT/.antigravity/instructions/$name" "instruction $name"
done

echo "  ✓ Antigravity adapter complete"
