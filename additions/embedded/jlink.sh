#!/usr/bin/env bash
set -euo pipefail

_EMBEDDED_DIR="$HOME/Embedded"
_JLINK_RULE_TARGET="/etc/udev/rules.d/99-jlink.rules"
_JLINK_BASHRC="$HOME/.bashrc"
_JLINK_FISH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"

MODULE_ID="jlink"
MODULE_SECTION="embedded"
MODULE_TITLE="Install SEGGER J-Link Software"
MODULE_TITLE_RU="Установка SEGGER J-Link Software"
MODULE_DESCRIPTION="Installs a manually downloaded SEGGER J-Link Linux x86_64 TGZ archive into ~/Embedded, installs its 99-jlink.rules udev rule and adds the selected J-Link directory to PATH for the current login shell (bash or fish). Set JLINK_ARCHIVE to an explicit archive path or place JLink_Linux_*_x86_64.tgz in ~/Downloads or ~/Embedded. SEGGER download and license acceptance remain manual."
MODULE_DESCRIPTION_RU="Устанавливает вручную скачанный TGZ-архив SEGGER J-Link для Linux x86_64 в ~/Embedded, устанавливает правило udev 99-jlink.rules и добавляет выбранный каталог J-Link в PATH текущего login shell (bash или fish). Можно передать JLINK_ARCHIVE с явным путём либо положить JLink_Linux_*_x86_64.tgz в ~/Downloads или ~/Embedded. Скачивание и принятие лицензии SEGGER остаются ручными."
MODULE_VERSION="1"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(tar)
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=(python3 tar udevadm)
MODULE_FILES=(
  "$_EMBEDDED_DIR"
  "$_JLINK_BASHRC"
  "$_JLINK_FISH_CONFIG"
  "$_JLINK_RULE_TARGET"
)
MODULE_TAGS=(embedded jlink segger debugger jtag swd udev)

preflight_steps() {
  local action="$1"

  [[ "$EUID" -ne 0 ]] || die 1 "Run this module as a regular user, not root"

  if [[ "$action" == "install" || "$action" == "reinstall" ]]; then
    [[ "$(uname -m)" == "x86_64" ]] ||
      die 3 "This module currently supports the SEGGER Linux x86_64 TGZ archive only"
  fi
}

_jlink_shell_kind() {
  case "$(basename -- "${SHELL:-}")" in
    fish) printf '%s\n' fish ;;
    bash) printf '%s\n' bash ;;
    *) return 1 ;;
  esac
}

_jlink_shell_config() {
  case "$(_jlink_shell_kind)" in
    fish) printf '%s\n' "$_JLINK_FISH_CONFIG" ;;
    bash) printf '%s\n' "$_JLINK_BASHRC" ;;
  esac
}

_jlink_install_path() {
  local target="$1"
  local shell_kind config content

  shell_kind="$(_jlink_shell_kind)" ||
    die 3 "Unsupported login shell: ${SHELL:-unset}. Supported shells: bash, fish"
  config="$(_jlink_shell_config)"

  case "$shell_kind" in
    fish)
      content="fish_add_path --path --append \"$target\""
      ;;
    bash)
      content="export PATH=\"\$PATH:$target\""
      ;;
  esac

  managed_block "$config" "${MODULE_ID}-path" "#" "$content"
}

_jlink_path_configured() {
  local config
  config="$(_jlink_shell_config)" || return 1
  managed_block_exists "$config" "${MODULE_ID}-path" "#"
}

_jlink_find_archive() {
  local -a candidates=()

  if [[ -n "${JLINK_ARCHIVE:-}" ]]; then
    [[ -f "$JLINK_ARCHIVE" ]] || return 1
    printf '%s\n' "$JLINK_ARCHIVE"
    return 0
  fi

  shopt -s nullglob
  candidates+=(
    "$HOME/Downloads"/JLink_Linux_*_x86_64.tgz
    "$_EMBEDDED_DIR"/JLink_Linux_*_x86_64.tgz
  )
  shopt -u nullglob

  [[ "${#candidates[@]}" -gt 0 ]] || return 1
  printf '%s\n' "${candidates[@]}" | sort -V | tail -n 1
}

_jlink_archive_root() {
  local archive="$1"
  local -a roots=()

  mapfile -t roots < <(
    tar -tzf "$archive" |
      sed 's#^\./##' |
      awk -F/ 'NF && $1 != "." && $1 != "" {print $1}' |
      sort -u
  )

  [[ "${#roots[@]}" -eq 1 ]] ||
    die 1 "J-Link archive must contain exactly one top-level directory: $archive"

  [[ "${roots[0]}" == JLink_Linux_*_x86_64 ]] ||
    die 1 "Unexpected J-Link archive directory: ${roots[0]}"

  printf '%s\n' "${roots[0]}"
}

