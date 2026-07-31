#!/usr/bin/env bash
set -euo pipefail

ADDITIONS_STATE_DIR="${ADDITIONS_STATE_DIR:-$HOME/.local/state/dots-hyprland-additions}"
ADDITIONS_LOG_DIR="$ADDITIONS_STATE_DIR/logs"
ADDITIONS_LOG_FILE="${ADDITIONS_LOG_FILE:-$ADDITIONS_LOG_DIR/$(date +%Y-%m-%d_%H-%M-%S).log}"

log_line() {
  local level="$1"
  shift
  local message="$*"
  local line
  mkdir -p "$ADDITIONS_LOG_DIR"
  line="$(date --iso-8601=seconds) [$level] $message"
  printf '%s\n' "$line"
  printf '%s\n' "$line" >>"$ADDITIONS_LOG_FILE"
}

log_info() {
  log_line INFO "$@"
}

log_warn() {
  log_line WARN "$@"
}

log_error() {
  log_line ERROR "$@"
}
