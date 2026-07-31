#!/usr/bin/env bash
set -euo pipefail

install_file_sudo() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"

  if [[ ! -f "$source" ]]; then
    log_error "Source file not found: $source"
    exit 3
  fi

  if [[ -f "$target" ]] && sudo cmp -s "$source" "$target"; then
    log_info "File already up to date: $target"
    return 0
  fi

  backup_file "$MODULE_ID" "$target"
  confirm_action local "Write $target" || return 0
  log_info "Installing file $source -> $target"
  sudo install -Dm"$mode" "$source" "$target"
}

install_file_user() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"

  if [[ ! -f "$source" ]]; then
    log_error "Source file not found: $source"
    exit 3
  fi

  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    log_info "File already up to date: $target"
    return 0
  fi

  backup_file "$MODULE_ID" "$target"
  confirm_action local "Write $target" || return 0
  log_info "Installing file $source -> $target"
  install -Dm"$mode" "$source" "$target"
}
