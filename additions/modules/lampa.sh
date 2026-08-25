#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="lampa"
MODULE_SECTION="additions"
MODULE_TITLE="Install Lampa with TorrServer"
MODULE_TITLE_RU="Установка Lampa с TorrServer"
MODULE_DESCRIPTION="Installs Lampa from AUR and the latest official TorrServer release from YouROK/TorrServer. Additionally, it installs the mpc-qt video player and writes user settings to ~/.config/mpc-qt/scripts/lampa.sh. TorrServer runs as a local-only user systemd service on 127.0.0.1:8090 with data in ~/.local/share/torrserver. Delete removes Lampa and module-managed TorrServer files but preserves TorrServer data and Lampa user configuration."
MODULE_DESCRIPTION_RU="Устанавливает Lampa из AUR и последний официальный релиз TorrServer из YouROK/TorrServer. Дополнительно ставит видеоплеер mpc-qt и записывает пользовательские настройки в ~/.config/mpc-qt/scripts/lampa.sh. TorrServer запускается как локальный пользовательский systemd-сервис на 127.0.0.1:8090 и хранит данные в ~/.local/share/torrserver. Удаление удаляет Lampa и управляемые модулем файлы TorrServer, но сохраняет данные TorrServer и пользовательскую конфигурацию Lampa."
MODULE_VERSION="1"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(curl)
MODULE_AUR_PACKAGES=(lampa mpc-qt)
MODULE_REQUIRED_COMMANDS=(curl systemctl)
MODULE_FILES=(
  "$HOME/.local/bin/TorrServer"
  "$HOME/.config/systemd/user/torrserver.service"
  "$HOME/.local/share/torrserver"
  "$HOME/.config/mpc-qt/scripts/lampa.sh"
)
MODULE_TAGS=(media cinema streaming torrent lampa torrserver)

_LAMPA_TORRSERVER_REPO="https://github.com/YouROK/TorrServer"
_LAMPA_TORRSERVER_BIN="$HOME/.local/bin/TorrServer"
_LAMPA_TORRSERVER_SERVICE="$HOME/.config/systemd/user/torrserver.service"
_LAMPA_TORRSERVER_DATA="$HOME/.local/share/torrserver"
_LAMPA_TORRSERVER_PORT="8090"
_MPC_QT_SCRIPT="$HOME/.config/mpc-qt/scripts/lampa.sh"

_lampa_torrserver_arch() {
  case "$(uname -m)" in
    x86_64) printf '%s\n' "amd64" ;;
    i386|i686) printf '%s\n' "386" ;;
    aarch64) printf '%s\n' "arm64" ;;
    armv7|armv7l) printf '%s\n' "arm7" ;;
    armv6|armv6l) printf '%s\n' "arm5" ;;
    *) return 1 ;;
  esac
}

_lampa_torrserver_download_url() {
  local arch
  arch="$(_lampa_torrserver_arch)" || return 1
  printf '%s/releases/latest/download/TorrServer-linux-%s\n' \
    "$_LAMPA_TORRSERVER_REPO" "$arch"
}

_lampa_torrserver_service_content() {
  cat <<EOF_SERVICE
[Unit]
Description=TorrServer - stream torrents over HTTP

[Service]
Type=simple
ExecStart=%h/.local/bin/TorrServer --ip 127.0.0.1 --port $_LAMPA_TORRSERVER_PORT --path %h/.local/share/torrserver
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOF_SERVICE
}

_lampa_install_torrserver_binary() {
  local url tmp return_code
  url="$(_lampa_torrserver_download_url)" || die 3 "Unsupported architecture for TorrServer: $(uname -m)"
  tmp="$(mktemp)"
  return_code=0

  if run_logged curl \
      --fail \
      --location \
      --silent \
      --show-error \
      --retry 3 \
      --connect-timeout 10 \
      --max-time 600 \
      --output "$tmp" \
      "$url"; then
    if [[ ! -s "$tmp" ]]; then
      rm -f -- "$tmp"
      die 1 "Downloaded TorrServer binary is empty"
    fi
    if install_file_user "$tmp" "$_LAMPA_TORRSERVER_BIN" 0755; then
      return_code=0
    else
      return_code=$?
    fi
  else
    return_code=$?
  fi

  rm -f -- "$tmp"
  return "$return_code"
}

preflight_steps() {
  local action="$1"

  [[ "$EUID" -ne 0 ]] || die 1 "Run this module as a regular user, not root"

  if [[ "$action" == "install" || "$action" == "reinstall" ]]; then
    _lampa_torrserver_arch >/dev/null || die 3 "Unsupported architecture for TorrServer: $(uname -m)"

    if system_service_exists torrserver; then
      die 1 "A system torrserver.service already exists. Remove or disable the existing TorrServer installation before using this module"
    fi

    if user_service_exists torrserver && \
        ! state_has_resource managed_paths "$_LAMPA_TORRSERVER_SERVICE"; then
      die 1 "An unmanaged user torrserver.service already exists. Refusing to overwrite it"
    fi
  fi
}

install_steps() {
  _lampa_install_torrserver_binary
  ensure_directory_user "$_LAMPA_TORRSERVER_DATA" 0755
  write_file_user \
    "$_LAMPA_TORRSERVER_SERVICE" \
    "$(_lampa_torrserver_service_content)" \
    0644
  user_systemd_daemon_reload
  enable_user_service torrserver
  restart_user_service torrserver

  log_info "TorrServer is available at http://127.0.0.1:$_LAMPA_TORRSERVER_PORT"

  install_file_user "$ROOT/additions/files/mpc-qt/lampa.lua" "$_MPC_QT_SCRIPT" 0755
}

delete_steps() {
  disable_user_service_if_exists torrserver
  remove_managed_path "$_LAMPA_TORRSERVER_SERVICE"
  user_systemd_daemon_reload
  remove_managed_path "$_LAMPA_TORRSERVER_BIN"
  remove_managed_path "$_MPC_QT_SCRIPT"

  # Preserve TorrServer databases, cache and settings on delete.
  state_forget_resource managed_paths "$_LAMPA_TORRSERVER_DATA"
  state_forget_resource created_paths "$_LAMPA_TORRSERVER_DATA"

  remove_packages lampa
  remove_managed_packages curl mpc-qt
}

status_steps() {
  package_installed lampa || return 5
  package_installed mpc-qt || return 5
  [[ -x "$_LAMPA_TORRSERVER_BIN" ]] || return 5
  [[ -f "$_MPC_QT_SCRIPT" ]] || return 5
  user_service_exists torrserver || return 5
  user_service_enabled torrserver || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
