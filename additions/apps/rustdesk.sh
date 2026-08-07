#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="rustdesk"
MODULE_SECTION="applications"
MODULE_TITLE="Remote descktop RustDesk"
MODULE_TITLE_RU="Удаленный рабочий стол RustDesk"
MODULE_DESCRIPTION="Installs RustDesk from the AUR package rustdesk-bin."
MODULE_DESCRIPTION_RU="Устанавливает RustDesk из AUR-пакета rustdesk-bin."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_AUR_PACKAGES=(rustdesk-bin)
MODULE_TAGS=(remote-desktop support aur application)

install_steps() { true; }
delete_steps() { remove_packages rustdesk-bin; }
status_steps() { package_installed rustdesk-bin && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
