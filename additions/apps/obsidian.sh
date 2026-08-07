#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="obsidian"
MODULE_SECTION="applications"
MODULE_TITLE="Obsidian Notes"
MODULE_TITLE_RU="Заметки Obsidian"
MODULE_DESCRIPTION="Installs the Obsidian note-taking application and sets up the SUPER + O keyboard shortcut to launch it."
MODULE_DESCRIPTION_RU="Устанавливает приложение для ведения заметок Obsidian и настраивает сочетание клавиш SUPER + O для его запуска."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(obsidian)
MODULE_TAGS=(notes knowledge application)

_KEYBINDS_FILE="$HOME/.config/hypr/custom/keybinds.lua"

install_steps() { 
    lua_block "$_KEYBINDS_FILE" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/obsidian-keybinds.lua")"
}

delete_steps() {
    remove_lua_block "$_KEYBINDS_FILE" "$MODULE_ID"
    remove_packages obsidian
}

status_steps() {
    package_installed obsidian || return 5
    lua_block_exists "$_KEYBINDS_FILE" "$MODULE_ID" || return 5
    return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
