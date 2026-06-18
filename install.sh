#!/usr/bin/env bash
# install.sh - Bootstrap SpecForge into a target project.
#
# Curl one-liner — same command installs AND updates (idempotent):
#   curl -fsSL https://raw.githubusercontent.com/fibunix/specforge/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --ide all
#
# From a local clone:
#   bash install.sh --source /path/to/specforge --dir /your/project --ide all
#
# Copies the framework (.specforge canon/profiles/lib/scripts + bin/sf) into the
# target, then runs sf-init. Project-owned content (project.yaml, work/, NEXT.md,
# and your own text in root AGENTS.md/CLAUDE.md outside the managed block) is
# never overwritten — so re-running on an existing project just pulls the latest
# framework and re-projects it. That is the update path.

set -euo pipefail

SPECFORGE_GIT_URL="${SPECFORGE_GIT_URL:-https://github.com/fibunix/specforge.git}"
SPECFORGE_VERSION="${SPECFORGE_VERSION:-main}"

SOURCE="${SPECFORGE_REPO:-}"; DIR="$(pwd)"; IDE=""; FORCE=false; DRY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    --ide) IDE="${2:-}"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --dry-run) DRY=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

TMP_CLONE=""
cleanup() { [ -n "$TMP_CLONE" ] && rm -rf "$TMP_CLONE" 2>/dev/null || true; }
trap cleanup EXIT

is_source_repo() {
  [ -n "$1" ] && [ -f "$1/install.sh" ] && \
    [ -f "$1/.specforge/scripts/sf-init.sh" ] && \
    [ -f "$1/.specforge/canon/root/SPECFORGE.md" ]
}

resolve_source() {
  # 1. Explicit / env source.
  if [ -n "$SOURCE" ]; then
    SOURCE="$(cd "$SOURCE" && pwd)"
    is_source_repo "$SOURCE" || { echo "error: --source is not a SpecForge repo: $SOURCE" >&2; exit 1; }
    return 0
  fi
  # 2. Running from inside a clone (not the case under curl|bash).
  local src dir
  set +u; src="${BASH_SOURCE[0]:-}"; set -u
  if [ -n "$src" ] && [ -f "$src" ]; then
    dir="$(cd "$(dirname "$src")" 2>/dev/null && pwd)" || dir=""
    if is_source_repo "$dir"; then SOURCE="$dir"; return 0; fi
  fi
  # 3. Clone from GitHub.
  command -v git >/dev/null 2>&1 || { echo "error: git required to download SpecForge" >&2; exit 1; }
  echo "Downloading SpecForge ($SPECFORGE_VERSION)..." >&2
  TMP_CLONE="$(mktemp -d)/specforge"
  git clone --depth 1 --branch "$SPECFORGE_VERSION" "$SPECFORGE_GIT_URL" "$TMP_CLONE" >/dev/null 2>&1 \
    || { echo "error: could not clone $SPECFORGE_GIT_URL@$SPECFORGE_VERSION" >&2; exit 1; }
  is_source_repo "$TMP_CLONE" || { echo "error: clone is not a valid SpecForge repo" >&2; exit 1; }
  SOURCE="$TMP_CLONE"
}

resolve_source
DIR="$(cd "$DIR" && pwd)"

# Re-running over an existing install is the update path (sf-init is idempotent
# and preserves project-owned content); relabel so the intent is clear.
if [ -d "$DIR/.specforge/canon" ]; then VERB="Updating"; else VERB="Installing"; fi
echo "$VERB SpecForge: $SOURCE -> $DIR"
if [ "$SOURCE" = "$DIR" ]; then
  echo "  (source == target; running init in place)"
else
  mkdir -p "$DIR/.specforge" "$DIR/bin"
  for sub in canon profiles lib scripts; do
    if [ "$DRY" = true ]; then
      echo "  → would copy .specforge/$sub"
    else
      rm -rf "$DIR/.specforge/$sub"
      cp -R "$SOURCE/.specforge/$sub" "$DIR/.specforge/$sub"
    fi
  done
  if [ "$DRY" != true ]; then
    cp "$SOURCE/bin/sf" "$DIR/bin/sf"; chmod +x "$DIR/bin/sf"
  fi
fi

[ "$DRY" = true ] && { echo "Dry run complete."; exit 0; }
chmod +x "$DIR/.specforge/scripts/"*.sh 2>/dev/null || true

INIT_ARGS=""
[ -n "$IDE" ] && INIT_ARGS="--ide $IDE"
# shellcheck disable=SC2086
( cd "$DIR" && bash "$DIR/.specforge/scripts/sf-init.sh" $INIT_ARGS )

echo "$VERB done. Run 'bin/sf status' or use /sf in your editor."
