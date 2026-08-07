#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="gnome-text-editor"
MODULE_SECTION="applications"
MODULE_TITLE="GNOME Text Editor"
MODULE_TITLE_RU="Текстовый редактор GNOME"
MODULE_DESCRIPTION="Installs GNOME Text Editor."
MODULE_DESCRIPTION_RU="Устанавливает текстовый редактор GNOME."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(gnome-text-editor)
MODULE_TAGS=(editor text application)

install_steps() { true; }
delete_steps() { remove_packages gnome-text-editor; }
status_steps() { package_installed gnome-text-editor && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
