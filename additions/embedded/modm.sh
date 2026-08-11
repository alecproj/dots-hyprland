#!/usr/bin/env bash
set -euo pipefail

_EMBEDDED_DIR="$HOME/Embedded"
_MODM_DIR="$_EMBEDDED_DIR/modm"
_MODM_VENV="$_MODM_DIR/modm-venv"
_MODM_PYTHON_VERSION="3.13.3"
_PYENV_ROOT="$HOME/.pyenv"
_MODM_VERSION_FILE="$_MODM_DIR/.python-version"

_BASH_CONFIG="$HOME/.bashrc"
_FISH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"

MODULE_ID="modm"
MODULE_SECTION="embedded"
MODULE_TITLE="Install modm development environment"
MODULE_TITLE_RU="Установка окружения разработки modm"
MODULE_DESCRIPTION="Installs pyenv and Python build dependencies, installs Python 3.13.3 through pyenv, creates ~/Embedded/modm/modm-venv and installs modm, SCons and pyelftools into it. Configures pyenv for the current login shell and adds a modm-env command that activates the virtual environment on demand, so normal Python usage is not affected."
MODULE_DESCRIPTION_RU="Устанавливает pyenv и зависимости сборки Python, устанавливает Python 3.13.3 через pyenv, создаёт ~/Embedded/modm/modm-venv и устанавливает в него modm, SCons и pyelftools. Настраивает pyenv для текущего login shell и добавляет команду modm-env для активации виртуального окружения по требованию, поэтому обычное использование Python не затрагивается."
MODULE_VERSION="2"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(
  scons
  doxygen
  pyenv
  base-devel
  git
  openssl
  zlib
  xz
  tk
  libffi
  sqlite
  bzip2
  ncurses
  readline
  curl
  python
)
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=(python3 pyenv git)
MODULE_FILES=(
  "$_EMBEDDED_DIR"
  "$_MODM_DIR"
  "$_MODM_VENV"
  "$_MODM_VERSION_FILE"
  "$_BASH_CONFIG"
  "$_FISH_CONFIG"
)
MODULE_TAGS=(embedded modm python pyenv scons lbuild fish bash)

_modm_shell() {
  local shell_path="${SHELL:-}"

  [[ -n "$shell_path" ]] || return 1

  case "$(basename -- "$shell_path")" in
    fish)
      printf '%s\n' fish
      ;;
    bash)
      printf '%s\n' bash
      ;;
    *)
      return 1
      ;;
  esac
}

_modm_shell_config() {
  case "$1" in
    fish)
      printf '%s\n' "$_FISH_CONFIG"
      ;;
    bash)
      printf '%s\n' "$_BASH_CONFIG"
      ;;
    *)
      return 1
      ;;
  esac
}

_modm_shell_block() {
  case "$1" in
    fish)
      cat <<'EOF'
set -gx PYENV_ROOT "$HOME/.pyenv"
test -d "$PYENV_ROOT/bin"; and fish_add_path --path "$PYENV_ROOT/bin"

if command -q pyenv
    pyenv init - fish | source
end

function modm-env
    set -l activate "$HOME/Embedded/modm/modm-venv/bin/activate.fish"

    if not test -f "$activate"
        echo "modm virtual environment not found: $activate" >&2
        return 1
    end

    source "$activate"
end
EOF
      ;;
    bash)
      cat <<'EOF'
export PYENV_ROOT="$HOME/.pyenv"

