#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT

# shellcheck source=additions/lib/log.sh
source "$ROOT/additions/lib/log.sh"
# shellcheck source=additions/lib/confirm.sh
source "$ROOT/additions/lib/confirm.sh"
# shellcheck source=additions/lib/state.sh
source "$ROOT/additions/lib/state.sh"
# shellcheck source=additions/lib/commands.sh
source "$ROOT/additions/lib/commands.sh"
# shellcheck source=additions/lib/backup.sh
source "$ROOT/additions/lib/backup.sh"
# shellcheck source=additions/lib/files.sh
source "$ROOT/additions/lib/files.sh"
# shellcheck source=additions/lib/blocks.sh
source "$ROOT/additions/lib/blocks.sh"
# shellcheck source=additions/lib/lua.sh
source "$ROOT/additions/lib/lua.sh"
# shellcheck source=additions/lib/packages.sh
source "$ROOT/additions/lib/packages.sh"
# shellcheck source=additions/lib/systemd.sh
source "$ROOT/additions/lib/systemd.sh"

# @api
# kind: metadata
# name: MODULE_ID
# required: true
# type: slug
# summary: Stable unique module identifier; must match the script filename without .sh.
# @end
# @api
# kind: metadata
# name: MODULE_SECTION
# required: false
# type: slug
# default: additions
# summary: Dynamic TUI section identifier; applications are placed in the applications section.
# @end
# @api
# kind: metadata
# name: MODULE_TITLE
# required: true
# type: string
# summary: Short English display title.
# @end
# @api
# kind: metadata
# name: MODULE_TITLE_RU
# required: false
# type: string
# summary: Optional Russian display title.
# @end
# @api
# kind: metadata
# name: MODULE_DESCRIPTION
# required: true
# type: string
# summary: English description of effects, preserved data and important limitations.
# @end
# @api
# kind: metadata
# name: MODULE_DESCRIPTION_RU
# required: false
# type: string
# summary: Optional Russian description.
# @end
# @api
# kind: metadata
# name: MODULE_VERSION
# required: false
# type: string
# default: 1
# summary: Module implementation version shown in generated API metadata.
# @end
# @api
# kind: metadata
# name: MODULE_DANGER
# required: false
# type: enum
# values: low, medium, high
# default: medium
# summary: Risk level used by the TUI and runner failure policy.
# @end
# @api
# kind: metadata
# name: MODULE_DEFAULT_ACTION
# required: false
# type: enum
# values: install, delete, reinstall, skip
# default: skip
# summary: Initial TUI action; non-skip values must be supported by MODULE_SUPPORTED_ACTIONS.
# @end
# @api
# kind: metadata
# name: MODULE_SUPPORTED_ACTIONS
# required: false
# type: array
# default: install delete reinstall
# summary: Actions implemented by the module; skip is always added by the TUI.
# @end
# @api
# kind: metadata
# name: MODULE_PACKAGES
# required: false
# type: array
# summary: Official repository packages installed automatically before install_steps.
# @end
# @api
# kind: metadata
# name: MODULE_AUR_PACKAGES
# required: false
# type: array
# summary: AUR packages installed automatically before install_steps.
# @end
# @api
# kind: metadata
# name: MODULE_REQUIRED_COMMANDS
# required: false
# type: array
# summary: Commands required after package installation and before module-specific install/reinstall steps.
# @end
# @api
# kind: metadata
# name: MODULE_FILES
# required: false
# type: array
# summary: Human-readable list of paths potentially managed by the module.
# @end
# @api
# kind: metadata
# name: MODULE_TAGS
# required: false
# type: array
# summary: Searchable descriptive tags included in generated API output.
# @end
# @api
# kind: metadata
# name: MODULE_VERIFY
# required: false
# type: boolean
# default: true
# summary: Verify status_steps after successful install, delete and reinstall actions.
# @end

for array_name in MODULE_PACKAGES MODULE_AUR_PACKAGES MODULE_REQUIRED_COMMANDS MODULE_FILES MODULE_TAGS; do
  if ! declare -p "$array_name" >/dev/null 2>&1; then
    declare -ag "$array_name=()"
  fi
done
if ! declare -p MODULE_SUPPORTED_ACTIONS >/dev/null 2>&1; then
  declare -ag MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
