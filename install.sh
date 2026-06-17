#!/usr/bin/env bash
# install.sh — Bootstrap SpecForge into a project.
#
# Usage:
#   # From GitHub (once published):
#   curl -fsSL https://raw.githubusercontent.com/USER/specforge/main/install.sh | bash
#
#   # From a local clone:
#   bash /path/to/specforge/install.sh
#
#   # With options:
#   bash install.sh --ide opencode --dir ./my-project
#   curl -fsSL <url>/install.sh | bash -s -- --ide opencode
#
# Options:
#   --source PATH   Path to specforge repo (default: auto-detect or download)
#   --ide IDE       IDE to configure (opencode, claude-code, codex, pi, antigravity, all)
#   --dir DIR       Target project directory (default: current directory)
#   --update        Update an existing SpecForge install (default when installed)
#   --dry-run       Preview update actions without changing files
#   --force         Overwrite existing .specforge/ without prompting
#   -h, --help      Show this help

set -euo pipefail

SPECFORGE_REPO="${SPECFORGE_REPO:-}"
SPECFORGE_VERSION="${SPECFORGE_VERSION:-main}"
SPECFORGE_GIT_URL="${SPECFORGE_GIT_URL:-https://github.com/fibunix/specforge.git}"

FORCE=false
UPDATE=false
DRY_RUN=false
TARGET_DIR=""
IDE_ARG=""
EXISTING_INSTALL=false

TEMP_CLONE=""

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${GREEN}✓${RESET} $1"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $1"; }
error() { echo -e "${RED}✗${RESET} $1" >&2; }

# ── Parse arguments ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SPECFORGE_REPO="$2"
      shift 2
      ;;
    --ide)
      IDE_ARG="$2"
      shift 2
      ;;
    --dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --update)
      UPDATE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      sed -n '2,/^set -euo pipefail$/p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      echo "Run: bash install.sh --help" >&2
      exit 1
      ;;
  esac
done

# ── Resolve target directory ──
TARGET_DIR="${TARGET_DIR:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
  error "Target directory does not exist: $TARGET_DIR"
  exit 1
}

SF_DIR="$TARGET_DIR/.specforge"

# ── Check for existing .specforge ──
if [ -d "$SF_DIR" ] && [ "$FORCE" = false ]; then
  if [ -f "$SF_DIR/scripts/sf-init.sh" ]; then
    EXISTING_INSTALL=true
    UPDATE=true
  else
    error "$SF_DIR exists but doesn't contain SpecForge scripts."
    echo "  Use --force to overwrite, or remove $SF_DIR manually." >&2
    exit 1
  fi
fi

# ── Cleanup function ──
cleanup() {
  if [ -n "$TEMP_CLONE" ] && [ -d "$TEMP_CLONE" ]; then
    rm -rf "$TEMP_CLONE"
  fi
}
trap cleanup EXIT

# ── Find or download the SpecForge source ──
resolve_source() {
  is_source_repo() {
    local candidate="$1"
    [ -f "$candidate/install.sh" ] &&
      [ -f "$candidate/.specforge/scripts/sf-init.sh" ] &&
      [ -f "$candidate/.specforge/root/SPECFORGE.md" ]
  }

  # 1. Explicit --source path
  if [ -n "$SPECFORGE_REPO" ]; then
    if ! is_source_repo "$SPECFORGE_REPO"; then
      error "--source does not point to a SpecForge repo: $SPECFORGE_REPO"
      exit 1
    fi
    echo "$SPECFORGE_REPO"
    return 0
  fi

  # 2. Running from inside the SpecForge repo itself (not applicable in curl|bash)
  local script_src script_dir
  set +u; script_src="${BASH_SOURCE[0]:-}"; set -u
  if [ -n "$script_src" ] && [ -f "$script_src" ]; then
    script_dir="$(cd "$(dirname "$script_src")" 2>/dev/null && pwd)" || script_dir=""
    if [ -n "$script_dir" ] && is_source_repo "$script_dir"; then
      echo "$script_dir"
      return 0
    fi
  fi

  # 3. Try to download from GitHub
  TEMP_CLONE="$(mktemp -d)/specforge"

  if command -v git &>/dev/null; then
    echo "Downloading SpecForge..." >&2
    if git clone --depth 1 --branch "$SPECFORGE_VERSION" "$SPECFORGE_GIT_URL" "$TEMP_CLONE" 2>/dev/null; then
      echo "$TEMP_CLONE"
      return 0
    fi
  fi

  error "Could not find or download SpecForge."
  echo "" >&2
  echo "  Options:" >&2
  echo "    1. Clone the repo and run: bash /path/to/specforge/install.sh" >&2
  echo "    2. Set SPECFORGE_REPO=/path/to/specforge and re-run" >&2
  echo "    3. Use --source /path/to/specforge" >&2
  exit 1
}

