#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="pantum-driver"
MODULE_SECTION="applications"
MODULE_TITLE="Pantum printer driver"
MODULE_TITLE_RU="Драйвер принтеров Pantum"
MODULE_DESCRIPTION="Installs the proprietary Pantum universal Linux printer driver from AUR. Printing services are configured separately by the Printing support module."
MODULE_DESCRIPTION_RU="Устанавливает проприетарный универсальный Linux-драйвер Pantum из AUR. Службы печати настраиваются отдельно модулем поддержки печати."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_AUR_PACKAGES=(pantum-universal-driver)
MODULE_TAGS=(printing printer pantum driver aur application)

install_steps() { true; }
delete_steps() { remove_packages pantum-universal-driver; }
status_steps() { package_installed pantum-universal-driver && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
