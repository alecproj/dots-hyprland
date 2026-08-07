#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="telegram-desktop"
MODULE_SECTION="applications"
MODULE_TITLE="Telegram Desktop"
MODULE_TITLE_RU="Telegram Desktop"
MODULE_DESCRIPTION="Installs the Telegram Desktop client and sets up the SUPER + T keyboard shortcut to launch it."
MODULE_DESCRIPTION_RU="Устанавливает клиент Telegram Desktop и настраивает сочетание клавиш SUPER + T для его запуска."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(telegram-desktop)
MODULE_TAGS=(messenger chat communication application)

_KEYBINDS_FILE="$HOME/.config/hypr/custom/keybinds.lua"

install_steps() {
    lua_block "$_KEYBINDS_FILE" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/telegram-keybinds.lua")"
}

delete_steps() {
    remove_lua_block "$_KEYBINDS_FILE" "$MODULE_ID"
    remove_packages telegram-desktop
}

status_steps() {
    lua_block_exists "$_KEYBINDS_FILE" "$MODULE_ID" || return 5
    package_installed telegram-desktop || return 5
    return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
