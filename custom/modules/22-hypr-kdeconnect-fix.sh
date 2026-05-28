#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gfhdhytghd/hypr-kdeconnect-fix.git"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
SRC_DIR="$CACHE_DIR/hypr-kdeconnect-fix"

PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
HYPRLAND_PORTAL_CONF="$PORTAL_DIR/hyprland-portals.conf"
FALLBACK_PORTAL_CONF="$PORTAL_DIR/portals.conf"

BACKUP_DIR="$CACHE_DIR/dots-hyprland-custom-backups/hypr-kdeconnect-fix"
STAMP="$(date +%Y%m%d-%H%M%S)"

REMOTE_KEY="org.freedesktop.impl.portal.RemoteDesktop"
REMOTE_VALUE="hypr-kdeconnect"

if [[ "${EUID}" -eq 0 ]]; then
  echo "ERROR: run as user, not root"
  exit 1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing command: $1"
    exit 1
  }
}

patch_portal_conf() {
  local conf="$1"
  local label="$2"
  local tmp

  mkdir -p "$(dirname "$conf")"
  tmp="$(mktemp)"

  if [[ ! -f "$conf" ]]; then
    cat > "$tmp" <<EOF
[preferred]
default = hyprland;gtk
org.freedesktop.impl.portal.FileChooser = kde
${REMOTE_KEY} = ${REMOTE_VALUE}
EOF
  else
    awk -v remote_key="$REMOTE_KEY" -v remote_value="$REMOTE_VALUE" '
      function trim(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        return s
      }

      function section_name(line, name) {
        name = line
        sub(/^[[:space:]]*\[/, "", name)
        sub(/\][[:space:]]*$/, "", name)
        return trim(name)
      }

      function print_remote_if_needed() {
        if (in_preferred && !saw_remote) {
          print remote_key " = " remote_value
          saw_remote = 1
        }
      }

      BEGIN {
        in_preferred = 0
        saw_preferred = 0
        saw_remote = 0
      }

      /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
        print_remote_if_needed()

        in_preferred = (section_name($0) == "preferred")
        if (in_preferred) {
          saw_preferred = 1
        }

        print
        next
      }

      {
        if (in_preferred) {
          key = $0
          sub(/=.*/, "", key)
          key = trim(key)

          if (key == remote_key) {
            if (!saw_remote) {
              print remote_key " = " remote_value
              saw_remote = 1
            }
            next
          }
        }

        print
      }

      END {
        if (!saw_preferred) {
          print ""
          print "[preferred]"
          print "default = hyprland;gtk"
          print "org.freedesktop.impl.portal.FileChooser = kde"
          print remote_key " = " remote_value
        } else {
          print_remote_if_needed()
        }
      }
    ' "$conf" > "$tmp"
  fi

  if [[ ! -f "$conf" ]] || ! cmp -s "$conf" "$tmp"; then
    mkdir -p "$BACKUP_DIR/$STAMP"

    if [[ -f "$conf" ]]; then
      cp -a "$conf" "$BACKUP_DIR/$STAMP/$(basename "$conf")"
    fi

    install -Dm644 "$tmp" "$conf"
    echo "Updated $label: $conf"
  else
    echo "No changes needed for $label: $conf"
  fi

  rm -f "$tmp"
}

need_cmd sudo
need_cmd pacman
need_cmd git
need_cmd awk
need_cmd cmake
need_cmd ctest
need_cmd systemctl

echo "[1/6] Installing dependencies"

pkgs=(
  git
  base-devel
  cmake
  pkgconf
  qt6-base
  wayland
  libxkbcommon
  libei
  xdg-desktop-portal
  kdeconnect
  sshfs
)

missing=()
for p in "${pkgs[@]}"; do
  pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
done

if (( ${#missing[@]} > 0 )); then
  sudo pacman -S --needed "${missing[@]}"
else
  echo "Dependencies already installed"
fi

echo "[2/6] Clone/update source"

mkdir -p "$CACHE_DIR"

if [[ -d "$SRC_DIR/.git" ]]; then
  git -C "$SRC_DIR" pull --ff-only
elif [[ -e "$SRC_DIR" ]]; then
  mv "$SRC_DIR" "${SRC_DIR}.not-git.bak.${STAMP}"
  git clone "$REPO_URL" "$SRC_DIR"
else
  git clone "$REPO_URL" "$SRC_DIR"
fi

echo "[3/6] Build/install to ~/.local"

cmake -S "$SRC_DIR" -B "$SRC_DIR/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local"

cmake --build "$SRC_DIR/build" -j"$(nproc)"
ctest --test-dir "$SRC_DIR/build" --output-on-failure
cmake --install "$SRC_DIR/build"

echo "[4/6] Patch xdg-desktop-portal configs"

mkdir -p "$PORTAL_DIR"

if [[ ! -f "$HYPRLAND_PORTAL_CONF" && -f "$FALLBACK_PORTAL_CONF" ]]; then
  install -Dm644 "$FALLBACK_PORTAL_CONF" "$HYPRLAND_PORTAL_CONF"
fi

patch_portal_conf "$HYPRLAND_PORTAL_CONF" "active Hyprland portal config"

if [[ -f "$FALLBACK_PORTAL_CONF" ]]; then
  patch_portal_conf "$FALLBACK_PORTAL_CONF" "fallback portal config"
else
  echo "Fallback portals.conf not found; skipped: $FALLBACK_PORTAL_CONF"
fi

echo "[5/6] Restart portal backend and KDE Connect"

systemctl --user daemon-reload

systemctl --user stop hypr-kdeconnect-portal.service 2>/dev/null || true
systemctl --user restart xdg-desktop-portal.service

# D-Bus activation may fail on this setup, so keep backend explicitly running.
systemctl --user start hypr-kdeconnect-portal.service

pkill kdeconnectd 2>/dev/null || true
sleep 1

if command -v kdeconnectd >/dev/null 2>&1; then
  nohup kdeconnectd >/tmp/kdeconnectd.log 2>&1 &
  disown || true
else
  echo "WARNING: kdeconnectd not found"
fi

echo "[6/6] Done"
echo
echo "Check:"
echo "  cat ~/.config/xdg-desktop-portal/hyprland-portals.conf"
echo "  cat ~/.config/xdg-desktop-portal/portals.conf"
echo "  busctl --user status org.freedesktop.impl.portal.desktop.hypr_kdeconnect"
echo "  pgrep -a kdeconnectd"
echo "  ~/.local/bin/hypr-kdeconnect-portal --self-test-motion 120 0"
echo "  hyprctl devices | grep -Ei 'hypr-kdeconnect|virtual|unknown-device'"
echo
echo "KDE Connect log:"
echo "  cat /tmp/kdeconnectd.log"
echo
echo "Backup:"
echo "  $BACKUP_DIR/$STAMP"
