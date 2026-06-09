#!/usr/bin/env bash
# Git helpers shared by SpecForge scripts.

sf_branch_for_spec() {
  local spec="$1"
  spec="${spec##*/}"
  spec="${spec%.md}"
  if [[ "$spec" =~ ^(SPEC-[0-9]+)-.+$ ]]; then
    spec="${BASH_REMATCH[1]}"
  elif [[ "$spec" =~ ^(SPEC-[A-Z0-9][A-Z0-9-]*-[0-9]+)-.+$ ]]; then
    spec="${BASH_REMATCH[1]}"
  fi
  echo "feature/$spec"
}

sf_default_worktree_for_spec() {
  local root="$1"
  local spec="$2"
  spec="${spec##*/}"
  spec="${spec%.md}"
  if [[ "$spec" =~ ^(SPEC-[0-9]+)-.+$ ]]; then
    spec="${BASH_REMATCH[1]}"
  elif [[ "$spec" =~ ^(SPEC-[A-Z0-9][A-Z0-9-]*-[0-9]+)-.+$ ]]; then
    spec="${BASH_REMATCH[1]}"
  fi
  echo "$root/.worktrees/$spec"
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

sf_worktree_for_spec() {
  local root="$1"
  local spec="$2"
  local branch
  branch="$(sf_branch_for_spec "$spec")"
  sf_worktree_for_branch "$root" "$branch" 2>/dev/null || sf_default_worktree_for_spec "$root" "$spec"
}

sf_review_base() {
  local root="$1"
  local branch="$2"
  local base_branch

  base_branch="$(sf_base_branch "$root" "$branch" 2>/dev/null || true)"
  if [ -n "$base_branch" ]; then
    git -C "$root" merge-base "$base_branch" "$branch" 2>/dev/null && return 0
  fi

  git -C "$root" merge-base HEAD "$branch" 2>/dev/null || git -C "$root" rev-parse HEAD
}
