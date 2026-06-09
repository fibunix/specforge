#!/usr/bin/env bash
# sf-doctor.sh - Check whether a SpecForge install is ready to use.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/managed-block.sh
source "$SCRIPT_DIR/lib/managed-block.sh"

ROOT="$(sf_root)"
SF="$ROOT/.specforge"
CFG="$SF/config.yaml"
ERRORS=0
WARNINGS=0

ok() { sf_ok "$1"; }
warn() { sf_warn "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { sf_fail "$1"; ERRORS=$((ERRORS + 1)); }

require_file() {
  local path="$1"
  local label="$2"
  [ -f "$path" ] && ok "$label" || fail "$label missing at $path"
}

require_executable() {
  local path="$1"
  local label="$2"
  if [ -x "$path" ]; then
    ok "$label is executable"
  elif [ -f "$path" ]; then
    fail "$label exists but is not executable"
  else
    fail "$label is missing"
  fi
}

check_symlink_target() {
  local path="$1"
  local target="$2"
  local label="$3"
  local current=""

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    warn "$label missing at $path"
    return
  fi

  current="$(readlink "$path" 2>/dev/null || true)"
  if [ "$current" = "$target" ]; then
    ok "$label points to $target"
  elif [ -n "$current" ]; then
    warn "$label points to $current, expected $target"
  else
    warn "$label exists as a regular file; preserved user content"
  fi
}

check_config() {
  require_file "$CFG" "config.yaml"
  [ -f "$CFG" ] || return

  local project_name test_command lint_command build_command source_dir projects
  project_name="$(sf_config_top_value "$CFG" project_name)"
  test_command="$(sf_config_top_value "$CFG" test_command)"
  lint_command="$(sf_config_top_value "$CFG" lint_command)"
  build_command="$(sf_config_top_value "$CFG" build_command)"
  source_dir="$(sf_config_top_value "$CFG" source_dir)"
  projects="$(sf_config_project_ids "$CFG")"

  [ -n "$project_name" ] || fail "config project_name is empty"
  [ "$project_name" != "my-project" ] || warn "config project_name still has the default value"

  if [ -z "$projects" ]; then
    [ -n "$test_command" ] || fail "config test_command is empty"
    [ -n "$lint_command" ] || warn "config lint_command is empty"
    [ -n "$build_command" ] || warn "config build_command is empty"
    [ -n "$source_dir" ] || warn "config source_dir is empty"
    [ "$test_command" != "npm test" ] || warn "config test_command still has the default value; confirm this project uses npm test"
    return
  fi

  ok "config projects declared"
  [ -z "$test_command" ] || warn "root test_command is set but projects are declared; sf-test.sh runs projects by default"

  for project_id in $projects; do
    local project_path project_test project_source project_dir
    project_path="$(sf_config_project_value "$CFG" "$project_id" path)"
    project_test="$(sf_config_project_value "$CFG" "$project_id" test_command)"
    project_source="$(sf_config_project_value "$CFG" "$project_id" source_dir)"

    [ -n "$project_test" ] || fail "config project '$project_id' test_command is empty"
    [ -n "$project_path" ] || warn "config project '$project_id' path is empty; root will be used"
    [ -n "$project_source" ] || warn "config project '$project_id' source_dir is empty"

    if [ -n "$project_path" ]; then
      project_dir="$(sf_config_project_dir "$ROOT" "$project_path")"
      [ -d "$project_dir" ] && ok "config project '$project_id' path exists" || warn "config project '$project_id' path missing at $project_path"
    fi
  done
}

check_scripts() {
  local script
  for script in sf-init.sh sf-update.sh sf-test.sh sf-worktree.sh sf-finalize.sh sf-review.sh sf-snapshot.sh sf-trace.sh sf-lint-specs.sh sf-doctor.sh sf-verify-build.sh; do
    require_executable "$SF/scripts/$script" "script $script"
  done

  for lib in common.sh config.sh git.sh spec.sh adapter.sh managed-block.sh; do
    require_file "$SF/scripts/lib/$lib" "script helper lib/$lib"
  done
}

check_command_surface() {
  local cmd
  for cmd in sf-finalize sf-plan sf-review sf-ship sf-status sf-test; do
    require_file "$SF/skills/$cmd/SKILL.md" "skill $cmd"
    require_file "$SF/adapters/opencode/commands/$cmd.md" "opencode command $cmd"
  done
}

check_root_instructions() {
  require_file "$SF/root/SPECFORGE.md" "managed root instruction template"
  require_file "$ROOT/AGENTS.md" "root AGENTS.md"

  if sf_has_managed_block "$ROOT/AGENTS.md"; then
    ok "root AGENTS.md has SpecForge managed block"
  else
    warn "root AGENTS.md has no SpecForge managed block; run sf update"
  fi
}

check_adapters() {
  local adapters_found=0

  if [ -d "$ROOT/.opencode" ]; then
    adapters_found=$((adapters_found + 1))
    check_symlink_target "$ROOT/.opencode/AGENTS.md" "../AGENTS.md" "opencode rules link"
    [ -d "$ROOT/.opencode/agents" ] && ok "opencode agents directory exists" || warn "opencode agents directory missing — run bash .specforge/adapters/opencode/adapt.sh"
    [ -e "$ROOT/.opencode/agents/sf.md" ] && ok "opencode sf agent linked" || warn "opencode sf agent missing — run bash .specforge/adapters/opencode/adapt.sh"
    [ -d "$ROOT/.opencode/commands" ] && ok "opencode commands directory exists" || warn "opencode commands directory missing — run bash .specforge/adapters/opencode/adapt.sh"
    [ -e "$ROOT/.opencode/commands/sf-plan.md" ] && ok "opencode sf-plan command linked" || warn "sf-plan command missing — run bash .specforge/adapters/opencode/adapt.sh"
    [ -d "$ROOT/.opencode/skills" ] && ok "opencode skills directory exists" || warn "opencode skills directory missing — run bash .specforge/adapters/opencode/adapt.sh"
  fi

  if [ -d "$ROOT/.claude" ]; then
    adapters_found=$((adapters_found + 1))
    if [ -e "$ROOT/CLAUDE.md" ] || [ -L "$ROOT/CLAUDE.md" ]; then
      claude_target="$(readlink "$ROOT/CLAUDE.md" 2>/dev/null || true)"
      if [ "$claude_target" = "AGENTS.md" ]; then
        ok "Claude Code root CLAUDE.md links to AGENTS.md"
      elif sf_has_managed_block "$ROOT/CLAUDE.md"; then
        ok "Claude Code root CLAUDE.md has SpecForge managed block"
      elif [ -f "$ROOT/CLAUDE.md" ] && grep -q '@AGENTS\.md' "$ROOT/CLAUDE.md"; then
        ok "Claude Code root CLAUDE.md imports AGENTS.md"
      else
        warn "existing root CLAUDE.md is preserved; run sf update --ide claude-code to add the SpecForge managed block"
      fi
    else
      warn "root CLAUDE.md missing; run bash .specforge/adapters/claude-code/adapt.sh"
    fi
    [ -d "$ROOT/.claude/agents" ] && ok "Claude Code agents directory exists" || warn "Claude Code agents directory missing"
    [ -d "$ROOT/.claude/skills" ] && ok "Claude Code skills directory exists" || warn "Claude Code skills directory missing — run bash .specforge/adapters/claude-code/adapt.sh"
    [ -e "$ROOT/.claude/skills/sf-plan" ] && ok "Claude Code sf-plan skill linked" || warn "sf-plan skill missing — run bash .specforge/adapters/claude-code/adapt.sh"
  fi

  if [ -d "$ROOT/.codex" ]; then
    adapters_found=$((adapters_found + 1))
    [ -f "$ROOT/AGENTS.md" ] && ok "Codex native AGENTS.md is present" || fail "Codex native AGENTS.md missing"
    [ -f "$ROOT/.codex/config.toml" ] && ok "Codex project config exists" || warn "Codex project config missing"
    [ -d "$ROOT/.codex/agents" ] && ok "Codex agents directory exists" || warn "Codex agents directory missing"
    [ -e "$ROOT/.codex/agents/sf-builder.toml" ] && ok "Codex sf-builder agent exists" || warn "Codex sf-builder agent missing"
    [ -d "$ROOT/.codex/instructions" ] && ok "Codex instructions directory exists" || warn "Codex instructions directory missing"
  fi

  if [ -d "$ROOT/.pi" ]; then
    adapters_found=$((adapters_found + 1))
    [ -f "$ROOT/AGENTS.md" ] && ok "Pi native AGENTS.md is present" || fail "Pi native AGENTS.md missing"
    [ -e "$ROOT/.pi/AGENTS.md" ] && warn "stale .pi/AGENTS.md exists; Pi reads root AGENTS.md/CLAUDE.md workspace context" || true
    [ -d "$ROOT/.pi/prompts" ] && ok "Pi prompts directory exists" || warn "Pi prompts directory missing"
    [ -d "$ROOT/.pi/skills" ] && ok "Pi skills directory exists" || warn "Pi skills directory missing"
    [ -d "$ROOT/.pi/agents" ] && ok "Pi agents directory exists" || warn "Pi agents directory missing"
  fi

  if [ -d "$ROOT/.antigravity" ]; then
    adapters_found=$((adapters_found + 1))
    [ -f "$ROOT/AGENTS.md" ] && ok "Antigravity workspace AGENTS.md is present" || fail "Antigravity workspace AGENTS.md missing"
    [ -e "$ROOT/.antigravity/AGENTS.md" ] && warn "stale .antigravity/AGENTS.md exists; Antigravity reads root AGENTS.md/GEMINI.md workspace context" || true
    [ -d "$ROOT/.antigravity/instructions" ] && ok "Antigravity instructions directory exists" || warn "Antigravity instructions directory missing"
  fi

  [ "$adapters_found" -gt 0 ] || warn "no IDE adapter directories found; run bash .specforge/scripts/sf-init.sh --ide <ide>"
}

echo "SpecForge doctor"
echo ""

[ -d "$SF" ] && ok ".specforge directory exists" || fail ".specforge directory missing"
check_config
check_scripts
check_command_surface
check_root_instructions
check_adapters

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "SpecForge doctor failed: $ERRORS error(s), $WARNINGS warning(s)." >&2
  exit 1
fi

echo "SpecForge doctor passed: $WARNINGS warning(s)."
