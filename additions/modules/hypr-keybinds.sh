#!/usr/bin/env bash
set -euo pipefail

_KEYBINDS_FILE="$HOME/.config/hypr/custom/keybinds.lua"
_GENERAL_FILE="$HOME/.config/hypr/custom/general.lua"

MODULE_ID="hypr-keybinds"
MODULE_SECTION="additions"
MODULE_TITLE="Setup custom Hyprland keybindings"
MODULE_TITLE_RU="Настройка пользовательских сочетаний клавиш Hyprland"
MODULE_DESCRIPTION="Setup the keyboard layout switching between Russian and English using the SUPER + SPACE keybind. Disables actions triggered by pressing the WIN key alone. Changes the keybind for opening the right sidebar to SUPER + BACKSLASH. Sets up Vim-style window navigation. Adds the ability to move windows between workspaces using the SUPER + CTRL + <number> combination. Existing files content remains unchanged."
MODULE_DESCRIPTION_RU="Настраивает смену раскладки клавиатуры между русской и английской с помощью сочетания SUPER + SPACE. Отключает действия по нажатии отдельно клавиши WIN. Заменяет сочетание клавиш для открытия правого меню на SUPER + BACKSLASH. Настраивает навигацию между окнами в стиле VIM. Добавляет перенос окон между рабочими столами по сочетанию SUPER + CTRL + <номер>. Постороннее содержимое управляемых файлов не изменяется."
MODULE_VERSION="1"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=()
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=(python3)
MODULE_FILES=(
  "$_GENERAL_FILE"
  "$_KEYBINDS_FILE"
)
MODULE_TAGS=(hyprland lua keybinds personal)

preflight_steps() {
  local action="$1"
  local source

  case "$action" in
    install|reinstall)
      for source in \
        "$ROOT/additions/files/hypr/kb-layout-general.lua" \
        "$ROOT/additions/files/hypr/system-keybinds.lua" \
        "$ROOT/additions/files/hypr/vim-style-keybinds.lua" \
        "$ROOT/additions/files/hypr/workspaces-keybinds.lua"; do
        [[ -f "$source" ]] || die 3 "Source file not found: $source"
      done
      ;;
  esac
}

_hypr_custom_reload() {
  if command_exists hyprctl &&
     [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    run_logged hyprctl reload ||
      log_warn "hyprctl reload failed"
  else
    log_info "Hyprland session is not active; reload skipped"
  fi
}

install_steps() {
  lua_block \
    "$_GENERAL_FILE" \
    "${MODULE_ID}-keyboard" \
    "$(cat "$ROOT/additions/files/hypr/kb-layout-general.lua")"

  lua_block \
    "$_KEYBINDS_FILE" \
    "${MODULE_ID}-system" \
    "$(cat "$ROOT/additions/files/hypr/system-keybinds.lua")"

  lua_block \
    "$_KEYBINDS_FILE" \
    "${MODULE_ID}-window" \
    "$(cat "$ROOT/additions/files/hypr/vim-style-keybinds.lua")"

  lua_block \
    "$_KEYBINDS_FILE" \
    "${MODULE_ID}-workspaces" \
    "$(cat "$ROOT/additions/files/hypr/workspaces-keybinds.lua")"

  _hypr_custom_reload
}

reinstall_steps() {
  install_steps
}

delete_steps() {
  remove_lua_block "$_GENERAL_FILE" "${MODULE_ID}-keyboard"
  remove_lua_block "$_KEYBINDS_FILE" "${MODULE_ID}-system"
  remove_lua_block "$_KEYBINDS_FILE" "${MODULE_ID}-window"
  remove_lua_block "$_KEYBINDS_FILE" "${MODULE_ID}-workspaces"

  _hypr_custom_reload
}

status_steps() {
  lua_block_exists "$_GENERAL_FILE" "${MODULE_ID}-keyboard" || return 5
  lua_block_exists "$_KEYBINDS_FILE" "${MODULE_ID}-system" || return 5
  lua_block_exists "$_KEYBINDS_FILE" "${MODULE_ID}-window" || return 5
  lua_block_exists "$_KEYBINDS_FILE" "${MODULE_ID}-workspaces" || return 5

  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
