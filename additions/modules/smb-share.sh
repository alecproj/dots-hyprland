#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="smb-share"
MODULE_SECTION="additions"
MODULE_TITLE="SMB share for VMs and LAN"
MODULE_TITLE_RU="SMB-шара для ВМ и локальной сети"
MODULE_DESCRIPTION="Installs Samba and shares ~/Share as Share for the current user on private IPv4 networks. Creates a Samba password when needed and preserves share data on delete; firewall rules are not changed."
MODULE_DESCRIPTION_RU="Устанавливает Samba и публикует ~/Share как Share для текущего пользователя в частных IPv4-сетях. При необходимости создаёт пароль Samba и сохраняет данные шары при удалении; правила firewall не меняются."
MODULE_VERSION="1"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(samba)
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=(smbpasswd pdbedit testparm)
MODULE_FILES=(/etc/samba/smb.conf "$HOME/Share")
MODULE_TAGS=(samba smb share lan virtualization)

_SMB_USER="${USER:-${LOGNAME:-}}"
_SMB_DIR="$HOME/Share"
_SMB_CONFIG="/etc/samba/smb.conf"

_smb_user_exists() {
  local entries line
  entries="$(run_logged sudo pdbedit -L)" || return 1
  while IFS= read -r line; do
    [[ "${line%%:*}" == "$_SMB_USER" ]] && return 0
  done <<<"$entries"
  return 1
}

_smb_create_user() {
  local password repeat

  [[ -r /dev/tty && -w /dev/tty ]] || die 1 "A terminal is required to set the Samba password"
  confirm_action local \
    "Create Samba password for $_SMB_USER" \
    "Создать пароль Samba для $_SMB_USER" || return 1

  printf 'New Samba password for %s: ' "$_SMB_USER" >/dev/tty
  IFS= read -r -s password </dev/tty
  printf '\nRepeat Samba password: ' >/dev/tty
  IFS= read -r -s repeat </dev/tty
  printf '\n' >/dev/tty

  [[ -n "$password" ]] || die 1 "Samba password must not be empty"
  [[ "$password" == "$repeat" ]] || die 1 "Samba passwords do not match"

  printf '%s\n%s\n' "$password" "$password" |
    run_logged sudo smbpasswd -s -a "$_SMB_USER"
  password=""
  repeat=""
  state_record_resource samba_users "$_SMB_USER"
}

_smb_write_config() {
  local content
  content="[global]
   workgroup = WORKGROUP
   server role = standalone server
   security = user
   server min protocol = SMB2
   logging = systemd

[Share]
   path = $_SMB_DIR
   browseable = yes
   read only = no
   guest ok = no
   valid users = $_SMB_USER
   force user = $_SMB_USER
   oplocks = no
   level2 oplocks = no
   create mask = 0664
   directory mask = 0775
   hosts allow = 127. 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
   hosts deny = 0.0.0.0/0
"
  write_file_sudo "$_SMB_CONFIG" "$content"
  run_logged sudo testparm -s "$_SMB_CONFIG" >/dev/null
}

preflight_steps() {
  local action="$1"

  [[ -n "$_SMB_USER" && -n "${HOME:-}" ]] || die 1 "Cannot determine current user or HOME"
  if [[ "$action" == "install" || "$action" == "reinstall" ]]; then
    [[ "$_SMB_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || die 1 "Unsupported Samba user name: $_SMB_USER"
  fi
}

install_steps() {
  ensure_directory_user "$HOME/VMS"
  ensure_directory_user "$_SMB_DIR"
  _smb_write_config

  _smb_user_exists || _smb_create_user

  enable_system_service smb
  restart_system_service smb

  state_record_resource configurations "$MODULE_ID"
  log_info "SMB share: \\\\HOST\\Share (user $_SMB_USER)"
}

delete_steps() {
  remove_managed_path "$_SMB_CONFIG"

  if state_has_resource samba_users "$_SMB_USER"; then
    run_confirmed local \
      "Remove Samba password for $_SMB_USER" \
      "Удалить пароль Samba для $_SMB_USER" \
      -- sudo smbpasswd -x "$_SMB_USER"
    state_forget_resource samba_users "$_SMB_USER"
  fi

  if state_has_resource system_services "smb.service"; then
    disable_system_service_if_exists smb
  elif system_service_enabled smb; then
    restart_system_service smb
  fi

  remove_managed_packages "${MODULE_PACKAGES[@]}"
  state_forget_resource configurations "$MODULE_ID"
  log_info "Preserved shared data under $_SMB_DIR"
}

status_steps() {
  state_has_resource configurations "$MODULE_ID" || return 5
  [[ -d "$_SMB_DIR" && -f "$_SMB_CONFIG" ]] || return 1
  package_installed samba || return 1
  command_exists testparm || return 1
  run_logged testparm -s "$_SMB_CONFIG" >/dev/null || return 1
  system_service_enabled smb || return 1
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
