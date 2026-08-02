#!/usr/bin/env bash
set -euo pipefail

# @api
# kind: environment
# name: ADDITIONS_LOG_FILE
# summary: Absolute path of the log file used by the current run.
# default: ~/.local/state/dots-hyprland-additions/logs/<timestamp>_<pid>.log
# @end
# @api
# kind: environment
# name: ADDITIONS_LOG_STDOUT
# summary: Set to 0 to suppress log messages on stdout/stderr while still writing the log file.
# default: 1
# values: 0, 1
# @end
# @api
# kind: environment
# name: ADDITIONS_DEBUG
# summary: Set to 1 to enable log_debug output.
# default: 0
# values: 0, 1
# @end

ADDITIONS_STATE_DIR="${ADDITIONS_STATE_DIR:-$HOME/.local/state/dots-hyprland-additions}"
ADDITIONS_LOG_DIR="$ADDITIONS_STATE_DIR/logs"
ADDITIONS_LOG_FILE="${ADDITIONS_LOG_FILE:-$ADDITIONS_LOG_DIR/$(date +%Y-%m-%d_%H-%M-%S_%N)_$$.log}"
ADDITIONS_LOG_STDOUT="${ADDITIONS_LOG_STDOUT:-1}"
ADDITIONS_DEBUG="${ADDITIONS_DEBUG:-0}"

_log_line() {
  local level="$1"
  shift
  local message="$*"
  local line

  mkdir -p "$ADDITIONS_LOG_DIR"
  line="$(date --iso-8601=seconds) [$level] $message"
  printf '%s\n' "$line" >>"$ADDITIONS_LOG_FILE"

  if [[ "$ADDITIONS_LOG_STDOUT" == "1" ]]; then
    if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
      printf '%s\n' "$line" >&2
    else
      printf '%s\n' "$line"
    fi
  fi
}

# @api
# kind: function
# name: log_debug
# signature: log_debug MESSAGE...
# summary: Write a DEBUG message when ADDITIONS_DEBUG=1.
# returns: 0
# effects: Appends to the current run log and optionally stdout.
# @end
log_debug() {
  [[ "$ADDITIONS_DEBUG" == "1" ]] || return 0
  _log_line DEBUG "$@"
}

# @api
# kind: function
# name: log_info
# signature: log_info MESSAGE...
# summary: Write an informational message.
# returns: 0
# effects: Appends to the current run log and optionally stdout.
# @end
log_info() {
  _log_line INFO "$@"
}

# @api
# kind: function
# name: log_warn
# signature: log_warn MESSAGE...
# summary: Write a warning message.
# returns: 0
# effects: Appends to the current run log and optionally stderr.
# @end
log_warn() {
  _log_line WARN "$@"
}

# @api
# kind: function
# name: log_error
# signature: log_error MESSAGE...
# summary: Write an error message without exiting.
# returns: 0
# effects: Appends to the current run log and optionally stderr.
# @end
log_error() {
  _log_line ERROR "$@"
}

# @api
# kind: function
# name: die
# signature: die EXIT_CODE MESSAGE...
# summary: Log an error and terminate the module with the supplied exit code.
# returns: Does not return.
# effects: Writes an ERROR log entry and exits the current module process.
# @end
die() {
  local exit_code="$1"
  shift
  log_error "$@"
  exit "$exit_code"
}
