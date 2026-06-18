#!/usr/bin/env bash
# Projection profile: OpenAI Codex. Sourced by lib/project.sh.
PROFILE_NAME="Codex"
PROFILE_DETECT_DIR=".codex"
PROFILE_ROOT_RULES="AGENTS.md"
PROFILE_RULES_SYMLINK=""
PROFILE_AGENTS_DIR=".codex/agents"
PROFILE_AGENTS_FMT="toml"
PROFILE_SKILLS_DIR=""
PROFILE_COMMANDS_DIR=""
PROFILE_DOCS_DIR=".codex/instructions"
PROFILE_CONFIG_FILE=".codex/config.toml"
PROFILE_CONFIG_BODY="[agents]
max_threads = 3
max_depth = 1"

profile_agent_toml() {
  local sandbox="read-only"
  [ "$FM_BASH" = "true" ] && sandbox="workspace-write"
  printf 'name = "%s"\n' "$(sf_snake "$FM_ID")"
  printf 'description = "%s"\n' "$FM_SUMMARY"
  printf 'sandbox_mode = "%s"\n' "$sandbox"
  printf 'developer_instructions = """\n%s\n"""\n' "$BODY"
}
