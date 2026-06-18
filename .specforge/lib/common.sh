#!/usr/bin/env bash
# Shared shell helpers for SpecForge scripts.

sf_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

sf_script_dir() {
  cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

sf_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s\n' "$value"
}

sf_ok() {
  echo "ok: $1"
}

sf_warn() {
  echo "warning: $1" >&2
}

sf_fail() {
  echo "error: $1" >&2
}

sf_die() {
  sf_fail "$1"
  exit "${2:-1}"
}

sf_usage() {
  echo "usage: $1" >&2
  exit 1
}

sf_require_file() {
  local path="$1"
  local label="$2"
  [ -f "$path" ] || sf_die "$label missing at $path"
}

sf_relpath() {
  local root="$1"
  local path="$2"
  if [ "$path" = "$root" ]; then
    echo "."
  else
    echo "${path#$root/}"
  fi
}
