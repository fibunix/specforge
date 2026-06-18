#!/usr/bin/env bash
# project.sh - the ONE generic projector. Renders canon/ assets into each IDE's
# layout using a per-IDE profile (data + tiny emit hooks). Replaces the old
# per-IDE adapt.sh scripts.
#
# Depends on: common.sh, managed-block.sh, frontmatter.sh (sourced by caller).
#
# Profile contract (variables a profile sets when sourced):
#   PROFILE_NAME            display name
#   PROFILE_DETECT_DIR      dir whose presence means "this IDE is installed"
#   PROFILE_ROOT_RULES      space-list of root files to managed-block (e.g. "AGENTS.md CLAUDE.md")
#   PROFILE_RULES_SYMLINK   "link|target" to create (e.g. ".opencode/AGENTS.md|../AGENTS.md"), or ""
#   PROFILE_AGENTS_DIR      where agent files go, or ""
#   PROFILE_AGENTS_FMT      "md" | "toml"
#   PROFILE_SKILLS_DIR      where skill dirs go, or ""
#   PROFILE_COMMANDS_DIR    where command files go, or ""
#   PROFILE_DOCS_DIR        where reference docs go, or ""
#   PROFILE_CONFIG_FILE     a config file to seed if absent, or ""
#   PROFILE_CONFIG_BODY     contents for that config file
# Profile functions (read exported FM_* and BODY; echo file contents):
#   profile_agent_frontmatter   -> YAML frontmatter lines (md agents)
#   profile_agent_toml          -> full TOML file (toml agents)
#   profile_skill_frontmatter   -> YAML frontmatter lines (skills)
#   profile_command_body        -> full command file (optional)

