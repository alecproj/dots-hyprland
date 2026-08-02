#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="firefox"
MODULE_SECTION="applications"
MODULE_TITLE="Firefox Browser"
MODULE_TITLE_RU="Браузер Firefox"
MODULE_DESCRIPTION="Installs Firefox browser from official Arch repositories."
MODULE_DESCRIPTION_RU="Устанавливает браузер Firefox из официальных репозиториев Arch Linux."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(firefox)
MODULE_TAGS=(browser web application)

install_steps() { true; }

delete_steps() { remove_packages firefox; }

status_steps() {
  package_installed firefox && return 0
  return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
