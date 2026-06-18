#!/usr/bin/env bash
# Work-item helpers: config resolution, base-branch wiring, and state derivation.
# Depends on common.sh, git.sh, config.sh being sourced first.

# Path to the single project config (repo root).
sf_config_path() {
  echo "$1/project.yaml"
}

# If project.yaml sets base_branch, export it so sf_base_branch honours it.
sf_apply_config_base_branch() {
  local root="$1"
  local cfg base
  cfg="$(sf_config_path "$root")"
  [ -f "$cfg" ] || return 0
  base="$(sf_config_top_value "$cfg" base_branch)"
  [ -n "$base" ] && export SPECFORGE_BASE_BRANCH="$base"
  return 0
}

sf_active_dir()  { echo "$1/.specforge/work/active"; }
sf_archive_dir() { echo "$1/.specforge/work/archive"; }

# List active work-item slugs (one per line).
sf_active_slugs() {
  local root="$1" d
  for d in "$root"/.specforge/work/active/*/; do
    [ -d "$d" ] || continue
    basename "$d"
  done
}

# Derive the lifecycle state of a work item purely from git + filesystem.
# Echoes one of: planning | ready | tests-red | implementing | verified | done | unknown
sf_work_state() {
  local root="$1" slug="$2"
  local branch wt ref subject

  branch="$(sf_branch_for_slug "$slug")"

  # Archived => done.
  if ls -d "$root"/.specforge/work/archive/*-"$slug"/ >/dev/null 2>&1; then
    echo "done"; return 0
  fi

  if ! sf_branch_exists "$root" "$branch"; then
    # No branch yet: planning (SPEC not approved) — or unknown if no dir.
    if [ -d "$root/.specforge/work/active/$slug" ]; then echo "planning"; else echo "unknown"; fi
    return 0
  fi

  # Branch exists. Inspect HEAD.
  wt="$(sf_worktree_for_branch "$root" "$branch" 2>/dev/null || true)"
  ref="$branch"

  if sf_has_verified_trailer "$root" "$ref"; then
    echo "verified"; return 0
  fi

  subject="$(git -C "$root" show -s --format='%s' "$ref" 2>/dev/null || true)"
  case "$subject" in
    *"red tests"*|*"tests-red"*) echo "tests-red"; return 0 ;;
  esac

  # Branch has commits beyond the red-tests marker but no trailer yet.
  echo "implementing"
}

# Echo the worktree path if one exists for the slug, else empty.
sf_existing_worktree() {
  local root="$1" slug="$2" branch
  branch="$(sf_branch_for_slug "$slug")"
  sf_worktree_for_branch "$root" "$branch" 2>/dev/null || true
}
