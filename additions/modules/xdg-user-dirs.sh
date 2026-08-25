#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="xdg-user-dirs"
MODULE_SECTION="additions"
MODULE_TITLE="Setup xdg-user-dirs"
MODULE_TITLE_RU="Настройка xdg-user-dirs"
MODULE_DESCRIPTION="Installs xdg-user-dirs and runs xdg-user-dirs-update. Existing user directory definitions are kept unless xdg-user-dirs itself decides an update is needed."
MODULE_DESCRIPTION_RU="Устанавливает xdg-user-dirs и запускает xdg-user-dirs-update. Существующие определения пользовательских каталогов сохраняются, если самому xdg-user-dirs не требуется их обновить."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(xdg-user-dirs)
MODULE_REQUIRED_COMMANDS=(xdg-user-dirs-update)
MODULE_TAGS=(xdg directories desktop)

install_steps() {
  run_logged xdg-user-dirs-update
}

delete_steps() {
  log_info "Removing xdg-user-dirs package. Existing user directories are preserved."
  remove_packages xdg-user-dirs
}

status_steps() {
  command_exists xdg-user-dirs-update && return 0
  return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
