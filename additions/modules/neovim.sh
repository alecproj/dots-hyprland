#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="neovim"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Neovim Editor"
MODULE_DESCRIPTION="Installs Neovim and common dependencies. This first-stage module does not replace an existing Neovim configuration; config migration should be added as a separate managed file or block."
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(neovim git ripgrep fd unzip npm tree-sitter-cli)

install_steps() {
  mkdir -p "$HOME/.config/nvim"
  log_info "Neovim packages installed. Existing ~/.config/nvim is not overwritten."
}

delete_steps() {
  log_info "Neovim delete removes packages only. User config is preserved."
  remove_packages neovim
}

status_steps() {
  command -v nvim >/dev/null 2>&1
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
