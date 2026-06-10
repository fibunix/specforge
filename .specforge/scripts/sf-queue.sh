#!/usr/bin/env bash
# sf-queue.sh — Append one requirement bullet to .specforge/NEXT.md.
#
# Usage:
#   sf-queue.sh "requirement text"
#
# Creates NEXT.md from the template if it does not exist.
# NEXT.md carries no Iteration field; it is the brief for the next iteration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ROOT="$(sf_root)"
TEXT="${1:-}"
[ -n "$TEXT" ] || sf_usage "sf-queue.sh \"requirement text\""

NEXT_MD="$ROOT/.specforge/NEXT.md"
TEMPLATE="$ROOT/.specforge/templates/NEXT.md"
TODAY="$(date +%Y-%m-%d)"

if [ ! -f "$NEXT_MD" ]; then
  if [ -f "$TEMPLATE" ]; then
    sed "s/YYYY-MM-DD/$TODAY/" "$TEMPLATE" > "$NEXT_MD"
    # Replace the placeholder bullet with the actual text
    sed -i.bak "s|^- <one bullet per queued requirement.*>|- $TEXT|" "$NEXT_MD"
    rm -f "$NEXT_MD.bak"
  else
    cat > "$NEXT_MD" <<EOF
# Next iteration — queued requirements

**Queued:** $TODAY

## Requirements

- $TEXT
EOF
  fi
  echo "Created $NEXT_MD"
  echo "  - $TEXT"
else
  # Append after the last bullet in the ## Requirements section.
  # Strategy: append a new bullet at the end of the Requirements section,
  # or at the end of the file if no such section exists.
  if grep -q '^## Requirements' "$NEXT_MD"; then
    # Insert bullet after the last existing bullet under Requirements,
    # or directly after the ## Requirements header if there are none.
    awk -v text="- $TEXT" '
      /^## Requirements$/ { in_req=1; print; next }
      in_req && /^## / { in_req=0; print text; print ""; print; next }
      { print }
      END { if (in_req) print text }
    ' "$NEXT_MD" > "$NEXT_MD.tmp"
    mv "$NEXT_MD.tmp" "$NEXT_MD"
  else
    printf '\n## Requirements\n\n- %s\n' "$TEXT" >> "$NEXT_MD"
  fi
  echo "Queued in $NEXT_MD:"
  echo "  - $TEXT"
fi
