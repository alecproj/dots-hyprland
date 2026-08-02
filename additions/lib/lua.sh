#!/usr/bin/env bash
set -euo pipefail

# @api
# kind: function
# name: lua_block_exists
# signature: lua_block_exists FILE MODULE_ID
# summary: Test whether a Hyprland Lua file contains the module managed block.
# returns: 0 when present, 1 otherwise.
# effects: Reads FILE.
# @end
lua_block_exists() {
  managed_block_exists "$1" "$2" "--"
}

# @api
# kind: function
# name: lua_block
# signature: lua_block FILE MODULE_ID CONTENT
# summary: Add or replace a managed Lua block using -- BEGIN/END additions markers.
# returns: 0 on success or declined step.
# effects: Preserves all Lua outside the block and applies backup/resource tracking.
# @end
lua_block() {
  managed_block "$1" "$2" "--" "$3"
}

# @api
# kind: function
# name: remove_lua_block
# signature: remove_lua_block FILE MODULE_ID
# summary: Remove only one managed Lua block.
# returns: 0 on success, absence or declined step.
# effects: Preserves all Lua outside the block and applies backup/resource tracking.
# @end
remove_lua_block() {
  remove_managed_block "$1" "$2" "--"
}
