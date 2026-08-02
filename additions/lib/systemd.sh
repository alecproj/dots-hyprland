#!/usr/bin/env bash
set -euo pipefail

_systemd_unit_name() {
  local service="$1"
  if [[ "$service" == *.* ]]; then
    printf '%s\n' "$service"
  else
    printf '%s.service\n' "$service"
  fi
}

_systemd_command() {
  local scope="$1"
  shift
  if [[ "$scope" == "system" ]]; then
    sudo systemctl "$@"
  else
    systemctl --user "$@"
  fi
}

_systemd_exists() {
  local scope="$1"
  local unit
  unit="$(_systemd_unit_name "$2")"
  if [[ "$scope" == "system" ]]; then
    systemctl list-unit-files --no-legend "$unit" 2>/dev/null | grep -Fq "$unit"
  else
    systemctl --user list-unit-files --no-legend "$unit" 2>/dev/null | grep -Fq "$unit"
  fi
}

_systemd_is_enabled() {
  local scope="$1"
  local unit
  unit="$(_systemd_unit_name "$2")"
  if [[ "$scope" == "system" ]]; then
    systemctl is-enabled "$unit" >/dev/null 2>&1
  else
    systemctl --user is-enabled "$unit" >/dev/null 2>&1
  fi
}

_systemd_enable() {
  local scope="$1"
  local unit
  unit="$(_systemd_unit_name "$2")"
  _systemd_exists "$scope" "$unit" || die 3 "Systemd unit not found: $unit"
  _systemd_is_enabled "$scope" "$unit" && {
    log_info "Service already enabled: $unit ($scope)"
    return 0
  }
  confirm_action local "Enable $unit ($scope)" "Включить $unit ($scope)" || return 1
  run_logged _systemd_command "$scope" enable "$unit"
  state_record_resource "${scope}_services" "$unit"
}

_systemd_disable_if_exists() {
  local scope="$1"
  local unit
  unit="$(_systemd_unit_name "$2")"
  _systemd_exists "$scope" "$unit" || {
    log_info "Service not present, skip disable: $unit ($scope)"
    return 0
  }
  _systemd_is_enabled "$scope" "$unit" || {
    log_info "Service already disabled: $unit ($scope)"
    return 0
  }
  confirm_action local "Disable $unit ($scope)" "Отключить $unit ($scope)" || return 1
  log_info "Disabling service: $unit ($scope)"
  if ! _systemd_command "$scope" disable --now "$unit"; then
    _systemd_command "$scope" disable "$unit"
  fi
  state_forget_resource "${scope}_services" "$unit"
}

_systemd_lifecycle() {
  local scope="$1"
  local operation="$2"
  local service="$3"
  local unit
  unit="$(_systemd_unit_name "$service")"
  _systemd_exists "$scope" "$unit" || die 3 "Systemd unit not found: $unit"
  confirm_action local \
    "${operation^} $unit ($scope)" \
    "Выполнить $operation для $unit ($scope)" || return 1
  run_logged _systemd_command "$scope" "$operation" "$unit"
}

# @api
# kind: function
# name: system_service_exists
# signature: system_service_exists SERVICE
# summary: Test whether a system unit file exists.
# returns: 0 when present, 1 otherwise.
# effects: Runs systemctl list-unit-files.
# @end
system_service_exists() { _systemd_exists system "$1"; }

# @api
# kind: function
# name: user_service_exists
# signature: user_service_exists SERVICE
# summary: Test whether a user unit file exists.
# returns: 0 when present, 1 otherwise.
# effects: Runs systemctl --user list-unit-files.
# @end
user_service_exists() { _systemd_exists user "$1"; }

# @api
# kind: function
# name: system_service_enabled
# signature: system_service_enabled SERVICE
# summary: Test whether a system unit is enabled.
# returns: 0 when enabled, nonzero otherwise.
# effects: Runs systemctl is-enabled.
# @end
system_service_enabled() { _systemd_is_enabled system "$1"; }

# @api
# kind: function
# name: user_service_enabled
# signature: user_service_enabled SERVICE
# summary: Test whether a user unit is enabled.
# returns: 0 when enabled, nonzero otherwise.
# effects: Runs systemctl --user is-enabled.
# @end
user_service_enabled() { _systemd_is_enabled user "$1"; }

