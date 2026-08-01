#!/usr/bin/env bash
set -euo pipefail

POLICY="${POLICY:-noconfirm}"
CONFIRM_DECLINED="${CONFIRM_DECLINED:-false}"
CONFIRM_CONTEXT_SHOWN="${CONFIRM_CONTEXT_SHOWN:-false}"

_effective_policy() {
  local state_file="${ADDITIONS_CONFIRM_STATE_FILE:-}"
  local saved_policy=""

  if [[ -n "$state_file" && -r "$state_file" ]]; then
    IFS= read -r saved_policy <"$state_file" || true
  fi

  case "$saved_policy" in
    noconfirm|confirm-local|confirm-all)
      printf '%s\n' "$saved_policy"
      ;;
    *)
      printf '%s\n' "$POLICY"
      ;;
  esac
}

_set_effective_policy() {
  local policy="$1"
  POLICY="$policy"
  export POLICY

  if [[ -n "${ADDITIONS_CONFIRM_STATE_FILE:-}" ]]; then
    printf '%s\n' "$policy" >"$ADDITIONS_CONFIRM_STATE_FILE"
  fi
}

_confirm_needed() {
  local scope="$1"
  local policy
  policy="$(_effective_policy)"

  case "$policy" in
    noconfirm)
      return 1
      ;;
    confirm-local)
      if [[ "$scope" == "local" ]]; then
        return 0
      fi
      if [[ "$scope" == "packages" && "${ADDITIONS_SELECTION_CONFIRMED:-0}" != "1" ]]; then
        return 0
      fi
      return 1
      ;;
    confirm-all)
      return 0
      ;;
    *)
      log_error "Invalid confirmation policy: $policy"
      exit 2
      ;;
  esac
}

_print_box_line() {
  local text="$1"
  printf '| %-74.74s |\n' "$text" >&9
}

_print_wrapped_box_line() {
  local label="$1"
  local value="$2"
  local first=true
  local line

  while IFS= read -r line; do
    if [[ "$first" == true ]]; then
      _print_box_line "$label: $line"
      first=false
    else
      _print_box_line "  $line"
    fi
  done < <(printf '%s\n' "$value" | fold -s -w 70)
}

_print_confirmation_context() {
  local language="${LANG:-en}"
  local module_label="Module"
  local action_label="Action"
  local danger_label="Danger"
  local description_label="Description"

  if [[ "$language" == "ru" ]]; then
    module_label="Модуль"
    action_label="Действие"
    danger_label="Опасность"
    description_label="Описание"
  fi

  printf '%s\n' '+----------------------------------------------------------------------------+' >&9
  _print_wrapped_box_line "$module_label" "${MODULE_TITLE:-${MODULE_ID:-unknown}} [${MODULE_ID:-unknown}]"
  _print_wrapped_box_line "$action_label" "${COMMAND:-unknown}"
  _print_wrapped_box_line "$danger_label" "${MODULE_DANGER:-medium}"
  _print_wrapped_box_line "$description_label" "${MODULE_DESCRIPTION:-No description provided.}"
  printf '%s\n' '+----------------------------------------------------------------------------+' >&9
  CONFIRM_CONTEXT_SHOWN=true
  export CONFIRM_CONTEXT_SHOWN
}

_print_confirmation_action() {
  local message="$1"
  local prompt="Proceed? [y]es / [n]o / [a]ll / [q]uit: "

  if [[ "${LANG:-en}" == "ru" ]]; then
    prompt="Продолжить? [y] да / [n] нет / [a] да для всех / [q] выход: "
  fi

  _print_wrapped_box_line "Step" "$message"
  printf '%s\n' '+----------------------------------------------------------------------------+' >&9
  printf '%s' "$prompt" >&9
}

confirm_action() {
  local scope="$1"
  local message="$2"
  local answer

  if ! _confirm_needed "$scope"; then
    return 0
  fi

  if ! exec 9<>/dev/tty 2>/dev/null; then
    log_error "Cannot ask for confirmation without a controlling terminal: $message"
    exit 4
  fi

  while true; do
    if [[ "$CONFIRM_CONTEXT_SHOWN" != "true" ]]; then
      _print_confirmation_context
    fi
    _print_confirmation_action "$message"

    if ! IFS= read -r answer <&9; then
      exec 9>&-
      log_error "Confirmation input closed: $message"
      exit 4
    fi

    case "$answer" in
      y|Y|yes|YES|д|Д|да|ДА)
        exec 9>&-
        return 0
        ;;
      n|N|no|NO|н|Н|нет|НЕТ)
        CONFIRM_DECLINED=true
        export CONFIRM_DECLINED
        exec 9>&-
        log_warn "Declined by user: $message"
        return 1
        ;;
      a|A|all|ALL|все|ВСЕ)
        _set_effective_policy noconfirm
        exec 9>&-
        log_info "User approved all remaining actions"
        return 0
        ;;
      q|Q|quit|QUIT|в|В|выход|ВЫХОД)
        exec 9>&-
        log_error "Cancelled by user: $message"
        exit 4
        ;;
      *)
        printf '%s\n' "Please enter y, n, a or q." >&9
        ;;
    esac
  done
}

confirmation_was_declined() {
  [[ "${CONFIRM_DECLINED:-false}" == "true" ]]
}
