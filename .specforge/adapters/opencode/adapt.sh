#!/usr/bin/env bash
# opencode adapter — install all SpecForge elements for opencode.
#
# What this sets up:
#   1. AGENTS.md          → .opencode/AGENTS.md (symlink; opencode also discovers root AGENTS.md natively)
#   2. Agents             → .opencode/agents/ (symlinks to .specforge/adapters/opencode/agents/)
#   3. Commands           → .opencode/commands/ (symlinks to .specforge/adapters/opencode/commands/)
#   4. Skills             → .opencode/skills/ (symlinks to .specforge/skills/)
#
# opencode reads:
#   - root AGENTS.md or .opencode/AGENTS.md for project instructions (native discovery)
#   - .opencode/agents/*.md for agent definitions
#   - .opencode/commands/*.md for slash commands
#   - .opencode/skills/*/SKILL.md for skills
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

echo "Setting up opencode..."

sf_update_managed_block "$ROOT/AGENTS.md" "$SF/root/SPECFORGE.md" false "AGENTS.md"

# 1. Rules: symlink AGENTS.md -> .opencode/AGENTS.md if absent
mkdir -p "$ROOT/.opencode"
sf_safe_link "../AGENTS.md" "$ROOT/.opencode/AGENTS.md" "AGENTS.md → .opencode/AGENTS.md"

# 2. Agents: symlink each .specforge/adapters/opencode/agents/*.md -> .opencode/agents/
mkdir -p "$ROOT/.opencode/agents"
for agent in "$SF"/adapters/opencode/agents/*.md; do
  [ -f "$agent" ] || continue
  name=$(basename "$agent")
  sf_safe_link "../../.specforge/adapters/opencode/agents/$name" "$ROOT/.opencode/agents/$name" "agent ${name%.md}"
done

# 3. Commands: symlink each .specforge/adapters/opencode/commands/*.md -> .opencode/commands/
mkdir -p "$ROOT/.opencode/commands"
for cmd in "$SF"/adapters/opencode/commands/*.md; do
  [ -f "$cmd" ] || continue
  name=$(basename "$cmd")
  sf_safe_link "../../.specforge/adapters/opencode/commands/$name" "$ROOT/.opencode/commands/$name" "command /${name%.md}"
done

# 4. Clean up stale opencode.json left by previous installs.
if [ -f "$ROOT/opencode.json" ]; then
  # Only remove if it looks like the SpecForge-generated file (has sf-plan command key)
  if grep -q '"sf-plan"' "$ROOT/opencode.json" 2>/dev/null; then
    rm "$ROOT/opencode.json"
    echo "  ✓ removed stale opencode.json (agents and commands now use file-based config)"
  else
    echo "  ⚠ preserving existing opencode.json — not a SpecForge-generated file"
  fi
fi

# 5. Clean up stale .opencode/commands/ symlinks pointing to old .specforge/commands/ path.
for cmd in "$ROOT/.opencode/commands"/sf-*.md; do
  [ -L "$cmd" ] || continue
  target="$(readlink "$cmd" 2>/dev/null || true)"
  if [[ "$target" == *".specforge/commands/"* ]]; then
    rm "$cmd"
    echo "  ✓ removed stale command symlink $(basename "$cmd")"
  fi
done

# 6. Skills: symlink each entire .specforge/skills/* directory -> .opencode/skills/
if [ -d "$SF/skills" ]; then
  mkdir -p "$ROOT/.opencode/skills"
  for skill_dir in "$SF"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    sf_safe_link "../../.specforge/skills/$skill_name" "$ROOT/.opencode/skills/$skill_name" "skill $skill_name"
  done
fi

echo "  ✓ opencode adapter complete"
