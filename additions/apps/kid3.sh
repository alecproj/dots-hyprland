#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="kid3"
MODULE_SECTION="applications"
MODULE_TITLE="Audio tag editor Kid3"
MODULE_TITLE_RU="Редактор аудио-тегов Kid3"
MODULE_DESCRIPTION="Installs the kid3 ID3 editor."
MODULE_DESCRIPTION_RU="Устанавливает kid3 ID3 редактор."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(kid3)
MODULE_TAGS=(music)

install_steps() { true; }
delete_steps() { remove_packages kid3; }
status_steps() { package_installed kid3 && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
