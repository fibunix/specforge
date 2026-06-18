#!/usr/bin/env bash
# Git helpers shared by SpecForge scripts (v2, slug-based work items).
#
# A work item is identified by a slug (e.g. "add-json-flag").
#   branch   = feature/<slug>
#   worktree = <root>/.worktrees/<slug>
#   work dir = <root>/.specforge/work/active/<slug>/  (archived to .specforge/work/archive/<date>-<slug>/)

# Validate a slug: lowercase letters, digits, hyphens. Echoes the slug or fails.
sf_validate_slug() {
  local slug="$1"
  case "$slug" in
    "" ) sf_fail "empty slug"; return 1 ;;
    *[!a-z0-9-]* ) sf_fail "invalid slug '$slug' (use lowercase letters, digits, hyphens)"; return 1 ;;
    -*|*- ) sf_fail "slug '$slug' must not start or end with a hyphen"; return 1 ;;
  esac
  printf '%s\n' "$slug"
}

sf_branch_for_slug() {
  echo "feature/$1"
}

sf_worktree_for_slug() {
  local root="$1"
  local slug="$2"
  echo "$root/.worktrees/$slug"
}

sf_current_branch() {
  local dir="$1"
  git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || true
}

sf_branch_exists() {
  local root="$1"
  local branch="$2"
  git -C "$root" show-ref --verify --quiet "refs/heads/$branch"
}

# Resolve the base branch. Order: SPECFORGE_BASE_BRANCH env, then common names,
# then origin/HEAD. Never returns the feature branch itself.
sf_base_branch() {
  local root="$1"
  local feature_branch="${2:-}"
  local branch

  if [ -n "${SPECFORGE_BASE_BRANCH:-}" ] && sf_branch_exists "$root" "$SPECFORGE_BASE_BRANCH"; then
    echo "$SPECFORGE_BASE_BRANCH"
    return 0
  fi

  for branch in main master trunk develop; do
    if [ "$branch" != "$feature_branch" ] && sf_branch_exists "$root" "$branch"; then
      echo "$branch"
      return 0
    fi
  done

  branch="$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [ -n "$branch" ] && [ "$branch" != "$feature_branch" ] && sf_branch_exists "$root" "$branch"; then
    echo "$branch"
    return 0
  fi

  return 1
}

sf_worktree_for_branch() {
  local root="$1"
  local branch="$2"
  git -C "$root" worktree list --porcelain | awk -v branch="refs/heads/$branch" '
    /^worktree / { current=$2; next }
    $0 == "branch " branch { print current; found=1; exit }
    END { if (!found) exit 1 }
  '
}

# True if HEAD of the given ref carries a "Verified-by:" git trailer.
sf_has_verified_trailer() {
  local root="$1"
  local ref="$2"
  git -C "$root" show -s --format='%(trailers:key=Verified-by,valueonly)' "$ref" 2>/dev/null | grep -q .
}
