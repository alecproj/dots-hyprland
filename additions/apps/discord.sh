#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="discord"
MODULE_SECTION="applications"
MODULE_TITLE="Discord"
MODULE_TITLE_RU="Discord"
MODULE_DESCRIPTION="Installs the Discord desktop client."
MODULE_DESCRIPTION_RU="Устанавливает настольный клиент Discord."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(discord)
MODULE_TAGS=(chat communication application)

install_steps() { true; }
delete_steps() { remove_packages discord; }
status_steps() { package_installed discord && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
