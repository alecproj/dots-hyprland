from __future__ import annotations

import json
import re
import subprocess
from collections import Counter
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from i18n import normalize_lang

ROOT = Path(__file__).resolve().parents[1]
ADDITIONS_DIR = ROOT / "additions"
VALID_DANGER = {"low", "medium", "high"}
VALID_ACTIONS = {"install", "delete", "reinstall", "skip"}
RUNTIME_ACTIONS = {"install", "delete", "reinstall"}
SECTION_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")
ID_PATTERN = SECTION_PATTERN
META_TIMEOUT_SECONDS = 5
STATUS_TIMEOUT_SECONDS = 10


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


def _string_tuple(value: Any, field: str) -> tuple[str, ...]:
    if value is None:
        return ()
    if not isinstance(value, list):
        raise ValueError(f"invalid list field: {field}")
    result: list[str] = []
    for item in value:
        if not isinstance(item, str) or not item.strip():
            raise ValueError(f"invalid list entry: {field}")
        text = item.strip()
        if text in result:
            raise ValueError(f"duplicate list entry in {field}: {text}")
        result.append(text)
    return tuple(result)


@dataclass(frozen=True)
class SectionMeta:
    id: str
    title: str
    title_ru: str
    module_paths: tuple[str, ...] = ()

    def title_for(self, lang: str) -> str:
        if normalize_lang(lang) == "ru" and self.title_ru:
            return self.title_ru
        return self.title


# Single source of truth for TUI sections, translations, order and module paths.
# Paths are exact and relative to additions/. A module's physical directory has
# no semantic meaning: any registered path may belong to any registered section.
SECTIONS: tuple[SectionMeta, ...] = (
    SectionMeta(
        id="additions",
        title="Additions",
        title_ru="Дополнения",
        module_paths=(
            "modules/hypr-keybinds.sh",
            "modules/xdg-user-dirs.sh",
            "modules/greetd-regreet.sh",
            "modules/throne-vpn.sh",
            "modules/neovim.sh",
            "modules/tmux.sh",
            "modules/hypr-kdeconnect-fix.sh",
            "modules/selfhosted-music.sh"
        ),
    ),
    SectionMeta(
        id="applications",
        title="Applications",
        title_ru="Приложения",
        module_paths=(
            "apps/discord.sh",
            "apps/dolphin-additions.sh",
            "apps/easyeffects.sh",
            "apps/firefox.sh",
            "apps/gnome-text-editor.sh",
            "apps/keepassxc.sh",
            "apps/libreoffice.sh",
            "apps/localsend.sh",
            "apps/mission-center.sh",
            "apps/obsidian.sh",
            "apps/openssh.sh",
            "apps/rust-toolchain.sh",
            "apps/rustdesk.sh",
            "apps/syncthing.sh",
            "apps/telegram-desktop.sh",
        ),
    ),
    SectionMeta(
        id="embedded",
        title="Embedded",
        title_ru="Встроенное ПО",
        module_paths=(
            "embedded/arm-none-eabi.sh",
            "embedded/jlink.sh",
            "embedded/modm.sh",
        ),
    ),
)


def _build_section_index() -> dict[str, SectionMeta]:
    result: dict[str, SectionMeta] = {}
    registered_paths: dict[str, str] = {}

    for section in SECTIONS:
        if not SECTION_PATTERN.fullmatch(section.id):
            raise RuntimeError(f"invalid registered section id: {section.id}")
        if section.id in result:
            raise RuntimeError(f"duplicate registered section id: {section.id}")
        if not section.title.strip():
            raise RuntimeError(f"registered section has no English title: {section.id}")

        for module_path in section.module_paths:
            path = Path(module_path)
            if path.is_absolute() or ".." in path.parts or path.suffix != ".sh":
                raise RuntimeError(
                    f"invalid registered module path in {section.id}: {module_path}"
                )
            previous = registered_paths.get(module_path)
            if previous is not None:
                raise RuntimeError(
                    f"module path registered twice: {module_path} ({previous}, {section.id})"
                )
            registered_paths[module_path] = section.id

        result[section.id] = section

    return result


SECTION_BY_ID = _build_section_index()


