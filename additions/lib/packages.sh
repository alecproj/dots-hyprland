#!/usr/bin/env bash
set -euo pipefail

# @api
# kind: function
# name: package_installed
# signature: package_installed PACKAGE
# summary: Test whether an Arch package is installed.
# returns: 0 when installed, 1 otherwise.
# effects: Runs pacman -Q.
# @end
package_installed() {
  command_exists pacman || return 1
  pacman -Q -- "$1" >/dev/null 2>&1
}

# @api
# kind: function
# name: package_available
# signature: package_available PACKAGE
# summary: Test whether a package exists in enabled pacman repositories.
# returns: 0 when available, 1 otherwise.
# effects: Runs pacman -Si.
# @end
package_available() {
  command_exists pacman || return 1
  pacman -Si -- "$1" >/dev/null 2>&1
}

# @api
# kind: function
# name: aur_helper
# signature: aur_helper
# summary: Print the preferred installed AUR helper.
# returns: 0 and prints yay or paru; returns 3 when neither exists.
# effects: Writes the helper name to stdout.
# @end
aur_helper() {
  local helper
  for helper in yay paru; do
    if command_exists "$helper"; then
      printf '%s\n' "$helper"
      return 0
    fi
  done
  return 3
}

# @api
# kind: function
# name: install_packages
# signature: install_packages PACKAGE...
# summary: Install missing repository packages with pacman --needed.
# returns: 0 on success or declined step; exits 3 when pacman is missing.
# effects: May use sudo pacman and records packages newly installed by this module.
# @end
install_packages() {
  local packages=("$@")
  local missing=()
  local package
  [[ "${#packages[@]}" -gt 0 ]] || return 0
  require_command pacman "install the Arch package manager"

  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    package_installed "$package" || missing+=("$package")
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_info "Packages already installed: ${packages[*]:-none}"
    return 0
  fi

  confirm_action packages \
    "Install packages: ${missing[*]}" \
    "Установить пакеты: ${missing[*]}" || return 1
  run_logged sudo pacman -S --needed --noconfirm -- "${missing[@]}"
  for package in "${missing[@]}"; do
    state_record_resource packages "$package"
  done
}

# @api
# kind: function
# name: install_aur_packages
# signature: install_aur_packages PACKAGE...
# summary: Install missing AUR packages with yay, falling back to paru.
# returns: 0 on success or declined step; exits 3 when no supported helper exists.
# effects: Executes the AUR helper and records packages newly installed by this module.
# @end
install_aur_packages() {
  local packages=("$@")
  local missing=()
  local package helper
  [[ "${#packages[@]}" -gt 0 ]] || return 0

  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    package_installed "$package" || missing+=("$package")
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_info "AUR packages already installed: ${packages[*]:-none}"
    return 0
  fi

  helper="$(aur_helper)" || die 3 "AUR helper not found. Install yay or paru, or install manually: ${missing[*]}"
  confirm_action packages \
    "Install AUR packages with $helper: ${missing[*]}" \
    "Установить AUR-пакеты через $helper: ${missing[*]}" || return 1
  run_logged "$helper" -S --needed --noconfirm -- "${missing[@]}"
  for package in "${missing[@]}"; do
    state_record_resource aur_packages "$package"
  done
}

# @api
# kind: function
# name: remove_packages
# signature: remove_packages PACKAGE...
# summary: Remove explicitly requested installed packages with pacman -Rns.
# returns: 0 on success, absence or declined step.
# effects: Uses sudo pacman and clears matching package ownership records.
# notes: Use remove_managed_packages for automatically installed dependencies that must not remove pre-existing packages.
# @end
remove_packages() {
  local packages=("$@")
  local installed=()
  local package
  [[ "${#packages[@]}" -gt 0 ]] || return 1
  require_command pacman "install the Arch package manager"

  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    package_installed "$package" && installed+=("$package")
  done
  if [[ "${#installed[@]}" -eq 0 ]]; then
    log_info "Packages already absent: ${packages[*]:-none}"
    return 0
  fi

  confirm_action packages \
    "Remove packages: ${installed[*]}" \
    "Удалить пакеты: ${installed[*]}" || return 1
  run_logged sudo pacman -Rns --noconfirm -- "${installed[@]}"
  for package in "${installed[@]}"; do
    state_forget_resource packages "$package"
    state_forget_resource aur_packages "$package"
  done
}

# @api
# kind: function
# name: remove_managed_packages
# signature: remove_managed_packages PACKAGE...
# summary: Remove only repository packages recorded as newly installed by this module.
# returns: 0 on success, absence or declined step.
# effects: May call remove_packages.
# @end
remove_managed_packages() {
  local managed=()
  local package
  for package in "$@"; do
    state_has_resource packages "$package" && managed+=("$package")
  done
  [[ "${#managed[@]}" -gt 0 ]] || {
    log_info "No managed repository packages selected for removal"
    return 0
  }
  remove_packages "${managed[@]}"
}

# @api
# kind: function
# name: remove_managed_aur_packages
# signature: remove_managed_aur_packages PACKAGE...
# summary: Remove only AUR packages recorded as newly installed by this module.
# returns: 0 on success, absence or declined step.
# effects: May call remove_packages.
# @end
remove_managed_aur_packages() {
  local managed=()
  local package
  for package in "$@"; do
    state_has_resource aur_packages "$package" && managed+=("$package")
  done
  [[ "${#managed[@]}" -gt 0 ]] || {
    log_info "No managed AUR packages selected for removal"
    return 0
  }
  remove_packages "${managed[@]}"
}
