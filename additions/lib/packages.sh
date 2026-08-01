#!/usr/bin/env bash
set -euo pipefail

package_installed() {
  local package="$1"
  pacman -Q "$package" >/dev/null 2>&1
}

aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    printf '%s\n' yay
    return 0
  fi
  return 3
}

install_packages() {
  local packages=("$@")
  local missing=()
  local package

  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    if ! package_installed "$package"; then
      missing+=("$package")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_info "Packages already installed: ${packages[*]:-none}"
    return 0
  fi

  confirm_action packages "Install packages: ${missing[*]}" || return 0
  log_info "Installing packages: ${missing[*]}"
  sudo pacman -S --needed --noconfirm "${missing[@]}"
}

install_aur_packages() {
  local packages=("$@")
  local missing=()
  local package helper

  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    if ! package_installed "$package"; then
      missing+=("$package")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_info "AUR packages already installed: ${packages[*]:-none}"
    return 0
  fi

  helper="$(aur_helper)" || {
    log_error "AUR helper not found. Install yay or install manually: ${missing[*]}"
    exit 3
  }

  confirm_action packages "Install AUR packages with $helper: ${missing[*]}" || return 0
  log_info "Installing AUR packages with $helper: ${missing[*]}"
  "$helper" -S --needed --noconfirm "${missing[@]}"
}

remove_packages() {
  local packages=("$@")
  local installed=()
  local package

  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    if package_installed "$package"; then
      installed+=("$package")
    fi
  done

  if [[ "${#installed[@]}" -eq 0 ]]; then
    log_info "Packages already absent: ${packages[*]:-none}"
    return 0
  fi

  confirm_action packages "Remove packages: ${installed[*]}" || return 0
  log_info "Removing packages: ${installed[*]}"
  sudo pacman -Rns --noconfirm "${installed[@]}"
}
