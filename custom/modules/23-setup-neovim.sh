#!/usr/bin/env bash
set -euo pipefail

REPO_SSH="git@github.com:alecproj/myneovim.git"
REPO_HTTPS="https://github.com/alecproj/myneovim.git"

NVIM_DIR="$HOME/.config/nvim"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
MASON_DIR="$DATA_DIR/nvim/mason"
NVIM_SITE_DIR="$DATA_DIR/nvim/site"

BACKUP_DIR="$CACHE_DIR/dots-hyprland-custom-backups/neovim"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$BACKUP_DIR/logs"

NVIM_TIMEOUT="${NVIM_TIMEOUT:-300s}"
RUN_HEALTH="${RUN_HEALTH:-0}"
FORCE_UPDATE="${FORCE_UPDATE:-0}"

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

repo_matches() {
  local url="$1"

  case "$url" in
    "$REPO_SSH"|"$REPO_HTTPS"|"https://github.com/alecproj/myneovim")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

backup_existing_nvim() {
  mkdir -p "$BACKUP_DIR"

  if [[ -e "$NVIM_DIR" ]]; then
    local target="$BACKUP_DIR/nvim.$STAMP"
    mv "$NVIM_DIR" "$target"
    echo "Backup saved: $target"
  fi
}

run_nvim_headless() {
  local log_file="$1"
  shift

  timeout "$NVIM_TIMEOUT" nvim --headless "$@" >"$log_file" 2>&1 || {
    local code="$?"
    echo "ERROR: nvim headless command failed or timed out"
    echo "Exit code: $code"
    echo "Log: $log_file"
    tail -n 100 "$log_file" || true
    exit "$code"
  }
}

pacman_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

npm_pkg_installed() {
  npm list -g --depth=0 "$1" >/dev/null 2>&1
}

mason_pkg_installed() {
  [[ -d "$MASON_DIR/packages/$1" ]]
}

treesitter_parser_installed() {
  local lang="$1"

  [[ -f "$NVIM_SITE_DIR/parser/$lang.so" ]] && return 0
  [[ -f "$HOME/.local/share/nvim/site/parser/$lang.so" ]] && return 0
  [[ -f "$HOME/.local/share/nvim/lazy/nvim-treesitter/parser/$lang.so" ]] && return 0
  [[ -f "/usr/share/nvim/runtime/parser/$lang.so" ]] && return 0

  return 1
}

need_cmd sudo
need_cmd pacman
need_cmd timeout

mkdir -p "$LOG_DIR"

echo "[1/7] Installing missing pacman dependencies"

pacman_pkgs=(
  neovim
  git
  base-devel
  nodejs
  npm
  python
  python-pip
  python-pynvim
  curl
  wget
  unzip
  tar
  gzip
  fd
  ripgrep
  xclip
  wl-clipboard
  jdk-openjdk
  qt6-declarative
  texlive-xetex
  texlive-latex
  texlive-latexrecommended
  texlive-latexextra
  texlive-fontsrecommended
  texlive-binextra
  biber
  zathura
  zathura-pdf-mupdf
  luarocks
  lsof
)

missing_pacman=()
for pkg in "${pacman_pkgs[@]}"; do
  pacman_installed "$pkg" || missing_pacman+=("$pkg")
done

