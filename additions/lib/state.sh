#!/usr/bin/env bash
set -euo pipefail

_state_cli() {
  python3 "$ROOT/additions/state.py" "$@"
}

# @api
# kind: function
# name: state_record_resource
# signature: state_record_resource KIND VALUE
# summary: Record a resource managed or created by the current module.
# returns: 0 on success.
# effects: Updates state.json under the current MODULE_ID.
# notes: KIND must be a lowercase slug such as packages, created_paths or system_services.
# @end
state_record_resource() {
  local kind="$1"
  local value="$2"
  _state_cli resource-add "$MODULE_ID" "$kind" "$value"
}

# @api
# kind: function
# name: state_forget_resource
# signature: state_forget_resource KIND VALUE
# summary: Remove a resource record for the current module.
# returns: 0 on success, including when the record is absent.
# effects: Updates state.json under the current MODULE_ID.
# @end
state_forget_resource() {
  local kind="$1"
  local value="$2"
  _state_cli resource-remove "$MODULE_ID" "$kind" "$value"
}

# @api
# kind: function
# name: state_has_resource
# signature: state_has_resource KIND VALUE
# summary: Test whether the current module owns a recorded resource.
# returns: 0 when recorded, 1 when absent.
# effects: Reads state.json.
# @end
state_has_resource() {
  local kind="$1"
  local value="$2"
  _state_cli resource-has "$MODULE_ID" "$kind" "$value"
}

# @api
# kind: function
# name: state_list_resources
# signature: state_list_resources KIND
# summary: Print all recorded resources of KIND for the current module, one per line.
# returns: 0 on success.
# effects: Reads state.json and writes to stdout.
# @end
state_list_resources() {
  local kind="$1"
  _state_cli resource-list "$MODULE_ID" "$kind"
}
