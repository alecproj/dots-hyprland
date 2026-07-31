from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

STATE_DIR = Path.home() / ".local" / "state" / "dots-hyprland-additions"
STATE_FILE = STATE_DIR / "state.json"
LOG_DIR = STATE_DIR / "logs"
BACKUP_DIR = STATE_DIR / "backups"


def ensure_state_dirs() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def default_state() -> dict[str, Any]:
    return {"version": 1, "modules": {}}


def load_state() -> dict[str, Any]:
    ensure_state_dirs()
    if not STATE_FILE.exists():
        return default_state()
    try:
        with STATE_FILE.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (json.JSONDecodeError, OSError):
        return default_state()
    if not isinstance(data, dict):
        return default_state()
    data.setdefault("version", 1)
    data.setdefault("modules", {})
    return data


def save_state(state: dict[str, Any]) -> None:
    ensure_state_dirs()
    tmp = STATE_FILE.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(state, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    tmp.replace(STATE_FILE)


def mark_module(module_id: str, status: str, action: str, success: bool = True, error: str | None = None) -> None:
    state = load_state()
    modules = state.setdefault("modules", {})
    entry = modules.setdefault(module_id, {})
    entry["status"] = status
    entry["last_action"] = action
    entry["last_success"] = now_iso() if success else entry.get("last_success")
    if error:
        entry["last_error"] = error
    elif "last_error" in entry:
        del entry["last_error"]
    save_state(state)


def get_module_status(module_id: str) -> str | None:
    state = load_state()
    entry = state.get("modules", {}).get(module_id)
    if not isinstance(entry, dict):
        return None
    status = entry.get("status")
    return status if isinstance(status, str) else None
