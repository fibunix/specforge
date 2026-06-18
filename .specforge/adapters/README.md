# IDE adapters

Each adapter symlinks and installs the SpecForge elements that a specific coding agent or IDE needs. Root instruction files are user-owned, with a fenced SpecForge-managed block that adapters may insert or replace.

## What each adapter installs

| IDE | Rules | Agents | Commands | Skills | Config | Notes |
|-----|-------|--------|----------|--------|--------|-------|
| **opencode** | `.opencode/AGENTS.md` symlink if absent | `.opencode/agents/` symlinks | `.opencode/commands/` symlinks | `.opencode/skills/` symlinks | — | File-based agents + commands; no opencode.json needed |
| **claude-code** | root `CLAUDE.md` managed block | `.claude/agents/` symlinks | — | `.claude/skills/` symlinks (phase + shared) | — | Skills replace commands; side-effect skills use `disable-model-invocation` |
| **codex** | root `AGENTS.md` native discovery | `.codex/agents/` symlinks | — | — | `.codex/config.toml` if absent | Custom agents + native AGENTS.md |
| **pi** | root `AGENTS.md` native discovery | `.pi/agents/` symlinks | — | `.pi/skills/` symlinks | `.pi/instructions/` symlinks | Skills only; agents when Pi subagent support is installed |
| **antigravity** | root `AGENTS.md` native workspace context | — | — | — | `.antigravity/instructions/` symlinks | Rules/reference only |

## Supported IDEs

| IDE | Adapter script | Rules target |
|-----|---------------|-------------|
| opencode | `.specforge/adapters/opencode/adapt.sh` | `.opencode/AGENTS.md` → `../AGENTS.md` if absent |
| claude-code | `.specforge/adapters/claude-code/adapt.sh` | `CLAUDE.md` managed block |
| codex | `.specforge/adapters/codex/adapt.sh` | `AGENTS.md` at project root (native) |
| pi | `.specforge/adapters/pi/adapt.sh` | `AGENTS.md` at project root (native) |
| antigravity | `.specforge/adapters/antigravity/adapt.sh` | `AGENTS.md` at project root (native workspace context) |

## Run all installed adapters

```bash
for a in .specforge/adapters/*/adapt.sh; do bash "$a"; done
```

## Run a specific adapter

```bash
bash .specforge/adapters/opencode/adapt.sh
bash .specforge/adapters/claude-code/adapt.sh
bash .specforge/adapters/codex/adapt.sh
```

## Add a new adapter

```bash
mkdir -p .specforge/adapters/<my-ide>
cat > .specforge/adapters/<my-ide>/adapt.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SF="$ROOT/.specforge"

safe_link() {
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

# 1. Rules: symlink AGENTS.md to where your IDE reads instructions
mkdir -p "$ROOT/.<my-ide>"
safe_link "../AGENTS.md" "$ROOT/.<my-ide>/AGENTS.md" "AGENTS.md → .<my-ide>/AGENTS.md"

# 2. Skills: symlink .specforge/skills/* if your IDE supports skills
# mkdir -p "$ROOT/.<my-ide>/skills"
# for skill_dir in "$SF"/skills/*/; do
#   [ -d "$skill_dir" ] || continue
#   skill_name=$(basename "$skill_dir")
#   safe_link "../../.specforge/skills/$skill_name" "$ROOT/.<my-ide>/skills/$skill_name" "skill $skill_name"
# done

# 3. Agents: symlink .specforge/agents/*.md if your IDE supports subagents
# mkdir -p "$ROOT/.<my-ide>/agents"
# for agent in "$SF"/agents/*.md; do
#   [ -f "$agent" ] || continue
#   name=$(basename "$agent")
#   safe_link "../../.specforge/agents/$name" "$ROOT/.<my-ide>/agents/$name" "agent ${name%.md}"
# done
EOF
chmod +x .specforge/adapters/<my-ide>/adapt.sh
```

## IDE-specific notes

### opencode
- Reads root `AGENTS.md` or `.opencode/AGENTS.md` for project instructions (native discovery)
- Discovers agents from `.opencode/agents/*.md`
- Discovers commands from `.opencode/commands/*.md`
- Discovers skills from `.opencode/skills/*/SKILL.md`
- The `sf` primary agent and sub-agent wrappers live in `.specforge/adapters/opencode/agents/`
- Commands are thin wrappers that point to the canonical skills in `.specforge/skills/`
- No `opencode.json` required
- If a stale `opencode.json` containing SpecForge commands is found, the adapter removes it automatically.

### Claude Code
- Reads root `CLAUDE.md` for project instructions
- Supports `CLAUDE.md` importing `@AGENTS.md`
- Discover subagents from `.claude/agents/*.md`
- Discovers skills from `.claude/skills/*/SKILL.md`
- The adapter never overwrites a whole root `CLAUDE.md`; it only inserts or replaces the SpecForge-managed block.
- Public SpecForge commands are installed as skills, not `.claude/commands/`.
  Manual side-effect commands (`sf-ship`, `sf-finalize`, `sf-test`) use
  `disable-model-invocation: true`; explicit autonomous commands (`sf-loop`,
  `sf-goal`) may advance only after independent reviewer PASS receipts.
- Internal reviewer skills (`sf-test-reviewer`, `sf-implementation-reviewer`,
  `sf-plan-reviewer`, `sf-task-reviewer`) are
  installed as skills for sub-agents but do not need slash-command wrappers.
- On re-run, the adapter removes any stale `sf-*.md` symlinks from `.claude/commands/` left by older installs.
- Reference: https://docs.anthropic.com/en/docs/claude-code/memory

### Pi
- Reads `AGENTS.md` (or `CLAUDE.md`) from cwd up through parent directories
- The adapter does not create `.pi/AGENTS.md`; root `AGENTS.md` is the project context file.
- Discovers prompt templates from `.pi/prompts/*.md` — invoked via `/name`
- Discovers skills from `.pi/skills/*/SKILL.md` — invoked via `/skill:name`
- Discovers `.pi/agents/*.md` when compatible Pi subagent support is installed.
- Extensions from `.pi/extensions/*.ts` and themes from `.pi/themes/`
- Config: `.pi/settings.json` for project-level settings
- Reference: https://github.com/earendil-works/pi/tree/main/packages/coding-agent

### Codex
- Natively discovers `AGENTS.md` at project root and walking up from CWD
- Discovers custom agents from `.codex/agents/*.toml`
- Config: `.codex/config.toml` for project-level settings
- Reference: https://developers.openai.com/codex/guides/agents-md

### Antigravity
- Reads root `AGENTS.md` or `GEMINI.md` from the active workspace.
- The adapter does not create `.antigravity/AGENTS.md`; that path is not the documented workspace context location.
- `.antigravity/instructions/` is only a reference-doc convenience folder.
