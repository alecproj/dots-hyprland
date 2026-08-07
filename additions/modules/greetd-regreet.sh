#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="greetd-regreet"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Greetd Login Manager"
MODULE_TITLE_RU="Настройка логин-менеджера Greetd"
MODULE_DESCRIPTION="Installs greetd, greetd-regreet and cage. Writes /etc/greetd/config.toml and /etc/greetd/regreet.toml with backup. Disables conflicting display managers and enables greetd.service."
MODULE_DESCRIPTION_RU="Устанавливает greetd, greetd-regreet и cage. С резервным копированием записывает /etc/greetd/config.toml и /etc/greetd/regreet.toml, отключает конфликтующие дисплейные менеджеры и включает greetd.service."
MODULE_VERSION="1"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(greetd greetd-regreet cage)
MODULE_REQUIRED_COMMANDS=(systemctl)
MODULE_FILES=(/etc/greetd/config.toml /etc/greetd/regreet.toml)
MODULE_TAGS=(login display-manager greetd)

preflight_steps() {
  local action="$1"
  if [[ "$action" == "install" || "$action" == "reinstall" ]]; then
    command_exists start-hyprland || die 3 "start-hyprland not found in PATH"
  fi
}

install_steps() {
  install_file_sudo "$ROOT/additions/files/greetd/config.toml" "/etc/greetd/config.toml"
  install_file_sudo "$ROOT/additions/files/greetd/regreet.toml" "/etc/greetd/regreet.toml"
  disable_system_service_if_exists sddm
  disable_system_service_if_exists gdm
  disable_system_service_if_exists ly
  enable_system_service greetd
}

delete_steps() {
  restore_backup_or_remove "$MODULE_ID" "/etc/greetd/config.toml"
  restore_backup_or_remove "$MODULE_ID" "/etc/greetd/regreet.toml"
  disable_system_service_if_exists greetd
}

status_steps() {
  system_service_enabled greetd && return 0
  return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
