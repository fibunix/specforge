#!/usr/bin/env bash
# Portability: bash-3.2 clean (no associative arrays) + every script parses.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
chk() { if eval "$2"; then echo "  ok: $1"; else echo "  FAIL: $1"; FAIL=1; fi; }

chk "no 'declare -A' anywhere"  '! grep -rn "declare -A" "$REPO/.specforge" "$REPO/bin" "$REPO/install.sh" 2>/dev/null'
chk "no 'mapfile/readarray'"    '! grep -rnE "\b(mapfile|readarray)\b" "$REPO/.specforge" "$REPO/bin" 2>/dev/null'

for f in "$REPO"/bin/sf "$REPO"/install.sh "$REPO"/.specforge/scripts/*.sh "$REPO"/.specforge/lib/*.sh "$REPO"/.specforge/profiles/*.sh; do
  chk "parses: ${f#$REPO/}" "bash -n '$f'"
done

# Canon completeness: the 6 roles and the entry skills exist.
for a in coordinator aligner designer test-author implementer verifier; do
  chk "agent $a present" "[ -f '$REPO/.specforge/canon/agents/$a.md' ]"
done
for s in sf sf-loop sf-align sf-design sf-build sf-status; do
  chk "skill $s present" "[ -f '$REPO/.specforge/canon/skills/$s/SKILL.md' ]"
done

[ "$FAIL" -eq 0 ] && echo "bash32.test.sh PASS" || { echo "bash32.test.sh FAIL"; exit 1; }
