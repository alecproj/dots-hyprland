#!/usr/bin/env bash
set -euo pipefail

USER_NAME="alec"
USER_HOME="/home/alec"
MUSIC_DIR="/srv/music"
NAVIDROME_DATA_DIR="/var/lib/navidrome"
NICOTINE_DATA_DIR="$USER_HOME/Music/data/nicotine"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ "$(id -un)" != "$USER_NAME" ]]; then
  echo "ERROR: run as $USER_NAME, not root"
  exit 1
fi

if [[ ! -d "$USER_HOME" ]]; then
  echo "ERROR: $USER_HOME not found"
  exit 1
fi

echo "==> Installing packages"
sudo pacman -S --needed --noconfirm navidrome feishin nicotine+

echo "==> Checking navidrome user"
if ! id navidrome >/dev/null 2>&1; then
  echo "ERROR: system user 'navidrome' was not created by package install"
  exit 1
fi

echo "==> Creating music library"
sudo install -d -o "$USER_NAME" -g navidrome -m 2775 "$MUSIC_DIR"
sudo install -d -o "$USER_NAME" -g navidrome -m 2775 "$MUSIC_DIR/new"
sudo install -d -o "$USER_NAME" -g navidrome -m 2775 "$MUSIC_DIR/favorites"
sudo install -d -o "$USER_NAME" -g navidrome -m 2775 "$MUSIC_DIR/playlists"

echo "==> Creating Navidrome data dirs"
sudo install -d -o navidrome -g navidrome -m 755 "$NAVIDROME_DATA_DIR"
sudo install -d -o navidrome -g navidrome -m 755 "$NAVIDROME_DATA_DIR/cache"

echo "==> Creating Nicotine+ dirs"
install -d -m 755 "$NICOTINE_DATA_DIR/incomplete"

echo "==> Creating ~/Music/library symlink"
install -d -m 755 "$USER_HOME/Music"

if [[ -L "$USER_HOME/Music/library" ]]; then
  current_target="$(readlink -f "$USER_HOME/Music/library" || true)"
  if [[ "$current_target" != "$MUSIC_DIR" ]]; then
    mv "$USER_HOME/Music/library" "$USER_HOME/Music/library.bak.$STAMP"
    ln -s "$MUSIC_DIR" "$USER_HOME/Music/library"
  fi
elif [[ -e "$USER_HOME/Music/library" ]]; then
  if [[ -d "$USER_HOME/Music/library" ]] && [[ -z "$(find "$USER_HOME/Music/library" -mindepth 1 -print -quit)" ]]; then
    rmdir "$USER_HOME/Music/library"
    ln -s "$MUSIC_DIR" "$USER_HOME/Music/library"
  else
    echo "ERROR: $USER_HOME/Music/library exists and is not empty."
    echo "Move it manually before rerun:"
    echo "  sudo cp -a \"$USER_HOME/Music/library/.\" \"$MUSIC_DIR/\""
    echo "  mv \"$USER_HOME/Music/library\" \"$USER_HOME/Music/library.bak.$STAMP\""
    echo "  ln -s \"$MUSIC_DIR\" \"$USER_HOME/Music/library\""
    exit 1
  fi
else
  ln -s "$MUSIC_DIR" "$USER_HOME/Music/library"
fi

echo "==> Installing Navidrome config"
if [[ -f /etc/navidrome/navidrome.toml ]] && ! cmp -s "$REPO_ROOT/custom/files/navidrome/navidrome.toml" /etc/navidrome/navidrome.toml; then
  sudo cp -a /etc/navidrome/navidrome.toml "/etc/navidrome/navidrome.toml.bak.$STAMP"
  echo "Backup: /etc/navidrome/navidrome.toml.bak.$STAMP"
fi

sudo install -Dm644 \
  "$REPO_ROOT/custom/files/navidrome/navidrome.toml" \
  /etc/navidrome/navidrome.toml

echo "==> Checking access"
sudo -u navidrome test -r "$MUSIC_DIR" || {
  echo "ERROR: navidrome cannot read $MUSIC_DIR"
  exit 1
}

sudo -u navidrome test -w "$NAVIDROME_DATA_DIR" || {
  echo "ERROR: navidrome cannot write to $NAVIDROME_DATA_DIR"
  exit 1
}

echo "==> Starting Navidrome"
sudo systemctl daemon-reload
sudo systemctl enable --now navidrome.service
sudo systemctl restart navidrome.service

echo
echo "OK"
echo "Navidrome: http://127.0.0.1:4533"
echo "Music:     $USER_HOME/Music/library -> $MUSIC_DIR"
echo "Data:      $NAVIDROME_DATA_DIR"
