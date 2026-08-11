#!/usr/bin/env bash
set -euo pipefail

_EMBEDDED_DIR="$HOME/Embedded"

MODULE_ID="arm-none-eabi"
MODULE_SECTION="embedded"
MODULE_TITLE="Install ARM bare-metal development toolchain"
MODULE_TITLE_RU="Установка ARM toolchain для bare-metal разработки"
MODULE_DESCRIPTION="Installs the Arch ARM bare-metal GCC/Newlib/GDB toolchain together with Git, CMake, Ninja, Make and OpenOCD. Ensures ~/Embedded exists. Delete removes the ARM toolchain and removes shared development tools only when this module installed them."
MODULE_DESCRIPTION_RU="Устанавливает ARM bare-metal toolchain GCC/Newlib/GDB из репозиториев Arch, а также Git, CMake, Ninja, Make и OpenOCD. Проверяет наличие ~/Embedded и создаёт каталог при необходимости. Удаление удаляет ARM toolchain, а общие инструменты разработки — только если их установил этот модуль."
MODULE_VERSION="1"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(
  arm-none-eabi-binutils
  arm-none-eabi-gcc
  arm-none-eabi-newlib
  arm-none-eabi-gdb
  git
  cmake
  ninja
  make
  openocd
)
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=(
  arm-none-eabi-gcc
  arm-none-eabi-g++
  arm-none-eabi-gdb
  git
  cmake
  ninja
  make
  openocd
)
MODULE_FILES=("$_EMBEDDED_DIR")
MODULE_TAGS=(embedded arm bare-metal gcc gdb cmake openocd)

preflight_steps() {
  [[ "$EUID" -ne 0 ]] || die 1 "Run this module as a regular user, not root"
}

install_steps() {
  ensure_directory_user "$_EMBEDDED_DIR"
}

reinstall_steps() {
  install_steps
}

delete_steps() {
  remove_packages \
    arm-none-eabi-gdb \
    arm-none-eabi-newlib \
    arm-none-eabi-gcc \
    arm-none-eabi-binutils

  remove_managed_packages git cmake ninja make openocd

  # ~/Embedded is a shared workspace for the whole section.
  state_forget_resource created_paths "$_EMBEDDED_DIR"
  state_forget_resource managed_paths "$_EMBEDDED_DIR"
}

status_steps() {
  [[ -d "$_EMBEDDED_DIR" ]] || return 5
  command_exists arm-none-eabi-gcc || return 5
  command_exists arm-none-eabi-g++ || return 5
  command_exists arm-none-eabi-gdb || return 5
  command_exists git || return 5
  command_exists cmake || return 5
  command_exists ninja || return 5
  command_exists make || return 5
  command_exists openocd || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
