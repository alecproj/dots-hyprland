#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="fs-diagnostics"
MODULE_SECTION="applications"
MODULE_TITLE="Filesystem diagnostics"
MODULE_TITLE_RU="Диагностика файловых систем"
MODULE_DESCRIPTION="Installs tools for diagnosing and restoring file systems on flash drives and SD cards. Packages include: f3 - checking the actual capacity of a drive; ddsecue - dumping a drive; testdisk - recovering partitions and lost data."
MODULE_DESCRIPTION_RU="Устанавливает инструменты для диагностики и восстановления файловых систем флешек и SD карт. Пакеты включают: f3 - проверка реальной ёмкости носителя; ddsecue - дамп носителя; testdisk - восстановление разделов и потерянных данных."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(f3 testdisk ddrescue)
MODULE_TAGS=(files flash usb sd)

install_steps() { true; }
delete_steps() { remove_packages f3 testdisk ddsecue; }

status_steps() {
    package_installed f3 || return 5
    package_installed testdisk || return 5
    package_installed ddsecue || return 5
    return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
