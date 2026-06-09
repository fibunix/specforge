#!/usr/bin/env bash
# sf-registry.sh - Generate requirement registry from active and archived SPECS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/spec.sh
source "$SCRIPT_DIR/lib/spec.sh"

ROOT="$(sf_root)"
COMMAND="${1:-rebuild}"
REGISTRY_MD="$ROOT/.specforge/REGISTRY.md"
REGISTRY_JSON="$ROOT/.specforge/registry.json"

usage() {
  sf_usage "sf-registry.sh rebuild | trace | summary"
}

registry_files() {
  sf_spec_files "$ROOT"
  if [ -d "$ROOT/.specforge/iterations" ]; then
    find "$ROOT/.specforge/iterations" -path '*/specs/SPEC-*.md' -type f | sort
  fi
}

emit_entries() {
  local file="$1"
  local spec scope source_path default_iteration

  spec="$(basename "$file" .md)"
  source_path="$(sf_relpath "$ROOT" "$file")"
  scope="active"
  default_iteration="$(sf_active_iteration "$ROOT")"

  case "$file" in
    "$ROOT"/.specforge/iterations/*/specs/SPEC-*.md)
      scope="archived"
      default_iteration="${file#"$ROOT/.specforge/iterations/"}"
      default_iteration="${default_iteration%%/*}"
      ;;
  esac

  awk -v spec="$spec" -v scope="$scope" -v source_path="$source_path" -v default_iteration="$default_iteration" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }
    function first_req(s) {
      if (match(s, /REQ-[A-Z0-9][A-Z0-9-]*-[0-9]+/)) {
        return substr(s, RSTART, RLENGTH)
      }
      return ""
    }
    function line_covers(line, req,    rest, n, parts, i) {
      if (line !~ /\(covers /) return 0
      rest=line
      sub(/^.*\(covers[[:space:]]*/, "", rest)
      sub(/\).*$/, "", rest)
      gsub(/,/, " ", rest)
      n=split(rest, parts, /[[:space:]]+/)
      for (i=1; i<=n; i++) if (parts[i] == req) return 1
      return 0
    }
    function count_tests(req,    i, done, total) {
      done=0
      total=0
      for (i=1; i<=test_count; i++) {
        if (line_covers(test_line[i], req)) {
          total++
          if (test_checked[i]) done++
        }
      }
      return done "/" total
    }
    function add_supersedes(new_req, old_req) {
      if (new_req == "" || old_req == "") return
      if (supersedes[new_req] == "") supersedes[new_req]=old_req
      else supersedes[new_req]=supersedes[new_req] "," old_req
    }
    /^\*\*Iteration:\*\*/ {
      iteration=$0
      sub(/^\*\*Iteration:\*\*[[:space:]]*/, "", iteration)
      next
    }
    /^\*\*State:\*\*/ {
      spec_state=$0
      sub(/^\*\*State:\*\*[[:space:]]*/, "", spec_state)
      next
    }
    /^\*\*Build state:\*\*/ {
      # Legacy field; used only when **State:** is absent.
      build_state=$0
      sub(/^\*\*Build state:\*\*[[:space:]]*/, "", build_state)
      next
    }
    /^## Acceptance criteria$/ { section="ac"; next }
    /^## Tests$/ { section="tests"; next }
    /^## Supersedes$/ { section="supersedes"; next }
    /^## / { section=""; next }
    section == "tests" && /^- \[[ x]\]/ {
      test_count++
      test_line[test_count]=$0
      test_checked[test_count]=($0 ~ /^- \[x\]/)
      next
    }
    section == "supersedes" && /^- / {
      line=$0
      sub(/^-+[[:space:]]*/, "", line)
      if (line ~ /->/) {
        split(line, parts, /->[[:space:]]*/)
        old_req=first_req(parts[1])
        new_req=first_req(parts[2])
        add_supersedes(new_req, old_req)
      } else if (line ~ /supersedes/) {
        split(line, parts, /supersedes/)
        new_req=first_req(parts[1])
        old_req=first_req(parts[2])
        add_supersedes(new_req, old_req)
      }
      next
    }
    section == "ac" && /^- \[[ x]\]/ {
      line=$0
      checked=(line ~ /^- \[x\]/)
      sub(/^- \[[ x]\][[:space:]]*/, "", line)
      id=line
      sub(/:.*/, "", id)
      text=line
      sub(/^[^:]+:[[:space:]]*/, "", text)
      if (text ~ /supersedes[[:space:]]+REQ-/) {
        rest=text
        sub(/^.*supersedes[[:space:]]*/, "", rest)
        add_supersedes(id, first_req(rest))
      }
      ac_count++
      ac_id[ac_count]=id
      ac_text[ac_count]=trim(text)
      ac_checked[ac_count]=checked
      next
    }
    END {
      if (iteration == "") iteration=default_iteration
      if (spec_state == "") spec_state=build_state
      for (i=1; i<=ac_count; i++) {
        if (ac_checked[i] || spec_state == "done") status="implemented"
        else if (scope == "active") status="active"
        else status="archived"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", ac_id[i], spec, status, count_tests(ac_id[i]), iteration, scope, source_path, supersedes[ac_id[i]], ac_text[i]
      }
    }
  ' "$file"
}

build_tsv() {
  local out="$1"
  local files=()
  local file

  while IFS= read -r file; do
    files+=("$file")
  done < <(registry_files)

  : > "$out"
  for file in ${files[@]+"${files[@]}"}; do
    emit_entries "$file" >> "$out"
  done
}