sf_project_ide() {
  local root="$1" ide="$2" dry="${3:-false}"
  local sf="$root/.specforge"
  local profile="$sf/profiles/$ide.sh"
  [ -f "$profile" ] || { sf_fail "no profile for IDE '$ide' ($profile)"; return 1; }

  # Reset profile vars/fns, then load this profile.
  PROFILE_NAME=""; PROFILE_DETECT_DIR=""; PROFILE_ROOT_RULES=""; PROFILE_RULES_SYMLINK=""
  PROFILE_AGENTS_DIR=""; PROFILE_AGENTS_FMT="md"; PROFILE_SKILLS_DIR=""
  PROFILE_COMMANDS_DIR=""; PROFILE_DOCS_DIR=""; PROFILE_CONFIG_FILE=""; PROFILE_CONFIG_BODY=""
  # shellcheck source=/dev/null
  source "$profile"

  echo "Projecting canon -> ${PROFILE_NAME:-$ide}"

  # 1. Root rules (managed block, preserves user content around it).
  local rf
  for rf in $PROFILE_ROOT_RULES; do
    sf_update_managed_block "$root/$rf" "$sf/canon/root/SPECFORGE.md" "$dry" "$rf"
  done

  # 2. Rules symlink (e.g. .opencode/AGENTS.md -> ../AGENTS.md).
  if [ -n "$PROFILE_RULES_SYMLINK" ]; then
    local link="${PROFILE_RULES_SYMLINK%%|*}" target="${PROFILE_RULES_SYMLINK##*|}"
    mkdir -p "$(dirname "$root/$link")"
    if [ ! -e "$root/$link" ] && [ ! -L "$root/$link" ]; then
      [ "$dry" = true ] && echo "  → would link $link -> $target" || { ln -s "$target" "$root/$link"; echo "  ✓ linked $link -> $target"; }
    fi
  fi

  # 3. Seed config file if absent (marker-stamped so update can manage it).
  if [ -n "$PROFILE_CONFIG_FILE" ] && [ ! -e "$root/$PROFILE_CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$root/$PROFILE_CONFIG_FILE")"
    if [ "$dry" = true ]; then
      echo "  → would seed $PROFILE_CONFIG_FILE"
    else
      { sf_marker_hash; printf '%s\n' "$PROFILE_CONFIG_BODY"; } > "$root/$PROFILE_CONFIG_FILE"
      echo "  ✓ seeded $PROFILE_CONFIG_FILE"
    fi
  fi

  # 4. Agents.
  if [ -n "$PROFILE_AGENTS_DIR" ]; then
    mkdir -p "$root/$PROFILE_AGENTS_DIR"
    sf_sweep_generated_files "$root/$PROFILE_AGENTS_DIR"
    local af id out tmp
    for af in "$sf"/canon/agents/*.md; do
      [ -f "$af" ] || continue
      _sf_load_fm "$af"
      id="$FM_ID"
      tmp="$(mktemp)"
      if [ "$PROFILE_AGENTS_FMT" = "toml" ]; then
        out="$root/$PROFILE_AGENTS_DIR/$(sf_snake "$id").toml"
        { sf_marker_hash; profile_agent_toml; } > "$tmp"
      else
        out="$root/$PROFILE_AGENTS_DIR/$id.md"
        { echo "---"; profile_agent_frontmatter; echo "---"; sf_marker_html; echo ""; printf '%s\n' "$BODY"; } > "$tmp"
      fi
      sf_write_if_ours "$tmp" "$out" "agent $id" "$dry"
      rm -f "$tmp"
    done
  fi

  # 5. Skills.
  if [ -n "$PROFILE_SKILLS_DIR" ]; then
    mkdir -p "$root/$PROFILE_SKILLS_DIR"
    sf_sweep_generated_skilldirs "$root/$PROFILE_SKILLS_DIR"
    local sd name out tmp
    for sd in "$sf"/canon/skills/*/; do
      [ -d "$sd" ] || continue
      [ -f "$sd/SKILL.md" ] || continue
      _sf_load_fm "$sd/SKILL.md"
      name="$FM_ID"
      out="$root/$PROFILE_SKILLS_DIR/$name/SKILL.md"
      tmp="$(mktemp)"
      { echo "---"; profile_skill_frontmatter; echo "---"; sf_marker_html; echo ""; printf '%s\n' "$BODY"; } > "$tmp"
      sf_write_if_ours "$tmp" "$out" "skill $name" "$dry"
      rm -f "$tmp"
    done
  fi

  # 6. Commands (optional; e.g. OpenCode slash commands).
  if [ -n "$PROFILE_COMMANDS_DIR" ] && sf_fn_exists profile_command_body; then
    mkdir -p "$root/$PROFILE_COMMANDS_DIR"
    sf_sweep_generated_files "$root/$PROFILE_COMMANDS_DIR"
    local cd2 name out tmp
    for cd2 in "$sf"/canon/skills/*/; do
      [ -d "$cd2" ] || continue
      [ -f "$cd2/SKILL.md" ] || continue
      _sf_load_fm "$cd2/SKILL.md"
      name="$FM_ID"
      out="$root/$PROFILE_COMMANDS_DIR/$name.md"
      tmp="$(mktemp)"
      profile_command_body > "$tmp"
      sf_write_if_ours "$tmp" "$out" "command /$name" "$dry"
      rm -f "$tmp"
    done
  fi

  # 7. Reference docs (verbatim copy with marker prepended).
  if [ -n "$PROFILE_DOCS_DIR" ]; then
    mkdir -p "$root/$PROFILE_DOCS_DIR"
    sf_sweep_generated_files "$root/$PROFILE_DOCS_DIR"
    local doc name out tmp
    for doc in "$sf"/canon/docs/*.md; do
      [ -f "$doc" ] || continue
      name="$(basename "$doc")"
      out="$root/$PROFILE_DOCS_DIR/$name"
      tmp="$(mktemp)"
      { sf_marker_html; echo ""; cat "$doc"; } > "$tmp"
      sf_write_if_ours "$tmp" "$out" "doc $name" "$dry"
      rm -f "$tmp"
    done
  fi

  echo "  ✓ ${PROFILE_NAME:-$ide} projection complete"
}

# Load neutral frontmatter fields from a canon file into FM_* + BODY.
_sf_load_fm() {
  local f="$1"
  FM_ID="$(sf_fm_field "$f" id)"
  FM_SUMMARY="$(sf_fm_field "$f" summary)"
  FM_ROLE="$(sf_fm_field "$f" role)"
  FM_BASH="$(sf_fm_field "$f" bash)"
  FM_MODEL="$(sf_fm_field "$f" model)"
  FM_TEMP="$(sf_fm_field "$f" temperature)"
  FM_COLOR="$(sf_fm_field "$f" color)"
  FM_SIDE_EFFECTS="$(sf_fm_field "$f" side_effects)"
  FM_AUTO="$(sf_fm_field "$f" auto)"
  BODY="$(sf_fm_body "$f")"
  export FM_ID FM_SUMMARY FM_ROLE FM_BASH FM_MODEL FM_TEMP FM_COLOR FM_SIDE_EFFECTS FM_AUTO BODY
}

sf_fn_exists() { type "$1" >/dev/null 2>&1; }

# Detect which IDEs are installed (presence of their detect dir).
sf_detect_ides() {
  local root="$1" ide list=""
  for ide in claude-code opencode codex pi antigravity; do
    case "$ide" in
      claude-code) [ -d "$root/.claude" ] && list="$list claude-code" ;;
      opencode)    [ -d "$root/.opencode" ] && list="$list opencode" ;;
      codex)       [ -d "$root/.codex" ] && list="$list codex" ;;
      pi)          [ -d "$root/.pi" ] && list="$list pi" ;;
      antigravity) [ -d "$root/.antigravity" ] && list="$list antigravity" ;;
    esac
  done
  echo "${list# }"
}