fi
MODULE_SECTION="${MODULE_SECTION:-additions}"
MODULE_VERSION="${MODULE_VERSION:-1}"
MODULE_DANGER="${MODULE_DANGER:-medium}"
MODULE_DEFAULT_ACTION="${MODULE_DEFAULT_ACTION:-skip}"
MODULE_VERIFY="${MODULE_VERIFY:-true}"
MODULE_DESCRIPTION="${MODULE_DESCRIPTION:-}"
MODULE_TITLE_RU="${MODULE_TITLE_RU:-}"
MODULE_DESCRIPTION_RU="${MODULE_DESCRIPTION_RU:-}"

_module_json_quote() {
  local value="$1"
  value="${value//\/\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "$value"
}

_module_json_array() {
  local first=true item
  printf '['
  for item in "$@"; do
    if [[ "$first" == true ]]; then first=false; else printf ', '; fi
    _module_json_quote "$item"
  done
  printf ']'
}

_module_json_localized() {
  local english="$1"
  local russian="${2:-}"
  printf '{"en": '
  _module_json_quote "$english"
  if [[ -n "$russian" ]]; then
    printf ', "ru": '
    _module_json_quote "$russian"
  fi
  printf '}'
}

_module_action_supported() {
  local requested="$1" action
  for action in "${MODULE_SUPPORTED_ACTIONS[@]}"; do
    [[ "$action" == "$requested" ]] && return 0
  done
  return 1
}

_module_validate_unique_array() {
  local array_name="$1"
  local -n values="$array_name"
  local seen=" " value
  for value in "${values[@]}"; do
    [[ -n "$value" ]] || die 2 "$array_name contains an empty value"
    [[ "$seen" != *" $value "* ]] || die 2 "$array_name contains duplicate value: $value"
    seen+="$value "
  done
}

_module_validate_contract() {
  : "${MODULE_ID:?MODULE_ID is required}"
  : "${MODULE_TITLE:?MODULE_TITLE is required}"
  : "${MODULE_DESCRIPTION:?MODULE_DESCRIPTION is required}"
  [[ "$MODULE_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die 2 "Invalid MODULE_ID: $MODULE_ID"
  [[ "$MODULE_SECTION" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die 2 "Invalid MODULE_SECTION: $MODULE_SECTION"
  case "$MODULE_DANGER" in low|medium|high) ;; *) die 2 "Invalid MODULE_DANGER: $MODULE_DANGER" ;; esac
  case "$MODULE_VERIFY" in true|false) ;; *) die 2 "Invalid MODULE_VERIFY: $MODULE_VERIFY" ;; esac

  _module_validate_unique_array MODULE_SUPPORTED_ACTIONS
  local action
  for action in "${MODULE_SUPPORTED_ACTIONS[@]}"; do
    case "$action" in install|delete|reinstall) ;; *) die 2 "Invalid supported action: $action" ;; esac
  done
  if [[ "$MODULE_DEFAULT_ACTION" != "skip" ]] && ! _module_action_supported "$MODULE_DEFAULT_ACTION"; then
    die 2 "MODULE_DEFAULT_ACTION is not supported: $MODULE_DEFAULT_ACTION"
  fi

  declare -F status_steps >/dev/null 2>&1 || die 2 "Module must define status_steps"
  if _module_action_supported install; then
    declare -F install_steps >/dev/null 2>&1 || die 2 "Install action requires install_steps"
  fi
  if _module_action_supported delete; then
    declare -F delete_steps >/dev/null 2>&1 || die 2 "Delete action requires delete_steps"
  fi
  if _module_action_supported reinstall && ! declare -F reinstall_steps >/dev/null 2>&1; then
    _module_action_supported install && _module_action_supported delete || \
      die 2 "Reinstall requires reinstall_steps or both install and delete support"
  fi
}