write_registry() {
  local tsv="$1"
  local generated
  generated="$(date +%Y-%m-%d)"

  awk -F '\t' -v generated="$generated" '
    {
      old_count=split($8, old_ids, /,/)
      for (i=1; i<=old_count; i++) if (old_ids[i] != "") superseded[old_ids[i]]=1
      row_count++
      req[row_count]=$1
      spec[row_count]=$2
      status[row_count]=$3
      tests[row_count]=$4
      iteration[row_count]=$5
      scope[row_count]=$6
      source[row_count]=$7
      supersedes[row_count]=$8
      text[row_count]=$9
    }
    END {
      for (i=1; i<=row_count; i++) {
        final_status=status[i]
        if (req[i] in superseded) final_status="superseded"
        count[final_status]++
      }

      print "# SpecForge Requirement Registry"
      print ""
      print "**Generated:** " generated
      print ""
      print "## Summary"
      print ""
      print "- Active: " count["active"]+0
      print "- Implemented: " count["implemented"]+0
      print "- Superseded: " count["superseded"]+0
      print ""
      print "## Requirements"
      print ""
      print "| Requirement | Status | Iteration | Spec | Tests | Source | Supersedes | Text |"
      print "|-------------|--------|-----------|------|-------|--------|------------|------|"
      for (i=1; i<=row_count; i++) {
        final_status=status[i]
        if (req[i] in superseded) final_status="superseded"
        supersedes_text=supersedes[i]
        if (supersedes_text == "") supersedes_text="-"
        printf "| `%s` | %s | `%s` | `%s` | %s | %s | %s | %s |\n", req[i], final_status, iteration[i], spec[i], tests[i], source[i], supersedes_text, text[i]
      }
    }
  ' "$tsv" > "$REGISTRY_MD"

  awk -F '\t' -v generated="$generated" '
    function json(s) {
      gsub(/\\/,"\\\\",s)
      gsub(/"/,"\\\"",s)
      gsub(/\t/,"\\t",s)
      return "\"" s "\""
    }
    {
      old_count=split($8, old_ids, /,/)
      for (i=1; i<=old_count; i++) if (old_ids[i] != "") superseded[old_ids[i]]=1
      row_count++
      req[row_count]=$1
      spec[row_count]=$2
      status[row_count]=$3
      tests[row_count]=$4
      iteration[row_count]=$5
      scope[row_count]=$6
      source[row_count]=$7
      supersedes[row_count]=$8
      text[row_count]=$9
    }
    END {
      print "{"
      print "  \"generated\": " json(generated) ","
      print "  \"requirements\": ["
      for (i=1; i<=row_count; i++) {
        final_status=status[i]
        if (req[i] in superseded) final_status="superseded"
        printf "    {\"id\": %s, \"status\": %s, \"iteration\": %s, \"spec\": %s, \"tests\": %s, \"source\": %s, \"source_path\": %s, \"supersedes\": [", json(req[i]), json(final_status), json(iteration[i]), json(spec[i]), json(tests[i]), json(scope[i]), json(source[i])
        n=split(supersedes[i], sup_ids, /,/)
        first=1
        for (j=1; j<=n; j++) {
          if (sup_ids[j] == "") continue
          if (!first) printf ", "
          printf "%s", json(sup_ids[j])
          first=0
        }
        printf "], \"text\": %s}", json(text[i])
        if (i < row_count) printf ","
        printf "\n"
      }
      print "  ]"
      print "}"
    }
  ' "$tsv" > "$REGISTRY_JSON"
}

trace_report() {
  local tsv="$1"

  printf "%-24s %-22s %-12s %-12s %-16s %s\n" "REQUIREMENT" "SPEC" "STATUS" "TESTS" "ITERATION" "TEXT"
  printf "%-24s %-22s %-12s %-12s %-16s %s\n" "-----------" "----" "------" "-----" "---------" "----"
  awk -F '\t' '
    {
      old_count=split($8, old_ids, /,/)
      for (i=1; i<=old_count; i++) if (old_ids[i] != "") superseded[old_ids[i]]=1
      row_count++
      req[row_count]=$1
      spec[row_count]=$2
      status[row_count]=$3
      tests[row_count]=$4
      iteration[row_count]=$5
      text[row_count]=$9
    }
    END {
      for (i=1; i<=row_count; i++) {
        final_status=status[i]
        if (req[i] in superseded) final_status="superseded"
        printf "%-24s %-22s %-12s %-12s %-16s %s\n", req[i], spec[i], final_status, tests[i], iteration[i], text[i]
      }
    }
  ' "$tsv"
}

summary_report() {
  local tsv="$1"
  awk -F '\t' '
    {
      old_count=split($8, old_ids, /,/)
      for (i=1; i<=old_count; i++) if (old_ids[i] != "") superseded[old_ids[i]]=1
      row_count++
      req[row_count]=$1
      status[row_count]=$3
    }
    END {
      for (i=1; i<=row_count; i++) {
        final_status=status[i]
        if (req[i] in superseded) final_status="superseded"
        count[final_status]++
      }
      printf "Registry: %d active, %d implemented, %d superseded\n", count["active"]+0, count["implemented"]+0, count["superseded"]+0
    }
  ' "$tsv"
}

run_with_tsv() {
  local mode="$1"
  local tmp
  tmp="$(mktemp)"
  build_tsv "$tmp"
  write_registry "$tmp"

  case "$mode" in
    rebuild)
      echo "Updated .specforge/REGISTRY.md and .specforge/registry.json"
      ;;
    trace)
      trace_report "$tmp"
      ;;
    summary)
      summary_report "$tmp"
      ;;
  esac
  rm -f "$tmp"
}

case "$COMMAND" in
  rebuild|trace|summary)
    run_with_tsv "$COMMAND"
    ;;
  *)
    usage
    ;;
esac
