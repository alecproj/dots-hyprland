#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="neovim"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Neovim Editor"
MODULE_TITLE_RU="Настройка редактора Neovim"
MODULE_DESCRIPTION="Installs Neovim and common dependencies. This first-stage module does not replace an existing Neovim configuration; config migration should be added as a separate managed file or block."
MODULE_DESCRIPTION_RU="Устанавливает Neovim и основные зависимости. Модуль первого этапа не заменяет существующую конфигурацию Neovim; её перенос следует реализовать отдельным управляемым файлом или блоком."
MODULE_VERSION="1"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(neovim git ripgrep fd unzip npm tree-sitter-cli)
MODULE_REQUIRED_COMMANDS=(nvim)
MODULE_FILES=("$HOME/.config/nvim")
MODULE_TAGS=(editor neovim development)

install_steps() {
  ensure_directory_user "$HOME/.config/nvim"
  log_info "Neovim packages installed. Existing ~/.config/nvim is not overwritten."
}

delete_steps() {
  log_info "Neovim delete removes the editor package only. User config is preserved."
  remove_packages neovim
}

status_steps() {
  command_exists nvim && return 0
  return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
