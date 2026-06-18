#!/usr/bin/env bash
# Contract tests for preserve-first SpecForge updates.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PROJECT="$TMP/project"
CALLER="$TMP/caller"
FAKE_BIN="$TMP/bin"
failures=0

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

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

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [ "$expected" != "$actual" ]; then
    fail "$label changed"
  fi
}

checksum_files() {
  shasum "$@" | awk '{ print $1 ":" $2 }'
}

mkdir -p "$PROJECT" "$CALLER"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --ide claude-code >/dev/null

cat > "$PROJECT/.specforge/ALIGN.md" <<'EOF'
# Alignment
**Status:** approved
EOF

cat > "$PROJECT/.specforge/DESIGN.md" <<'EOF'
# Design
**Status:** approved
EOF

cat > "$PROJECT/.specforge/config.yaml" <<'EOF'
project_name: preserve-me
test_command: echo test
EOF

cat > "$PROJECT/.specforge/specs/SPEC-001.md" <<'EOF'
# SPEC-001
**Status:** approved
**Branch:** feature/SPEC-001
**Build state:** done
**Traces to:** DESIGN.md

## Acceptance criteria
- [x] REQ-UPD-001: Existing specs survive updates

## Tests
- [x] tests/update.test.sh (covers REQ-UPD-001)

## Implementation
- [x] src/update.sh
EOF

awk '
  BEGIN { print "# User Project Rules\n\nUser before SpecForge." }
  { print }
  END { print "\nUser after SpecForge." }
' "$PROJECT/AGENTS.md" > "$PROJECT/AGENTS.md.tmp"
mv "$PROJECT/AGENTS.md.tmp" "$PROJECT/AGENTS.md"

owned_files=(
  "$PROJECT/.specforge/ALIGN.md"
  "$PROJECT/.specforge/DESIGN.md"
  "$PROJECT/.specforge/config.yaml"
  "$PROJECT/.specforge/specs/SPEC-001.md"
)

before_owned="$(checksum_files "${owned_files[@]}")"
before_agents="$(checksum_files "$PROJECT/AGENTS.md" "$PROJECT/CLAUDE.md")"

rm -rf "$PROJECT/.specforge/root"
rm -rf "$PROJECT/.specforge/skills/sf-quickspec"
rm -rf "$PROJECT/.specforge/skills/sf-reviewer"
rm -f "$PROJECT/.specforge/adapters/opencode/commands/sf-quickspec.md"
ln -s "../../.specforge/skills/sf-auto-review" "$PROJECT/.claude/skills/sf-auto-review"
bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --update --dry-run --ide claude-code >/dev/null

after_dry_owned="$(checksum_files "${owned_files[@]}")"
after_dry_agents="$(checksum_files "$PROJECT/AGENTS.md" "$PROJECT/CLAUDE.md")"
assert_equal "$before_owned" "$after_dry_owned" "project-owned files after dry-run"
assert_equal "$before_agents" "$after_dry_agents" "instruction files after dry-run"
if [ -e "$PROJECT/.specforge/root" ]; then
  fail "dry-run should not create .specforge/root"
fi
if [ -e "$PROJECT/.specforge/skills/sf-quickspec" ]; then
  fail "dry-run should not restore .specforge/skills/sf-quickspec"
fi
if [ ! -L "$PROJECT/.claude/skills/sf-auto-review" ]; then
  fail "dry-run should not remove stale Claude Code skill symlink"
fi

(cd "$CALLER" && bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --update --ide claude-code >/dev/null)

after_update_owned="$(checksum_files "${owned_files[@]}")"
assert_equal "$before_owned" "$after_update_owned" "project-owned files after update"
if [ ! -f "$PROJECT/.specforge/root/SPECFORGE.md" ]; then
  fail "update should restore .specforge/root/SPECFORGE.md"
fi
if [ ! -f "$PROJECT/.specforge/skills/sf-quickspec/SKILL.md" ]; then
  fail "update should restore .specforge/skills/sf-quickspec/SKILL.md"
fi
if [ ! -f "$PROJECT/.specforge/skills/sf-reviewer/SKILL.md" ]; then
  fail "update should restore .specforge/skills/sf-reviewer/SKILL.md"
fi
if [ ! -f "$PROJECT/.specforge/adapters/opencode/commands/sf-quickspec.md" ]; then
  fail "update should restore .specforge/adapters/opencode/commands/sf-quickspec.md"
fi
if [ -e "$CALLER/CLAUDE.md" ] || [ -e "$CALLER/.claude" ]; then
  fail "update adapter should not write to caller working directory"
fi

assert_contains "$PROJECT/AGENTS.md" "User before SpecForge"
assert_contains "$PROJECT/AGENTS.md" "User after SpecForge"
assert_contains "$PROJECT/AGENTS.md" "/sf-loop"
assert_contains "$PROJECT/AGENTS.md" "/sf-quickspec"
assert_contains "$PROJECT/AGENTS.md" "<!-- BEGIN SPECFORGE MANAGED BLOCK v1 -->"
assert_contains "$PROJECT/AGENTS.md" "<!-- END SPECFORGE MANAGED BLOCK v1 -->"
assert_contains "$PROJECT/CLAUDE.md" "<!-- BEGIN SPECFORGE MANAGED BLOCK v1 -->"
assert_contains "$PROJECT/CLAUDE.md" "/sf-loop"
assert_contains "$PROJECT/CLAUDE.md" "/sf-quickspec"
[ -e "$PROJECT/.claude/skills/sf-quickspec" ] || fail "update should link Claude Code sf-quickspec skill"
[ -e "$PROJECT/.claude/skills/sf-reviewer" ] || fail "update should link Claude Code internal reviewer skill"
[ ! -L "$PROJECT/.claude/skills/sf-auto-review" ] || fail "update should remove stale Claude Code sf-auto-review skill"

begin_count="$(grep -Fxc "<!-- BEGIN SPECFORGE MANAGED BLOCK v1 -->" "$PROJECT/AGENTS.md")"
end_count="$(grep -Fxc "<!-- END SPECFORGE MANAGED BLOCK v1 -->" "$PROJECT/AGENTS.md")"
assert_equal "1" "$begin_count" "AGENTS.md begin marker count"
assert_equal "1" "$end_count" "AGENTS.md end marker count"

cat >> "$PROJECT/AGENTS.md" <<'EOF'
<!-- BEGIN SPECFORGE MANAGED BLOCK v1 -->
duplicate
<!-- END SPECFORGE MANAGED BLOCK v1 -->
EOF

if bash "$ROOT/install.sh" --source "$ROOT" --dir "$PROJECT" --update --dry-run >/dev/null 2>&1; then
  fail "duplicate managed blocks should fail update"
fi

mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$1" != "clone" ]; then
  echo "unsupported fake git command: $*" >&2
  exit 1
fi

dest="${@: -1}"
mkdir -p "$(dirname "$dest")"
cp -R "$SPECFORGE_TEST_SOURCE" "$dest"
EOF
chmod +x "$FAKE_BIN/git"

rm -f "$PROJECT/.specforge/scripts/sf-update.sh"
rm -rf "$PROJECT/.specforge/root"
rm -f "$PROJECT/AGENTS.md"
PATH="$FAKE_BIN:$PATH" \
  SPECFORGE_TEST_SOURCE="$ROOT" \
  SPECFORGE_GIT_URL="file://$ROOT" \
  bash -s -- --update --dry-run --dir "$PROJECT" < "$ROOT/install.sh" >/dev/null

if [ "$failures" -gt 0 ]; then
  echo "$failures update safety assertion(s) failed." >&2
  exit 1
fi

echo "update safety contract passed"
