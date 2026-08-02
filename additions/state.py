from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

STATE_DIR = Path.home() / ".local" / "state" / "dots-hyprland-additions"
STATE_FILE = STATE_DIR / "state.json"
LOG_DIR = STATE_DIR / "logs"
BACKUP_DIR = STATE_DIR / "backups"
RESOURCE_KIND_PATTERN = re.compile(r"^[a-z][a-z0-9_-]*$")


def ensure_state_dirs() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def default_state() -> dict[str, Any]:
    return {"version": 2, "modules": {}}


def load_state() -> dict[str, Any]:
    ensure_state_dirs()
    if not STATE_FILE.exists():
        return default_state()
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return default_state()
    if not isinstance(data, dict):
        return default_state()
    data["version"] = max(int(data.get("version", 1)), 2)
    if not isinstance(data.get("modules"), dict):
        data["modules"] = {}
    return data


def save_state(state: dict[str, Any]) -> None:
    ensure_state_dirs()
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(STATE_FILE)


def _module_entry(state: dict[str, Any], module_id: str) -> dict[str, Any]:
    modules = state.setdefault("modules", {})
    entry = modules.setdefault(module_id, {})
    if not isinstance(entry, dict):
        entry = {}
        modules[module_id] = entry
    resources = entry.setdefault("resources", {})
    if not isinstance(resources, dict):
        entry["resources"] = {}
    return entry


def mark_module(
    module_id: str,
    status: str,
    action: str,
    success: bool = True,
    error: str | None = None,
) -> None:
    state = load_state()
    entry = _module_entry(state, module_id)
    entry["status"] = status
    entry["last_action"] = action
    if success:
        entry["last_success"] = now_iso()
        entry.pop("last_error", None)
    elif error:
        entry["last_error"] = error
    save_state(state)


def get_module_status(module_id: str) -> str | None:
    state = load_state()
    entry = state.get("modules", {}).get(module_id)
    if not isinstance(entry, dict):
        return None
    status = entry.get("status")
    return status if isinstance(status, str) else None


def _validate_resource_kind(kind: str) -> None:
    if not RESOURCE_KIND_PATTERN.fullmatch(kind):
        raise ValueError(f"invalid resource kind: {kind}")


def add_resource(module_id: str, kind: str, value: str) -> None:
    _validate_resource_kind(kind)
    state = load_state()
    entry = _module_entry(state, module_id)
    resources = entry.setdefault("resources", {})
    values = resources.setdefault(kind, [])
    if not isinstance(values, list):
        values = []
        resources[kind] = values
    if value not in values:
        values.append(value)
        values.sort()
        save_state(state)


def remove_resource(module_id: str, kind: str, value: str) -> None:
    _validate_resource_kind(kind)
    state = load_state()
    entry = _module_entry(state, module_id)
    resources = entry.setdefault("resources", {})
    values = resources.get(kind, [])
    if not isinstance(values, list) or value not in values:
        return
    values.remove(value)
    if values:
        resources[kind] = values
    else:
        resources.pop(kind, None)
    save_state(state)


def has_resource(module_id: str, kind: str, value: str) -> bool:
    _validate_resource_kind(kind)
    state = load_state()
    entry = state.get("modules", {}).get(module_id, {})
    if not isinstance(entry, dict):
        return False
    resources = entry.get("resources", {})
    if not isinstance(resources, dict):
        return False
    values = resources.get(kind, [])
    return isinstance(values, list) and value in values


def list_resources(module_id: str, kind: str) -> list[str]:
    _validate_resource_kind(kind)
    state = load_state()
    entry = state.get("modules", {}).get(module_id, {})
    if not isinstance(entry, dict):
        return []
    resources = entry.get("resources", {})
    if not isinstance(resources, dict):
        return []
    values = resources.get(kind, [])
    return [str(value) for value in values] if isinstance(values, list) else []


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="dots-hyprland additions state helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    mark = subparsers.add_parser("mark")
    mark.add_argument("module_id")
    mark.add_argument("status")
    mark.add_argument("action")
    mark.add_argument("--error")

    for command in ("resource-add", "resource-remove", "resource-has"):
        item = subparsers.add_parser(command)
        item.add_argument("module_id")
        item.add_argument("kind")
        item.add_argument("value")

    listing = subparsers.add_parser("resource-list")
    listing.add_argument("module_id")
    listing.add_argument("kind")

    subparsers.add_parser("dump")
    return parser


def main(argv: list[str]) -> int:
    args = _build_parser().parse_args(argv)
    try:
        if args.command == "mark":
            mark_module(
                args.module_id,
                args.status,
                args.action,
                success=args.error is None,
                error=args.error,
            )
            return 0
        if args.command == "resource-add":
            add_resource(args.module_id, args.kind, args.value)
            return 0
        if args.command == "resource-remove":
            remove_resource(args.module_id, args.kind, args.value)
            return 0
        if args.command == "resource-has":
            return 0 if has_resource(args.module_id, args.kind, args.value) else 1
        if args.command == "resource-list":
            for value in list_resources(args.module_id, args.kind):
                print(value)
            return 0
        if args.command == "dump":
            print(json.dumps(load_state(), indent=2, ensure_ascii=False))
            return 0
    except (OSError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
