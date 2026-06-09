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

for f in "${files[@]}"; do
  spec="$(basename "$f")"

  grep -q '^\*\*Status:\*\*[[:space:]]' "$f" || fail "$spec missing **Status:**"
  grep -q '^\*\*Branch:\*\*[[:space:]]' "$f" || fail "$spec missing **Branch:**"
  grep -q '^\*\*Build state:\*\*[[:space:]]' "$f" || fail "$spec missing **Build state:**"
  grep -q '^\*\*Traces to:\*\*[[:space:]]' "$f" || fail "$spec missing **Traces to:**"
  grep -q '^\*\*Iteration:\*\*[[:space:]]' "$f" || fail "$spec missing **Iteration:**"

  status="$(sf_spec_field "$f" "Status")"
  case "$status" in
    draft|approved) ;;
    "") ;;
    *) fail "$spec has invalid **Status:** $status" ;;
  esac

  build_state="$(sf_spec_field "$f" "Build state")"
  case "$build_state" in
    not-started|tests-red|implemented|done) ;;
    "") ;;
    *) fail "$spec has invalid **Build state:** $build_state" ;;
  esac

  awk -v file="$spec" -v build_state="$build_state" '
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
      if (build_state == "done" && (ac_done < ac_total || test_done < test_total || impl_done < impl_total)) {
        err("has Build state done but not all checkboxes are checked")
      }
      if (errors > 0) exit 1
    }
  ' "$f" || ERRORS=$((ERRORS + 1))
done

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

if [ "$ERRORS" -gt 0 ]; then
  echo "SPEC lint failed with $ERRORS error group(s)." >&2
  exit 1
fi

echo "SPEC lint passed."
