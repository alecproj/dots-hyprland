#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="dolphin-additions"
MODULE_SECTION="applications"
MODULE_TITLE="Dolphin file manager add-ons"
MODULE_TITLE_RU="Дополнения файлового менеджера Dolphin"
MODULE_DESCRIPTION="Installs the Dolphin file manager add-ons."
MODULE_DESCRIPTION_RU="Устанавливает дополнения файлового менеджера Dolphin."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(
  ark
  dolphin
  dolphin-plugins
  filelight
  gwenview
  kdeconnect
  kdialog
  kio-admin
  kio-extras
  konsole
  partitionmanager
  signon-kwallet-extension
)
MODULE_TAGS=(dolphin kde application)

install_steps() { true; }

delete_steps() {
    remove_packages ark dolphin dolphin-plugins filelight \
      gwenview kdeconnect kdialog kio-admin kio-extras \
      konsole partitionmanager signon-kwallet-extension
}

status_steps() { package_installed filelight && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
