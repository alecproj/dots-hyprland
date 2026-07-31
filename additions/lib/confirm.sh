#!/usr/bin/env bash
set -euo pipefail

POLICY="${POLICY:-noconfirm}"

confirm_action() {
  local scope="$1"
  local message="$2"

  case "$POLICY" in
    noconfirm)
      return 0
      ;;
    confirm-local)
      if [[ "$scope" != "local" ]]; then
        return 0
      fi
      ;;
    confirm-all)
      ;;
    *)
      log_error "Invalid confirmation policy: $POLICY"
      exit 2
      ;;
  esac

  local answer
  while true; do
    if [[ -r /dev/tty ]]; then
      printf '%s [y/n/a/q] ' "$message" >/dev/tty
      read -r answer </dev/tty
    else
      log_error "Cannot ask for confirmation without /dev/tty: $message"
      exit 4
    fi

    case "$answer" in
      y|Y|yes|YES)
        return 0
        ;;
      n|N|no|NO)
        log_warn "Skipped by user: $message"
        return 1
        ;;
      a|A)
        POLICY="noconfirm"
        export POLICY
        return 0
        ;;
      q|Q)
        log_error "Cancelled by user: $message"
        exit 4
        ;;
    esac
  done
}
