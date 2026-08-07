#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="mission-center"
MODULE_SECTION="applications"
MODULE_TITLE="Mission Center Task manager"
MODULE_TITLE_RU="Диспетчер задач Mission Center"
MODULE_DESCRIPTION="Installs the Mission Center task manager and sets up the CTRL + SHIFT + Escape keyboard shortcut to launch it."
MODULE_DESCRIPTION_RU="Устанавливает системный монитор Mission Center и настраивает сочетание клавиш CTRL + SHIFT + Escape для его запуска."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(mission-center)
MODULE_TAGS=(system-monitor performance application)

_KEYBINDS_FILE="$HOME/.config/hypr/custom/keybinds.lua"

install_steps() {
    lua_block "$_KEYBINDS_FILE" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/taskmanager-keybinds.lua")"
}

delete_steps() {
    remove_lua_block "$_KEYBINDS_FILE" "$MODULE_ID"
    remove_packages mission-center
}

status_steps() {
    lua_block_exists "$_KEYBINDS_FILE" "$MODULE_ID" || return 5
    package_installed mission-center || return 0
    return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
