#!/usr/bin/env bash
set -euo pipefail

_files_validate_mode() {
  [[ "$1" =~ ^[0-7]{3,4}$ ]] || die 2 "Invalid file mode: $1"
}

_files_path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

_files_compare() {
  local privilege="$1"
  local source="$2"
  local target="$3"
  [[ -f "$target" && ! -L "$target" ]] || return 1
  if [[ "$privilege" == "sudo" ]]; then
    sudo cmp -s -- "$source" "$target"
  else
    cmp -s -- "$source" "$target"
  fi
}

_files_install_generated() {
  local privilege="$1"
  local source="$2"
  local target="$3"
  local mode="$4"
  local message_en="$5"
  local message_ru="$6"
  local existed=false

  _files_validate_mode "$mode"
  [[ -f "$source" ]] || die 3 "Source file not found: $source"
  if [[ -d "$target" && ! -L "$target" ]]; then
    die 1 "Target is a directory, expected a file: $target"
  fi
  if _files_compare "$privilege" "$source" "$target"; then
    log_info "File already up to date: $target"
    return 0
  fi

  if _files_path_exists "$target"; then
    existed=true
  fi
  backup_path "$MODULE_ID" "$target" || return 1
  confirm_action local "$message_en" "$message_ru" || return 1

  log_info "Installing file $source -> $target"
  if [[ -L "$target" ]]; then
    if [[ "$privilege" == "sudo" ]]; then sudo rm -f -- "$target"; else rm -f -- "$target"; fi
  fi
  if [[ "$privilege" == "sudo" ]]; then
    sudo install -Dm"$mode" -- "$source" "$target"
  else
    install -Dm"$mode" -- "$source" "$target"
  fi
  state_record_resource managed_paths "$target"
  if [[ "$existed" == false ]]; then
    state_record_resource created_paths "$target"
  fi
}

# @api
# kind: function
# name: install_file_user
# signature: install_file_user SOURCE TARGET [MODE]
# summary: Idempotently install a user-owned file with backup and confirmation.
# returns: 0 on success or declined step; exits 3 when SOURCE is missing.
# effects: May create or replace TARGET and records it as a managed path.
# @end
install_file_user() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"
  _files_install_generated user "$source" "$target" "$mode" \
    "Write $target" "Записать $target"
}

# @api
# kind: function
# name: install_file_sudo
# signature: install_file_sudo SOURCE TARGET [MODE]
# summary: Idempotently install a privileged file with backup and confirmation.
# returns: 0 on success or declined step; exits 3 when SOURCE is missing.
# effects: Uses sudo to create or replace TARGET and records it as a managed path.
# @end
install_file_sudo() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"
  _files_install_generated sudo "$source" "$target" "$mode" \
    "Write $target" "Записать $target"
}

# @api
# kind: function
# name: write_file_user
# signature: write_file_user TARGET CONTENT [MODE]
# summary: Idempotently write generated text content to a user-owned file.
# returns: 0 on success or declined step.
# effects: May create or replace TARGET with backup and resource tracking.
# @end
write_file_user() {
  local target="$1"
  local content="$2"
  local mode="${3:-0644}"
  local tmp return_code
  tmp="$(mktemp)"
  printf '%s' "$content" >"$tmp"
  if _files_install_generated user "$tmp" "$target" "$mode" \
      "Write $target" "Записать $target"; then
    return_code=0
  else
    return_code=$?
  fi
  rm -f -- "$tmp"
  return "$return_code"
}

# @api
# kind: function
# name: write_file_sudo
# signature: write_file_sudo TARGET CONTENT [MODE]
# summary: Idempotently write generated text content to a privileged file.
# returns: 0 on success or declined step.
# effects: Uses sudo to create or replace TARGET with backup and resource tracking.
# @end
write_file_sudo() {
  local target="$1"
  local content="$2"
  local mode="${3:-0644}"
  local tmp return_code
  tmp="$(mktemp)"
  printf '%s' "$content" >"$tmp"
  if _files_install_generated sudo "$tmp" "$target" "$mode" \
      "Write $target" "Записать $target"; then
    return_code=0
  else
    return_code=$?
  fi
  rm -f -- "$tmp"
  return "$return_code"
}

