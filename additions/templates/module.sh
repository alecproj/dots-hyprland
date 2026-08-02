#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="example-module"
MODULE_SECTION="additions"
MODULE_TITLE="Example module"
MODULE_TITLE_RU="Пример модуля"
MODULE_DESCRIPTION="Describe exactly what is installed, changed, preserved and removed."
MODULE_DESCRIPTION_RU="Точно опишите установку, изменения, сохраняемые данные и удаление."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=()
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=()
MODULE_FILES=()
MODULE_TAGS=(example)

preflight_steps() {
  local action="$1"
  log_debug "Preflight for $action"
}

install_steps() {
  true
}

delete_steps() {
  true
}

status_steps() {
  # Return 0 when installed/configured, 5 when absent, 1 on check error.
  return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
