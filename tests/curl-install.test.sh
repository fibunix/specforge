#!/usr/bin/env bash
# Curl-style install + remote upgrade: no local clone, fetch from a git "remote".
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
chk() { if eval "$2"; then echo "  ok: $1"; else echo "  FAIL: $1"; FAIL=1; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Build a local "remote" repo with the current framework on branch main.
REMOTE="$WORK/remote"; mkdir -p "$REMOTE/.specforge"; cd "$REMOTE"
git init -q; git config user.email t@t; git config user.name t; git branch -m main
cp "$REPO/install.sh" .; cp -R "$REPO/bin" .
for s in canon profiles lib scripts; do cp -R "$REPO/.specforge/$s" ".specforge/$s"; done
git add -A; git commit -q -m snapshot

# Fresh target; install by piping install.sh over stdin (BASH_SOURCE is not a file).
TGT="$WORK/target"; mkdir -p "$TGT"; cd "$TGT"
git init -q; git config user.email t@t; git config user.name t; git commit -q --allow-empty -m init
cat "$REPO/install.sh" | SPECFORGE_GIT_URL="$REMOTE" SPECFORGE_VERSION=main bash -s -- --dir "$TGT" --ide claude-code >/dev/null 2>&1

chk "curl install placed .specforge" '[ -f "$TGT/.specforge/scripts/sf-init.sh" ]'
chk "curl install placed bin/sf"     '[ -x "$TGT/bin/sf" ]'
chk "curl install projected canon"   '[ -f "$TGT/.claude/agents/verifier.md" ]'

# Remote upgrade restores a deleted framework file (no local source clone present).
rm -f "$TGT/.specforge/lib/project.sh"
( cd "$TGT" && SPECFORGE_GIT_URL="$REMOTE" SPECFORGE_VERSION=main bash bin/sf update >/dev/null 2>&1 )
chk "sf update refetched project.sh" '[ -f "$TGT/.specforge/lib/project.sh" ]'

[ "$FAIL" -eq 0 ] && echo "curl-install.test.sh PASS" || { echo "curl-install.test.sh FAIL"; exit 1; }
