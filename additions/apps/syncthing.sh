#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="syncthing"
MODULE_SECTION="applications"
MODULE_TITLE="File synchronizer Syncthing"
MODULE_TITLE_RU="Синхронизатор файлов Syncthing"
MODULE_DESCRIPTION="Installs Syncthing. User or system services are not enabled automatically."
MODULE_DESCRIPTION_RU="Устанавливает Syncthing. Пользовательские и системные сервисы автоматически не включаются."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(syncthing)
MODULE_TAGS=(sync files network application)

install_steps() { true; }
delete_steps() { remove_packages syncthing; }
status_steps() { package_installed syncthing && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
