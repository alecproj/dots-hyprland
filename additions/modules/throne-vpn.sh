#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="throne-vpn"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Throne VPN"
MODULE_TITLE_RU="Настройка Throne VPN"
MODULE_DESCRIPTION="Installs Throne from AUR package throne-bin when needed and adds a managed Hyprland Lua keybind block for launching Throne. Existing Throne configuration is not changed."
MODULE_DESCRIPTION_RU="При необходимости устанавливает Throne из AUR-пакета throne-bin и добавляет управляемый Lua-блок Hyprland с привязкой клавиш для запуска Throne. Существующая конфигурация Throne не изменяется."
MODULE_VERSION="1"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_AUR_PACKAGES=(throne-bin)
MODULE_REQUIRED_COMMANDS=(throne)
MODULE_FILES=("$HOME/.config/hypr/custom/keybinds.lua")
MODULE_TAGS=(vpn proxy hyprland lua aur)

install_steps() {
  lua_block "$HOME/.config/hypr/custom/keybinds.lua" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/throne-vpn-keybinds.lua")"
  if command_exists hyprctl && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    run_logged hyprctl reload || log_warn "hyprctl reload failed"
  fi
}

delete_steps() {
  remove_lua_block "$HOME/.config/hypr/custom/keybinds.lua" "$MODULE_ID"
  remove_packages throne-bin
}

status_steps() {
  command_exists throne && lua_block_exists "$HOME/.config/hypr/custom/keybinds.lua" "$MODULE_ID" && return 0
  return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