_jlink_find_rule() {
  find "$1" -type f -name 99-jlink.rules -print -quit
}

_jlink_installed_dir() {
  local -a candidates=()
  local -a valid=()
  local candidate

  [[ -d "$_EMBEDDED_DIR" ]] || return 1

  shopt -s nullglob
  candidates=("$_EMBEDDED_DIR"/JLink_Linux_*_x86_64)
  shopt -u nullglob

  for candidate in "${candidates[@]}"; do
    [[ -d "$candidate" && -x "$candidate/JLinkExe" ]] && valid+=("$candidate")
  done

  [[ "${#valid[@]}" -gt 0 ]] || return 1
  printf '%s\n' "${valid[@]}" | sort -V | tail -n 1
}

_jlink_reload_udev() {
  run_confirmed all \
    "Reload udev rules" \
    "Перезагрузить правила udev" \
    -- sudo udevadm control --reload-rules

  run_confirmed all \
    "Re-enumerate connected SEGGER J-Link USB devices" \
    "Переподключить обнаруженные USB-устройства SEGGER J-Link" \
    -- sudo udevadm trigger \
      --action=remove \
      --attr-match=idVendor=1366 \
      --subsystem-match=usb

  run_confirmed all \
    "Add connected SEGGER J-Link USB devices again" \
    "Повторно добавить обнаруженные USB-устройства SEGGER J-Link" \
    -- sudo udevadm trigger \
      --action=add \
      --attr-match=idVendor=1366 \
      --subsystem-match=usb
}

install_steps() {
  local archive root target rule_source

  ensure_directory_user "$_EMBEDDED_DIR"

  if target="$(_jlink_installed_dir)"; then
    log_info "Using existing J-Link installation: $target"
  else
    archive="$(_jlink_find_archive)" ||
      die 3 "J-Link archive not found. Download Linux 64-bit TGZ from https://www.segger.com/downloads/jlink/ and set JLINK_ARCHIVE=/path/to/JLink_Linux_*_x86_64.tgz"

    root="$(_jlink_archive_root "$archive")"
    target="$_EMBEDDED_DIR/$root"

    [[ ! -e "$target" && ! -L "$target" ]] ||
      die 1 "Existing J-Link target is incomplete or conflicting: $target"

    run_confirmed local \
      "Extract J-Link Software into $target" \
      "Распаковать J-Link Software в $target" \
      -- tar -xzf "$archive" -C "$_EMBEDDED_DIR"

    state_record_resource created_paths "$target"
    state_record_resource managed_paths "$target"

    [[ -x "$target/JLinkExe" ]] ||
      die 1 "JLinkExe not found after extracting archive: $target"
  fi

  rule_source="$(_jlink_find_rule "$target")"
  [[ -n "$rule_source" && -f "$rule_source" ]] ||
    die 1 "99-jlink.rules not found inside $target"

  install_file_sudo "$rule_source" "$_JLINK_RULE_TARGET"

  _jlink_install_path "$target"

  _jlink_reload_udev
}

reinstall_steps() {
  install_steps
}

delete_steps() {
  local path

  remove_managed_block "$_JLINK_BASHRC" "${MODULE_ID}-path" "#"
  remove_managed_block "$_JLINK_FISH_CONFIG" "${MODULE_ID}-path" "#"
  remove_managed_path "$_JLINK_RULE_TARGET"

  while IFS= read -r path; do
    case "$path" in
      "$_EMBEDDED_DIR"/JLink_Linux_*_x86_64)
        remove_managed_path "$path"
        ;;
    esac
  done < <(state_list_resources created_paths)

  if command_exists udevadm; then
    run_confirmed all \
      "Reload udev rules after removing J-Link configuration" \
      "Перезагрузить правила udev после удаления конфигурации J-Link" \
      -- sudo udevadm control --reload-rules
  fi

  # ~/Embedded is a shared workspace for the whole section.
  state_forget_resource created_paths "$_EMBEDDED_DIR"
  state_forget_resource managed_paths "$_EMBEDDED_DIR"
}

status_steps() {
  local target

  [[ -d "$_EMBEDDED_DIR" ]] || return 5
  target="$(_jlink_installed_dir)" || return 5
  [[ -x "$target/JLinkExe" ]] || return 5
  [[ -f "$_JLINK_RULE_TARGET" ]] || return 5
  _jlink_path_configured || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
