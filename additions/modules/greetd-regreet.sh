#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="greetd-regreet"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Greetd Login Manager"
MODULE_DESCRIPTION="Installs greetd, greetd-regreet and cage. Writes /etc/greetd/config.toml and /etc/greetd/regreet.toml with backup. Disables conflicting display managers and enables greetd.service."
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(greetd greetd-regreet cage)
MODULE_FILES=(/etc/greetd/config.toml /etc/greetd/regreet.toml)

install_steps() {
  if ! command -v start-hyprland >/dev/null 2>&1; then
    log_warn "start-hyprland not found in PATH. greetd config still uses start-hyprland."
  fi

  install_file_sudo "$ROOT/additions/files/greetd/config.toml" "/etc/greetd/config.toml"
  install_file_sudo "$ROOT/additions/files/greetd/regreet.toml" "/etc/greetd/regreet.toml"

  disable_service_if_exists sddm
  disable_service_if_exists gdm
  disable_service_if_exists ly
  enable_service greetd
}

delete_steps() {
  restore_backup_or_remove "$MODULE_ID" "/etc/greetd/config.toml"
  restore_backup_or_remove "$MODULE_ID" "/etc/greetd/regreet.toml"
  disable_service_if_exists greetd
}

status_steps() {
  systemctl is-enabled greetd >/dev/null 2>&1
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
