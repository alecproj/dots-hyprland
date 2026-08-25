#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="vlc"
MODULE_SECTION="applications"
MODULE_TITLE="VLC video player"
MODULE_TITLE_RU="Видеоплеер VLC"
MODULE_DESCRIPTION="Installs vlc and vlc-plugins-extra packages."
MODULE_DESCRIPTION_RU="Устанавливает пакеты vlc and vlc-plugins-extra."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=()
MODULE_AUR_PACKAGES=(vlc vlc-plugins-extra)
MODULE_TAGS=(video)

install_steps() { true; }
delete_steps() { remove_packages vlc vlc-plugins-extra; }

status_steps() {
    package_installed vlc || return 5
    package_installed vlc-plugins-extra || return 5
    return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
