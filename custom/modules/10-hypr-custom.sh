#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SRC="$ROOT/custom/files/hypr/custom"
DST="$HOME/.config/hypr/custom"

mkdir -p "$DST"

install -Dm644 "$SRC/general.lua" "$DST/general.lua"
install -Dm644 "$SRC/keybinds.lua" "$DST/keybinds.lua"

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload
fi
