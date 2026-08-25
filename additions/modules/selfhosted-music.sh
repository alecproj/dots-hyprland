#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="selfhosted-music"
MODULE_SECTION="additions"
MODULE_TITLE="Configure self-hosted music stack"
MODULE_TITLE_RU="Настройка локального музыкального сервера"
MODULE_DESCRIPTION="Installs Navidrome, Feishin and Nicotine+, kid3, configures /srv/music and /var/lib/navidrome, installs the legacy Navidrome configuration, links ~/Music/library and enables navidrome.service. Delete restores managed config and the library link, removes the four applications, and preserves music and service data directories."
MODULE_DESCRIPTION_RU="Устанавливает Navidrome, Feishin и Nicotine+, kid3, настраивает /srv/music и /var/lib/navidrome, устанавливает прежнюю конфигурацию Navidrome, создаёт ссылку ~/Music/library и включает navidrome.service. Удаление восстанавливает управляемую конфигурацию и ссылку, удаляет четыре приложения, но сохраняет музыкальную библиотеку и данные сервиса."
MODULE_VERSION="1"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(navidrome feishin nicotine+ kid3)
MODULE_REQUIRED_COMMANDS=(systemctl id find readlink)
MODULE_FILES=(
  /srv/music
  /var/lib/navidrome
  /etc/navidrome/navidrome.toml
  "$HOME/Music/library"
  "$HOME/Music/data/nicotine/incomplete"
)
MODULE_TAGS=(music navidrome feishin nicotine selfhosted service)

_SELFHOSTED_MUSIC_LIBRARY="/srv/music"
_SELFHOSTED_MUSIC_DATA="/var/lib/navidrome"
_SELFHOSTED_MUSIC_NICOTINE="$HOME/Music/data/nicotine"
_SELFHOSTED_MUSIC_LINK="$HOME/Music/library"
_SELFHOSTED_MUSIC_CONFIG="/etc/navidrome/navidrome.toml"

_selfhosted_music_require_safe_library_link() {
  if [[ -L "$_SELFHOSTED_MUSIC_LINK" || ! -e "$_SELFHOSTED_MUSIC_LINK" ]]; then
    return 0
  fi
  if [[ -d "$_SELFHOSTED_MUSIC_LINK" ]] &&
      [[ -z "$(find "$_SELFHOSTED_MUSIC_LINK" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    return 0
  fi
  die 1 "$_SELFHOSTED_MUSIC_LINK exists and contains data. Move or merge it manually before installing this module."
}

_selfhosted_music_ensure_system_directory() {
  local owner="$1"
  local group="$2"
  local mode="$3"
  local path="$4"
  run_confirmed local \
    "Ensure directory $path ($owner:$group, mode $mode)" \
    "Настроить каталог $path ($owner:$group, режим $mode)" \
    -- sudo install -d -o "$owner" -g "$group" -m "$mode" -- "$path"
}

preflight_steps() {
  local action="$1"
  [[ "$EUID" -ne 0 ]] || die 1 "Run this module as a regular user, not root"
  if [[ "$action" == "install" || "$action" == "reinstall" ]]; then
    _selfhosted_music_require_safe_library_link
  fi
}

install_steps() {
  local user_name
  user_name="$(id -un)"
  id navidrome >/dev/null 2>&1 || die 3 "System user 'navidrome' was not created by the package"

  _selfhosted_music_ensure_system_directory "$user_name" navidrome 2775 "$_SELFHOSTED_MUSIC_LIBRARY"
  _selfhosted_music_ensure_system_directory "$user_name" navidrome 2775 "$_SELFHOSTED_MUSIC_LIBRARY/new"
  _selfhosted_music_ensure_system_directory "$user_name" navidrome 2775 "$_SELFHOSTED_MUSIC_LIBRARY/favorites"
  _selfhosted_music_ensure_system_directory "$user_name" navidrome 2775 "$_SELFHOSTED_MUSIC_LIBRARY/playlists"
  _selfhosted_music_ensure_system_directory navidrome navidrome 0755 "$_SELFHOSTED_MUSIC_DATA"
  _selfhosted_music_ensure_system_directory navidrome navidrome 0755 "$_SELFHOSTED_MUSIC_DATA/cache"

  ensure_directory_user "$_SELFHOSTED_MUSIC_NICOTINE/incomplete"
  ensure_directory_user "$HOME/Music"
  install_symlink_user "$_SELFHOSTED_MUSIC_LIBRARY" "$_SELFHOSTED_MUSIC_LINK"
  install_file_sudo \
    "$ROOT/custom/files/navidrome/navidrome.toml" \
    "$_SELFHOSTED_MUSIC_CONFIG"

  run_logged sudo -u navidrome test -r "$_SELFHOSTED_MUSIC_LIBRARY"
  run_logged sudo -u navidrome test -w "$_SELFHOSTED_MUSIC_DATA"
  systemd_daemon_reload
  enable_system_service navidrome
  restart_system_service navidrome
}

reinstall_steps() {
  install_steps
}

delete_steps() {
  disable_system_service_if_exists navidrome
  remove_managed_path "$_SELFHOSTED_MUSIC_CONFIG"
  remove_managed_path "$_SELFHOSTED_MUSIC_LINK"
  remove_packages navidrome feishin nicotine+
  remove_managed_packages kid3
  log_info "Preserved music and application data: $_SELFHOSTED_MUSIC_LIBRARY, $_SELFHOSTED_MUSIC_DATA, $_SELFHOSTED_MUSIC_NICOTINE"
}

status_steps() {
  package_installed navidrome || return 5
  system_service_enabled navidrome || return 5
  [[ -f "$_SELFHOSTED_MUSIC_CONFIG" ]] || return 5
  cmp -s -- "$ROOT/custom/files/navidrome/navidrome.toml" "$_SELFHOSTED_MUSIC_CONFIG" || return 5
  [[ -L "$_SELFHOSTED_MUSIC_LINK" ]] || return 5
  [[ "$(readlink -f -- "$_SELFHOSTED_MUSIC_LINK" 2>/dev/null || true)" == "$_SELFHOSTED_MUSIC_LIBRARY" ]] || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
