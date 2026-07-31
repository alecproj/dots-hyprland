#!/usr/bin/env bash
set -euo pipefail

lua_block_exists() {
  local file="$1"
  local module_id="$2"
  [[ -f "$file" ]] && grep -Fq -- "-- BEGIN additions:$module_id" "$file"
}

lua_block() {
  local file="$1"
  local module_id="$2"
  local content="$3"
  local tmp new_file

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : >"$file"

  tmp="$(mktemp)"
  new_file="$(mktemp)"
  printf '%s\n' "$content" >"$tmp"

  FILE_PATH="$file" MODULE_ID_ARG="$module_id" CONTENT_PATH="$tmp" python3 - <<'PY' >"$new_file"
from __future__ import annotations
import os
from pathlib import Path

file_path = Path(os.environ["FILE_PATH"])
module_id = os.environ["MODULE_ID_ARG"]
content_path = Path(os.environ["CONTENT_PATH"])
begin = f"-- BEGIN additions:{module_id}"
end = f"-- END additions:{module_id}"
old = file_path.read_text(encoding="utf-8") if file_path.exists() else ""
block = begin + "\n" + content_path.read_text(encoding="utf-8").rstrip() + "\n" + end + "\n"
lines = old.splitlines(keepends=True)
out: list[str] = []
skipping = False
found = False
for line in lines:
    if line.rstrip("\n") == begin:
        skipping = True
        found = True
        out.append(block)
        continue
    if skipping:
        if line.rstrip("\n") == end:
            skipping = False
        continue
    out.append(line)
if not found:
    if out and not out[-1].endswith("\n"):
        out[-1] += "\n"
    if out and out[-1].strip():
        out.append("\n")
    out.append(block)
print("".join(out), end="")
PY

  if cmp -s "$file" "$new_file"; then
    log_info "Lua block already up to date: $file ($module_id)"
    rm -f "$tmp" "$new_file"
    return 0
  fi

  backup_file "$MODULE_ID" "$file"
  confirm_action local "Edit Lua block $module_id in $file" || {
    rm -f "$tmp" "$new_file"
    return 0
  }
  log_info "Writing Lua block $module_id in $file"
  install -Dm644 "$new_file" "$file"
  rm -f "$tmp" "$new_file"
}

remove_lua_block() {
  local file="$1"
  local module_id="$2"
  local new_file

  [[ -f "$file" ]] || return 0
  new_file="$(mktemp)"

  FILE_PATH="$file" MODULE_ID_ARG="$module_id" python3 - <<'PY' >"$new_file"
from __future__ import annotations
import os
from pathlib import Path

file_path = Path(os.environ["FILE_PATH"])
module_id = os.environ["MODULE_ID_ARG"]
begin = f"-- BEGIN additions:{module_id}"
end = f"-- END additions:{module_id}"
lines = file_path.read_text(encoding="utf-8").splitlines(keepends=True)
out: list[str] = []
skipping = False
for line in lines:
    if line.rstrip("\n") == begin:
        skipping = True
        continue
    if skipping:
        if line.rstrip("\n") == end:
            skipping = False
        continue
    out.append(line)
print("".join(out), end="")
PY

  if cmp -s "$file" "$new_file"; then
    log_info "Lua block absent: $file ($module_id)"
    rm -f "$new_file"
    return 0
  fi

  backup_file "$MODULE_ID" "$file"
  confirm_action local "Remove Lua block $module_id from $file" || {
    rm -f "$new_file"
    return 0
  }
  log_info "Removing Lua block $module_id from $file"
  install -Dm644 "$new_file" "$file"
  rm -f "$new_file"
}
