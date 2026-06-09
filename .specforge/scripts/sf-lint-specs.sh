#!/usr/bin/env bash
# sf-lint-specs.sh — Lightweight SPEC quality checks.
#
# This is a read-only linter. It enforces the v2 contract without creating a
# central state file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"

ROOT="$(sf_root)"
ERRORS=0
WARNINGS=0

files=()
while IFS= read -r file; do
  files+=("$file")
done < <(sf_spec_files "$ROOT")
if [ "${#files[@]}" -eq 0 ]; then
  echo "(no specs yet - run /sf-plan)"
  exit 0
fi

fail() {
  sf_fail "$1"
  ERRORS=$((ERRORS + 1))
}

warn() {
  sf_warn "$1"
  WARNINGS=$((WARNINGS + 1))
}

for f in "${files[@]}"; do
  spec="$(basename "$f")"

  # Support both new (State) and legacy (Status + Build state) field names.
  has_state=0
  has_legacy=0
  grep -q '^\*\*State:\*\*[[:space:]]' "$f" && has_state=1 || true
  grep -q '^\*\*Status:\*\*[[:space:]]' "$f" && has_legacy=1 || true

  if [ "$has_state" -eq 0 ] && [ "$has_legacy" -eq 0 ]; then
    fail "$spec missing **State:** field"
  elif [ "$has_state" -eq 0 ] && [ "$has_legacy" -eq 1 ]; then
    warn "$spec uses legacy **Status:** / **Build state:** fields; migrate to **State:** (see SPEC-FORMAT.md)"
  fi

  grep -q '^\*\*Traces to:\*\*[[:space:]]' "$f" || fail "$spec missing **Traces to:**"
  grep -q '^\*\*Iteration:\*\*[[:space:]]' "$f" || fail "$spec missing **Iteration:**"

  state="$(sf_spec_state "$f")"
  case "$state" in
    draft|approved|tests-red|done) ;;
    implemented) warn "$spec uses legacy **State:** implemented; the lifecycle is draft -> approved -> tests-red -> done (see SPEC-FORMAT.md)" ;;
    "") ;;
    *) fail "$spec has invalid **State:** $state" ;;
  esac

  awk -v file="$spec" -v state="$state" '
    function err(msg) {
      print "error: " file " " msg > "/dev/stderr"
      errors++
    }
    function id_exists(id,    i) {
      for (i in ac_ids) {
        if (i == id) return 1
      }
      return 0
    }
    function mark_covers(line, checked,    rest, n, parts, i, id) {
      if (line !~ /\(covers /) {
        err("test line missing covers list: " line)
        return
      }
      rest=line
      sub(/^.*\(covers[[:space:]]*/, "", rest)
      sub(/\).*$/, "", rest)
      gsub(/,/, " ", rest)
      n=split(rest, parts, /[[:space:]]+/)
      for (i=1; i<=n; i++) {
        id=parts[i]
        if (id == "") continue
        test_refs[id]++
        if (checked) test_refs_done[id]++
        if (!id_exists(id)) {
          err("test references unknown requirement " id)
        }
      }
    }
    /^## Acceptance criteria$/ { section="ac"; next }
    /^## Tests$/ { section="tests"; next }
    /^## Implementation$/ { section="impl"; next }
    /^## / { section=""; next }
    section == "ac" && /^- \[[ x]\]/ {
      ac_total++
      line=$0
      sub(/^- \[[ x]\][[:space:]]*/, "", line)
      id=line
      sub(/:.*/, "", id)
      if (id !~ /^REQ-[A-Z0-9][A-Z0-9-]*-[0-9]+$/) {
        err("acceptance criterion must start with stable requirement ID like REQ-AUTH-001: " line)
      }
      if (id in ac_ids) {
        err("duplicate requirement ID " id)
      }
      ac_ids[id]=1
      ac_checked[id]=($0 ~ /^- \[x\]/)
      if ($0 ~ /^- \[x\]/) ac_done++
      next
    }
    section == "tests" && /^- \[[ x]\]/ {
      test_total++
      if ($0 ~ /^- \[x\]/) test_done++
      mark_covers($0, ($0 ~ /^- \[x\]/))
      next
    }
    section == "impl" && /^- \[[ x]\]/ {
      impl_total++
      if ($0 ~ /^- \[x\]/) impl_done++
      next
    }
    END {
      if (ac_total == 0) err("has no acceptance criteria")
      if (ac_total > 8) err("has more than 8 acceptance criteria")
      for (id in ac_ids) {
        if (!(id in test_refs)) err(id " is not covered by any test line")
        if (ac_checked[id] && test_refs_done[id] < test_refs[id]) {
          err(id " is checked but not all covering tests are checked")
        }
      }
      if (impl_done > 0 && test_done < test_total) {
        err("has checked implementation while some tests remain unchecked")
      }
      if (state == "done" && (ac_done < ac_total || test_done < test_total || impl_done < impl_total)) {
        err("has State done but not all checkboxes are checked")
      }
      if (errors > 0) exit 1
    }
  ' "$f" || ERRORS=$((ERRORS + 1))
done

# ── Cross-spec duplicate requirement IDs ────────────────────────────────────
duplicate_ids="$(
  awk '
    /^## Acceptance criteria$/ { section="ac"; next }
    /^## / { section=""; next }
    section == "ac" && /^- \[[ x]\]/ {
      line=$0
      sub(/^- \[[ x]\][[:space:]]*/, "", line)
      id=line
      sub(/:.*/, "", id)
      if (id ~ /^REQ-[A-Z0-9][A-Z0-9-]*-[0-9]+$/) {
        spec_seen[FILENAME SUBSEP id]=1
      }
    }
    END {
      for (key in spec_seen) {
        split(key, parts, SUBSEP)
        id=parts[2]
        seen[id]++
      }
      for (id in seen) {
        if (seen[id] > 1) print id
      }
    }
  ' "${files[@]}"
)"

