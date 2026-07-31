#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="xdg-user-dirs"
MODULE_SECTION="additions"
MODULE_TITLE="Setup xdg-user-dirs"
MODULE_DESCRIPTION="Installs xdg-user-dirs and runs xdg-user-dirs-update. Existing user directory definitions are kept unless xdg-user-dirs itself decides an update is needed."
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(xdg-user-dirs)

install_steps() {
  log_info "Running xdg-user-dirs-update"
  xdg-user-dirs-update
}

delete_steps() {
  log_info "xdg-user-dirs delete is a no-op; user directories are not removed."
}

status_steps() {
  command -v xdg-user-dirs-update >/dev/null 2>&1
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