_files_ensure_directory() {
  local privilege="$1"
  local target="$2"
  local mode="$3"
  _files_validate_mode "$mode"
  if [[ -d "$target" ]]; then
    return 0
  fi
  _files_path_exists "$target" && die 1 "Path exists and is not a directory: $target"
  confirm_action local "Create directory $target" "Создать каталог $target" || return 1
  if [[ "$privilege" == "sudo" ]]; then
    sudo install -d -m"$mode" -- "$target"
  else
    install -d -m"$mode" -- "$target"
  fi
  state_record_resource managed_paths "$target"
  state_record_resource created_paths "$target"
  log_info "Created directory: $target"
}

# @api
# kind: function
# name: ensure_directory_user
# signature: ensure_directory_user TARGET [MODE]
# summary: Create a user-owned directory only when it is absent.
# returns: 0 on success or declined step.
# effects: May create TARGET and records it as created by the module.
# @end
ensure_directory_user() {
  _files_ensure_directory user "$1" "${2:-0755}"
}

# @api
# kind: function
# name: ensure_directory_sudo
# signature: ensure_directory_sudo TARGET [MODE]
# summary: Create a privileged directory only when it is absent.
# returns: 0 on success or declined step.
# effects: Uses sudo and records TARGET as created by the module.
# @end
ensure_directory_sudo() {
  _files_ensure_directory sudo "$1" "${2:-0755}"
}

_files_install_symlink() {
  local privilege="$1"
  local source="$2"
  local target="$3"
  local existed=false
  if [[ -L "$target" && "$(readlink -- "$target")" == "$source" ]]; then
    log_info "Symlink already up to date: $target -> $source"
    return 0
  fi
  if _files_path_exists "$target"; then
    existed=true
  fi
  backup_path "$MODULE_ID" "$target" || return 1
  confirm_action local "Link $target -> $source" "Создать ссылку $target -> $source" || return 1
  if [[ "$privilege" == "sudo" ]]; then
    sudo rm -rf -- "$target"
    sudo mkdir -p -- "$(dirname -- "$target")"
    sudo ln -s -- "$source" "$target"
  else
    rm -rf -- "$target"
    mkdir -p -- "$(dirname -- "$target")"
    ln -s -- "$source" "$target"
  fi
  state_record_resource managed_paths "$target"
  if [[ "$existed" == false ]]; then
    state_record_resource created_paths "$target"
  fi
  log_info "Installed symlink: $target -> $source"
}

# @api
# kind: function
# name: install_symlink_user
# signature: install_symlink_user SOURCE TARGET
# summary: Idempotently install a user-owned symbolic link.
# returns: 0 on success or declined step.
# effects: May back up and replace TARGET and records ownership state.
# @end
install_symlink_user() {
  _files_install_symlink user "$1" "$2"
}

# @api
# kind: function
# name: install_symlink_sudo
# signature: install_symlink_sudo SOURCE TARGET
# summary: Idempotently install a privileged symbolic link.
# returns: 0 on success or declined step.
# effects: Uses sudo, may back up and replace TARGET, and records ownership state.
# @end
install_symlink_sudo() {
  _files_install_symlink sudo "$1" "$2"
}

# @api
# kind: function
# name: remove_managed_path
# signature: remove_managed_path TARGET
# summary: Restore a backup for TARGET or remove it only when this module created it.
# returns: 0 on success or safe no-op.
# effects: May restore or delete TARGET after confirmation.
# @end
remove_managed_path() {
  restore_backup_or_remove "$MODULE_ID" "$1"
}
