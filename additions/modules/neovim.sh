#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="neovim"
MODULE_SECTION="additions"
MODULE_TITLE="Install Alec's Neovim environment"
MODULE_TITLE_RU="Установка окружения Neovim от Alec"
MODULE_DESCRIPTION="Installs the Neovim toolchain, clones or safely updates alecproj/myneovim, installs missing global npm tools, Lazy plugins, Mason packages and Treesitter parsers. A conflicting non-Git directory or repository with another origin stops installation without modifying it. Local repository changes are preserved and skip the update. Delete removes only the Neovim package and preserves configuration, plugins, npm tools and development dependencies."
MODULE_DESCRIPTION_RU="Устанавливает окружение Neovim, безопасно клонирует или обновляет alecproj/myneovim, ставит недостающие глобальные npm-инструменты, плагины Lazy, пакеты Mason и парсеры Treesitter. Конфликтующий обычный каталог или Git-репозиторий с другим origin останавливает установку без изменения данных. Локальные изменения репозитория сохраняются, а обновление пропускается. Удаление удаляет только пакет Neovim и сохраняет конфигурацию, плагины, npm-инструменты и зависимости разработки."
MODULE_VERSION="2"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(
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
  tree-sitter-cli
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
MODULE_REQUIRED_COMMANDS=(git nvim npm timeout fd rg python3)
MODULE_FILES=("$HOME/.config/nvim")
MODULE_TAGS=(editor neovim development lsp mason treesitter personal)

_NEOVIM_REPO_SSH="git@github.com:alecproj/myneovim.git"
_NEOVIM_REPO_HTTPS="https://github.com/alecproj/myneovim.git"
_NEOVIM_REPO_URL="${NEOVIM_REPO_URL:-$_NEOVIM_REPO_HTTPS}"
_NEOVIM_DIR="$HOME/.config/nvim"
_NEOVIM_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
_NEOVIM_MASON_DIR="$_NEOVIM_DATA_DIR/nvim/mason"
_NEOVIM_SITE_DIR="$_NEOVIM_DATA_DIR/nvim/site"
_NEOVIM_TIMEOUT="${NVIM_TIMEOUT:-300s}"

_neovim_prepare_repo() {
  git_sync_repo \
    "$_NEOVIM_REPO_URL" \
    "$_NEOVIM_DIR" \
    "$_NEOVIM_REPO_HTTPS" \
    "$_NEOVIM_REPO_SSH"
}

_neovim_npm_package_installed() {
  npm list -g --depth=0 "$1" >/dev/null 2>&1
}

_neovim_install_npm_tools() {
  local -a missing=()
  command_exists tree-sitter || missing+=(tree-sitter-cli)
  command_exists tsc || missing+=(typescript)
  command_exists opencode || missing+=(opencode-ai)
  _neovim_npm_package_installed neovim || missing+=(neovim)
  [[ "${#missing[@]}" -gt 0 ]] || {
    log_info "Global npm tools are already installed"
    return 0
  }
  run_confirmed packages \
    "Install global npm tools: ${missing[*]}" \
    "Установить глобальные npm-инструменты: ${missing[*]}" \
    -- sudo npm install -g --no-audit --no-fund -- "${missing[@]}"
}

_neovim_run_headless() {
  local message_en="$1"
  local message_ru="$2"
  shift 2
  run_confirmed all "$message_en" "$message_ru" \
    -- timeout "$_NEOVIM_TIMEOUT" nvim --headless "$@"
}

_neovim_mason_package_installed() {
  [[ -d "$_NEOVIM_MASON_DIR/packages/$1" ]]
}

_neovim_treesitter_parser_installed() {
  local language="$1"
  [[ -f "$_NEOVIM_SITE_DIR/parser/$language.so" ]] ||
    [[ -f "$HOME/.local/share/nvim/site/parser/$language.so" ]] ||
    [[ -f "$HOME/.local/share/nvim/lazy/nvim-treesitter/parser/$language.so" ]] ||
    [[ -f "/usr/share/nvim/runtime/parser/$language.so" ]]
}

_neovim_install_plugins() {
  if [[ "${FORCE_UPDATE:-0}" == "1" ]]; then
    _neovim_run_headless \
      "Synchronize Neovim plugins" \
      "Синхронизировать плагины Neovim" \
      "+Lazy! sync" "+qa"
  else
    _neovim_run_headless \
      "Install missing Neovim plugins" \
      "Установить недостающие плагины Neovim" \
      "+Lazy! install" "+qa"
  fi
}

_neovim_install_mason_packages() {
  local package
  local -a wanted=(
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
  local -a missing=()
  for package in "${wanted[@]}"; do
    _neovim_mason_package_installed "$package" || missing+=("$package")
  done
  [[ "${#missing[@]}" -gt 0 ]] || {
    log_info "Mason packages are already installed"
    return 0
  }
  _neovim_run_headless \
    "Update Mason registry" \
    "Обновить реестр Mason" \
    "+MasonUpdate" "+qa"
  _neovim_run_headless \
    "Install Mason packages: ${missing[*]}" \
    "Установить пакеты Mason: ${missing[*]}" \
    "+MasonInstall ${missing[*]}" "+qa"
}

_neovim_install_treesitter_parsers() {
  local parser
  local -a wanted=(c cpp lua python javascript markdown html bash latex)
  local -a missing=()
  for parser in "${wanted[@]}"; do
    _neovim_treesitter_parser_installed "$parser" || missing+=("$parser")
  done
  [[ "${#missing[@]}" -gt 0 ]] || {
    log_info "Treesitter parsers are already installed"
    return 0
  }
  _neovim_run_headless \
    "Install Treesitter parsers: ${missing[*]}" \
    "Установить парсеры Treesitter: ${missing[*]}" \
    "+TSInstallSync ${missing[*]}" "+qa"
}

preflight_steps() {
  [[ "$EUID" -ne 0 ]] || die 1 "Run this module as a regular user, not root"
}

install_steps() {
  _neovim_prepare_repo
  _neovim_install_npm_tools
  _neovim_install_plugins
  _neovim_install_mason_packages
  _neovim_install_treesitter_parsers

  if [[ "${RUN_HEALTH:-0}" == "1" ]]; then
    _neovim_run_headless \
      "Run Neovim health checks" \
      "Запустить диагностику Neovim" \
      "+checkhealth mason" \
      "+checkhealth vim.lsp" \
      "+checkhealth provider" \
      "+checkhealth clipboard" \
      "+qa" || log_warn "Neovim health check reported errors"
  fi
}

reinstall_steps() {
  install_steps
}

delete_steps() {
  log_info "Removing the Neovim package only; configuration, plugins, npm tools and dependencies are preserved"
  remove_packages neovim
}

status_steps() {
  command_exists nvim || return 5
  git_repo_matches \
    "$_NEOVIM_DIR" \
    "$_NEOVIM_REPO_URL" \
    "$_NEOVIM_REPO_HTTPS" \
    "$_NEOVIM_REPO_SSH" || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
