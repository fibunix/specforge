#!/usr/bin/env bash
# sf-init.sh — One-time project bootstrap for SpecForge.
#
# Creates the .specforge/ layout (if missing), a starter config.yaml,
# copies AGENTS.md to the project root, then runs the selected adapter(s)
# which set up IDE-specific symlinks, agents, commands, and skills.
#
# What each adapter installs:
#   opencode:     AGENTS.md symlink if absent, agents/, commands/, skills/ (file-based; no opencode.json)
#   claude-code:  root CLAUDE.md symlink if absent, agents/, skills/
#   codex:        Confirms AGENTS.md at root, agents/, config.toml if absent, instructions/
#   pi:           Uses root AGENTS.md, prompts/, skills/, agents/, instructions/
#   antigravity:  Confirms root AGENTS.md, instructions/
#
# Usage:
#   bash .specforge/scripts/sf-init.sh                    # interactive
#   bash .specforge/scripts/sf-init.sh --ide opencode     # non-interactive
#   bash .specforge/scripts/sf-init.sh --ide claude-code,codex  # multiple
#   bash .specforge/scripts/sf-init.sh --ide all          # all adapters
#
# Idempotent: safe to run twice.

set -euo pipefail

# Resolve ROOT from script location if not in a git repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/../../.git" ] || git rev-parse --show-toplevel &>/dev/null; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
else
  ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
SF="$ROOT/.specforge"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/managed-block.sh
source "$SCRIPT_DIR/lib/managed-block.sh"

VALID_IDES="opencode claude-code codex pi antigravity"

# ── Parse arguments ──
IDE_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ide)
      IDE_ARG="$2"
      shift 2
      ;;
    *)
      echo "usage: sf-init.sh [--ide <ide1,ide2,...|all>]" >&2
      exit 1
      ;;
  esac
done

# ── Helper: validate and normalize IDE names ──
normalize_ide() {
  local input="$1"
  case "$input" in
    1|opencode)      echo "opencode" ;;
    2|claude-code)   echo "claude-code" ;;
    3|codex)         echo "codex" ;;
    4|pi)            echo "pi" ;;
    5|antigravity)   echo "antigravity" ;;
    *)               echo "" ;;
  esac
}

# ── 1. Create directory structure ──
mkdir -p "$SF/scripts" "$SF/agents" "$SF/commands" "$SF/docs" "$SF/specs" "$SF/templates" "$SF/root"

# ── 2. config.yaml — only if it doesn't exist yet ──
if [ ! -f "$SF/config.yaml" ]; then
  cat > "$SF/config.yaml" <<'YAML'
# SpecForge project config. Edit values; agents read this file.
project_name: my-project
test_command: npm test
lint_command: npm run lint
build_command: npm run build
source_dir: src

# Repos with multiple projects can replace the flat commands above with
# a projects list. `sf test` runs every project; `sf test sdf` runs one.
#
# projects:
#   - id: sdf
#     name: NetSuite SDF
#     path: netsuite/sdf
#     source_dir: src
#     test_command: npm test
#     lint_command: npm run lint
#     build_command: npm run build
#   - id: extension
#     name: NetSuite Extension
#     path: netsuite/extension
#     source_dir: src
#     test_command: npm test
#   - id: theme
#     name: NetSuite Theme
#     path: netsuite/theme
#     source_dir: src
#     test_command: npm test
YAML
  echo "Created $SF/config.yaml (edit it for your project)"
fi

# ── 3. .gitignore additions ──
GITIGNORE="$ROOT/.gitignore"
touch "$GITIGNORE"
grep -qxF ".specforge/ALIGN.md.tmp" "$GITIGNORE" || echo ".specforge/ALIGN.md.tmp" >> "$GITIGNORE"

# ── 4. Make scripts executable ──
chmod +x "$SF/scripts/"*.sh 2>/dev/null || true
chmod +x "$SF/adapters/"*/adapt.sh 2>/dev/null || true

# ── 5. Ensure root instructions have a SpecForge-managed block ──
if [ -f "$SF/root/SPECFORGE.md" ]; then
  sf_update_managed_block "$ROOT/AGENTS.md" "$SF/root/SPECFORGE.md" false "AGENTS.md"
elif [ -f "$SF/root/AGENTS.md" ] && [ ! -f "$ROOT/AGENTS.md" ]; then
  cp "$SF/root/AGENTS.md" "$ROOT/AGENTS.md"
  echo "Copied AGENTS.md to project root"
else
  echo "AGENTS.md already exists at project root — skipping"
fi

# ── 6. IDE selection ──
if [ -n "$IDE_ARG" ]; then
  # Non-interactive mode
  if [ "$IDE_ARG" = "all" ]; then
    IDE_LIST="$VALID_IDES"
  else
    IDE_LIST=$(echo "$IDE_ARG" | tr ',' ' ')
  fi
else
  # Interactive mode
  echo ""
  echo "Which coding agent / IDE are you using?"
  echo ""
  echo "  1) opencode       — .opencode/ agents, commands, skills (file-based; no opencode.json)"
  echo "  2) claude-code    — root CLAUDE.md if absent + agents/ + skills/"
  echo "  3) codex          — AGENTS.md at root (native discovery) + .codex/agents + instructions/"
  echo "  4) pi             — root AGENTS.md + .pi prompts, skills, agents, and instructions/"
  echo "  5) antigravity    — AGENTS.md at root (native workspace context) + instructions/"
  echo ""
  if [ -e /dev/tty ]; then
    read -rp "Enter number(s), space-separated (e.g. '1' or '1 2'), or 'all': " RESPONSE </dev/tty
  else
    echo "Non-interactive install detected. No IDE selected." >&2
    echo "Run later: bash .specforge/scripts/sf-init.sh --ide <ide>" >&2
    RESPONSE=""
  fi
  IDE_LIST=""
  for token in $RESPONSE; do
    normalized="$(normalize_ide "$token")"
    if [ -n "$normalized" ]; then
      IDE_LIST="$IDE_LIST $normalized"
    fi
  done
  IDE_LIST="${IDE_LIST# }"
fi

# ── 7. Run selected adapter(s) ──
ADAPTERS_RUN=0

for IDE in $IDE_LIST; do
  ADAPTER="$SF/adapters/$IDE/adapt.sh"
  if [ -f "$ADAPTER" ]; then
    echo ""
    echo "Running $IDE adapter..."
    bash "$ADAPTER"
    ADAPTERS_RUN=$((ADAPTERS_RUN + 1))
  else
    echo "Warning: no adapter found for $IDE (expected $ADAPTER)"
  fi
done

if [ "$ADAPTERS_RUN" -eq 0 ]; then
  echo ""
  echo "No IDE adapter installed. You can run adapters later:"
  echo "  bash .specforge/adapters/<ide>/adapt.sh"
  echo ""
  echo "Available adapters: $VALID_IDES"
fi

# ── 8. Final message ──
cat <<'MSG'

SpecForge initialized.

Next steps:
  1. Edit .specforge/config.yaml (projects, test/lint/build commands, source dirs)
  2. Open the project in your editor and run /sf-plan
MSG
