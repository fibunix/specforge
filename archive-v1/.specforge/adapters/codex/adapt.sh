#!/usr/bin/env bash
# codex adapter - set up AGENTS.md and custom agents for OpenAI Codex.
#
# What this sets up:
#   1. AGENTS.md         → already at project root (Codex discovers it natively)
#   2. Custom agents     -> .codex/agents/ (symlinks to Codex TOML agents)
#   3. Instructions docs -> .codex/instructions/ (symlinks for reference)
#
# Codex reads:
#   - AGENTS.md at project root (native discovery — no symlink needed)
#   - AGENTS.md walking up from CWD (global ~/.codex/AGENTS.md first)
#   - .codex/agents/*.toml custom agents
#   - Config: ~/.codex/config.toml or .codex/config.toml for project settings
#
# References:
#   - AGENTS.md: https://developers.openai.com/codex/guides/agents-md
#   - Config: https://developers.openai.com/codex/config-basic
#   - Subagents: https://developers.openai.com/codex/subagents
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

echo "Setting up Codex..."

# 1. Rules: Codex natively discovers AGENTS.md at project root.
sf_update_managed_block "$ROOT/AGENTS.md" "$SF/root/SPECFORGE.md" false "AGENTS.md"

# 2. Codex config directory (for project-level settings, optional).
mkdir -p "$ROOT/.codex"
echo "  ✓ Created .codex/ directory"

if [ ! -f "$ROOT/.codex/config.toml" ]; then
  cat > "$ROOT/.codex/config.toml" <<'TOML'
[agents]
max_threads = 3
max_depth = 1
TOML
  echo "  ✓ created .codex/config.toml"
else
  echo "  ⚠ preserving existing .codex/config.toml"
fi

# 3. Symlink custom agents.
mkdir -p "$ROOT/.codex/agents"
for agent in "$SF"/adapters/codex/agents/*.toml; do
  [ -f "$agent" ] || continue
  name=$(basename "$agent")
  sf_safe_link "../../.specforge/adapters/codex/agents/$name" "$ROOT/.codex/agents/$name" "Codex agent ${name%.toml}"
done

# 4. Symlink docs for easy reference inside .codex/
mkdir -p "$ROOT/.codex/instructions"
for doc in "$SF"/docs/*.md; do
  [ -f "$doc" ] || continue
  name=$(basename "$doc")
  sf_safe_link "../../.specforge/docs/$name" "$ROOT/.codex/instructions/$name" "instruction $name"
done

echo "  ✓ Codex adapter complete"
echo ""
echo "  NOTE: Codex reads AGENTS.md natively. No rules symlink needed."
echo "  Custom SpecForge agents are available under .codex/agents/ after project trust."