if (( ${#missing_pacman[@]} > 0 )); then
  sudo pacman -S --needed --noconfirm "${missing_pacman[@]}"
else
  echo "Pacman dependencies already installed"
fi

need_cmd git
need_cmd nvim
need_cmd npm
need_cmd fd
need_cmd rg

echo "[2/7] Installing missing global npm tools"

missing_npm=()

command -v tree-sitter >/dev/null 2>&1 || missing_npm+=("tree-sitter-cli")
command -v tsc >/dev/null 2>&1 || missing_npm+=("typescript")
command -v opencode >/dev/null 2>&1 || missing_npm+=("opencode-ai")
npm_pkg_installed neovim || missing_npm+=("neovim")

if (( ${#missing_npm[@]} > 0 )); then
  sudo npm install -g --no-audit --no-fund "${missing_npm[@]}"
else
  echo "Global npm tools already installed"
fi

echo "[3/7] Clone/update Neovim config"

mkdir -p "$(dirname "$NVIM_DIR")"

export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new}"

if [[ -d "$NVIM_DIR/.git" ]]; then
  origin_url="$(git -C "$NVIM_DIR" remote get-url origin 2>/dev/null || true)"

  if repo_matches "$origin_url"; then
    echo "Existing myneovim repo found"

    git -C "$NVIM_DIR" remote set-url origin "$REPO_SSH"

    if [[ -n "$(git -C "$NVIM_DIR" status --porcelain)" ]]; then
      echo "Local changes detected; skipping git pull"
    else
      git -C "$NVIM_DIR" fetch --prune origin

      if [[ "$FORCE_UPDATE" == "1" ]]; then
        git -C "$NVIM_DIR" pull --ff-only
      else
        local_branch="$(git -C "$NVIM_DIR" rev-parse --abbrev-ref HEAD)"
        upstream_ref="$(git -C "$NVIM_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

        if [[ -n "$upstream_ref" ]]; then
          local_rev="$(git -C "$NVIM_DIR" rev-parse HEAD)"
          upstream_rev="$(git -C "$NVIM_DIR" rev-parse "$upstream_ref")"
          base_rev="$(git -C "$NVIM_DIR" merge-base HEAD "$upstream_ref")"

          if [[ "$local_rev" == "$upstream_rev" ]]; then
            echo "Repo already up to date"
          elif [[ "$local_rev" == "$base_rev" ]]; then
            git -C "$NVIM_DIR" pull --ff-only
          else
            echo "Local branch '$local_branch' diverged from '$upstream_ref'; skipping pull"
          fi
        else
          echo "No upstream branch configured; skipping pull"
        fi
      fi
    fi
  else
    echo "Existing ~/.config/nvim is a different git repo: ${origin_url:-unknown}"
    backup_existing_nvim
    git clone "$REPO_SSH" "$NVIM_DIR"
  fi
elif [[ -e "$NVIM_DIR" ]]; then
  echo "Existing ~/.config/nvim is not a git repo"
  backup_existing_nvim
  git clone "$REPO_SSH" "$NVIM_DIR"
else
  git clone "$REPO_SSH" "$NVIM_DIR"
fi

echo "[4/7] Install missing lazy.nvim plugins"

if [[ "$FORCE_UPDATE" == "1" ]]; then
  run_nvim_headless \
    "$LOG_DIR/lazy-sync.$STAMP.log" \
    "+Lazy! sync" \
    "+qa"
else
  run_nvim_headless \
    "$LOG_DIR/lazy-install.$STAMP.log" \
    "+Lazy! install" \
    "+qa"
fi

echo "[5/7] Install missing Mason packages"

mason_pkgs=(
  lua-language-server
  pyright
  ruff
  typescript-language-server
  ltex-ls
  clangd
  clang-format
  cortex-debug
  bash-language-server
  qmlls
)

missing_mason=()
for pkg in "${mason_pkgs[@]}"; do
  mason_pkg_installed "$pkg" || missing_mason+=("$pkg")
done

if (( ${#missing_mason[@]} > 0 )); then
  echo "Missing Mason packages: ${missing_mason[*]}"

  run_nvim_headless \
    "$LOG_DIR/mason-update.$STAMP.log" \
    "+MasonUpdate" \
    "+qa"

  run_nvim_headless \
    "$LOG_DIR/mason-install.$STAMP.log" \
    "+MasonInstall ${missing_mason[*]}" \
    "+qa"
else
  echo "Mason packages already installed; skipping MasonUpdate/MasonInstall"
fi

echo "[6/7] Install missing Treesitter parsers"

treesitter_parsers=(
  c
  cpp
  lua
  python
  javascript
  markdown
  html
  bash
  latex
)

missing_ts=()
for parser in "${treesitter_parsers[@]}"; do
  treesitter_parser_installed "$parser" || missing_ts+=("$parser")
done

if (( ${#missing_ts[@]} > 0 )); then
  echo "Missing Treesitter parsers: ${missing_ts[*]}"

  run_nvim_headless \
    "$LOG_DIR/treesitter-install.$STAMP.log" \
    "+TSInstallSync ${missing_ts[*]}" \
    "+qa"
else
  echo "Treesitter parsers already installed; skipping TSInstallSync"
fi

echo "[7/7] Health check"

if [[ "$RUN_HEALTH" == "1" ]]; then
  nvim --headless \
    "+checkhealth mason" \
    "+checkhealth vim.lsp" \
    "+checkhealth provider" \
    "+checkhealth clipboard" \
    "+qa" \
    >"$LOG_DIR/checkhealth.$STAMP.log" 2>&1 || true

  echo "Health log:"
  echo "  $LOG_DIR/checkhealth.$STAMP.log"
else
  echo "Skipped. Run with RUN_HEALTH=1 to enable checkhealth."
fi

echo "Done"
echo
echo "Config:"
echo "  $NVIM_DIR"
echo
echo "Logs:"
echo "  $LOG_DIR"
echo
echo "Useful commands:"
echo "  nvim"
echo "  nvim +Lazy"
echo "  nvim +Mason"
echo "  RUN_HEALTH=1 ./custom/modules/23-setup-neovim.sh"
echo "  FORCE_UPDATE=1 ./custom/modules/23-setup-neovim.sh"
