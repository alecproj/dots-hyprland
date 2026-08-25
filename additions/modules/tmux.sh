#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="tmux"
MODULE_SECTION="additions"
MODULE_TITLE="Setup terminal multiplexer (tmux)"
MODULE_TITLE_RU="Настройка терминального мультиплексора (tmux)"
MODULE_DESCRIPTION="Installs tmux, inetutils, Git and Wayland clipboard tools. Writes ~/.config/tmux/tmux.conf with backup and installs the Catppuccin theme plus the configured TPM plugins. Existing plugin repositories with local changes are preserved and not updated. Run tmux after installation."
MODULE_DESCRIPTION_RU="Устанавливает tmux, inetutils, Git и инструменты буфера обмена Wayland. С резервным копированием записывает ~/.config/tmux/tmux.conf и устанавливает тему Catppuccin вместе с настроенными плагинами TPM. Существующие репозитории плагинов с локальными изменениями сохраняются и не обновляются. После установки выполните tmux."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(tmux inetutils git wl-clipboard)
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=(tmux git wl-copy wl-paste)
MODULE_FILES=(
  "$HOME/.config/tmux/tmux.conf"
  "$HOME/.config/tmux/plugins"
)
MODULE_TAGS=(terminal tmux multiplexer wayland catppuccin plugins)

TMUX_CONFIG="$HOME/.config/tmux/tmux.conf"
TMUX_PLUGIN_ROOT="$HOME/.config/tmux/plugins"

TMUX_PLUGIN_URLS=(
  "https://github.com/tmux-plugins/tpm.git"
  "https://github.com/tmux-plugins/tmux-sensible.git"
  "https://github.com/christoomey/vim-tmux-navigator.git"
  "https://github.com/tmux-plugins/tmux-pain-control.git"
  "https://github.com/jaclu/tmux-menus.git"
  "https://github.com/tmux-plugins/tmux-resurrect.git"
  "https://github.com/tmux-plugins/tmux-sessionist.git"
  "https://github.com/catppuccin/tmux.git"
)

TMUX_PLUGIN_PATHS=(
  "$TMUX_PLUGIN_ROOT/tpm"
  "$TMUX_PLUGIN_ROOT/tmux-sensible"
  "$TMUX_PLUGIN_ROOT/vim-tmux-navigator"
  "$TMUX_PLUGIN_ROOT/tmux-pain-control"
  "$TMUX_PLUGIN_ROOT/tmux-menus"
  "$TMUX_PLUGIN_ROOT/tmux-resurrect"
  "$TMUX_PLUGIN_ROOT/tmux-sessionist"
  "$TMUX_PLUGIN_ROOT/catppuccin/tmux"
)

_tmux_sync_plugin() {
  local url="$1"
  local directory="$2"
  local existed=true

  if [[ ! -e "$directory" && ! -L "$directory" ]]; then
    existed=false
  fi

  git_sync_repo "$url" "$directory"

  if [[ "$existed" == false ]]; then
    state_record_resource managed_paths "$directory"
    state_record_resource created_paths "$directory"
  fi
}

_tmux_sync_plugins() {
  local index
  for index in "${!TMUX_PLUGIN_URLS[@]}"; do
    _tmux_sync_plugin \
      "${TMUX_PLUGIN_URLS[$index]}" \
      "${TMUX_PLUGIN_PATHS[$index]}"
  done
}

_tmux_plugins_ready() {
  local index
  for index in "${!TMUX_PLUGIN_URLS[@]}"; do
    git_repo_matches \
      "${TMUX_PLUGIN_PATHS[$index]}" \
      "${TMUX_PLUGIN_URLS[$index]}" || return 1
  done
}

_tmux_remove_plugins() {
  local index
  for ((index=${#TMUX_PLUGIN_PATHS[@]} - 1; index >= 0; index--)); do
    remove_managed_path "${TMUX_PLUGIN_PATHS[$index]}"
  done
}

_tmux_reload_if_running() {
  if tmux list-sessions >/dev/null 2>&1; then
    run_logged tmux source-file "$TMUX_CONFIG"
  fi
}

install_steps() {
  _tmux_sync_plugins
  install_file_user \
    "$ROOT/additions/files/tmux/tmux.conf" \
    "$TMUX_CONFIG"
  _tmux_reload_if_running
}

delete_steps() {
  remove_managed_path "$TMUX_CONFIG"
  _tmux_remove_plugins
  remove_packages tmux
  remove_managed_packages git wl-clipboard inetutils
}

status_steps() {
  package_installed tmux || return 5
  package_installed inetutils || return 5
  package_installed git || return 5
  package_installed wl-clipboard || return 5
  [[ -f "$TMUX_CONFIG" ]] || return 5
  cmp -s -- "$ROOT/additions/files/tmux/tmux.conf" "$TMUX_CONFIG" || return 5
  _tmux_plugins_ready || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
