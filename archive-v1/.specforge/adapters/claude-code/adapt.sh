#!/usr/bin/env bash
# claude-code adapter — install all SpecForge elements for Claude Code.
#
# What this sets up:
#   1. CLAUDE.md           → project-root CLAUDE.md (symlink to AGENTS.md if absent)
#   2. Subagents           → .claude/agents/ (symlinks to .specforge/agents/)
#   3. Skills              → .claude/skills/ (symlinks to .specforge/skills/)
#
# Claude Code reads:
#   - ./CLAUDE.md for project instructions
#   - .claude/agents/*.md for subagent definitions
#   - .claude/skills/*/SKILL.md for skills (user-invocable + auto-invocable)
#
# Note: .claude/commands/ is the legacy path. Skills are the modern equivalent and
# support invocation control (disable-model-invocation for side-effect commands).
#
# References:
#   - CLAUDE.md: https://docs.anthropic.com/en/docs/claude-code/memory
#   - Subagents: https://docs.anthropic.com/en/docs/claude-code/sub-agents
#   - Skills/commands: https://docs.anthropic.com/en/docs/claude-code/skills
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

echo "Setting up Claude Code..."

# 1. Rules: preserve user content and update only the SpecForge-managed block.
mkdir -p "$ROOT/.claude"
sf_update_managed_block "$ROOT/AGENTS.md" "$SF/root/SPECFORGE.md" false "AGENTS.md"
sf_update_managed_block "$ROOT/CLAUDE.md" "$SF/root/SPECFORGE.md" false "CLAUDE.md"

# 2. Subagents: symlink each .specforge/agents/*.md -> .claude/agents/
mkdir -p "$ROOT/.claude/agents"
for agent in "$SF"/agents/*.md; do
  [ -f "$agent" ] || continue
  name=$(basename "$agent")
  sf_safe_link "../../.specforge/agents/$name" "$ROOT/.claude/agents/$name" "agent ${name%.md}"
done

# 3. Clean up stale .claude/commands/ symlinks left by previous installs.
if [ -d "$ROOT/.claude/commands" ]; then
  for cmd in "$ROOT/.claude/commands"/sf-*.md; do
    [ -L "$cmd" ] || continue
    target="$(readlink "$cmd" 2>/dev/null || true)"
    if [[ "$target" == *".specforge/commands/"* ]]; then
      rm "$cmd"
      echo "  ✓ removed stale command symlink $(basename "$cmd")"
    fi
  done
fi

# 4. Shared skills: symlink each entire .specforge/skills/* directory -> .claude/skills/
if [ -d "$SF/skills" ]; then
  mkdir -p "$ROOT/.claude/skills"
  sf_remove_stale_specforge_links "$ROOT/.claude/skills" ".specforge/skills/" "skill"
  for skill_dir in "$SF"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    sf_safe_link "../../.specforge/skills/$skill_name" "$ROOT/.claude/skills/$skill_name" "skill $skill_name"
  done
fi

echo "  ✓ Claude Code adapter complete"
