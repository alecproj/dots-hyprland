#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT

# shellcheck source=additions/lib/log.sh
source "$ROOT/additions/lib/log.sh"
# shellcheck source=additions/lib/confirm.sh
source "$ROOT/additions/lib/confirm.sh"
# shellcheck source=additions/lib/backup.sh
source "$ROOT/additions/lib/backup.sh"
# shellcheck source=additions/lib/files.sh
source "$ROOT/additions/lib/files.sh"
# shellcheck source=additions/lib/lua.sh
source "$ROOT/additions/lib/lua.sh"
# shellcheck source=additions/lib/packages.sh
source "$ROOT/additions/lib/packages.sh"
# shellcheck source=additions/lib/systemd.sh
source "$ROOT/additions/lib/systemd.sh"

if ! declare -p MODULE_PACKAGES >/dev/null 2>&1; then
  declare -ag MODULE_PACKAGES=()
fi
if ! declare -p MODULE_AUR_PACKAGES >/dev/null 2>&1; then
  declare -ag MODULE_AUR_PACKAGES=()
fi
if ! declare -p MODULE_FILES >/dev/null 2>&1; then
  declare -ag MODULE_FILES=()
fi
MODULE_SECTION="${MODULE_SECTION:-additions}"
MODULE_DANGER="${MODULE_DANGER:-medium}"
MODULE_DEFAULT_ACTION="${MODULE_DEFAULT_ACTION:-skip}"
MODULE_DESCRIPTION="${MODULE_DESCRIPTION:-}"
MODULE_TITLE_RU="${MODULE_TITLE_RU:-}"
MODULE_DESCRIPTION_RU="${MODULE_DESCRIPTION_RU:-}"

json_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "$value"
}

json_array() {
  local first=true
  local item
  printf '['
  for item in "$@"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      printf ', '
    fi
    json_quote "$item"
  done
  printf ']'
}

json_localized() {
  local english="$1"
  local russian="${2:-}"

  printf '{"en": '
  json_quote "$english"
  if [[ -n "$russian" ]]; then
    printf ', "ru": '
    json_quote "$russian"
  fi
  printf '}'
}

module_meta() {
  cat <<JSON
{
  "id": $(json_quote "$MODULE_ID"),
  "section": $(json_quote "$MODULE_SECTION"),
  "title": $(json_quote "$MODULE_TITLE"),
  "description": $(json_quote "$MODULE_DESCRIPTION"),
  "title_i18n": $(json_localized "$MODULE_TITLE" "$MODULE_TITLE_RU"),
  "description_i18n": $(json_localized "$MODULE_DESCRIPTION" "$MODULE_DESCRIPTION_RU"),
  "packages": $(json_array "${MODULE_PACKAGES[@]}"),
  "aur_packages": $(json_array "${MODULE_AUR_PACKAGES[@]}"),
  "files": $(json_array "${MODULE_FILES[@]}"),
  "danger": $(json_quote "$MODULE_DANGER"),
  "default_action": $(json_quote "$MODULE_DEFAULT_ACTION")
}
JSON
}

mark_state() {
  local module_id="$1"
  local status="$2"
  local action="$3"
  python3 - "$module_id" "$status" "$action" <<'PY'
from __future__ import annotations
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

module_id, status, action = sys.argv[1:4]
state_dir = Path.home() / ".local" / "state" / "dots-hyprland-additions"
state_file = state_dir / "state.json"
state_dir.mkdir(parents=True, exist_ok=True)
try:
    data = json.loads(state_file.read_text(encoding="utf-8"))
except Exception:
    data = {"version": 1, "modules": {}}
data.setdefault("version", 1)
data.setdefault("modules", {})
data["modules"][module_id] = {
    "status": status,
    "last_action": action,
    "last_success": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
}
tmp = state_file.with_suffix(".tmp")
tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
tmp.replace(state_file)
PY
}

module_usage() {
  cat >&2 <<EOF_USAGE
Usage: $0 meta|status|install|delete|reinstall [--policy=noconfirm|confirm-local|confirm-all] [--backup=true|false] [--lang=en|ru]
EOF_USAGE
}

parse_module_args() {
  COMMAND="${1:-}"
  [[ -n "$COMMAND" ]] || {
    module_usage
    exit 2
  }
  shift || true

  POLICY="noconfirm"
  BACKUP="true"
  ADDITIONS_LANG="en"
  CONFIRM_DECLINED=false

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --policy=*)
        POLICY="${1#--policy=}"
        ;;
      --backup=*)
        BACKUP="${1#--backup=}"
        ;;
      --lang=*)
        ADDITIONS_LANG="${1#--lang=}"
        ;;
      *)
        log_error "Unknown argument: $1"
        module_usage
        exit 2
        ;;
    esac
    shift
  done

  case "$POLICY" in
    noconfirm|confirm-local|confirm-all) ;;
    *) log_error "Invalid policy: $POLICY"; exit 2 ;;
  esac
  case "$BACKUP" in
    true|false) ;;
    *) log_error "Invalid backup value: $BACKUP"; exit 2 ;;
  esac
  case "$ADDITIONS_LANG" in
    en|ru) ;;
    *) log_error "Invalid lang: $ADDITIONS_LANG"; exit 2 ;;
  esac
  MODULE_LANG="$ADDITIONS_LANG"
  export POLICY BACKUP ADDITIONS_LANG MODULE_LANG CONFIRM_DECLINED
}

run_status() {
  if declare -F status_steps >/dev/null 2>&1; then
    if status_steps; then
      exit 0
    fi
    exit 5
  fi
  exit 5
}

ensure_action_complete() {
  local action="$1"
  if confirmation_was_declined; then
    log_error "Action incomplete because one or more steps were declined: $MODULE_ID ($action)"
    return 1
  fi
}

run_install() {
  log_info "Starting install: $MODULE_ID"
  install_packages "${MODULE_PACKAGES[@]}"
  install_aur_packages "${MODULE_AUR_PACKAGES[@]}"
  if declare -F install_steps >/dev/null 2>&1; then
    install_steps
  fi
  ensure_action_complete install
  mark_state "$MODULE_ID" installed install
  log_info "Install completed: $MODULE_ID"
}

run_delete() {
  log_info "Starting delete: $MODULE_ID"
  if declare -F delete_steps >/dev/null 2>&1; then
    delete_steps
  fi
  ensure_action_complete delete
  mark_state "$MODULE_ID" deleted delete
  log_info "Delete completed: $MODULE_ID"
}

module_dispatch() {
  : "${MODULE_ID:?MODULE_ID is required}"
  : "${MODULE_TITLE:?MODULE_TITLE is required}"

  parse_module_args "$@"
  case "$COMMAND" in
    meta)
      module_meta
      ;;
    status)
      run_status
      ;;
    install)
      run_install
      ;;
    delete)
      run_delete
      ;;
    reinstall)
      run_delete
      run_install
      mark_state "$MODULE_ID" installed reinstall
      ;;
    *)
      log_error "Unknown command: $COMMAND"
      module_usage
      exit 2
      ;;
  esac
}
