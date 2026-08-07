#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="localsend"
MODULE_SECTION="applications"
MODULE_TITLE="Data transfer LocalSend"
MODULE_TITLE_RU="Передача данных LocalSend"
MODULE_DESCRIPTION="Installs LocalSend from the AUR package localsend-bin."
MODULE_DESCRIPTION_RU="Устанавливает LocalSend из AUR-пакета localsend-bin."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_AUR_PACKAGES=(localsend-bin)
MODULE_TAGS=(files transfer network aur application)

install_steps() { true; }
delete_steps() { remove_packages localsend-bin; }
status_steps() { package_installed localsend-bin && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
