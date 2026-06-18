#!/usr/bin/env bash
# Packaging: projection across IDEs, strict-schema safety, no-clobber, orphan retire.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
chk() { if eval "$2"; then echo "  ok: $1"; else echo "  FAIL: $1"; FAIL=1; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T"; git init -q; git config user.email t@t; git config user.name t
git commit -q --allow-empty -m init
bash "$REPO/install.sh" --source "$REPO" --dir "$T" --ide all >/dev/null 2>&1

chk "claude agents projected"      '[ -f "$T/.claude/agents/verifier.md" ]'
chk "claude skills projected"      '[ -f "$T/.claude/skills/sf-loop/SKILL.md" ]'
chk "opencode agents projected"    '[ -f "$T/.opencode/agents/designer.md" ]'
chk "opencode commands projected"  '[ -f "$T/.opencode/commands/sf.md" ]'
chk "codex toml projected"         '[ -f "$T/.codex/agents/test_author.toml" ]'
chk "pi agents projected"          '[ -f "$T/.pi/agents/coordinator.md" ]'
chk "antigravity docs projected"   '[ -f "$T/.antigravity/instructions/WORKFLOW.md" ]'
chk "no opencode.json written"     '[ ! -f "$T/opencode.json" ]'
chk "AGENTS.md managed block"      'grep -q "BEGIN SPECFORGE MANAGED BLOCK" "$T/AGENTS.md"'
chk "CLAUDE.md managed block"      'grep -q "BEGIN SPECFORGE MANAGED BLOCK" "$T/CLAUDE.md"'
chk "generated files carry marker" 'grep -q "SPECFORGE-GENERATED" "$T/.claude/agents/verifier.md"'

# OpenCode strict-schema: agent frontmatter must only contain allowlisted keys.
fm="$(sed -n '/^---$/,/^---$/p' "$T/.opencode/agents/designer.md" | grep -E '^[a-z_]+:' || true)"
bad="$(printf '%s\n' "$fm" | grep -Ev '^(description|mode|temperature|color|permission|bash):' || true)"
chk "opencode agent keys allowlisted" '[ -z "$bad" ]'
chk "no anthropic/ model id leaked" '! grep -rq "anthropic/" "$T/.opencode" 2>/dev/null'

# No-clobber: a user file without the marker survives update.
echo "mine" > "$T/.claude/agents/custom.md"
bash "$T/.specforge/scripts/sf-update.sh" --root "$T" --source "$REPO" >/dev/null 2>&1
chk "user file preserved on update" '[ -f "$T/.claude/agents/custom.md" ]'

# Orphan retirement: a stray marker file is removed on update.
printf '<!-- SPECFORGE-GENERATED x -->\nstale\n' > "$T/.claude/agents/orphan.md"
bash "$T/.specforge/scripts/sf-update.sh" --root "$T" --source "$REPO" >/dev/null 2>&1
chk "orphan retired on update" '[ ! -f "$T/.claude/agents/orphan.md" ]'

# Doctor healthy.
chk "doctor reports healthy" '( cd "$T" && bash "$T/.specforge/scripts/sf-doctor.sh" >/dev/null 2>&1 )'

[ "$FAIL" -eq 0 ] && echo "packaging.test.sh PASS" || { echo "packaging.test.sh FAIL"; exit 1; }
