#!/usr/bin/env bash
set -euo pipefail

_backup_legacy_target_name() {
  local target="$1"
  target="${target#/}"
  target="${target//\//_}"
  printf '%s\n' "$target"
}

_backup_target_key() {
  local target="$1"
  local hash base
  read -r hash _ < <(printf '%s' "$target" | sha256sum)
  base="$(basename -- "$target")"
  base="${base//[^a-zA-Z0-9._-]/_}"
  printf '%s--%s\n' "${hash:0:16}" "${base:-root}"
}

_backup_path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

_backup_use_sudo() {
  local target="$1"
  [[ "$target" != "$HOME" && "$target" != "$HOME"/* ]]
}

_backup_copy_to_store() {
  local target="$1"
  local destination="$2"
  if _backup_use_sudo "$target"; then
    sudo cp -a -- "$target" "$destination"
  else
    cp -a -- "$target" "$destination"
  fi
}

_backup_restore_copy() {
  local backup="$1"
  local target="$2"
  if _backup_use_sudo "$target"; then
    sudo rm -rf -- "$target"
    sudo mkdir -p -- "$(dirname -- "$target")"
    sudo cp -a -- "$backup" "$target"
  else
    rm -rf -- "$target"
    mkdir -p -- "$(dirname -- "$target")"
    cp -a -- "$backup" "$target"
  fi
}

_backup_remove_target() {
  local target="$1"
  if _backup_use_sudo "$target"; then
    sudo rm -rf -- "$target"
  else
    rm -rf -- "$target"
  fi
}

# @api
# kind: function
# name: backup_path
# signature: backup_path MODULE_ID TARGET
# summary: Back up an existing file, directory or symlink when backups are enabled.
# returns: 0
# effects: Creates a collision-resistant backup under the additions state directory.
# notes: Existing legacy backup names remain readable, but all new names include a target-path hash.
# @end
backup_path() {
  local module_id="$1"
  local target="$2"

  if [[ "${BACKUP:-true}" != "true" ]]; then
    log_info "Backup disabled for $target"
    return 0
  fi
  _backup_path_exists "$target" || return 0

  local stamp backup_dir backup_name
  stamp="$(date +%Y-%m-%d_%H-%M-%S_%N)"
  backup_dir="${ADDITIONS_STATE_DIR:-$HOME/.local/state/dots-hyprland-additions}/backups/$module_id/$stamp"
  backup_name="$(_backup_target_key "$target")"

  confirm_action local "Back up $target" "Создать резервную копию $target" || return 0
  mkdir -p -- "$backup_dir"
  log_info "Backup $target -> $backup_dir/$backup_name"
  _backup_copy_to_store "$target" "$backup_dir/$backup_name"
}

# @api
# kind: function
# name: backup_file
# signature: backup_file MODULE_ID TARGET
# summary: Compatibility alias for backup_path.
# returns: The backup_path return code.
# effects: Same as backup_path.
# @end
backup_file() {
  backup_path "$@"
}

# @api
# kind: function
# name: latest_backup_for
# signature: latest_backup_for MODULE_ID TARGET
# summary: Print the newest backup path for TARGET.
# returns: 0; prints nothing when no backup exists.
# effects: Reads the backup directory.
# @end
latest_backup_for() {
  local module_id="$1"
  local target="$2"
  local backup_root current_name legacy_name
  backup_root="${ADDITIONS_STATE_DIR:-$HOME/.local/state/dots-hyprland-additions}/backups/$module_id"
  current_name="$(_backup_target_key "$target")"
  legacy_name="$(_backup_legacy_target_name "$target")"
  [[ -d "$backup_root" ]] || return 0
  find "$backup_root" -mindepth 2 -maxdepth 2 \( -type f -o -type d -o -type l \) \
    \( -name "$current_name" -o -name "$legacy_name" \) 2>/dev/null | sort | tail -n 1 || true
}

# @api
# kind: function
# name: backup_exists
# signature: backup_exists MODULE_ID TARGET
# summary: Test whether at least one backup exists for TARGET.
# returns: 0 when a backup exists, 1 otherwise.
# effects: Reads the backup directory.
# @end
backup_exists() {
  local backup
  backup="$(latest_backup_for "$1" "$2")"
  [[ -n "$backup" && ( -e "$backup" || -L "$backup" ) ]]
}

# @api
# kind: function
# name: restore_backup_or_remove
# signature: restore_backup_or_remove MODULE_ID TARGET
# summary: Restore the latest backup, or remove TARGET only when the module recorded that it created the path.
# returns: 0 on success or safe no-op.
# effects: May restore or delete a path after confirmation and updates resource ownership state.
# notes: An untracked path without a backup is never deleted.
# @end
restore_backup_or_remove() {
  local module_id="$1"
  local target="$2"
  local backup
  backup="$(latest_backup_for "$module_id" "$target")"

  if [[ -n "$backup" && ( -e "$backup" || -L "$backup" ) ]]; then
    confirm_action \
      local \
      "Restore backup for $target" \
      "Восстановить резервную копию $target" || return 1
    log_info "Restoring backup $backup -> $target"
    _backup_restore_copy "$backup" "$target"
    state_forget_resource created_paths "$target"
    state_forget_resource managed_paths "$target"
    return 0
  fi

  if _backup_path_exists "$target" && state_has_resource created_paths "$target"; then
    confirm_action \
      local \
      "Remove managed path $target" \
      "Удалить управляемый путь $target" || return 1
    log_info "Removing managed path $target"
    _backup_remove_target "$target"
    state_forget_resource created_paths "$target"
    state_forget_resource managed_paths "$target"
    return 0
  fi

  if _backup_path_exists "$target"; then
    log_warn "Not removing untracked path without backup: $target"
  fi
}
