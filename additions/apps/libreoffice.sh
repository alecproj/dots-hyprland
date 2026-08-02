#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="libreoffice"
MODULE_SECTION="applications"
MODULE_TITLE="LibreOffice"
MODULE_TITLE_RU="LibreOffice"
MODULE_DESCRIPTION="Installs LibreOffice Fresh from official Arch repositories."
MODULE_DESCRIPTION_RU="Устанавливает LibreOffice Fresh из официальных репозиториев Arch Linux."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(libreoffice-fresh)
MODULE_TAGS=(office documents application)

install_steps() { true; }

delete_steps() { remove_packages libreoffice-fresh; }

status_steps() {
  package_installed libreoffice-fresh && return 0
  return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
