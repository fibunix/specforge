#!/usr/bin/env bash
# Adapter fixture contracts for public commands and internal reviewer skills.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
failures=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_exists() {
  local path="$1"
  [ -e "$path" ] || fail "$path should exist"
}

assert_not_exists() {
  local path="$1"
  [ ! -e "$path" ] || fail "$path should not exist"
}

assert_contains() {
  local file="$1" pattern="$2"
  grep -Eq "$pattern" "$file" || fail "$file should contain pattern: $pattern"
}

public_commands=(sf-plan sf-test sf-ship sf-review sf-finalize sf-status sf-loop sf-goal sf-task)
internal_skills=(sf-plan-reviewer sf-test-reviewer sf-implementation-reviewer sf-task-reviewer)

# opencode exposes public slash-command wrappers and internal reviewer skills.
PROJECT="$TMP/opencode"
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide opencode >/dev/null
assert_contains "$PROJECT/AGENTS.md" "/sf-loop"
assert_contains "$PROJECT/AGENTS.md" "/sf-goal"
for command in "${public_commands[@]}"; do
  assert_exists "$PROJECT/.opencode/commands/$command.md"
done
for skill in "${internal_skills[@]}"; do
  assert_exists "$PROJECT/.opencode/skills/$skill/SKILL.md"
  assert_not_exists "$PROJECT/.opencode/commands/$skill.md"
done
assert_not_exists "$PROJECT/.opencode/skills/sf-auto-review"
assert_exists "$PROJECT/.opencode/agents/sf-test-reviewer.md"
assert_exists "$PROJECT/.opencode/agents/sf-implementation-reviewer.md"

# Codex uses AGENTS.md and custom agent wrappers, not slash-command files.
PROJECT="$TMP/codex"
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide codex >/dev/null
assert_contains "$PROJECT/AGENTS.md" "/sf-loop"
assert_exists "$PROJECT/.codex/agents/sf-builder.toml"
assert_exists "$PROJECT/.codex/agents/sf-test-reviewer.toml"
assert_exists "$PROJECT/.codex/agents/sf-implementation-reviewer.toml"
assert_exists "$PROJECT/.codex/instructions/FLOW.md"

# Claude Code gets managed instructions plus skills; internal reviewers are skills only.
PROJECT="$TMP/claude"
mkdir -p "$PROJECT"
git init -q -b main "$PROJECT"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide claude-code >/dev/null
assert_contains "$PROJECT/CLAUDE.md" "/sf-loop"
for command in "${public_commands[@]}"; do
  assert_exists "$PROJECT/.claude/skills/$command/SKILL.md"
done
for skill in "${internal_skills[@]}"; do
  assert_exists "$PROJECT/.claude/skills/$skill/SKILL.md"
done
assert_not_exists "$PROJECT/.claude/skills/sf-auto-review"
assert_not_exists "$PROJECT/.claude/commands/sf-loop.md"

if [ "$failures" -gt 0 ]; then
  echo "$failures adapter fixture assertion(s) failed." >&2
  exit 1
fi

echo "adapter fixture contract passed"
