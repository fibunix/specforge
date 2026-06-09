#!/usr/bin/env bash
# Helpers for the small .specforge/config.yaml shape.

sf_config_top_value() {
  local cfg="$1"
  local key="$2"
  awk -v key="$key" '
    $0 ~ "^[^[:space:]#-][^:]*:" {
      split($0, parts, ":")
      if (parts[1] == key) {
        sub("^[^:]*:[[:space:]]*", "")
        print
        exit
      }
    }
  ' "$cfg" 2>/dev/null | while IFS= read -r value; do sf_trim "$value"; done
}

sf_config_project_ids() {
  local cfg="$1"
  awk '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      return value
    }
    /^[[:space:]]*projects:[[:space:]]*$/ { in_projects = 1; next }
    in_projects && $0 ~ /^[^[:space:]#-][^:]*:/ { exit }
    in_projects {
      line = $0
      if (line ~ /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/) {
        sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", line)
        print clean(line)
        next
      }
      if (line ~ /^[[:space:]]*id:[[:space:]]*/) {
        sub(/^[[:space:]]*id:[[:space:]]*/, "", line)
        print clean(line)
      }
    }
  ' "$cfg" 2>/dev/null
}

sf_config_project_value() {
  local cfg="$1"
  local project_id="$2"
  local key="$3"
  awk -v want="$project_id" -v key="$key" '
    function clean(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      return value
    }
    /^[[:space:]]*projects:[[:space:]]*$/ { in_projects = 1; next }
    in_projects && $0 ~ /^[^[:space:]#-][^:]*:/ { exit }
    in_projects {
      line = $0
      if (line ~ /^[[:space:]]*-[[:space:]]*/) {
        in_project = 0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        if (line ~ /^id:[[:space:]]*/) {
          id_value = line
          sub(/^id:[[:space:]]*/, "", id_value)
          in_project = (clean(id_value) == want)
        }
        if (in_project && line ~ ("^" key ":[[:space:]]*")) {
          sub("^[^:]*:[[:space:]]*", "", line)
          print clean(line)
          exit
        }
        next
      }
      if (line ~ /^[[:space:]]*id:[[:space:]]*/) {
        id_value = line
        sub(/^[[:space:]]*id:[[:space:]]*/, "", id_value)
        in_project = (clean(id_value) == want)
        next
      }
      if (in_project && line ~ ("^[[:space:]]*" key ":[[:space:]]*")) {
        sub("^[[:space:]]*" key ":[[:space:]]*", "", line)
        print clean(line)
        exit
      }
    }
  ' "$cfg" 2>/dev/null
}

sf_config_project_dir() {
  local root="$1"
  local path="$2"
  [ -n "$path" ] || path="."
  case "$path" in
    /*) echo "$path" ;;
    *) echo "$root/$path" ;;
  esac
}