def _registered_module_paths() -> list[tuple[Path, str]]:
    return [
        (ADDITIONS_DIR / module_path, section.id)
        for section in SECTIONS
        for module_path in section.module_paths
    ]


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
    required_commands: tuple[str, ...] = ()
    files: tuple[str, ...] = ()
    tags: tuple[str, ...] = ()
    supported_actions: tuple[str, ...] = ("install", "delete", "reinstall")
    version: str = "1"
    verify: bool = True
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

        module_id = data["id"].strip()
        if not ID_PATTERN.fullmatch(module_id):
            raise ValueError(f"invalid id: {module_id}")
        if path.stem != module_id:
            raise ValueError(f"module id must match filename: {module_id} != {path.stem}")

        section = data["section"].strip()
        if not SECTION_PATTERN.fullmatch(section):
            raise ValueError(f"invalid section: {section}")

        default_action = data["default_action"].strip()
        if default_action not in VALID_ACTIONS:
            raise ValueError(f"invalid default_action: {default_action}")

        danger = data.get("danger", "medium")
        if danger not in VALID_DANGER:
            raise ValueError(f"invalid danger: {danger}")

        supported_actions = _string_tuple(
            data.get("supported_actions", ["install", "delete", "reinstall"]),
            "supported_actions",
        )
        if not supported_actions:
            raise ValueError("supported_actions must not be empty")
        invalid_actions = set(supported_actions) - RUNTIME_ACTIONS
        if invalid_actions:
            raise ValueError(f"invalid supported action(s): {', '.join(sorted(invalid_actions))}")
        if default_action != "skip" and default_action not in supported_actions:
            raise ValueError("default_action is not listed in supported_actions")

        verify = data.get("verify", True)
        if not isinstance(verify, bool):
            raise ValueError("verify must be boolean")

        version = data.get("version", "1")
        if not isinstance(version, str) or not version.strip():
            raise ValueError("version must be a non-empty string")

        return cls(
            id=module_id,
            section=section,
            title=data["title"].strip(),
            description=data["description"].strip(),
            default_action=default_action,
            path=path,
            packages=_string_tuple(data.get("packages", []), "packages"),
            aur_packages=_string_tuple(data.get("aur_packages", []), "aur_packages"),
            required_commands=_string_tuple(data.get("required_commands", []), "required_commands"),
            files=_string_tuple(data.get("files", []), "files"),
            tags=_string_tuple(data.get("tags", []), "tags"),
            supported_actions=supported_actions,
            version=version.strip(),
            verify=verify,
            danger=danger,
            title_i18n=_translation_map(data.get("title_i18n"), "title_i18n"),
            description_i18n=_translation_map(data.get("description_i18n"), "description_i18n"),
        )

    def title_for(self, lang: str) -> str:
        language = normalize_lang(lang)
        return (self.title_i18n or {}).get(language, self.title)

    def description_for(self, lang: str) -> str:
        language = normalize_lang(lang)
        return (self.description_i18n or {}).get(language, self.description)

    def actions_with_skip(self) -> tuple[str, ...]:
        return (*self.supported_actions, "skip")


def _run_script(path: Path, command: str, timeout: int) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            [str(path), command],
            cwd=str(ROOT),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            errors="replace",
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"{command} timed out after {timeout}s: {path}") from exc


def _meta_from_script(path: Path) -> ModuleMeta:
    result = _run_script(path, "meta", META_TIMEOUT_SECONDS)
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

    for path, registered_section in _registered_module_paths():
        try:
            meta = _meta_from_script(path)
            if meta.section != registered_section:
                raise ValueError(
                    f"section mismatch for {path}: "
                    f"registry={registered_section}, module={meta.section}"
                )
            if with_status:
                meta = meta_with_status(meta)
            modules.append(meta)
        except Exception as exc:  # noqa: BLE001 - one bad module must not break the TUI.
            modules.append(
                ModuleMeta(
                    id=path.stem,
                    section=registered_section,
                    title=path.name,
                    description=str(exc),
                    default_action="skip",
                    danger="high",
                    path=path,
                    status="error",
                    meta_error=str(exc),
                )
            )

    counts = Counter(module.id for module in modules)
    duplicate_ids = {module_id for module_id, count in counts.items() if count > 1}
    if duplicate_ids:
        modules = [
            replace(module, status="error", meta_error=f"duplicate module id: {module.id}")
            if module.id in duplicate_ids
            else module
            for module in modules
        ]
    return modules


def meta_with_status(meta: ModuleMeta) -> ModuleMeta:
    try:
        result = _run_script(meta.path, "status", STATUS_TIMEOUT_SECONDS)
    except RuntimeError:
        return replace(meta, status="unknown")
    if result.returncode == 0:
        status = "installed"
    elif result.returncode == 5:
        status = "not-installed"
    else:
        status = "unknown"
    return replace(meta, status=status)


def module_by_id(modules: list[ModuleMeta]) -> dict[str, ModuleMeta]:
    result: dict[str, ModuleMeta] = {}
    for module in modules:
        if module.id in result:
            raise ValueError(f"duplicate module id: {module.id}")
        result[module.id] = module
    return result
