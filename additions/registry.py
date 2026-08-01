from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from i18n import normalize_lang

ROOT = Path(__file__).resolve().parents[1]
ADDITIONS_DIR = ROOT / "additions"
BUILTIN_SECTIONS = ("additions", "applications")
VALID_DANGER = {"low", "medium", "high"}
VALID_ACTIONS = {"install", "delete", "reinstall", "skip"}
SECTION_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def _translation_map(value: Any, field: str) -> dict[str, str]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise ValueError(f"invalid translation map: {field}")
    result: dict[str, str] = {}
    for language, text in value.items():
        if not isinstance(language, str) or not isinstance(text, str):
            raise ValueError(f"invalid translation entry: {field}")
        if text.strip():
            result[language] = text.strip()
    return result


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
    title_i18n: dict[str, str] | None = None
    description_i18n: dict[str, str] | None = None

    @classmethod
    def from_json(cls, data: dict[str, Any], path: Path) -> "ModuleMeta":
        for field in ("id", "section", "title", "description", "default_action"):
            value = data.get(field)
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"missing or invalid meta field: {field}")

        section = data["section"].strip()
        if not SECTION_PATTERN.fullmatch(section):
            raise ValueError(f"invalid section: {section}")

        default_action = data["default_action"]
        if default_action not in VALID_ACTIONS:
            raise ValueError(f"invalid default_action: {default_action}")

        danger = data.get("danger", "medium")
        if danger not in VALID_DANGER:
            raise ValueError(f"invalid danger: {danger}")

        title_i18n = _translation_map(data.get("title_i18n"), "title_i18n")
        description_i18n = _translation_map(data.get("description_i18n"), "description_i18n")

        return cls(
            id=data["id"].strip(),
            section=section,
            title=data["title"].strip(),
            description=data["description"].strip(),
            default_action=default_action,
            danger=danger,
            packages=tuple(str(item) for item in data.get("packages", []) if str(item)),
            aur_packages=tuple(str(item) for item in data.get("aur_packages", []) if str(item)),
            files=tuple(str(item) for item in data.get("files", []) if str(item)),
            path=path,
            title_i18n=title_i18n,
            description_i18n=description_i18n,
        )

    def title_for(self, lang: str) -> str:
        language = normalize_lang(lang)
        return (self.title_i18n or {}).get(language, self.title)

    def description_for(self, lang: str) -> str:
        language = normalize_lang(lang)
        return (self.description_i18n or {}).get(language, self.description)


def _meta_from_script(path: Path) -> ModuleMeta:
    result = subprocess.run(
        [str(path), "meta"],
        cwd=str(ROOT),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        errors="replace",
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
            except Exception as exc:  # noqa: BLE001 - one bad module must not break the TUI.
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
        errors="replace",
        check=False,
    )
    if result.returncode == 0:
        status = "installed"
    elif result.returncode == 5:
        status = "not-installed"
    else:
        status = "unknown"
    return replace(meta, status=status)


def module_by_id(modules: list[ModuleMeta]) -> dict[str, ModuleMeta]:
    return {module.id: module for module in modules}
