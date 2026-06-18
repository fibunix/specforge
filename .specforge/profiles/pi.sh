#!/usr/bin/env bash
# Projection profile: Pi. Sourced by lib/project.sh.
PROFILE_NAME="Pi"
PROFILE_DETECT_DIR=".pi"
PROFILE_ROOT_RULES="AGENTS.md"
PROFILE_RULES_SYMLINK=""
PROFILE_AGENTS_DIR=".pi/agents"
PROFILE_AGENTS_FMT="md"
PROFILE_SKILLS_DIR=".pi/skills"
PROFILE_COMMANDS_DIR=""
PROFILE_DOCS_DIR=".pi/instructions"
PROFILE_CONFIG_FILE=""
PROFILE_CONFIG_BODY=""

profile_agent_frontmatter() {
  echo "name: $FM_ID"
  echo "description: $FM_SUMMARY"
}

profile_skill_frontmatter() {
  echo "name: $FM_ID"
  echo "description: $FM_SUMMARY"
}
