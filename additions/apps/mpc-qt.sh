#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="mpc-qt"
MODULE_SECTION="applications"
MODULE_TITLE="MPC-QT video player"
MODULE_TITLE_RU="Видеоплеер MPC-QT"
MODULE_DESCRIPTION="Installs the MPC-QT package from AUR."
MODULE_DESCRIPTION_RU="Устанавливает пакет видеоплеера MPC-QT из AUR."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=()
MODULE_AUR_PACKAGES=(mpc-qt)
MODULE_TAGS=(video)

install_steps() { true; }
delete_steps() { remove_packages mpc-qt; }
status_steps() { package_installed mpc-qt && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