_module_meta() {
  cat <<JSON
{
  "id": $(_module_json_quote "$MODULE_ID"),
  "section": $(_module_json_quote "$MODULE_SECTION"),
  "title": $(_module_json_quote "$MODULE_TITLE"),
  "description": $(_module_json_quote "$MODULE_DESCRIPTION"),
  "title_i18n": $(_module_json_localized "$MODULE_TITLE" "$MODULE_TITLE_RU"),
  "description_i18n": $(_module_json_localized "$MODULE_DESCRIPTION" "$MODULE_DESCRIPTION_RU"),
  "version": $(_module_json_quote "$MODULE_VERSION"),
  "packages": $(_module_json_array "${MODULE_PACKAGES[@]}"),
  "aur_packages": $(_module_json_array "${MODULE_AUR_PACKAGES[@]}"),
  "required_commands": $(_module_json_array "${MODULE_REQUIRED_COMMANDS[@]}"),
  "files": $(_module_json_array "${MODULE_FILES[@]}"),
  "tags": $(_module_json_array "${MODULE_TAGS[@]}"),
  "supported_actions": $(_module_json_array "${MODULE_SUPPORTED_ACTIONS[@]}"),
  "verify": $MODULE_VERIFY,
  "danger": $(_module_json_quote "$MODULE_DANGER"),
  "default_action": $(_module_json_quote "$MODULE_DEFAULT_ACTION")
}
JSON
}

_module_mark_state() {
  _state_cli mark "$1" "$2" "$3"
}

_module_usage() {
  cat >&2 <<EOF
Usage: $0 meta|status|install|delete|reinstall [--policy=noconfirm|confirm-local|confirm-all] [--backup=true|false] [--lang=en|ru]
EOF
}

_module_parse_args() {
  COMMAND="${1:-}"
  [[ -n "$COMMAND" ]] || { _module_usage; exit 2; }
  shift || true
  POLICY="noconfirm"
  BACKUP="true"
  ADDITIONS_LANG="en"
  CONFIRM_DECLINED=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --policy=*) POLICY="${1#--policy=}" ;;
      --backup=*) BACKUP="${1#--backup=}" ;;
      --lang=*) ADDITIONS_LANG="${1#--lang=}" ;;
      *) log_error "Unknown argument: $1"; _module_usage; exit 2 ;;
    esac
    shift
  done
  case "$POLICY" in noconfirm|confirm-local|confirm-all) ;; *) die 2 "Invalid policy: $POLICY" ;; esac
  case "$BACKUP" in true|false) ;; *) die 2 "Invalid backup value: $BACKUP" ;; esac
  case "$ADDITIONS_LANG" in en|ru) ;; *) die 2 "Invalid language: $ADDITIONS_LANG" ;; esac
  MODULE_LANG="$ADDITIONS_LANG"
  export POLICY BACKUP ADDITIONS_LANG MODULE_LANG CONFIRM_DECLINED
}

_module_status_code() {
  local had_errexit=false return_code
  [[ $- == *e* ]] && had_errexit=true
  set +e
  status_steps
  return_code=$?
  [[ "$had_errexit" == true ]] && set -e
  case "$return_code" in 0|5) return "$return_code" ;; *) return 1 ;; esac
}

_module_verify() {
  local expected="$1" return_code
  [[ "$MODULE_VERIFY" == "true" ]] || return 0
  if _module_status_code; then return_code=0; else return_code=$?; fi
  if [[ "$expected" == "installed" && "$return_code" -ne 0 ]]; then
    die 1 "Post-action verification failed: $MODULE_ID is not installed/configured"
  fi
  if [[ "$expected" == "deleted" && "$return_code" -ne 5 ]]; then
    die 1 "Post-action verification failed: $MODULE_ID is still installed/configured"
  fi
}

_module_preflight() {
  declare -F preflight_steps >/dev/null 2>&1 || return 0
  preflight_steps "$1"
}

_module_require_commands() {
  local command_name
  for command_name in "${MODULE_REQUIRED_COMMANDS[@]}"; do
    require_command "$command_name"
  done
}

_module_install_body() {
  local run_preflight="${1:-true}"
  [[ "$run_preflight" == "false" ]] || _module_preflight install
  install_packages "${MODULE_PACKAGES[@]}"
  install_aur_packages "${MODULE_AUR_PACKAGES[@]}"
  _module_require_commands
  install_steps
  _confirm_was_declined && die 1 "Install action was declined: $MODULE_ID"
  _module_verify installed
}

_module_delete_body() {
  local run_preflight="${1:-true}"
  [[ "$run_preflight" == "false" ]] || _module_preflight delete
  delete_steps
  _confirm_was_declined && die 1 "Delete action was declined: $MODULE_ID"
  _module_verify deleted
}

