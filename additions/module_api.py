from __future__ import annotations

import json
import re
import subprocess
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from registry import ADDITIONS_DIR, ModuleMeta, discover_modules

ROOT = ADDITIONS_DIR.parent
LIB_DIR = ADDITIONS_DIR / "lib"
MODULE_DIRS = (ADDITIONS_DIR / "modules", ADDITIONS_DIR / "apps")
TEMPLATE_FILE = ADDITIONS_DIR / "templates" / "module.sh"
DOC_FILES = (ADDITIONS_DIR / "setup-additions",)
FUNCTION_PATTERN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{")
API_START = "# @api"
API_END = "# @end"
API_SCHEMA_VERSION = 1


@dataclass(frozen=True)
class ApiEntry:
    kind: str
    name: str
    source: str
    line: int
    attributes: dict[str, str]


@dataclass(frozen=True)
class ApiIssue:
    severity: str
    code: str
    message: str
    source: str = ""


def _relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def _parse_api_blocks(path: Path) -> list[ApiEntry]:
    entries: list[ApiEntry] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0
    while index < len(lines):
        if lines[index].strip() != API_START:
            index += 1
            continue
        start_line = index + 1
        index += 1
        attributes: dict[str, str] = {}
        while index < len(lines) and lines[index].strip() != API_END:
            text = lines[index].strip()
            if text.startswith("#"):
                text = text[1:].strip()
            if text:
                key, separator, value = text.partition(":")
                if separator:
                    attributes[key.strip()] = value.strip()
            index += 1
        if index >= len(lines):
            raise ValueError(f"unterminated @api block at {_relative(path)}:{start_line}")
        kind = attributes.pop("kind", "").strip()
        name = attributes.pop("name", "").strip()
        if not kind or not name:
            raise ValueError(f"@api block missing kind/name at {_relative(path)}:{start_line}")
        entries.append(ApiEntry(kind, name, _relative(path), start_line, attributes))
        index += 1
    return entries


def _function_definitions(path: Path) -> list[tuple[str, int]]:
    result: list[tuple[str, int]] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        match = FUNCTION_PATTERN.match(line)
        if match:
            result.append((match.group(1), line_number))
    return result


def _module_dict(module: ModuleMeta) -> dict[str, Any]:
    return {
        "id": module.id,
        "section": module.section,
        "title": module.title,
        "description": module.description,
        "version": module.version,
        "danger": module.danger,
        "default_action": module.default_action,
        "supported_actions": list(module.supported_actions),
        "packages": list(module.packages),
        "aur_packages": list(module.aur_packages),
        "required_commands": list(module.required_commands),
        "files": list(module.files),
        "tags": list(module.tags),
        "path": _relative(module.path),
        "meta_error": module.meta_error,
    }


def validate_api(entries: list[ApiEntry], modules: list[ModuleMeta]) -> list[ApiIssue]:
    issues: list[ApiIssue] = []
    definitions: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for path in sorted(LIB_DIR.glob("*.sh")):
        for name, line in _function_definitions(path):
            definitions[name].append((_relative(path), line))

    for name, locations in sorted(definitions.items()):
        if len(locations) > 1:
            rendered = ", ".join(f"{source}:{line}" for source, line in locations)
            issues.append(ApiIssue("error", "function-collision", f"shell function {name} is defined multiple times: {rendered}"))

    function_docs: dict[str, list[ApiEntry]] = defaultdict(list)
    for entry in entries:
        if entry.kind == "function":
            function_docs[entry.name].append(entry)
    for name, locations in sorted(definitions.items()):
        if name.startswith("_"):
            continue
        if name not in function_docs:
            source, line = locations[0]
            issues.append(ApiIssue("error", "undocumented-public-function", f"public function {name} has no @api documentation", f"{source}:{line}"))
    for name, docs in sorted(function_docs.items()):
        if name not in definitions:
            issues.append(ApiIssue("error", "orphan-function-doc", f"documented function {name} is not defined", docs[0].source))
        if len(docs) > 1:
            issues.append(ApiIssue("error", "duplicate-function-doc", f"function {name} has multiple @api blocks"))

    callbacks = {entry.name for entry in entries if entry.kind == "callback"}
    lib_names = set(definitions)
    seen_ids: dict[str, str] = {}
    for module in modules:
        if module.meta_error:
            issues.append(ApiIssue("error", "module-meta", f"{module.id}: {module.meta_error}", _relative(module.path)))
        previous = seen_ids.get(module.id)
        if previous:
            issues.append(ApiIssue("error", "duplicate-module-id", f"duplicate module id {module.id}: {previous}, {_relative(module.path)}"))
        else:
            seen_ids[module.id] = _relative(module.path)

        try:
            syntax = subprocess.run(["bash", "-n", str(module.path)], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            if syntax.returncode != 0:
                issues.append(ApiIssue("error", "shell-syntax", syntax.stderr.strip(), _relative(module.path)))
        except OSError as exc:
            issues.append(ApiIssue("error", "bash-unavailable", str(exc), _relative(module.path)))

        functions = {name for name, _ in _function_definitions(module.path)}
        collisions = functions & lib_names
        for name in sorted(collisions):
            issues.append(ApiIssue("error", "module-library-collision", f"module function {name} collides with lib API/runtime", _relative(module.path)))
        for name in sorted(functions - callbacks):
            if not name.startswith("_"):
                issues.append(ApiIssue("error", "module-helper-visibility", f"module helper {name} must start with _ or be a documented callback", _relative(module.path)))
        if "status_steps" not in functions:
            issues.append(ApiIssue("error", "missing-callback", f"{module.id} must define status_steps", _relative(module.path)))
        if "install" in module.supported_actions and "install_steps" not in functions:
            issues.append(ApiIssue("error", "missing-callback", f"{module.id} supports install but lacks install_steps", _relative(module.path)))
        if "delete" in module.supported_actions and "delete_steps" not in functions:
            issues.append(ApiIssue("error", "missing-callback", f"{module.id} supports delete but lacks delete_steps", _relative(module.path)))
        if "reinstall" in module.supported_actions and "reinstall_steps" not in functions:
            if not {"install", "delete"}.issubset(module.supported_actions):
                issues.append(ApiIssue("error", "missing-callback", f"{module.id} needs reinstall_steps or install+delete support", _relative(module.path)))

    return issues


def build_api() -> dict[str, Any]:
    entries: list[ApiEntry] = []
    parse_issues: list[ApiIssue] = []
    for path in [*sorted(LIB_DIR.glob("*.sh")), *DOC_FILES]:
        try:
            entries.extend(_parse_api_blocks(path))
        except (OSError, ValueError) as exc:
            parse_issues.append(ApiIssue("error", "api-parse", str(exc), _relative(path)))
    modules = discover_modules(with_status=False)
    issues = [*parse_issues, *validate_api(entries, modules)]
    template = TEMPLATE_FILE.read_text(encoding="utf-8") if TEMPLATE_FILE.exists() else ""
    return {
        "schema_version": API_SCHEMA_VERSION,
        "source": "additions/lib/*.sh @api blocks and module meta output",
        "entries": [asdict(entry) for entry in sorted(entries, key=lambda item: (item.kind, item.source, item.line, item.name))],
        "modules": [_module_dict(module) for module in sorted(modules, key=lambda item: (item.section, item.id))],
        "template": template,
        "issues": [asdict(issue) for issue in issues],
    }


def _entry_value(entry: dict[str, Any], key: str, default: str = "") -> str:
    return str(entry.get("attributes", {}).get(key, default))


def render_markdown(api: dict[str, Any]) -> str:
    lines = [
        "# dots-hyprland additions module API",
        "",
        "This document is generated from the current source. Do not edit generated output; edit `@api` blocks or module metadata instead.",
        "",
    ]
    entries = api["entries"]
    group_order = ["command", "metadata", "callback", "function", "policy", "environment", "exit_code"]
    titles = {
        "command": "CLI and module commands",
        "metadata": "Module metadata",
        "callback": "Module callbacks",
        "function": "Public shell helper functions",
        "policy": "Confirmation policies",
        "environment": "Runtime environment",
        "exit_code": "Exit codes",
    }
    for kind in group_order:
        group = [entry for entry in entries if entry["kind"] == kind]
        if not group:
            continue
        lines.extend([f"## {titles[kind]}", ""])
        for entry in group:
            signature = _entry_value(entry, "signature", entry["name"])
            lines.append(f"### `{signature}`")
            lines.append("")
            summary = _entry_value(entry, "summary")
            if summary:
                lines.append(summary)
                lines.append("")
            details = []
            for key in ("required", "type", "values", "default", "returns", "effects", "notes"):
                value = _entry_value(entry, key)
                if value:
                    details.append(f"- **{key.replace('_', ' ').title()}:** {value}")
            details.append(f"- **Source:** `{entry['source']}:{entry['line']}`")
            lines.extend(details)
            lines.append("")

    lines.extend(["## Current modules", ""])
    for module in api["modules"]:
        lines.append(f"### `{module['id']}` — {module['title']}")
        lines.append("")
        lines.append(module["description"])
        lines.append("")
        lines.append(f"- Section: `{module['section']}`")
        lines.append(f"- Version: `{module['version']}`")
        lines.append(f"- Danger: `{module['danger']}`")
        lines.append(f"- Actions: `{', '.join(module['supported_actions'])}`")
        lines.append(f"- Repository packages: `{', '.join(module['packages']) or '-'}`")
        lines.append(f"- AUR packages: `{', '.join(module['aur_packages']) or '-'}`")
        lines.append(f"- Required commands: `{', '.join(module['required_commands']) or '-'}`")
        lines.append(f"- Managed paths: `{', '.join(module['files']) or '-'}`")
        lines.append(f"- Source: `{module['path']}`")
        lines.append("")

    if api.get("template"):
        lines.extend(["## Module template", "", "```bash", api["template"].rstrip(), "```", ""])

    issues = api["issues"]
    lines.extend(["## Validation", ""])
    if issues:
        for issue in issues:
            source = f" (`{issue['source']}`)" if issue.get("source") else ""
            lines.append(f"- **{issue['severity'].upper()} {issue['code']}:** {issue['message']}{source}")
    else:
        lines.append("API and module contract validation passed.")
    lines.append("")
    return "\n".join(lines)


def render_json(api: dict[str, Any]) -> str:
    return json.dumps(api, indent=2, ensure_ascii=False) + "\n"


def write_output(content: str, output: str | None) -> None:
    if not output or output == "-":
        print(content, end="")
        return
    path = Path(output).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def emit_api(output_format: str, output: str | None = None) -> int:
    api = build_api()
    content = render_json(api) if output_format == "json" else render_markdown(api)
    write_output(content, output)
    return 1 if any(issue["severity"] == "error" for issue in api["issues"]) else 0


def check_api() -> int:
    api = build_api()
    issues = api["issues"]
    if not issues:
        print("API validation passed.")
        return 0
    for issue in issues:
        source = f" [{issue['source']}]" if issue.get("source") else ""
        print(f"{issue['severity'].upper()} {issue['code']}: {issue['message']}{source}")
    return 1 if any(issue["severity"] == "error" for issue in issues) else 0
