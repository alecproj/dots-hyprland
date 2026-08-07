#!/usr/bin/env bash
set -euo pipefail

_git_strip_url() {
  local url="${1%/}"
  printf '%s\n' "${url%.git}"
}

# @api
# kind: function
# name: git_repo_matches
# signature: git_repo_matches DIRECTORY URL...
# summary: Check that DIRECTORY is a Git work tree whose origin matches one of the supplied URLs.
# returns: 0 when the repository and origin match, 1 otherwise.
# effects: Runs git rev-parse and git remote get-url.
# @end
git_repo_matches() {
  local directory="$1"
  shift
  local origin expected

  [[ "$#" -gt 0 ]] || die 2 "git_repo_matches requires at least one URL"
  command_exists git || return 1
  git -C "$directory" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  origin="$(git -C "$directory" remote get-url origin 2>/dev/null)" || return 1
  origin="$(_git_strip_url "$origin")"

  for expected in "$@"; do
    [[ "$origin" == "$(_git_strip_url "$expected")" ]] && return 0
  done
  return 1
}

# @api
# kind: function
# name: git_sync_repo
# signature: git_sync_repo URL DIRECTORY [ALLOWED_ORIGIN...]
# summary: Clone a missing repository or update an existing clean repository with git pull --ff-only.
# returns: 0 after clone, update, or a dirty-repository skip; exits 1 for a conflicting path, unexpected origin, or failed pull.
# effects: May prompt, clone into DIRECTORY, or fast-forward the existing repository.
# notes: Existing non-Git paths and repositories with an unexpected origin are never moved or overwritten. Dirty repositories are preserved and update is skipped.
# @end
git_sync_repo() {
  local url="$1"
  local directory="$2"
  shift 2
  local -a allowed_origins=("$url" "$@")

  require_command git

  if [[ ! -e "$directory" && ! -L "$directory" ]]; then
    ensure_directory_user "$(dirname -- "$directory")"
    run_confirmed local \
      "Clone Git repository into $directory" \
      "Клонировать Git-репозиторий в $directory" \
      -- git clone -- "$url" "$directory"
    return
  fi

  git -C "$directory" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
    die 1 "Path exists and is not a Git repository: $directory"

  git_repo_matches "$directory" "${allowed_origins[@]}" || \
    die 1 "Git repository has an unexpected origin: $directory"

  if [[ -n "$(git -C "$directory" status --porcelain)" ]]; then
    log_warn "Git repository has local changes; update skipped: $directory"
    return 0
  fi

  run_confirmed local \
    "Update Git repository in $directory" \
    "Обновить Git-репозиторий в $directory" \
    -- git -C "$directory" pull --ff-only
}
