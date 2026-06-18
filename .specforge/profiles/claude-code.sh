#!/usr/bin/env bash
# Projection profile: Claude Code. Sourced by lib/project.sh.
PROFILE_NAME="Claude Code"
PROFILE_DETECT_DIR=".claude"
PROFILE_ROOT_RULES="AGENTS.md CLAUDE.md"
PROFILE_RULES_SYMLINK=""
PROFILE_AGENTS_DIR=".claude/agents"
PROFILE_AGENTS_FMT="md"
PROFILE_SKILLS_DIR=".claude/skills"
PROFILE_COMMANDS_DIR=""
PROFILE_DOCS_DIR=""
PROFILE_CONFIG_FILE=""
PROFILE_CONFIG_BODY=""

profile_agent_frontmatter() {
  echo "name: $FM_ID"
  echo "description: $FM_SUMMARY"
  if [ -n "$FM_MODEL" ]; then echo "model: $FM_MODEL"; fi
}

profile_skill_frontmatter() {
  echo "name: $FM_ID"
  echo "description: $FM_SUMMARY"
  # Side-effecting commands must not be auto-invoked by the model.
  if [ "$FM_SIDE_EFFECTS" = "true" ]; then echo "disable-model-invocation: true"; fi
}