# @api
# kind: function
# name: enable_system_service
# signature: enable_system_service SERVICE
# summary: Idempotently enable a system service after confirmation.
# returns: 0 on success or declined step; exits 3 when the unit is missing.
# effects: Uses sudo systemctl enable and records the service.
# @end
enable_system_service() { _systemd_enable system "$1"; }

# @api
# kind: function
# name: enable_user_service
# signature: enable_user_service SERVICE
# summary: Idempotently enable a user service after confirmation.
# returns: 0 on success or declined step; exits 3 when the unit is missing.
# effects: Runs systemctl --user enable and records the service.
# @end
enable_user_service() { _systemd_enable user "$1"; }

# @api
# kind: function
# name: disable_system_service_if_exists
# signature: disable_system_service_if_exists SERVICE
# summary: Disable and stop a system service only when it exists and is enabled.
# returns: 0 on success, absence or declined step.
# effects: Uses sudo systemctl disable --now.
# @end
disable_system_service_if_exists() { _systemd_disable_if_exists system "$1"; }

# @api
# kind: function
# name: disable_user_service_if_exists
# signature: disable_user_service_if_exists SERVICE
# summary: Disable and stop a user service only when it exists and is enabled.
# returns: 0 on success, absence or declined step.
# effects: Runs systemctl --user disable --now.
# @end
disable_user_service_if_exists() { _systemd_disable_if_exists user "$1"; }

# @api
# kind: function
# name: start_system_service
# signature: start_system_service SERVICE
# summary: Start a system service after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Uses sudo systemctl start.
# @end
start_system_service() { _systemd_lifecycle system start "$1"; }

# @api
# kind: function
# name: restart_system_service
# signature: restart_system_service SERVICE
# summary: Restart a system service after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Uses sudo systemctl restart.
# @end
restart_system_service() { _systemd_lifecycle system restart "$1"; }

# @api
# kind: function
# name: start_user_service
# signature: start_user_service SERVICE
# summary: Start a user service after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Runs systemctl --user start.
# @end
start_user_service() { _systemd_lifecycle user start "$1"; }

# @api
# kind: function
# name: restart_user_service
# signature: restart_user_service SERVICE
# summary: Restart a user service after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Runs systemctl --user restart.
# @end
restart_user_service() { _systemd_lifecycle user restart "$1"; }

# @api
# kind: function
# name: stop_system_service
# signature: stop_system_service SERVICE
# summary: Stop a system service after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Uses sudo systemctl stop.
# @end
stop_system_service() { _systemd_lifecycle system stop "$1"; }

# @api
# kind: function
# name: stop_user_service
# signature: stop_user_service SERVICE
# summary: Stop a user service after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Runs systemctl --user stop.
# @end
stop_user_service() { _systemd_lifecycle user stop "$1"; }

# @api
# kind: function
# name: systemd_daemon_reload
# signature: systemd_daemon_reload
# summary: Reload system systemd unit definitions after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Uses sudo systemctl daemon-reload.
# @end
systemd_daemon_reload() {
  run_confirmed local "Reload systemd units" "Перезагрузить конфигурацию systemd" -- sudo systemctl daemon-reload
}

# @api
# kind: function
# name: user_systemd_daemon_reload
# signature: user_systemd_daemon_reload
# summary: Reload user systemd unit definitions after confirmation.
# returns: The systemctl exit code or 0 when declined.
# effects: Runs systemctl --user daemon-reload.
# @end
user_systemd_daemon_reload() {
  run_confirmed local "Reload user systemd units" "Перезагрузить пользовательскую конфигурацию systemd" -- systemctl --user daemon-reload
}

# @api
# kind: function
# name: service_exists
# signature: service_exists SERVICE
# summary: Deprecated compatibility alias for system_service_exists.
# returns: Same as system_service_exists.
# effects: Same as system_service_exists.
# @end
service_exists() { system_service_exists "$1"; }

# @api
# kind: function
# name: enable_service
# signature: enable_service SERVICE
# summary: Deprecated compatibility alias for enable_system_service.
# returns: Same as enable_system_service.
# effects: Same as enable_system_service.
# @end
enable_service() { enable_system_service "$1"; }

# @api
# kind: function
# name: disable_service_if_exists
# signature: disable_service_if_exists SERVICE
# summary: Deprecated compatibility alias for disable_system_service_if_exists.
# returns: Same as disable_system_service_if_exists.
# effects: Same as disable_system_service_if_exists.
# @end
disable_service_if_exists() { disable_system_service_if_exists "$1"; }
