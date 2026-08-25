#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/solaar/rules.yaml"
HYPRLAND_EXECS="$HOME/.config/hypr/custom/execs.lua"

MODULE_ID="solaar"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Solaar"
MODULE_TITLE_RU="Настройка Solaar"
MODULE_DESCRIPTION="Installs a Linux manager for many Logitech keyboards, mice, and other devices that connect wirelessly. Adds the manager to startup. Binds the bottom button of the MX Master 3S mouse (Mouse Gesture Button) to CTRL by writing a configuration file."
MODULE_DESCRIPTION_RU="Устанавливает Linux менеджер для большинства беспроводных устройст Logitech. Добавляет менеджер в autostart. Биндит нижкнюю кнопку мыши MX Master 3S (Mouse Gesture Button) на CTRL записывая конфигурационный файл."
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(solaar)
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=()
MODULE_FILES=("$CONFIG_FILE" "$HYPRLAND_EXECS")
MODULE_TAGS=(example)

install_steps() {
  lua_block "$HYPRLAND_EXECS" "$MODULE_ID" "$(cat "$ROOT/additions/files/hypr/solaar-autostart.lua")"
  managed_block "$CONFIG_FILE" "$MODULE_ID" "##" "$(cat "$ROOT/additions/files/solaar/rules.yaml")"
}

delete_steps() {
  remove_lua_block "$HYPRLAND_EXECS" "$MODULE_ID"
  remove_managed_block "$CONFIG_FILE" "$MODULE_ID" "##"
  remove_packages solaar
}

status_steps() {
  package_installed solaar || return 5
  lua_block_exists "$HYPRLAND_EXECS" "$MODULE_ID" || return 5
  managed_block_exists "$CONFIG_FILE" "$MODULE_ID" "##" || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
