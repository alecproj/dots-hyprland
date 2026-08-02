#!/usr/bin/env bash
set -euo pipefail

_command_quote() {
  local quoted=()
  local argument
  for argument in "$@"; do
    printf -v argument '%q' "$argument"
    quoted+=("$argument")
  done
  printf '%s' "${quoted[*]}"
}

# @api
# kind: function
# name: command_exists
# signature: command_exists COMMAND
# summary: Test whether an executable is available in PATH.
# returns: 0 when available, 1 otherwise.
# effects: None.
# @end
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# @api
# kind: function
# name: require_command
# signature: require_command COMMAND [INSTALL_HINT]
# summary: Require one executable before continuing.
# returns: 0 when available; exits 3 when missing.
# effects: Logs a dependency error on failure.
# @end
require_command() {
  local command_name="$1"
  local hint="${2:-}"
  if command_exists "$command_name"; then
    return 0
  fi
  if [[ -n "$hint" ]]; then
    die 3 "Required command not found: $command_name ($hint)"
  fi
  die 3 "Required command not found: $command_name"
}

# @api
# kind: function
# name: require_any_command
# signature: require_any_command COMMAND...
# summary: Print the first available command from the supplied alternatives.
# returns: 0 and prints a command; exits 3 when none are available.
# effects: Writes the selected command to stdout.
# @end
require_any_command() {
  local command_name
  for command_name in "$@"; do
    if command_exists "$command_name"; then
      printf '%s\n' "$command_name"
      return 0
    fi
  done
  die 3 "None of the required commands are available: $*"
}

# @api
# kind: function
# name: run_logged
# signature: run_logged COMMAND [ARG...]
# summary: Log a shell-escaped command and execute it without eval.
# returns: The executed command exit code.
# effects: Executes a process and writes its command line to the run log.
# @end
run_logged() {
  [[ "$#" -gt 0 ]] || die 2 "run_logged requires a command"
  log_info "Running: $(_command_quote "$@")"
  "$@"
}

# @api
# kind: function
# name: run_confirmed
# signature: run_confirmed SCOPE MESSAGE_EN MESSAGE_RU -- COMMAND [ARG...]
# summary: Ask according to the active confirmation policy, then execute and log a command.
# returns: The command exit code; 0 when the user declines the step.
# effects: May prompt on /dev/tty and execute a process.
# notes: SCOPE is local, packages or all. A declined step marks the module action incomplete.
# @end
run_confirmed() {
  local scope="$1"
  local message_en="$2"
  local message_ru="$3"
  shift 3
  [[ "${1:-}" == "--" ]] || die 2 "run_confirmed requires -- before the command"
  shift
  [[ "$#" -gt 0 ]] || die 2 "run_confirmed requires a command"
  confirm_action "$scope" "$message_en" "$message_ru" || return 1
  run_logged "$@"
}
