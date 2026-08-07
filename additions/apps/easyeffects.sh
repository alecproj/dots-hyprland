#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="easyeffects"
MODULE_SECTION="applications"
MODULE_TITLE="Audio effects Easy Effects"
MODULE_TITLE_RU="Аудиоэффекты Easy Effects"
MODULE_DESCRIPTION="Installs Easy Effects and Linux Studio Plugins for PipeWire audio processing."
MODULE_DESCRIPTION_RU="Устанавливает Easy Effects и Linux Studio Plugins для обработки звука PipeWire."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(easyeffects lsp-plugins)
MODULE_TAGS=(audio pipewire effects application)

install_steps() { true; }

delete_steps() { remove_packages easyeffects lsp-plugins; }

status_steps() {
    package_installed easyeffects || return 5
    package_installed lsp-plugins || return 5

    return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
