#!/usr/bin/env bash
set -euo pipefail

HYPRLAND_EXECS="$HOME/.config/hypr/custom/execs.lua"
HYPRLAND_KEYBINDS="$HOME/.config/hypr/custom/keybinds.lua"
THRONE_AUTOSTART="$HOME/.local/bin/throne-autostart"

MODULE_ID="throne-vpn"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Throne VPN"
MODULE_TITLE_RU="Настройка Throne VPN"
MODULE_DESCRIPTION="Installs Throne from AUR, adds the managed Hyprland launch keybind installs the throne-autostart helper in ~/.local/bin and adds throne-autostart to startup. Existing Throne application configuration is not changed."
MODULE_DESCRIPTION_RU="Устанавливает Throne из AUR, добавляет сочетание клавиш запуска Hyprland, устанавливает helper throne-autostart в ~/.local/bin и добавляет throne-autostart в autostart. Существующая конфигурация приложения Throne не изменяется."
MODULE_VERSION="2"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_AUR_PACKAGES=(throne-bin)
MODULE_REQUIRED_COMMANDS=(throne)
MODULE_FILES=(
  "$HYPRLAND_EXECS"
  "$HYPRLAND_KEYBINDS"
  "$THRONE_AUTOSTART"
)
MODULE_TAGS=(vpn proxy hyprland autostart)

_hyprctl_vpn_reload() {
  if command_exists hyprctl && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    run_logged hyprctl reload || log_warn "hyprctl reload failed"
  fi
}

install_steps() {
  lua_block "$HYPRLAND_EXECS" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/throne-autostart.lua")"
  lua_block "$HYPRLAND_KEYBINDS" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/throne-vpn-keybinds.lua")"
  install_file_user "$ROOT/additions/files/bin/throne-autostart" "$THRONE_AUTOSTART" 0755
  _hyprctl_vpn_reload
}

delete_steps() {
  remove_lua_block "$HYPRLAND_EXECS" "$MODULE_ID"
  remove_lua_block "$HYPRLAND_KEYBINDS" "$MODULE_ID"
  remove_managed_path "$THRONE_AUTOSTART"
  remove_packages throne-bin
  _hyprctl_vpn_reload
}

status_steps() {
  command_exists throne || return 5
  [[ -x "$THRONE_AUTOSTART" ]] || return 5
  lua_block_exists "$HYPRLAND_KEYBINDS" "$MODULE_ID" || return 5
  lua_block_exists "$HYPRLAND_EXECS" "$MODULE_ID" || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
