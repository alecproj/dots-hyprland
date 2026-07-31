#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="throne-vpn"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Throne VPN"
MODULE_DESCRIPTION="Installs Throne from AUR package throne-bin when needed and adds a managed Hyprland Lua keybind block for launching Throne. Existing Throne configuration is not changed."
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_AUR_PACKAGES=(throne-bin)
MODULE_FILES=("$HOME/.config/hypr/custom/keybinds.lua")

install_steps() {
  lua_block "$HOME/.config/hypr/custom/keybinds.lua" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/throne-vpn-keybinds.lua")"

  if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    log_info "Reloading Hyprland"
    hyprctl reload || log_warn "hyprctl reload failed"
  fi
}

delete_steps() {
  remove_lua_block "$HOME/.config/hypr/custom/keybinds.lua" "$MODULE_ID"
}

status_steps() {
  command -v throne >/dev/null 2>&1 || command -v throne-bin >/dev/null 2>&1
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
