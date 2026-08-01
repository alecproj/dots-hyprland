#!/usr/bin/env bash
set -euo pipefail

POLICY="${POLICY:-noconfirm}"
CONFIRM_DECLINED="${CONFIRM_DECLINED:-false}"

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

_confirm_color_enabled() {
  [[ -t 9 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]
}

_confirm_paint() {
  local code="$1"
  local text="$2"
  if _confirm_color_enabled; then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

_localized_confirmation_message() {
  local message_en="$1"
  local message_ru="${2:-}"
  if [[ "${ADDITIONS_LANG:-en}" == "ru" && -n "$message_ru" ]]; then
    printf '%s\n' "$message_ru"
  else
    printf '%s\n' "$message_en"
  fi
}

_print_confirmation_prompt() {
  local message="$1"
  local prompt invalid_context

  if [[ "${ADDITIONS_LANG:-en}" == "ru" ]]; then
    prompt="[y] да  [n] нет  [a] да для всех  [q] выход: "
    invalid_context="Введите y, n, a или q."
  else
    prompt="[y] yes  [n] no  [a] yes to all  [q] quit: "
    invalid_context="Enter y, n, a or q."
  fi

  printf '\n' >&9
  _confirm_paint '1;33' '?' >&9
  printf ' ' >&9
  if [[ "${ADDITIONS_RUNNER_CONTEXT:-0}" != "1" ]]; then
    local module_title="${MODULE_TITLE:-${MODULE_ID:-module}}"
    if [[ "${ADDITIONS_LANG:-en}" == "ru" && -n "${MODULE_TITLE_RU:-}" ]]; then
      module_title="$MODULE_TITLE_RU"
    fi
    _confirm_paint '1;36' "$module_title" >&9
    printf ' — ' >&9
  fi
  printf '%s\n' "$message" >&9
  printf '  ' >&9
  _confirm_paint '1' "$prompt" >&9

  CONFIRM_INVALID_MESSAGE="$invalid_context"
}

confirm_action() {
  local scope="$1"
  local message_en="$2"
  local message_ru="${3:-}"
  local message answer

  if ! _confirm_needed "$scope"; then
    return 0
  fi

  message="$(_localized_confirmation_message "$message_en" "$message_ru")"

  if ! exec 9<>/dev/tty 2>/dev/null; then
    log_error "Cannot ask for confirmation without a controlling terminal: $message_en"
    exit 4
  fi

  while true; do
    _print_confirmation_prompt "$message"

    if ! IFS= read -r answer <&9; then
      exec 9>&-
      log_error "Confirmation input closed: $message_en"
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
        log_warn "Declined by user: $message_en"
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
        log_error "Cancelled by user: $message_en"
        exit 4
        ;;
      *)
        printf '  %s\n' "$CONFIRM_INVALID_MESSAGE" >&9
        ;;
    esac
  done
}

confirmation_was_declined() {
  [[ "${CONFIRM_DECLINED:-false}" == "true" ]]
}
