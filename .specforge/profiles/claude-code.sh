#!/usr/bin/env bash
# Projection profile: Claude Code. Sourced by lib/project.sh.
PROFILE_NAME="Claude Code"
PROFILE_DETECT_DIR=".claude"
# AGENTS.md is the single source of truth; CLAUDE.md is a symlink onto it when
# the project has no CLAUDE.md of its own (step 2 only links when absent, so a
# user's real CLAUDE.md is preserved and gets the managed block injected instead).
PROFILE_ROOT_RULES="AGENTS.md CLAUDE.md"
PROFILE_RULES_SYMLINK="CLAUDE.md|AGENTS.md"
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
  if [ -n "$FM_COLOR" ]; then echo "color: $FM_COLOR"; fi
}

profile_skill_frontmatter() {
  echo "name: $FM_ID"
  echo "description: $FM_SUMMARY"
  # Side-effecting commands must not be auto-invoked by the model.
  if [ "$FM_SIDE_EFFECTS" = "true" ]; then echo "disable-model-invocation: true"; fi
}
