#!/usr/bin/env bash
# Contract tests for the public slash-command surface.

set -euo pipefail

failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! grep -Eq "$pattern" "$file"; then
    fail "$file should contain pattern: $pattern"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "$file should not contain pattern: $pattern"
  fi
}

canonical_commands=(sf-plan sf-test sf-ship sf-review sf-finalize sf-status)
legacy_commands=(sf-align sf-design sf-build sf-trace sf-next)
primary_docs=(README.md AGENTS.md .specforge/root/AGENTS.md .specforge/docs/FLOW.md)

# opencode commands are now file-based; check that each canonical command file exists
for command in "${canonical_commands[@]}"; do
  if [ ! -f ".specforge/adapters/opencode/commands/$command.md" ]; then
    fail ".specforge/adapters/opencode/commands/$command.md missing"
  fi
done

for command in "${legacy_commands[@]}"; do
  if [ -f ".specforge/adapters/opencode/commands/$command.md" ]; then
    fail ".specforge/adapters/opencode/commands/$command.md should not exist (legacy)"
  fi
done

for doc in "${primary_docs[@]}"; do
  for command in /sf-plan /sf-test /sf-ship /sf-review /sf-finalize /sf-status; do
    assert_contains "$doc" "$command"
  done

  for command in /sf-align /sf-design /sf-build /sf-trace; do
    assert_not_contains "$doc" "$command"
  done
done

for doc in AGENTS.md .specforge/root/AGENTS.md; do
  assert_contains "$doc" "<!-- BEGIN SPECFORGE MANAGED BLOCK v1 -->"
  assert_contains "$doc" "<!-- END SPECFORGE MANAGED BLOCK v1 -->"
done

assert_contains .specforge/skills/sf-plan/SKILL.md "ALIGN"
assert_contains .specforge/skills/sf-plan/SKILL.md "DESIGN"
assert_contains .specforge/skills/sf-plan/SKILL.md "SPEC"
assert_contains .specforge/skills/sf-plan/SKILL.md "NEXT[.]md"
assert_contains .specforge/skills/sf-plan/SKILL.md "archive-reset"
assert_contains .specforge/skills/sf-plan/SKILL.md "SUMMARY[.]md"
assert_contains .specforge/skills/sf-plan/SKILL.md "iterations/\*/specs"
assert_contains .specforge/skills/sf-plan/SKILL.md "Wave planning"
assert_not_contains .specforge/skills/sf-plan/SKILL.md "run /sf-align"
assert_not_contains .specforge/skills/sf-plan/SKILL.md "run /sf-design"
assert_not_contains .specforge/skills/sf-plan/SKILL.md "/sf-next"

assert_contains .specforge/skills/sf-status/SKILL.md "trace"
assert_contains .specforge/skills/sf-status/SKILL.md "requirement"
assert_contains .specforge/skills/sf-status/SKILL.md "NEXT[.]md"
assert_contains .specforge/skills/sf-status/SKILL.md "sf-facts"
assert_contains .specforge/skills/sf-status/SKILL.md "Decision ladder"
assert_not_contains .specforge/skills/sf-status/SKILL.md "sf-trace"
assert_not_contains .specforge/skills/sf-status/SKILL.md "sf-snapshot"

assert_contains .specforge/skills/sf-review/SKILL.md "merge-base"
assert_contains .specforge/skills/sf-review/SKILL.md "declared"
assert_not_contains .specforge/skills/sf-review/SKILL.md "sf-review[.]sh"

assert_contains .specforge/agents/aligner.md "load-bearing"
assert_contains .specforge/agents/aligner.md "NEXT[.]md"
assert_contains .specforge/agents/aligner.md "iterations/\*/specs"
assert_contains .specforge/agents/designer.md "do not design directly from it"
assert_contains .specforge/agents/designer.md "Supersedes"

assert_contains .specforge/specs/TEMPLATE.md "Iteration"
assert_contains .specforge/specs/TEMPLATE.md "Supersedes"

assert_not_contains .specforge/scripts/sf-doctor.sh "sf-align[.]md|[/]sf-align([[:space:]]|$)"
assert_not_contains .specforge/scripts/sf-doctor.sh "sf-design[.]md|[/]sf-design([[:space:]]|$)"
assert_not_contains .specforge/scripts/sf-doctor.sh "sf-build[.]md|[/]sf-build([[:space:]]|$)"
assert_not_contains .specforge/scripts/sf-doctor.sh "sf-trace[.]md|[/]sf-trace([[:space:]]|$)"

for legacy_skill in \
  .specforge/skills/sf-align \
  .specforge/skills/sf-design \
  .specforge/skills/sf-build \
  .specforge/skills/sf-trace
do
  if [ -f "$legacy_skill/SKILL.md" ]; then
    assert_contains "$legacy_skill/SKILL.md" "legacy|Legacy|compatibility|Compatibility"
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "$failures command surface assertion(s) failed." >&2
  exit 1
fi

echo "command surface contract passed"
