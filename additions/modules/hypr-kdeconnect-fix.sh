#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="hypr-kdeconnect-fix"
MODULE_SECTION="additions"
MODULE_TITLE="Setup KDE Connect with fix"
MODULE_TITLE_RU="Установка KDE Connect с исправлением"
MODULE_DESCRIPTION="Builds hypr-kdeconnect-portal from source into ~/.local, configures the RemoteDesktop XDG portal backend, reloads user systemd and restarts KDE Connect. The source repository is cloned or fast-forwarded when clean; local changes are preserved and skip the update. Portal configuration and installed files are backed up or tracked. Source and build caches are preserved on delete."
MODULE_DESCRIPTION_RU="Собирает hypr-kdeconnect-portal из исходников в ~/.local, настраивает RemoteDesktop backend XDG Portal, перезагружает пользовательский systemd и перезапускает KDE Connect. Репозиторий клонируется или обновляется fast-forward при отсутствии локальных изменений; локальные изменения сохраняются и обновление пропускается. Конфигурация портала и установленные файлы резервируются или отслеживаются. Исходники и кэш сборки при удалении сохраняются."
MODULE_VERSION="1"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(
  git
  base-devel
  cmake
  pkgconf
  qt6-base
  wayland
  libxkbcommon
  libei
  xdg-desktop-portal
  kdeconnect
  sshfs
  procps-ng
)
MODULE_REQUIRED_COMMANDS=(git cmake ctest systemctl kdeconnectd python3)
MODULE_FILES=(
  "$HOME/.local/bin/hypr-kdeconnect-portal"
  "$HOME/.local/share/xdg-desktop-portal/portals/hypr-kdeconnect.portal"
  "$HOME/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hypr_kdeconnect.service"
  "$HOME/.local/share/systemd/user/hypr-kdeconnect-portal.service"
  "$HOME/.config/xdg-desktop-portal/hyprland-portals.conf"
  "$HOME/.config/xdg-desktop-portal/portals.conf"
)
MODULE_TAGS=(kdeconnect portal remote-desktop hyprland wayland build)

_HYPR_KDECONNECT_REPO_URL="${HYPR_KDECONNECT_REPO_URL:-https://github.com/gfhdhytghd/hypr-kdeconnect-fix.git}"
_HYPR_KDECONNECT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-kdeconnect-fix"
_HYPR_KDECONNECT_PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
_HYPR_KDECONNECT_ACTIVE_CONF="$_HYPR_KDECONNECT_PORTAL_DIR/hyprland-portals.conf"
_HYPR_KDECONNECT_FALLBACK_CONF="$_HYPR_KDECONNECT_PORTAL_DIR/portals.conf"
_HYPR_KDECONNECT_REMOTE_KEY="org.freedesktop.impl.portal.RemoteDesktop"
_HYPR_KDECONNECT_REMOTE_VALUE="hypr-kdeconnect"
_HYPR_KDECONNECT_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dots-hyprland-additions/kdeconnectd.log"
_HYPR_KDECONNECT_TARGETS=(
  "$HOME/.local/bin/hypr-kdeconnect-portal"
  "$HOME/.local/share/xdg-desktop-portal/portals/hypr-kdeconnect.portal"
  "$HOME/.local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.hypr_kdeconnect.service"
  "$HOME/.local/share/systemd/user/hypr-kdeconnect-portal.service"
)

_hypr_kdeconnect_path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

_hypr_kdeconnect_prepare_source() {
  git_sync_repo "$_HYPR_KDECONNECT_REPO_URL" "$_HYPR_KDECONNECT_CACHE_DIR"
}

_hypr_kdeconnect_render_portal_config() {
  local source_file="$1"
  python3 - "$source_file" "$_HYPR_KDECONNECT_REMOTE_KEY" "$_HYPR_KDECONNECT_REMOTE_VALUE" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
remote_key = sys.argv[2]
remote_value = sys.argv[3]
text = path.read_text(encoding="utf-8") if path.exists() else ""
lines = text.splitlines()
out: list[str] = []
in_preferred = False
saw_preferred = False
saw_remote = False

def add_remote() -> None:
    global saw_remote
    if in_preferred and not saw_remote:
        out.append(f"{remote_key} = {remote_value}")
        saw_remote = True

for line in lines:
    match = re.match(r"^\s*\[([^]]+)]\s*$", line)
    if match:
        add_remote()
        in_preferred = match.group(1).strip() == "preferred"
        saw_preferred = saw_preferred or in_preferred
        out.append(line)
        continue
    if in_preferred and "=" in line:
        key = line.split("=", 1)[0].strip()
        if key == remote_key:
            if not saw_remote:
                out.append(f"{remote_key} = {remote_value}")
                saw_remote = True
            continue
    out.append(line)

add_remote()
if not saw_preferred:
    if out and out[-1].strip():
        out.append("")
    out.extend([
        "[preferred]",
        "default = hyprland;gtk",
        "org.freedesktop.impl.portal.FileChooser = kde",
        f"{remote_key} = {remote_value}",
    ])

print("\n".join(out))
PY
}

_hypr_kdeconnect_patch_portal_config() {
  local target="$1"
  local source_file="${2:-$target}"
  local content
  content="$(_hypr_kdeconnect_render_portal_config "$source_file")"
  content+=$'\n'
  write_file_user "$target" "$content"
}

