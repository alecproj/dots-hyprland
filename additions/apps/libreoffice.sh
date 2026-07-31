#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="libreoffice"
MODULE_SECTION="applications"
MODULE_TITLE="LibreOffice"
MODULE_DESCRIPTION="Installs LibreOffice Fresh from official Arch repositories."
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(libreoffice-fresh)

install_steps() {
  true
}

delete_steps() {
  remove_packages libreoffice-fresh
}

status_steps() {
  pacman -Q libreoffice-fresh >/dev/null 2>&1
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
