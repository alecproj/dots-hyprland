#!/usr/bin/env bash
set -euo pipefail

_unit_name() {
  local service="$1"
  if [[ "$service" == *.service ]]; then
    printf '%s\n' "$service"
  else
    printf '%s.service\n' "$service"
  fi
}

service_exists() {
  local unit
  unit="$(_unit_name "$1")"
  systemctl list-unit-files "$unit" >/dev/null 2>&1
}

enable_service() {
  local unit
  unit="$(_unit_name "$1")"
  service_exists "$unit" || {
    log_error "Systemd service not found: $unit"
    exit 3
  }
  if systemctl is-enabled "$unit" >/dev/null 2>&1; then
    log_info "Service already enabled: $unit"
    return 0
  fi
  confirm_action local "Enable $unit" "Включить $unit" || return 0
  log_info "Enabling service: $unit"
  sudo systemctl enable "$unit"
}

disable_service_if_exists() {
  local unit
  unit="$(_unit_name "$1")"
  service_exists "$unit" || {
    log_info "Service not present, skip disable: $unit"
    return 0
  }
  if ! systemctl is-enabled "$unit" >/dev/null 2>&1; then
    log_info "Service already disabled: $unit"
    return 0
  fi
  confirm_action local "Disable $unit" "Отключить $unit" || return 0
  log_info "Disabling service: $unit"
  sudo systemctl disable --now "$unit" 2>/dev/null || sudo systemctl disable "$unit"
}
