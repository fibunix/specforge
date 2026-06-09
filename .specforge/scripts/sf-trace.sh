#!/usr/bin/env bash
# sf-trace.sh - Requirement trace report generated from active and archived SPEC files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$ROOT/.specforge/scripts/sf-registry.sh" ]; then
  bash "$ROOT/.specforge/scripts/sf-registry.sh" trace
else
  bash "$SCRIPT_DIR/sf-registry.sh" trace
fi
