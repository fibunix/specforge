#!/usr/bin/env bash
# Contract tests for generated active/archive requirement registry.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PROJECT="$TMP/project"
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

mkdir -p "$PROJECT/.specforge/specs" "$PROJECT/.specforge/iterations/ITER-old/specs"

cat > "$PROJECT/.specforge/specs/SPEC-new.md" <<'EOF'
# SPEC-new

**Status:** approved
**Traces to:** .specforge/ALIGN.md § "current" | .specforge/DESIGN.md § "current"
**Iteration:** ITER-current
**Build state:** not-started
**Branch:** feature/SPEC-new

## Acceptance criteria

- [ ] REQ-NEW-001: New behavior replaces the old behavior
- [ ] REQ-ACT-001: Active requirements remain visible

## Tests

- [ ] tests/new.test.sh (covers REQ-NEW-001)
- [ ] tests/active.test.sh (covers REQ-ACT-001)

## Implementation

- [ ] src/new.sh

## Supersedes

- REQ-OLD-001 -> REQ-NEW-001
EOF

cat > "$PROJECT/.specforge/iterations/ITER-old/specs/SPEC-old.md" <<'EOF'
# SPEC-old

**Status:** approved
**Traces to:** .specforge/iterations/ITER-old/ALIGN.md § "old" | .specforge/iterations/ITER-old/DESIGN.md § "old"
**Iteration:** ITER-old
**Build state:** done
**Branch:** feature/SPEC-old

## Acceptance criteria

- [x] REQ-OLD-001: Old behavior was implemented

## Tests

- [x] tests/old.test.sh (covers REQ-OLD-001)

## Implementation

- [x] src/old.sh
EOF

(cd "$PROJECT" && bash "$ROOT/.specforge/scripts/sf-registry.sh" rebuild >/dev/null)

assert_contains "$PROJECT/.specforge/REGISTRY.md" 'REQ-OLD-001.*superseded'
assert_contains "$PROJECT/.specforge/REGISTRY.md" 'REQ-NEW-001.*active'
assert_contains "$PROJECT/.specforge/REGISTRY.md" 'REQ-ACT-001.*active'
assert_contains "$PROJECT/.specforge/registry.json" '"id": "REQ-OLD-001".*"status": "superseded"'
assert_contains "$PROJECT/.specforge/registry.json" '"id": "REQ-NEW-001".*"supersedes": \["REQ-OLD-001"\]'

trace_output="$(cd "$PROJECT" && bash "$ROOT/.specforge/scripts/sf-trace.sh")"
if ! grep -Eq 'REQ-OLD-001[[:space:]]+SPEC-old[[:space:]]+superseded' <<<"$trace_output"; then
  fail "trace should include archived superseded requirements"
fi
if ! grep -Eq 'REQ-NEW-001[[:space:]]+SPEC-new[[:space:]]+active' <<<"$trace_output"; then
  fail "trace should include active requirements"
fi

(cd "$PROJECT" && bash "$ROOT/.specforge/scripts/sf-lint-specs.sh" >/dev/null)

sed '/^\*\*Iteration:\*\*/d' "$PROJECT/.specforge/specs/SPEC-new.md" > "$PROJECT/.specforge/specs/SPEC-new.tmp"
mv "$PROJECT/.specforge/specs/SPEC-new.tmp" "$PROJECT/.specforge/specs/SPEC-new.md"
if (cd "$PROJECT" && bash "$ROOT/.specforge/scripts/sf-lint-specs.sh" >/dev/null 2>&1); then
  fail "spec lint should require active SPEC iteration metadata"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures registry-state assertion(s) failed." >&2
  exit 1
fi

echo "registry-state contract passed"
