#!/usr/bin/env bash
set -euo pipefail

_blocks_validate_id() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die 2 "Invalid managed block id: $1"
}

_blocks_marker() {
  local prefix="$1"
  local boundary="$2"
  local block_id="$3"
  printf '%s %s additions:%s' "$prefix" "$boundary" "$block_id"
}

_blocks_render() {
  local file="$1"
  local block_id="$2"
  local prefix="$3"
  local content_file="$4"
  local output_file="$5"
  local operation="$6"

  FILE_PATH="$file" BLOCK_ID="$block_id" COMMENT_PREFIX="$prefix" \
    CONTENT_PATH="$content_file" OPERATION="$operation" python3 - <<'PY' >"$output_file"
from __future__ import annotations

import os
import sys
from pathlib import Path

path = Path(os.environ["FILE_PATH"])
block_id = os.environ["BLOCK_ID"]
prefix = os.environ["COMMENT_PREFIX"]
content_path = Path(os.environ["CONTENT_PATH"])
operation = os.environ["OPERATION"]
begin = f"{prefix} BEGIN additions:{block_id}"
end = f"{prefix} END additions:{block_id}"
old = path.read_text(encoding="utf-8") if path.exists() else ""
content = content_path.read_text(encoding="utf-8").rstrip("\n")
block = f"{begin}\n{content}\n{end}\n"
lines = old.splitlines(keepends=True)
out: list[str] = []
in_block = False
found = False

for line in lines:
    stripped = line.rstrip("\r\n")
    if stripped == begin:
        if in_block or found:
            print(f"duplicate managed block start: {begin}", file=sys.stderr)
            raise SystemExit(1)
        in_block = True
        found = True
        if operation == "update":
            out.append(block)
        continue
    if stripped == end:
        if not in_block:
            print(f"managed block end without start: {end}", file=sys.stderr)
            raise SystemExit(1)
        in_block = False
        continue
    if not in_block:
        out.append(line)

if in_block:
    print(f"unterminated managed block: {begin}", file=sys.stderr)
    raise SystemExit(1)

if operation == "update" and not found:
    if out and not out[-1].endswith("\n"):
        out[-1] += "\n"
    if out and out[-1].strip():
        out.append("\n")
    out.append(block)

print("".join(out), end="")
PY
}

# @api
# kind: function
# name: managed_block_exists
# signature: managed_block_exists FILE BLOCK_ID [COMMENT_PREFIX]
# summary: Test whether FILE contains a managed block start marker.
# returns: 0 when present, 1 otherwise.
# effects: Reads FILE.
# @end
managed_block_exists() {
  local file="$1"
  local block_id="$2"
  local prefix="${3:-#}"
  local begin
  _blocks_validate_id "$block_id"
  begin="$(_blocks_marker "$prefix" BEGIN "$block_id")"
  [[ -f "$file" ]] && grep -Fq -- "$begin" "$file"
}

_blocks_update() {
  local privilege="$1"
  local file="$2"
  local block_id="$3"
  local prefix="$4"
  local content="$5"
  local content_file output_file return_code
  _blocks_validate_id "$block_id"
  [[ "$prefix" != *$'\n'* && "$prefix" != *$'\r'* ]] || die 2 "Invalid comment prefix"

  content_file="$(mktemp)"
  output_file="$(mktemp)"
  printf '%s\n' "$content" >"$content_file"
  if ! _blocks_render "$file" "$block_id" "$prefix" "$content_file" "$output_file" update; then
    rm -f -- "$content_file" "$output_file"
    die 1 "Cannot update malformed managed block $block_id in $file"
  fi

  if [[ -f "$file" ]] && cmp -s -- "$file" "$output_file"; then
    log_info "Managed block already up to date: $file ($block_id)"
    rm -f -- "$content_file" "$output_file"
    return 0
  fi

  if _files_install_generated "$privilege" "$output_file" "$file" 0644 \
      "Update managed block $block_id in $file" \
      "Обновить управляемый блок $block_id в $file"; then
    return_code=0
  else
    return_code=$?
  fi
  if [[ -f "$file" ]] && cmp -s -- "$file" "$output_file"; then
    state_record_resource managed_blocks "$file::$prefix::$block_id"
  fi
  rm -f -- "$content_file" "$output_file"
  return "$return_code"
}

# @api
# kind: function
# name: managed_block
# signature: managed_block FILE BLOCK_ID COMMENT_PREFIX CONTENT
# summary: Add or replace one managed text block in a user-owned file.
# returns: 0 on success or declined step; exits 1 on malformed markers.
# effects: Preserves all content outside the marked block and uses backup/resource tracking.
# @end
managed_block() {
  _blocks_update user "$1" "$2" "$3" "$4"
}

# @api
# kind: function
# name: managed_block_sudo
# signature: managed_block_sudo FILE BLOCK_ID COMMENT_PREFIX CONTENT
# summary: Add or replace one managed text block in a privileged file.
# returns: 0 on success or declined step; exits 1 on malformed markers.
# effects: Uses sudo while preserving all content outside the marked block.
# @end
managed_block_sudo() {
  _blocks_update sudo "$1" "$2" "$3" "$4"
}

_blocks_remove() {
  local privilege="$1"
  local file="$2"
  local block_id="$3"
  local prefix="$4"
  local empty_content output_file return_code
  _blocks_validate_id "$block_id"
  [[ -f "$file" ]] || return 0
  if ! managed_block_exists "$file" "$block_id" "$prefix"; then
    log_info "Managed block absent: $file ($block_id)"
    return 0
  fi

  empty_content="$(mktemp)"
  output_file="$(mktemp)"
  : >"$empty_content"
  if ! _blocks_render "$file" "$block_id" "$prefix" "$empty_content" "$output_file" remove; then
    rm -f -- "$empty_content" "$output_file"
    die 1 "Cannot remove malformed managed block $block_id from $file"
  fi

  if [[ ! -s "$output_file" ]] && state_has_resource created_paths "$file"; then
    rm -f -- "$empty_content" "$output_file"
    remove_managed_path "$file"
    state_forget_resource managed_blocks "$file::$prefix::$block_id"
    return 0
  fi

  if _files_install_generated "$privilege" "$output_file" "$file" 0644 \
      "Remove managed block $block_id from $file" \
      "Удалить управляемый блок $block_id из $file"; then
    return_code=0
  else
    return_code=$?
  fi
  if [[ -f "$file" ]] && cmp -s -- "$file" "$output_file"; then
    state_forget_resource managed_blocks "$file::$prefix::$block_id"
  fi
  rm -f -- "$empty_content" "$output_file"
  return "$return_code"
}

# @api
# kind: function
# name: remove_managed_block
# signature: remove_managed_block FILE BLOCK_ID [COMMENT_PREFIX]
# summary: Remove only the selected managed block from a user-owned file.
# returns: 0 on success, absence or declined step; exits 1 on malformed markers.
# effects: Preserves all content outside the block and uses backup/resource tracking.
# @end
remove_managed_block() {
  _blocks_remove user "$1" "$2" "${3:-#}"
}

# @api
# kind: function
# name: remove_managed_block_sudo
# signature: remove_managed_block_sudo FILE BLOCK_ID [COMMENT_PREFIX]
# summary: Remove only the selected managed block from a privileged file.
# returns: 0 on success, absence or declined step; exits 1 on malformed markers.
# effects: Uses sudo and preserves all content outside the block.
# @end
remove_managed_block_sudo() {
  _blocks_remove sudo "$1" "$2" "${3:-#}"
}