if [[ -d "$PYENV_ROOT/bin" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

modm-env() {
  local activate="$HOME/Embedded/modm/modm-venv/bin/activate"

  if [[ ! -f "$activate" ]]; then
    printf 'modm virtual environment not found: %s\n' "$activate" >&2
    return 1
  fi

  source "$activate"
}
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

_modm_python_installed() {
  env PYENV_ROOT="$_PYENV_ROOT" pyenv versions --bare 2>/dev/null |
    grep -Fxq "$_MODM_PYTHON_VERSION"
}

_modm_install_python() {
  if _modm_python_installed; then
    log_info "pyenv Python $_MODM_PYTHON_VERSION is already installed"
    return 0
  fi

  run_confirmed local \
    "Build and install Python $_MODM_PYTHON_VERSION with pyenv" \
    "Собрать и установить Python $_MODM_PYTHON_VERSION через pyenv" \
    -- env PYENV_ROOT="$_PYENV_ROOT" pyenv install "$_MODM_PYTHON_VERSION"
}

_modm_prepare_venv() {
  if [[ -e "$_MODM_VENV" || -L "$_MODM_VENV" ]]; then
    [[ -d "$_MODM_VENV" && -x "$_MODM_VENV/bin/python" ]] ||
      die 1 "Existing modm virtual environment is incomplete or conflicting: $_MODM_VENV"

    log_info "modm virtual environment already present: $_MODM_VENV"
    return 0
  fi

  run_confirmed local \
    "Create modm virtual environment with Python $_MODM_PYTHON_VERSION" \
    "Создать виртуальное окружение modm на Python $_MODM_PYTHON_VERSION" \
    -- env \
      PYENV_ROOT="$_PYENV_ROOT" \
      PYENV_VERSION="$_MODM_PYTHON_VERSION" \
      pyenv exec python -m venv "$_MODM_VENV"

  state_record_resource created_paths "$_MODM_VENV"
  state_record_resource managed_paths "$_MODM_VENV"
}

_modm_install_python_packages() {
  run_confirmed local \
    "Install or update modm, SCons and pyelftools in the virtual environment" \
    "Установить или обновить modm, SCons и pyelftools в виртуальном окружении" \
    -- "$_MODM_VENV/bin/python" -m pip install \
      --upgrade \
      pip \
      modm \
      scons \
      pyelftools
}

_modm_install_shell_config() {
  local shell_name shell_config shell_block

  shell_name="$(_modm_shell)" ||
    die 3 "Unsupported login shell: ${SHELL:-unknown}. Supported shells: bash, fish"

  shell_config="$(_modm_shell_config "$shell_name")"
  shell_block="$(_modm_shell_block "$shell_name")"

  ensure_directory_user "$(dirname -- "$shell_config")"

  managed_block \
    "$shell_config" \
    "${MODULE_ID}-environment" \
    "#" \
    "$shell_block"
}

_modm_remove_shell_configs() {
  remove_managed_block \
    "$_BASH_CONFIG" \
    "${MODULE_ID}-environment" \
    "#"

  remove_managed_block \
    "$_FISH_CONFIG" \
    "${MODULE_ID}-environment" \
    "#"
}

_modm_shell_configured() {
  local shell_name shell_config

  shell_name="$(_modm_shell)" || return 1
  shell_config="$(_modm_shell_config "$shell_name")" || return 1

  managed_block_exists \
    "$shell_config" \
    "${MODULE_ID}-environment" \
    "#"
}

preflight_steps() {
  local action="$1"

  [[ "$EUID" -ne 0 ]] ||
    die 1 "Run this module as a regular user, not root"

  case "$action" in
    install|reinstall)
      _modm_shell >/dev/null ||
        die 3 "Unsupported login shell: ${SHELL:-unknown}. Supported shells: bash, fish"
      ;;
  esac
}

install_steps() {
  ensure_directory_user "$_EMBEDDED_DIR"
  ensure_directory_user "$_MODM_DIR"

  _modm_install_python

  write_file_user \
    "$_MODM_VERSION_FILE" \
    "$_MODM_PYTHON_VERSION"$'\n'

  _modm_prepare_venv
  _modm_install_python_packages
  _modm_install_shell_config
}

reinstall_steps() {
  install_steps
}

delete_steps() {
  _modm_remove_shell_configs
  remove_managed_path "$_MODM_VERSION_FILE"

  if state_has_resource created_paths "$_MODM_VENV"; then
    remove_managed_path "$_MODM_VENV"
  else
    log_info "Preserving pre-existing modm virtual environment: $_MODM_VENV"
  fi

  # These directories are shared/user workspaces.
  # Release ownership without deleting them.
  state_forget_resource created_paths "$_MODM_DIR"
  state_forget_resource managed_paths "$_MODM_DIR"
  state_forget_resource created_paths "$_EMBEDDED_DIR"
  state_forget_resource managed_paths "$_EMBEDDED_DIR"

  log_info "Preserving system packages and pyenv Python $_MODM_PYTHON_VERSION"
}

status_steps() {
  [[ -d "$_EMBEDDED_DIR" ]] || return 5
  [[ -d "$_MODM_DIR" ]] || return 5

  command_exists pyenv || return 5
  _modm_python_installed || return 5

  [[ -f "$_MODM_VERSION_FILE" ]] || return 5
  [[ "$(cat "$_MODM_VERSION_FILE")" == "$_MODM_PYTHON_VERSION" ]] || return 5

  [[ -x "$_MODM_VENV/bin/python" ]] || return 5
  [[ -x "$_MODM_VENV/bin/lbuild" ]] || return 5
  [[ -x "$_MODM_VENV/bin/scons" ]] || return 5

  "$_MODM_VENV/bin/python" -c 'import elftools' >/dev/null 2>&1 ||
    return 5

  _modm_shell_configured || return 5

  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
