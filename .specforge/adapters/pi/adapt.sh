#!/usr/bin/env bash
# pi adapter — set up skills and agents for Pi.
#
# What this sets up:
#   1. Skills             → .pi/skills/ (symlinks to .specforge/skills/)
#   2. Agents             → .pi/agents/ (symlinks to .specforge/agents/)
#   3. Instructions docs  → .pi/instructions/ (symlinks to .specforge/docs/)
#
# Pi reads:
#   - AGENTS.md (or CLAUDE.md) from cwd up through parent directories
#   - ~/.pi/agent/AGENTS.md for global instructions
#   - .pi/skills/*/SKILL.md for skills (invoked via /skill:name)
#   - .pi/extensions/*.ts for extensions
#   - .pi/settings.json for project settings
#
# References:
#   - Context files: https://github.com/earendil-works/pi/tree/main/packages/coding-agent  (README, "Context Files")
#   - Skills: https://github.com/earendil-works/pi/tree/main/packages/coding-agent  (README, "Skills")
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

echo "Setting up Pi..."

sf_update_managed_block "$ROOT/AGENTS.md" "$SF/root/SPECFORGE.md" false "AGENTS.md"

# 1. Clean up stale .pi/prompts/ symlinks left by previous installs.
if [ -d "$ROOT/.pi/prompts" ]; then
  for cmd in "$ROOT/.pi/prompts"/sf-*.md; do
    [ -L "$cmd" ] || continue
    target="$(readlink "$cmd" 2>/dev/null || true)"
    if [[ "$target" == *".specforge/commands/"* ]]; then
      rm "$cmd"
      echo "  ✓ removed stale prompt symlink $(basename "$cmd")"
    fi
  done
fi

# 2. Skills: symlink each entire .specforge/skills/* directory -> .pi/skills/
#    Pi discovers skills from .pi/skills/*/SKILL.md - invoked via /skill:name
if [ -d "$SF/skills" ]; then
  mkdir -p "$ROOT/.pi/skills"
  for skill_dir in "$SF"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    sf_safe_link "../../.specforge/skills/$skill_name" "$ROOT/.pi/skills/$skill_name" "skill $skill_name"
  done
fi

# 3. Optional project subagent definitions for Pi subagent extensions.
mkdir -p "$ROOT/.pi/agents"
for agent in "$SF"/agents/*.md; do
  [ -f "$agent" ] || continue
  name=$(basename "$agent")
  sf_safe_link "../../.specforge/agents/$name" "$ROOT/.pi/agents/$name" "Pi agent ${name%.md}"
done

# 4. Instructions docs for easy reference
mkdir -p "$ROOT/.pi/instructions"
for doc in "$SF"/docs/*.md; do
  [ -f "$doc" ] || continue
  name=$(basename "$doc")
  sf_safe_link "../../.specforge/docs/$name" "$ROOT/.pi/instructions/$name" "instruction $name"
done

echo "  ✓ Pi adapter complete"
