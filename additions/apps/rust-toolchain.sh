#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="rust-toolchain"
MODULE_SECTION="applications"
MODULE_TITLE="Rust toolchain"
MODULE_TITLE_RU="Инструментарий Rust"
MODULE_DESCRIPTION="Installs the distribution-provided Rust compiler and Cargo tools."
MODULE_DESCRIPTION_RU="Устанавливает компилятор Rust и Cargo из репозиториев дистрибутива."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(rust)
MODULE_REQUIRED_COMMANDS=(rustc cargo)
MODULE_TAGS=(rust development compiler)

install_steps() { true; }
delete_steps() { remove_packages rust; }
status_steps() { package_installed rust && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