if [ -n "$duplicate_ids" ]; then
  while IFS= read -r id; do
    [ -n "$id" ] && fail "duplicate requirement ID across specs: $id"
  done <<EOF
$duplicate_ids
EOF
fi

# ── S2b: Iteration consistency ───────────────────────────────────────────────
# All active artifacts must share the same Iteration value.
active_iteration="$(sf_active_iteration "$ROOT")"
if [ -n "$active_iteration" ] && [ "$active_iteration" != "none" ]; then
  for artifact in "$ROOT/.specforge/ALIGN.md" "$ROOT/.specforge/DESIGN.md"; do
    if [ -f "$artifact" ]; then
      art_iter="$(sf_spec_field "$artifact" "Iteration")"
      if [ -n "$art_iter" ] && [ "$art_iter" != "$active_iteration" ]; then
        fail "$(basename "$artifact") Iteration ($art_iter) does not match active iteration ($active_iteration)"
      fi
    fi
  done
  for f in "${files[@]}"; do
    spec_iter="$(sf_spec_field "$f" "Iteration")"
    if [ -n "$spec_iter" ] && [ "$spec_iter" != "$active_iteration" ]; then
      fail "$(basename "$f") Iteration ($spec_iter) does not match active iteration ($active_iteration)"
    fi
  done
fi

# ── E3: Cross-spec file overlap ──────────────────────────────────────────────
# Warn when two active specs declare the same test or implementation file.
overlap_output="$(
  awk '
    /^## Tests$/ { section="tests"; next }
    /^## Implementation$/ { section="impl"; next }
    /^## / { section=""; next }
    (section == "tests" || section == "impl") && /^- \[[ x]\]/ {
      line=$0
      sub(/^- \[[ x]\][[:space:]]*/, "", line)
      # Extract file path: first token before whitespace
      split(line, parts, /[[:space:]]/)
      path=parts[1]
      if (path != "") {
        if (path in seen) {
          if (seen[path] != FILENAME) {
            print "warning: file " path " declared in both " seen[path] " and " FILENAME
          }
        } else {
          seen[path]=FILENAME
        }
      }
    }
  ' "${files[@]}"
)"

if [ -n "$overlap_output" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && { sf_warn "$line"; WARNINGS=$((WARNINGS + 1)); }
  done <<EOF
$overlap_output
EOF
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "SPEC lint failed with $ERRORS error group(s)." >&2
  exit 1
fi

if [ "$WARNINGS" -gt 0 ]; then
  echo "SPEC lint passed with $WARNINGS warning(s)."
else
  echo "SPEC lint passed."
fi
