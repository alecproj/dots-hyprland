#!/usr/bin/env bash
set -euo pipefail

_ARDUINO_DESKTOP_SOURCE="/usr/share/applications/arduino-ide-v2.desktop"
_ARDUINO_DESKTOP_TARGET="${XDG_DATA_HOME:-$HOME/.local/share}/applications/arduino-ide-v2.desktop"

MODULE_ID="arduino-ide"
MODULE_SECTION="embedded"
MODULE_TITLE="Install Arduino IDE"
MODULE_TITLE_RU="Установка Arduino IDE"
MODULE_DESCRIPTION="Installs the official Arduino IDE 2.x binary from AUR and creates a per-user desktop launcher that forces Electron to X11 via --ozone-platform=x11 for reliable startup under Hyprland/Wayland. Delete removes the launcher override and Arduino IDE package while preserving sketches, board packages, libraries and IDE preferences. Serial/USB group membership is not changed."
MODULE_DESCRIPTION_RU="Устанавливает официальный бинарный Arduino IDE 2.x из AUR и создаёт пользовательский desktop launcher, принудительно запускающий Electron через X11 с --ozone-platform=x11 для стабильной работы в Hyprland/Wayland. Удаление убирает override launcher и пакет Arduino IDE, сохраняя скетчи, пакеты плат, библиотеки и настройки IDE. Членство пользователя в группах доступа к serial/USB не изменяется."
MODULE_VERSION="1"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=()
MODULE_AUR_PACKAGES=(arduino-ide-bin)
MODULE_REQUIRED_COMMANDS=(arduino-ide)
MODULE_FILES=("$_ARDUINO_DESKTOP_TARGET")
MODULE_TAGS=(embedded arduino ide electron wayland hyprland xwayland)

preflight_steps() {
  local action="$1"

  [[ "$EUID" -ne 0 ]] || die 1 "Run this module as a regular user, not root"

  if [[ "$action" == "install" || "$action" == "reinstall" ]]; then
    [[ "$(uname -m)" == "x86_64" ]] ||
      die 3 "arduino-ide-bin currently targets Linux x86_64"
  fi
}

_arduino_desktop_content() {
  local line
  local found_exec=false

  [[ -f "$_ARDUINO_DESKTOP_SOURCE" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == Exec=* ]]; then
      printf '%s\n' 'Exec=arduino-ide --ozone-platform=x11 %U'
      found_exec=true
    else
      printf '%s\n' "$line"
    fi
  done <"$_ARDUINO_DESKTOP_SOURCE"

  [[ "$found_exec" == true ]]
}

_arduino_desktop_configured() {
  local line

  [[ -f "$_ARDUINO_DESKTOP_TARGET" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == 'Exec=arduino-ide --ozone-platform=x11 %U' ]] && return 0
  done <"$_ARDUINO_DESKTOP_TARGET"
  return 1
}

install_steps() {
  local content

  [[ -f "$_ARDUINO_DESKTOP_SOURCE" ]] ||
    die 3 "Desktop entry not found after installing arduino-ide-bin: $_ARDUINO_DESKTOP_SOURCE"

  content="$(_arduino_desktop_content)" ||
    die 1 "Could not build X11 desktop launcher from $_ARDUINO_DESKTOP_SOURCE"

  write_file_user "$_ARDUINO_DESKTOP_TARGET" "$content" 0644
}

delete_steps() {
  remove_managed_path "$_ARDUINO_DESKTOP_TARGET"
  remove_packages arduino-ide-bin
}

status_steps() {
  package_installed arduino-ide-bin || return 5
  command_exists arduino-ide || return 5
  _arduino_desktop_configured || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
