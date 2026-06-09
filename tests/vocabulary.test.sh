#!/usr/bin/env bash
# Vocabulary guard: the single **State:** lifecycle must not drift back into
# legacy wording. Legacy parsing is allowed only in the sanctioned fallback
# sites; agent manuals and skills must never instruct legacy fields.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

# ── Skills and agent manuals: zero tolerance ─────────────────────────────────
# These are instructions agents follow literally; legacy vocabulary here means
# agents write legacy fields into fresh specs.
hits="$(grep -rn 'Build state\|not-started' \
  "$ROOT/.specforge/skills" "$ROOT/.specforge/agents" 2>/dev/null || true)"
if [ -n "$hits" ]; then
  fail "legacy vocabulary in skills/agents:
$hits"
fi

# Adapter agent mirrors carry the same instructions.
hits="$(grep -rn 'Build state\|not-started' \
  "$ROOT/.specforge/adapters" --include='*.toml' --include='*.md' 2>/dev/null || true)"
if [ -n "$hits" ]; then
  fail "legacy vocabulary in adapter agent definitions:
$hits"
fi

# ── Scripts: legacy parsing only in sanctioned fallback sites ─────────────────
allowlist="lib/spec.sh sf-lint-specs.sh sf-registry.sh"
while IFS= read -r line; do
  [ -n "$line" ] || continue
  file="${line%%:*}"
  rel="${file#"$ROOT/.specforge/scripts/"}"
  allowed=0
  for ok in $allowlist; do
    [ "$rel" = "$ok" ] && allowed=1
  done
  if [ "$allowed" -eq 0 ]; then
    fail "legacy 'Build state' parsing outside sanctioned sites: $line"
  fi
done <<EOF
$(grep -rn 'Build state' "$ROOT/.specforge/scripts" 2>/dev/null || true)
EOF

# ── Wave must stay bash-3.2 compatible (no associative arrays anywhere) ───────
hits="$(grep -rn 'declare -A' "$ROOT/.specforge/scripts" "$ROOT/bin" "$ROOT/install.sh" 2>/dev/null || true)"
if [ -n "$hits" ]; then
  fail "bash-4-only associative arrays found (macOS ships bash 3.2):
$hits"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures vocabulary assertion(s) failed." >&2
  exit 1
fi

echo "vocabulary contract passed"
