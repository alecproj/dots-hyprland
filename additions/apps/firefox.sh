#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="firefox"
MODULE_SECTION="applications"
MODULE_TITLE="Firefox Browser"
MODULE_TITLE_RU="Браузер Firefox"
MODULE_DESCRIPTION="Installs Firefox browser from official Arch repositories."
MODULE_DESCRIPTION_RU="Устанавливает браузер Firefox из официальных репозиториев Arch Linux."
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(firefox)

install_steps() {
  true
}

delete_steps() {
  remove_packages firefox
}

status_steps() {
  pacman -Q firefox >/dev/null 2>&1
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