_hypr_kdeconnect_record_install_targets() {
  local target="$1"
  local was_created="$2"
  state_record_resource managed_paths "$target"
  if [[ "$was_created" == "true" ]]; then
    state_record_resource created_paths "$target"
  fi
}

_hypr_kdeconnect_restart_daemon() {
  command_exists pkill && run_logged pkill kdeconnectd 2>/dev/null || true
  confirm_action local \
    "Start kdeconnectd in the user session" \
    "Запустить kdeconnectd в пользовательской сессии" || return 1
  ensure_directory_user "$(dirname "$_HYPR_KDECONNECT_LOG")"
  log_info "Starting kdeconnectd; log: $_HYPR_KDECONNECT_LOG"
  nohup kdeconnectd >"$_HYPR_KDECONNECT_LOG" 2>&1 </dev/null &
  disown || true
}

preflight_steps() {
  [[ "$EUID" -ne 0 ]] || die 1 "Run this module as a regular user, not root"
}

install_steps() {
  local target created was_created
  local -a created_targets=()

  _hypr_kdeconnect_prepare_source

  run_confirmed local \
    "Configure hypr-kdeconnect-portal" \
    "Настроить сборку hypr-kdeconnect-portal" \
    -- cmake \
      -S "$_HYPR_KDECONNECT_CACHE_DIR" \
      -B "$_HYPR_KDECONNECT_CACHE_DIR/build" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$HOME/.local"

  run_confirmed local \
    "Build hypr-kdeconnect-portal" \
    "Собрать hypr-kdeconnect-portal" \
    -- cmake --build "$_HYPR_KDECONNECT_CACHE_DIR/build" -j"$(nproc)"

  run_confirmed local \
    "Run hypr-kdeconnect-portal tests" \
    "Запустить тесты hypr-kdeconnect-portal" \
    -- ctest --test-dir "$_HYPR_KDECONNECT_CACHE_DIR/build" --output-on-failure

  for target in "${_HYPR_KDECONNECT_TARGETS[@]}"; do
    if ! _hypr_kdeconnect_path_exists "$target"; then
      created_targets+=("$target")
    fi
    backup_path "$MODULE_ID" "$target"
  done

  run_confirmed local \
    "Install hypr-kdeconnect-portal into $HOME/.local" \
    "Установить hypr-kdeconnect-portal в $HOME/.local" \
    -- cmake --install "$_HYPR_KDECONNECT_CACHE_DIR/build"

  for target in "${_HYPR_KDECONNECT_TARGETS[@]}"; do
    was_created=false
    for created in "${created_targets[@]}"; do
      [[ "$created" == "$target" ]] && was_created=true
    done
    _hypr_kdeconnect_record_install_targets "$target" "$was_created"
  done

  ensure_directory_user "$_HYPR_KDECONNECT_PORTAL_DIR"
  if [[ ! -f "$_HYPR_KDECONNECT_ACTIVE_CONF" && -f "$_HYPR_KDECONNECT_FALLBACK_CONF" ]]; then
    _hypr_kdeconnect_patch_portal_config       "$_HYPR_KDECONNECT_ACTIVE_CONF"       "$_HYPR_KDECONNECT_FALLBACK_CONF"
  else
    _hypr_kdeconnect_patch_portal_config "$_HYPR_KDECONNECT_ACTIVE_CONF"
  fi
  if [[ -f "$_HYPR_KDECONNECT_FALLBACK_CONF" ]]; then
    _hypr_kdeconnect_patch_portal_config "$_HYPR_KDECONNECT_FALLBACK_CONF"
  fi

  user_systemd_daemon_reload
  if user_service_exists xdg-desktop-portal; then
    restart_user_service xdg-desktop-portal
  fi
  if user_service_exists hypr-kdeconnect-portal; then
    start_user_service hypr-kdeconnect-portal
  fi
  _hypr_kdeconnect_restart_daemon
}

reinstall_steps() {
  install_steps
}

delete_steps() {
  local target
  if user_service_exists hypr-kdeconnect-portal; then
    stop_user_service hypr-kdeconnect-portal
  fi
  command_exists pkill && run_logged pkill kdeconnectd 2>/dev/null || true

  remove_managed_path "$_HYPR_KDECONNECT_ACTIVE_CONF"
  remove_managed_path "$_HYPR_KDECONNECT_FALLBACK_CONF"
  for target in "${_HYPR_KDECONNECT_TARGETS[@]}"; do
    remove_managed_path "$target"
  done

  user_systemd_daemon_reload
  if user_service_exists xdg-desktop-portal; then
    restart_user_service xdg-desktop-portal
  fi
  log_info "Source and build cache preserved: $_HYPR_KDECONNECT_CACHE_DIR"
  log_info "Repository packages are preserved to avoid removing shared dependencies."
}

status_steps() {
  [[ -x "$HOME/.local/bin/hypr-kdeconnect-portal" ]] || return 5
  [[ -f "$HOME/.local/share/systemd/user/hypr-kdeconnect-portal.service" ]] || return 5
  [[ -f "$_HYPR_KDECONNECT_ACTIVE_CONF" ]] || return 5
  grep -Eq \
    "^[[:space:]]*${_HYPR_KDECONNECT_REMOTE_KEY//./\\.}[[:space:]]*=[[:space:]]*${_HYPR_KDECONNECT_REMOTE_VALUE}[[:space:]]*$" \
    "$_HYPR_KDECONNECT_ACTIVE_CONF" || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
