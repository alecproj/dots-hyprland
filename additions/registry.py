from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ADDITIONS_DIR = ROOT / "additions"
VALID_SECTIONS = {"additions", "applications"}
VALID_DANGER = {"low", "medium", "high"}
VALID_ACTIONS = {"install", "delete", "reinstall", "skip"}


@dataclass(frozen=True)
class ModuleMeta:
    id: str
    section: str
    title: str
    description: str
    default_action: str
    path: Path
    packages: tuple[str, ...] = ()
    aur_packages: tuple[str, ...] = ()
    files: tuple[str, ...] = ()
    danger: str = "medium"
    status: str = "unknown"
    meta_error: str | None = None

    @classmethod
    def from_json(cls, data: dict[str, Any], path: Path) -> "ModuleMeta":
        for field in ("id", "section", "title", "description", "default_action"):
            value = data.get(field)
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"missing or invalid meta field: {field}")
        section = data["section"]
        if section not in VALID_SECTIONS:
            raise ValueError(f"invalid section: {section}")
        default_action = data["default_action"]
        if default_action not in VALID_ACTIONS:
            raise ValueError(f"invalid default_action: {default_action}")
        danger = data.get("danger", "medium")
        if danger not in VALID_DANGER:
            raise ValueError(f"invalid danger: {danger}")
        return cls(
            id=data["id"],
            section=section,
            title=data["title"],
            description=data["description"],
            default_action=default_action,
            danger=danger,
            packages=tuple(str(item) for item in data.get("packages", []) if str(item)),
            aur_packages=tuple(str(item) for item in data.get("aur_packages", []) if str(item)),
            files=tuple(str(item) for item in data.get("files", []) if str(item)),
            path=path,
        )


def _meta_from_script(path: Path) -> ModuleMeta:
    result = subprocess.run(
        [str(path), "meta"],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"meta failed: {path}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON from {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError(f"meta JSON must be an object: {path}")
    return ModuleMeta.from_json(payload, path)


def discover_modules(with_status: bool = True) -> list[ModuleMeta]:
    modules: list[ModuleMeta] = []
    for directory in (ADDITIONS_DIR / "modules", ADDITIONS_DIR / "apps"):
        for path in sorted(directory.glob("*.sh")):
            try:
                meta = _meta_from_script(path)
                if with_status:
                    meta = meta_with_status(meta)
                modules.append(meta)
            except Exception as exc:  # noqa: BLE001 - TUI must not crash on bad module meta.
                modules.append(
                    ModuleMeta(
                        id=path.stem,
                        section="additions" if directory.name == "modules" else "applications",
                        title=path.name,
                        description=str(exc),
                        default_action="skip",
                        danger="high",
                        path=path,
                        status="error",
                        meta_error=str(exc),
                    )
                )
    return modules


def meta_with_status(meta: ModuleMeta) -> ModuleMeta:
    result = subprocess.run(
        [str(meta.path), "status"],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode == 0:
        status = "installed"
    elif result.returncode == 5:
        status = "not-installed"
    else:
        status = "unknown"
    return ModuleMeta(
        id=meta.id,
        section=meta.section,
        title=meta.title,
        description=meta.description,
        default_action=meta.default_action,
        path=meta.path,
        packages=meta.packages,
        aur_packages=meta.aur_packages,
        files=meta.files,
        danger=meta.danger,
        status=status,
        meta_error=meta.meta_error,
    )


def module_by_id(modules: list[ModuleMeta]) -> dict[str, ModuleMeta]:
    return {module.id: module for module in modules}
