#!/usr/bin/env bash
set -euo pipefail

backup_target_name() {
  local target="$1"
  target="${target#/}"
  target="${target//\//_}"
  printf '%s\n' "$target"
}

backup_file() {
  local module_id="$1"
  local target="$2"

  if [[ "${BACKUP:-true}" != "true" ]]; then
    log_info "Backup disabled for $target"
    return 0
  fi

  if [[ ! -e "$target" ]]; then
    return 0
  fi

  local stamp backup_dir backup_name
  stamp="$(date +%Y-%m-%d_%H-%M-%S_%N)"
  backup_dir="${ADDITIONS_STATE_DIR:-$HOME/.local/state/dots-hyprland-additions}/backups/$module_id/$stamp"
  backup_name="$(backup_target_name "$target")"

  confirm_action local "Back up $target" "Создать резервную копию $target" || return 1
  mkdir -p "$backup_dir"
  log_info "Backup $target -> $backup_dir/$backup_name"
  if [[ -w "$target" && -r "$target" ]]; then
    cp -a "$target" "$backup_dir/$backup_name"
  else
    sudo cp -a "$target" "$backup_dir/$backup_name"
    sudo chown "$(id -u):$(id -g)" "$backup_dir/$backup_name" 2>/dev/null || true
  fi
}

latest_backup_for() {
  local module_id="$1"
  local target="$2"
  local backup_root backup_name
  backup_root="${ADDITIONS_STATE_DIR:-$HOME/.local/state/dots-hyprland-additions}/backups/$module_id"
  backup_name="$(backup_target_name "$target")"
  find "$backup_root" -mindepth 2 -maxdepth 2 -type f -name "$backup_name" 2>/dev/null | sort | tail -n 1
}

restore_backup_or_remove() {
  local module_id="$1"
  local target="$2"
  local backup
  backup="$(latest_backup_for "$module_id" "$target")"

  if [[ -n "$backup" && -f "$backup" ]]; then
    confirm_action \
      local \
      "Restore backup for $target" \
      "Восстановить резервную копию $target" || return 0
    log_info "Restoring backup $backup -> $target"
    sudo install -Dm644 "$backup" "$target"
    return 0
  fi

  if [[ -e "$target" ]]; then
    confirm_action \
      local \
      "Remove managed file $target" \
      "Удалить управляемый файл $target" || return 0
    log_info "Removing managed file $target"
    sudo rm -f "$target"
  fi
}
