#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="keepassxc"
MODULE_SECTION="applications"
MODULE_TITLE="Password manager KeePassXC"
MODULE_TITLE_RU="Менеджер паролей KeePassXC"
MODULE_DESCRIPTION="Installs the KeePassXC password manager."
MODULE_DESCRIPTION_RU="Устанавливает менеджер паролей KeePassXC."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(keepassxc)
MODULE_TAGS=(passwords security application)

install_steps() { true; }
delete_steps() { remove_packages keepassxc; }
status_steps() { package_installed keepassxc && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
