#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

sudo pacman -S --needed --noconfirm greetd greetd-regreet cage

if ! command -v start-hyprland >/dev/null 2>&1; then
  echo "ERROR: start-hyprland not found in PATH"
  exit 1
fi

sudo install -Dm644 "$ROOT/custom/files/greetd/config.toml" \
  /etc/greetd/config.toml

if [[ -f "$ROOT/custom/files/greetd/regreet.toml" ]]; then
  sudo install -Dm644 "$ROOT/custom/files/greetd/regreet.toml" \
    /etc/greetd/regreet.toml
fi

sudo systemctl disable --now sddm 2>/dev/null || true
sudo systemctl disable --now gdm 2>/dev/null || true
sudo systemctl disable --now ly 2>/dev/null || true
sudo systemctl enable greetd

echo "greetd/ReGreet configured. Reboot to test autologin."
