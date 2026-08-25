#!/usr/bin/env bash
set -euo pipefail

BINARY="$HOME/.local/bin/win11-rdp"
DESKTOP="$HOME/.local/share/applications/win11.desktop"

MODULE_ID="win11-launcher"
MODULE_SECTION="additions"
MODULE_TITLE="Windows 11 VM launcher"
MODULE_TITLE_RU="Запуск Windows 11 VM"
MODULE_DESCRIPTION="Creates application launcher for Windows 11 VM with FreeRDP connection."
MODULE_DESCRIPTION_RU="Создаёт ярлык запуска Windows 11 VM с подключением через FreeRDP."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"

MODULE_PACKAGES=(
  freerdp
  libvirt
)

MODULE_REQUIRED_COMMANDS=(
  virsh
  xfreerdp3
)

MODULE_FILES=(
  "$BINARY"
  "$DESKTOP"
)

_win11_desktop_content() {
  cat <<EOF
[Desktop Entry]
Name=Windows 11
Comment=Start Windows 11 VM and connect via RDP
Exec=$BINARY
Icon=computer
Terminal=false
Type=Application
Categories=Utility;
EOF
}

install_steps() {
  install_file_user "$ROOT/additions/files/bin/win11-rdp" "$BINARY" 0755
  write_file_user "$DESKTOP" "$(_win11_desktop_content)"

  update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
}

delete_steps() {
  remove_managed_path "$BINARY"
  remove_managed_path "$DESKTOP"

  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
}

status_steps() {
  [[ -x "$BINARY" ]] || return 5
  [[ -f "$DESKTOP" ]] || return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
