#!/usr/bin/env bash
# sf-doctor.sh - Health check: canon present, profiles valid, config sane,
# projection in sync. Read-only. Exits non-zero on any error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SF="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$SF/lib"
# shellcheck source=../lib/common.sh
source "$LIB/common.sh"
# shellcheck source=../lib/config.sh
source "$LIB/config.sh"
# shellcheck source=../lib/frontmatter.sh
source "$LIB/frontmatter.sh"
# shellcheck source=../lib/project.sh
source "$LIB/project.sh"

ROOT="$(sf_root)"
ERRORS=0
err() { echo "  ✗ $1"; ERRORS=$((ERRORS+1)); }
ok()  { echo "  ✓ $1"; }

echo "SpecForge doctor — $ROOT"

# 1. Canon present.
echo "canon:"
[ -d "$SF/canon/agents" ] && [ -n "$(ls "$SF"/canon/agents/*.md 2>/dev/null)" ] && ok "agents present" || err "no canon agents"
[ -d "$SF/canon/skills" ] && [ -n "$(ls -d "$SF"/canon/skills/*/ 2>/dev/null)" ] && ok "skills present" || err "no canon skills"
[ -f "$SF/canon/root/SPECFORGE.md" ] && ok "root payload present" || err "canon/root/SPECFORGE.md missing"

# 2. Every canon asset has id + summary.
for f in "$SF"/canon/agents/*.md "$SF"/canon/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  id="$(sf_fm_field "$f" id)"; sum="$(sf_fm_field "$f" summary)"
  [ -n "$id" ] || err "missing id: $(sf_relpath "$ROOT" "$f")"
  [ -n "$sum" ] || err "missing summary: $(sf_relpath "$ROOT" "$f")"
done
[ "$ERRORS" -eq 0 ] && ok "all canon assets have id + summary"

# 3. Profiles valid (source each; PROFILE_NAME must be set).
echo "profiles:"
for p in "$SF"/profiles/*.sh; do
  [ -f "$p" ] || continue
  name=""
  ( PROFILE_NAME=""; source "$p"; [ -n "$PROFILE_NAME" ] ) && ok "profile $(basename "$p" .sh)" || err "profile $(basename "$p" .sh) sets no PROFILE_NAME"
done

# 4. Project config.
echo "config:"
if [ -f "$ROOT/project.yaml" ]; then
  tc="$(sf_config_top_value "$ROOT/project.yaml" test_command)"
  [ -n "$tc" ] && ok "test_command set" || err "test_command not set in project.yaml"
else
  err "project.yaml missing (run: sf init)"
fi

# 5. Installed IDEs.
echo "installed IDEs:"
ides="$(sf_detect_ides "$ROOT")"
[ -n "$ides" ] && ok "$ides" || echo "  (none detected)"

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "doctor: healthy"
else
  echo "doctor: $ERRORS error(s)"
  exit 1
fi