_module_reinstall_body() {
  _module_preflight reinstall
  if declare -F reinstall_steps >/dev/null 2>&1; then
    install_packages "${MODULE_PACKAGES[@]}"
    install_aur_packages "${MODULE_AUR_PACKAGES[@]}"
    _module_require_commands
    reinstall_steps
  else
    _module_delete_body false
    CONFIRM_DECLINED=false
    export CONFIRM_DECLINED
    _module_install_body false
  fi
  _confirm_was_declined && die 1 "Reinstall action was declined: $MODULE_ID"
  _module_verify installed
}

# @api
# kind: callback
# name: status_steps
# signature: status_steps
# required: true
# summary: Return 0 when installed/configured, 5 when absent, and 1 for a status-check error.
# @end
# @api
# kind: callback
# name: install_steps
# signature: install_steps
# required: when install is supported
# summary: Apply only module-specific installation/configuration operations; packages are installed by the runtime first.
# @end
# @api
# kind: callback
# name: delete_steps
# signature: delete_steps
# required: when delete is supported
# summary: Remove only module-managed changes and explicitly selected packages.
# @end
# @api
# kind: callback
# name: reinstall_steps
# signature: reinstall_steps
# required: false
# summary: Optional custom reinstall implementation; otherwise runtime performs delete followed by install.
# @end
# @api
# kind: callback
# name: preflight_steps
# signature: preflight_steps ACTION
# required: false
# summary: Validate prerequisites before an action makes changes; return nonzero to abort safely.
# @end

# @api
# kind: command
# name: meta
# signature: MODULE_SCRIPT meta
# summary: Print validated module metadata as JSON.
# @end
# @api
# kind: command
# name: status
# signature: MODULE_SCRIPT status
# summary: Exit 0 when installed/configured, 5 when absent, or 1 on check failure.
# @end
# @api
# kind: command
# name: install
# signature: MODULE_SCRIPT install --policy=POLICY --backup=BOOL --lang=LANG
# summary: Install packages, run install_steps, verify status and update state.
# @end
# @api
# kind: command
# name: delete
# signature: MODULE_SCRIPT delete --policy=POLICY --backup=BOOL --lang=LANG
# summary: Run delete_steps, verify absence and update state.
# @end
# @api
# kind: command
# name: reinstall
# signature: MODULE_SCRIPT reinstall --policy=POLICY --backup=BOOL --lang=LANG
# summary: Run reinstall_steps or the generic delete/install sequence, then verify and update state.
# @end

# @api
# kind: exit_code
# name: 0
# summary: Success.
# @end
# @api
# kind: exit_code
# name: 1
# summary: Generic failure, verification failure or declined required step.
# @end
# @api
# kind: exit_code
# name: 2
# summary: Invalid module contract, action or arguments.
# @end
# @api
# kind: exit_code
# name: 3
# summary: Required command, package helper, source file or systemd unit is missing.
# @end
# @api
# kind: exit_code
# name: 4
# summary: User cancelled the current run.
# @end
# @api
# kind: exit_code
# name: 5
# summary: status reports that the module is not installed/configured.
# @end

# @api
# kind: function
# name: module_dispatch
# signature: module_dispatch "$@"
# summary: Validate metadata, parse the standard module command and invoke the shared runtime.
# returns: Uses the documented module exit codes.
# effects: Dispatches status/install/delete/reinstall and updates state after successful actions.
# notes: This must be the final command in every module or application script.
# @end
module_dispatch() {
  _module_validate_contract
  _module_parse_args "$@"

  case "$COMMAND" in
    meta)
      _module_meta
      ;;
    status)
      if _module_status_code; then exit 0; else exit $?; fi
      ;;
    install)
      _module_action_supported install || die 2 "Unsupported action for $MODULE_ID: install"
      _module_install_body
      _module_mark_state "$MODULE_ID" installed install
      log_info "Install completed: $MODULE_ID"
      ;;
    delete)
      _module_action_supported delete || die 2 "Unsupported action for $MODULE_ID: delete"
      _module_delete_body
      _module_mark_state "$MODULE_ID" deleted delete
      log_info "Delete completed: $MODULE_ID"
      ;;
    reinstall)
      _module_action_supported reinstall || die 2 "Unsupported action for $MODULE_ID: reinstall"
      _module_reinstall_body
      _module_mark_state "$MODULE_ID" installed reinstall
      log_info "Reinstall completed: $MODULE_ID"
      ;;
    *)
      _module_usage
      die 2 "Unknown command: $COMMAND"
      ;;
  esac
}
