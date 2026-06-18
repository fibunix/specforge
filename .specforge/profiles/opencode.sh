#!/usr/bin/env bash
# Projection profile: OpenCode. Sourced by lib/project.sh.
# NOTE: emit ONLY allowlisted keys — OpenCode's config is additionalProperties:false.
# Never write opencode.json and never set anthropic/ model IDs (Go subscription).
PROFILE_NAME="OpenCode"
PROFILE_DETECT_DIR=".opencode"
PROFILE_ROOT_RULES="AGENTS.md"
PROFILE_RULES_SYMLINK=".opencode/AGENTS.md|../AGENTS.md"
PROFILE_AGENTS_DIR=".opencode/agents"
PROFILE_AGENTS_FMT="md"
PROFILE_SKILLS_DIR=".opencode/skills"
PROFILE_COMMANDS_DIR=".opencode/commands"
PROFILE_DOCS_DIR=""
PROFILE_CONFIG_FILE=""
PROFILE_CONFIG_BODY=""

profile_agent_frontmatter() {
  echo "description: $FM_SUMMARY"
  if [ -n "$FM_ROLE" ]; then echo "mode: $FM_ROLE"; fi
  if [ -n "$FM_TEMP" ]; then echo "temperature: $FM_TEMP"; fi
  if [ -n "$FM_COLOR" ]; then echo "color: \"$FM_COLOR\""; fi
  echo "permission:"
  if [ "$FM_BASH" = "true" ]; then echo "  bash: allow"; else echo "  bash: deny"; fi
}

profile_skill_frontmatter() {
  echo "name: $FM_ID"
  echo "description: $FM_SUMMARY"
}

profile_command_body() {
  echo "---"
  echo "description: $FM_SUMMARY"
  echo "---"
  sf_marker_html
  echo ""
  printf '%s\n' "$BODY"
}
