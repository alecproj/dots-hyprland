#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="openssh"
MODULE_SECTION="applications"
MODULE_TITLE="OpenSSH tools"
MODULE_TITLE_RU="Инструменты OpenSSH"
MODULE_DESCRIPTION="Installs the OpenSSH client and server tools from the official Arch repositories. No service is enabled automatically."
MODULE_DESCRIPTION_RU="Устанавливает клиентские и серверные инструменты OpenSSH из официальных репозиториев Arch Linux. Сервисы автоматически не включаются."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(openssh)
MODULE_REQUIRED_COMMANDS=(ssh)
MODULE_TAGS=(ssh network tools)

install_steps() { true; }
delete_steps() { remove_packages openssh; }
status_steps() { package_installed openssh && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
