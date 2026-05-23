#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

install_list() {
  grep -vE '^\s*(#|$)' "$1"
}

PACMAN_LIST="$ROOT/custom/packages/personal-pacman.txt"
AUR_LIST="$ROOT/custom/packages/personal-aur.txt"

if [[ -s "$PACMAN_LIST" ]]; then
  install_list "$PACMAN_LIST" | xargs -r sudo pacman -S --needed --noconfirm
fi

if [[ -s "$AUR_LIST" ]]; then
  command -v yay >/dev/null 2>&1 || {
    echo "yay not found; skipping AUR personal packages."
    exit 1
  }

  install_list "$AUR_LIST" | xargs -r yay -S --needed --noconfirm
fi