# ── Copy framework files ──
install_framework() {
  local source="$1"
  local src_sf="$source/.specforge"

  echo ""
  echo -e "${BOLD}Installing SpecForge into $TARGET_DIR${RESET}"
  echo ""

  # Remove existing .specforge if --force
  if [ -d "$SF_DIR" ]; then
    rm -rf "$SF_DIR"
    warn "Removed existing .specforge/ (--force)"
  fi

  # Copy the entire .specforge directory
  cp -r "$src_sf" "$SF_DIR"

  # Remove project-specific files that shouldn't be carried over
  rm -f "$SF_DIR/ALIGN.md" 2>/dev/null || true
  rm -f "$SF_DIR/DESIGN.md" 2>/dev/null || true
  rm -f "$SF_DIR/NEXT.md" 2>/dev/null || true
  rm -f "$SF_DIR/REGISTRY.md" "$SF_DIR/registry.json" 2>/dev/null || true
  rm -f "$SF_DIR/config.yaml" 2>/dev/null || true
  rm -rf "$SF_DIR/iterations" 2>/dev/null || true
  rm -rf "$SF_DIR/specs/SPEC-"*.md 2>/dev/null || true
  rm -f "$SF_DIR/tasks/TASK-"*.md 2>/dev/null || true

  # Ensure specs/ has .gitkeep and TEMPLATE.md
  mkdir -p "$SF_DIR/specs"
  if [ ! -f "$SF_DIR/specs/.gitkeep" ]; then
    touch "$SF_DIR/specs/.gitkeep"
  fi
  if [ ! -f "$SF_DIR/specs/TEMPLATE.md" ]; then
    error "TEMPLATE.md missing from source — this shouldn't happen"
    exit 1
  fi

  # Ensure tasks/ has .gitkeep and TEMPLATE.md
  mkdir -p "$SF_DIR/tasks"
  if [ ! -f "$SF_DIR/tasks/.gitkeep" ]; then
    touch "$SF_DIR/tasks/.gitkeep"
  fi
  if [ ! -f "$SF_DIR/tasks/TEMPLATE.md" ]; then
    error "tasks/TEMPLATE.md missing from source — this shouldn't happen"
    exit 1
  fi

  # Make scripts executable
  chmod +x "$SF_DIR/scripts/"*.sh 2>/dev/null || true
  chmod +x "$SF_DIR/adapters/"*/adapt.sh 2>/dev/null || true

  info "Copied .specforge/ framework files"
}

update_framework() {
  local source="$1"
  local update_script="$source/.specforge/scripts/sf-update.sh"

  if [ ! -f "$update_script" ]; then
    error "Update script missing from source: $update_script"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}Updating SpecForge in $TARGET_DIR${RESET}"
  echo ""

  args=(--root "$TARGET_DIR" --source "$source")
  if [ -n "$IDE_ARG" ]; then
    args+=(--ide "$IDE_ARG")
  fi
  if [ "$DRY_RUN" = true ]; then
    args+=(--dry-run)
  fi

  bash "$update_script" "${args[@]}"
}

# ── Main ──
SOURCE="$(resolve_source)"

if [ "$UPDATE" = true ]; then
  if [ "$EXISTING_INSTALL" = false ]; then
    error "--update requested but SpecForge is not installed in $TARGET_DIR"
    exit 1
  fi
  update_framework "$SOURCE"
  echo ""
  info "SpecForge update finished!"
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  echo ""
  echo -e "${BOLD}Dry run: would install SpecForge into $TARGET_DIR${RESET}"
  echo ""
  exit 0
fi

install_framework "$SOURCE"

# ── Run sf-init.sh ──
echo ""
echo "Running sf-init.sh..."
echo ""

INIT_ARGS=""
if [ -n "$IDE_ARG" ]; then
  INIT_ARGS="--ide $IDE_ARG"
fi

(cd "$TARGET_DIR" && bash "$SF_DIR/scripts/sf-init.sh" $INIT_ARGS)

echo ""
info "SpecForge installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Edit .specforge/config.yaml (projects, test/lint/build commands, source dirs)"
echo "  2. Open the project in your editor"
echo "  3. Run /sf-plan to start the Plan phase"
echo ""
