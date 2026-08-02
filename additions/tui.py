#!/usr/bin/env python3
from __future__ import annotations

import argparse
import curses
import sys
import textwrap
from dataclasses import dataclass
from typing import Any

from i18n import (
    SUPPORTED_LANGUAGES,
    danger_text,
    policy_text,
    status_text,
    tr,
)
from module_api import check_api, emit_api
from registry import BUILTIN_SECTIONS, ModuleMeta, discover_modules, module_by_id
from runner import (
    RunOptions,
    clear_terminal,
    exit_code,
    print_summary,
    run_actions,
    terminal_failure_prompt,
)

ACTIONS = ["install", "delete", "reinstall", "skip"]
ACTION_KEYS = {"install": "I", "delete": "D", "reinstall": "R", "skip": "S"}
POLICIES = ["noconfirm", "confirm-local", "confirm-all"]
LANGUAGES = list(SUPPORTED_LANGUAGES)
BACKUPS = ["true", "false"]

PAIR_TITLE = 1
PAIR_SECTION = 2
PAIR_INSTALL = 3
PAIR_DELETE = 4
PAIR_REINSTALL = 5
PAIR_SKIP = 6
PAIR_RUN = 7
PAIR_HELP = 8
PAIR_LOW = 9
PAIR_MEDIUM = 10
PAIR_HIGH = 11
PAIR_STATUS = 12
PAIR_ERROR = 13


@dataclass
class Settings:
    policy: str = "noconfirm"
    lang: str = "en"
    backup: str = "true"


@dataclass
class RunRequest:
    actions: dict[str, str]
    settings: Settings


@dataclass(frozen=True)
class SectionSpec:
    id: str
    translation_key: str
    module_section: str | None = None


@dataclass
class Row:
    kind: str
    label: str
    module: ModuleMeta | None = None
    setting: str | None = None
    section: str | None = None


@dataclass(frozen=True)
class ModalLine:
    text: str = ""
    style: str = "normal"


def init_colors() -> None:
    if not curses.has_colors():
        return
    curses.start_color()
    background = -1
    try:
        curses.use_default_colors()
    except curses.error:
        background = curses.COLOR_BLACK

    definitions = {
        PAIR_TITLE: (curses.COLOR_CYAN, background),
        PAIR_SECTION: (curses.COLOR_BLUE, background),
        PAIR_INSTALL: (curses.COLOR_GREEN, background),
        PAIR_DELETE: (curses.COLOR_RED, background),
        PAIR_REINSTALL: (curses.COLOR_YELLOW, background),
        PAIR_SKIP: (curses.COLOR_WHITE, background),
        PAIR_RUN: (curses.COLOR_GREEN, background),
        PAIR_HELP: (curses.COLOR_CYAN, background),
        PAIR_LOW: (curses.COLOR_GREEN, background),
        PAIR_MEDIUM: (curses.COLOR_YELLOW, background),
        PAIR_HIGH: (curses.COLOR_RED, background),
        PAIR_STATUS: (curses.COLOR_CYAN, background),
        PAIR_ERROR: (curses.COLOR_RED, background),
    }
    for pair_id, (foreground, background) in definitions.items():
        try:
            curses.init_pair(pair_id, foreground, background)
        except curses.error:
            continue


def color_pair(pair_id: int) -> int:
    if not curses.has_colors():
        return curses.A_NORMAL
    return curses.color_pair(pair_id)


class AdditionsTui:
    def __init__(
        self,
        stdscr: Any,
        modules: list[ModuleMeta],
        settings: Settings | None = None,
    ) -> None:
        self.stdscr = stdscr
        self.modules = modules
        self.settings = settings or Settings()
        self.actions = {module.id: module.default_action for module in modules}
        self.cursor = 0
        self.scroll = 0
        self.sections = self._build_sections()
        self.collapsed = {section.id: False for section in self.sections}

    def _build_sections(self) -> list[SectionSpec]:
        sections = [SectionSpec("settings", "settings")]
        known = set()
        for section_id in BUILTIN_SECTIONS:
            sections.append(SectionSpec(section_id, section_id, section_id))
            known.add(section_id)
        for section_id in sorted({module.section for module in self.modules} - known):
            sections.append(SectionSpec(section_id, section_id, section_id))
        return sections

    def section_label(self, section: SectionSpec) -> str:
        translated = tr(self.settings.lang, section.translation_key)
        if translated == section.translation_key and section.id not in {"settings", *BUILTIN_SECTIONS}:
            return section.id.replace("-", " ").title()
        return translated

    def selected_count(self) -> int:
        return sum(action != "skip" for action in self.actions.values())

    def settings_rows(self) -> list[Row]:
        lang = self.settings.lang
        return [
            Row("button", tr(lang, "skip_all"), setting="skip_all", section="settings"),
            Row("button", tr(lang, "install_all"), setting="install_all", section="settings"),
            Row("button", tr(lang, "reinstall_all"), setting="reinstall_all", section="settings"),
            Row(
                "toggle",
                f"{tr(lang, 'policy')}: {policy_text(lang, self.settings.policy)}",
                setting="policy",
                section="settings",
            ),
            Row(
                "toggle",
                f"{tr(lang, 'language')}: {self.settings.lang}",
                setting="language",
                section="settings",
            ),
            Row(
                "toggle",
                f"{tr(lang, 'backup')}: {tr(lang, 'yes' if self.settings.backup == 'true' else 'no')}",
                setting="backup",
                section="settings",
            ),
        ]

    def rows(self) -> list[Row]:
        rows: list[Row] = []
        for section in self.sections:
            rows.append(
                Row(
                    "section",
                    self.section_label(section),
                    section=section.id,
                )
            )
            if self.collapsed.get(section.id, False):
                continue
            if section.id == "settings":
                rows.extend(self.settings_rows())
                continue
            section_modules = [
                module for module in self.modules if module.section == section.module_section
            ]
            if section_modules:
                rows.extend(
                    Row(
                        "module",
                        self.module_label(module),
                        module=module,
                        section=section.id,
                    )
                    for module in section_modules
                )
            else:
                rows.append(Row("info", tr(self.settings.lang, "empty"), section=section.id))

        rows.extend(
            [
                Row("blank", ""),
                Row(
                    "run",
                    tr(self.settings.lang, "run_count", count=self.selected_count()),
                    setting="run",
                ),
                Row("help", tr(self.settings.lang, "help"), setting="help"),
            ]
        )
        return rows

    @staticmethod
    def selectable_indexes(rows: list[Row]) -> list[int]:
        return [
            index
            for index, row in enumerate(rows)
            if row.kind in {"section", "button", "toggle", "module", "run", "help"}
        ]

    def module_label(self, module: ModuleMeta) -> str:
        action = self.actions.get(module.id, module.default_action)
        status = status_text(self.settings.lang, module.status)
        return f"[{ACTION_KEYS[action]}] {module.title_for(self.settings.lang)}  ·  {status}"

    def clamp_cursor(self) -> None:
        rows = self.rows()
        selectable = self.selectable_indexes(rows)
        if not selectable:
            self.cursor = 0
            return
        if self.cursor not in selectable:
            self.cursor = min(selectable, key=lambda index: abs(index - self.cursor))
        self.cursor = max(selectable[0], min(selectable[-1], self.cursor))

    def move(self, delta: int) -> None:
        rows = self.rows()
        selectable = self.selectable_indexes(rows)
        if not selectable:
            return
        if self.cursor not in selectable:
            self.cursor = selectable[0]
            return
        position = selectable.index(self.cursor)
        position = max(0, min(len(selectable) - 1, position + delta))
        self.cursor = selectable[position]

    @staticmethod
    def cycle_value(current: str, values: list[str], delta: int = 1) -> str:
        index = values.index(current)
        return values[(index + delta) % len(values)]

    def current_row(self) -> Row | None:
        rows = self.rows()
        if not rows or self.cursor >= len(rows):
            return None
        return rows[self.cursor]

    def current_module(self) -> ModuleMeta | None:
        row = self.current_row()
        return row.module if row and row.kind == "module" else None

    def _move_to_section(self, section_id: str) -> None:
        for index, row in enumerate(self.rows()):
            if row.kind == "section" and row.section == section_id:
                self.cursor = index
                return

    def toggle_section(self, section_id: str) -> None:
        self.collapsed[section_id] = not self.collapsed.get(section_id, False)
        self._move_to_section(section_id)

    def collapse_current_section(self) -> None:
        row = self.current_row()
        if not row or not row.section:
            return
        self.collapsed[row.section] = True
        self._move_to_section(row.section)

    def expand_or_open(self) -> None:
        row = self.current_row()
        if not row:
            return
        if row.kind == "section" and row.section:
            self.collapsed[row.section] = False
            return
        if row.kind == "module" and row.module:
            self.show_details(row.module)

    def activate(self) -> str | None:
        row = self.current_row()
        if not row:
            return None
        if row.kind == "section" and row.section:
            self.toggle_section(row.section)
            return None
        if row.kind == "button":
            actions = {
                "skip_all": "skip",
                "install_all": "install",
                "reinstall_all": "reinstall",
            }
            if row.setting in actions:
                self.set_all(actions[row.setting])
            return None
        if row.kind == "toggle":
            self.toggle(row.setting or "")
            return None
        if row.kind == "module" and row.module:
            self.show_details(row.module)
            return None
        if row.kind == "run":
            return "run"
        if row.kind == "help":
            self.show_help()
        return None

    def toggle(self, setting: str) -> None:
        if setting == "policy":
            self.settings.policy = self.cycle_value(self.settings.policy, POLICIES)
        elif setting == "language":
            self.settings.lang = self.cycle_value(self.settings.lang, LANGUAGES)
        elif setting == "backup":
            self.settings.backup = self.cycle_value(self.settings.backup, BACKUPS)

    def set_all(self, action: str) -> None:
        for module in self.modules:
            if action == "skip" or action in module.supported_actions:
                self.actions[module.id] = action

    def set_action(self, action: str) -> None:
        module = self.current_module()
        if module and (action == "skip" or action in module.supported_actions):
            self.actions[module.id] = action

    def cycle_action(self) -> str | None:
        module = self.current_module()
        if module:
            current = self.actions.get(module.id, module.default_action)
            available = list(module.actions_with_skip())
            self.actions[module.id] = self.cycle_value(current, available)
            return None
        return self.activate()

    def row_attr(self, row: Row, selected: bool) -> int:
        attr = curses.A_NORMAL
        if row.kind == "section":
            attr |= curses.A_BOLD | color_pair(PAIR_SECTION)
        elif row.kind == "run":
            attr |= curses.A_BOLD | color_pair(PAIR_RUN)
        elif row.kind == "help":
            attr |= color_pair(PAIR_HELP)
        elif row.kind == "module" and row.module:
            action = self.actions.get(row.module.id, row.module.default_action)
            pair = {
                "install": PAIR_INSTALL,
                "delete": PAIR_DELETE,
                "reinstall": PAIR_REINSTALL,
                "skip": PAIR_SKIP,
            }.get(action, PAIR_SKIP)
            attr |= color_pair(pair)
            if action == "skip":
                attr |= curses.A_DIM
        elif row.kind == "info":
            attr |= curses.A_DIM
        if selected:
            attr |= curses.A_REVERSE
        return attr

    def _safe_addstr(self, window: Any, y: int, x: int, text: str, attr: int = 0) -> None:
        height, width = window.getmaxyx()
        if y < 0 or y >= height or x < 0 or x >= width:
            return
        try:
            window.addstr(y, x, text[: max(0, width - x - 1)], attr)
        except curses.error:
            pass

    def draw(self) -> None:
        self.stdscr.erase()
        height, width = self.stdscr.getmaxyx()
        rows = self.rows()
        self.clamp_cursor()

        title = tr(self.settings.lang, "app_title")
        selected = f"{tr(self.settings.lang, 'selected')}: {self.selected_count()}"
        self._safe_addstr(
            self.stdscr,
            0,
            0,
            title,
            curses.A_BOLD | color_pair(PAIR_TITLE),
        )
        if len(title) + len(selected) + 3 < width:
            self._safe_addstr(
                self.stdscr,
                0,
                max(0, width - len(selected) - 1),
                selected,
                color_pair(PAIR_STATUS),
            )

        content_top = 2
        visible_height = max(1, height - content_top - 2)
        if self.cursor < self.scroll:
            self.scroll = self.cursor
        if self.cursor >= self.scroll + visible_height:
            self.scroll = self.cursor - visible_height + 1
        self.scroll = max(0, min(self.scroll, max(0, len(rows) - visible_height)))

        for offset, row in enumerate(rows[self.scroll : self.scroll + visible_height]):
            index = offset + self.scroll
            y = content_top + offset
            selected_row = index == self.cursor and row.kind in {
                "section",
                "button",
                "toggle",
                "module",
                "run",
                "help",
            }
            label = row.label
            if row.kind == "section" and row.section:
                arrow = "▸" if self.collapsed.get(row.section, False) else "▾"
                label = f"{arrow} {label}"
            elif row.kind in {"button", "toggle", "module"}:
                label = f"  {label}"
            elif row.kind == "run":
                label = f"▶ {label}"
            elif row.kind == "help":
                label = f"? {label}"
            self._safe_addstr(self.stdscr, y, 0, label, self.row_attr(row, selected_row))

        self._safe_addstr(
            self.stdscr,
            height - 1,
            0,
            tr(self.settings.lang, "main_help"),
            curses.A_DIM,
        )
        self.stdscr.refresh()

    def _wrap_modal_lines(self, lines: list[ModalLine], width: int) -> list[ModalLine]:
        wrapped: list[ModalLine] = []
        for line in lines:
            if not line.text:
                wrapped.append(line)
                continue
            paragraphs = line.text.splitlines() or [""]
            for paragraph in paragraphs:
                pieces = textwrap.wrap(paragraph, width=max(10, width)) or [""]
                wrapped.extend(ModalLine(piece, line.style) for piece in pieces)
        return wrapped

    def modal_attr(self, style: str) -> int:
        if style == "title":
            return curses.A_BOLD | color_pair(PAIR_TITLE)
        if style == "label":
            return curses.A_BOLD | color_pair(PAIR_SECTION)
        if style == "low":
            return curses.A_BOLD | color_pair(PAIR_LOW)
        if style == "medium":
            return curses.A_BOLD | color_pair(PAIR_MEDIUM)
        if style == "high":
            return curses.A_BOLD | color_pair(PAIR_HIGH)
        if style == "error":
            return curses.A_BOLD | color_pair(PAIR_ERROR)
        if style == "dim":
            return curses.A_DIM
        return curses.A_NORMAL

    def show_modal(self, title: str, lines: list[ModalLine]) -> None:
        screen_height, screen_width = self.stdscr.getmaxyx()
        win_h = max(6, min(max(6, screen_height - 2), 24))
        win_w = max(24, min(max(24, screen_width - 2), 88))
        win_h = min(win_h, screen_height)
        win_w = min(win_w, screen_width)
        y = max(0, (screen_height - win_h) // 2)
        x = max(0, (screen_width - win_w) // 2)
        window = curses.newwin(win_h, win_w, y, x)
        window.keypad(True)
        content_width = max(10, win_w - 4)
        content = self._wrap_modal_lines(lines, content_width)
        viewport_height = max(1, win_h - 4)
        scroll = 0

        while True:
            window.erase()
            try:
                window.box()
            except curses.error:
                pass
            self._safe_addstr(
                window,
                0,
                2,
                f" {title} ",
                curses.A_BOLD | color_pair(PAIR_TITLE),
            )

            for offset, line in enumerate(content[scroll : scroll + viewport_height]):
                self._safe_addstr(window, 1 + offset, 2, line.text, self.modal_attr(line.style))

            if len(content) > viewport_height:
                first = scroll + 1
                last = min(len(content), scroll + viewport_height)
                position = f"{first}-{last}/{len(content)}"
                self._safe_addstr(window, win_h - 2, 2, position, curses.A_DIM)
                hint = tr(self.settings.lang, "scroll_hint")
            else:
                hint = tr(self.settings.lang, "close_hint")
            self._safe_addstr(window, win_h - 1, 2, f" {hint} ", curses.A_DIM)
            window.refresh()

            key = window.getch()
            if key in (27, ord("q"), 10, 13, curses.KEY_LEFT, ord("h")):
                break
            if key in (curses.KEY_DOWN, ord("j")):
                scroll = min(max(0, len(content) - viewport_height), scroll + 1)
            elif key in (curses.KEY_UP, ord("k")):
                scroll = max(0, scroll - 1)
            elif key == curses.KEY_NPAGE:
                scroll = min(max(0, len(content) - viewport_height), scroll + viewport_height)
            elif key == curses.KEY_PPAGE:
                scroll = max(0, scroll - viewport_height)
            elif key == curses.KEY_HOME:
                scroll = 0
            elif key == curses.KEY_END:
                scroll = max(0, len(content) - viewport_height)

        del window
        self.stdscr.touchwin()
        self.stdscr.refresh()

    def show_details(self, module: ModuleMeta) -> None:
        lang = self.settings.lang
        lines = [
            ModalLine(tr(lang, "title"), "label"),
            ModalLine(module.title_for(lang), "title"),
            ModalLine(),
            ModalLine(tr(lang, "description"), "label"),
            ModalLine(module.description_for(lang)),
            ModalLine(),
            ModalLine(tr(lang, "repo_packages"), "label"),
            ModalLine(", ".join(module.packages) if module.packages else tr(lang, "none")),
            ModalLine(),
            ModalLine(tr(lang, "aur_packages"), "label"),
            ModalLine(", ".join(module.aur_packages) if module.aur_packages else tr(lang, "none")),
            ModalLine(),
            ModalLine(tr(lang, "files"), "label"),
        ]
        if module.files:
            lines.extend(ModalLine(f"• {item}") for item in module.files)
        else:
            lines.append(ModalLine(tr(lang, "none")))
        lines.extend(
            [
                ModalLine(),
                ModalLine(f"{tr(lang, 'danger')}: {danger_text(lang, module.danger)}", module.danger),
                ModalLine(f"{tr(lang, 'status')}: {status_text(lang, module.status)}"),
                ModalLine(f"{tr(lang, 'module_id')}: {module.id}", "dim"),
            ]
        )
        if module.meta_error:
            lines.extend(
                [
                    ModalLine(),
                    ModalLine(tr(lang, "meta_error"), "error"),
                    ModalLine(module.meta_error, "error"),
                ]
            )
        self.show_modal(tr(lang, "details_title"), lines)

    def show_help(self) -> None:
        lang = self.settings.lang
        lines = [
            ModalLine(tr(lang, "help_navigation"), "label"),
            ModalLine(tr(lang, "help_nav_body")),
            ModalLine(),
            ModalLine(tr(lang, "help_actions"), "label"),
            ModalLine(tr(lang, "help_action_body")),
            ModalLine(),
            ModalLine(tr(lang, "help_execution"), "label"),
            ModalLine(tr(lang, "help_execution_body")),
        ]
        self.show_modal(tr(lang, "help_title"), lines)

    def request(self) -> RunRequest:
        return RunRequest(
            actions=dict(self.actions),
            settings=Settings(
                policy=self.settings.policy,
                lang=self.settings.lang,
                backup=self.settings.backup,
            ),
        )

    def run(self) -> RunRequest | None:
        try:
            curses.curs_set(0)
        except curses.error:
            pass
        self.stdscr.keypad(True)
        init_colors()
        self.clamp_cursor()

        while True:
            self.draw()
            key = self.stdscr.getch()
            if key in (ord("q"), 27):
                return None
            if key in (curses.KEY_DOWN, ord("j")):
                self.move(1)
            elif key in (curses.KEY_UP, ord("k")):
                self.move(-1)
            elif key in (curses.KEY_LEFT, ord("h")):
                self.collapse_current_section()
            elif key in (curses.KEY_RIGHT, ord("l")):
                self.expand_or_open()
            elif key in (10, 13):
                if self.activate() == "run":
                    return self.request()
            elif key == ord(" "):
                if self.cycle_action() == "run":
                    return self.request()
            elif key == ord("i"):
                self.set_action("install")
            elif key == ord("d"):
                self.set_action("delete")
            elif key == ord("r"):
                self.set_action("reinstall")
            elif key == ord("s"):
                self.set_action("skip")
            elif key in (curses.KEY_F1, ord("?")):
                self.show_help()
            elif key in (curses.KEY_F10, 19):
                return self.request()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="dots-hyprland additions setup")
    api_group = parser.add_mutually_exclusive_group()
    api_group.add_argument(
        "--print-api",
        nargs="?",
        const="markdown",
        choices=("markdown", "json"),
        metavar="FORMAT",
        help="print the auto-generated module API as markdown or json",
    )
    api_group.add_argument(
        "--check-api",
        action="store_true",
        help="validate lib documentation, shell function collisions and module contracts",
    )
    parser.add_argument(
        "--api-output",
        metavar="PATH",
        help="write --print-api output to PATH instead of stdout",
    )
    parser.add_argument("--no-tui", action="store_true")
    parser.add_argument("--install", default="")
    parser.add_argument("--delete", default="")
    parser.add_argument("--reinstall", default="")
    parser.add_argument("--policy", default="noconfirm", choices=POLICIES)
    parser.add_argument("--backup", default="true", choices=BACKUPS)
    parser.add_argument("--lang", default="en", choices=LANGUAGES)
    return parser.parse_args(argv)


def parse_module_list(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def execute(modules: list[ModuleMeta], actions: dict[str, str], options: RunOptions) -> int:
    clear_terminal()
    summary = run_actions(
        modules,
        actions,
        options,
        failure_callback=terminal_failure_prompt,
    )
    print_summary(summary, options.lang)
    return exit_code(summary)


def run_no_tui(args: argparse.Namespace) -> int:
    modules = discover_modules(with_status=False)
    by_id = module_by_id(modules)
    actions = {module.id: "skip" for module in modules}

    for action_name in ("install", "delete", "reinstall"):
        for module_id in parse_module_list(getattr(args, action_name)):
            if module_id not in by_id:
                print(tr(args.lang, "unknown_module", module_id=module_id), file=sys.stderr)
                return 2
            module = by_id[module_id]
            if action_name not in module.supported_actions:
                print(
                    tr(args.lang, "unsupported_action", action=action_name, module_id=module_id),
                    file=sys.stderr,
                )
                return 2
            actions[module_id] = action_name

    options = RunOptions(
        policy=args.policy,
        backup=args.backup,
        lang=args.lang,
        selection_confirmed=False,
    )
    return execute(modules, actions, options)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.api_output and not args.print_api:
        print("--api-output requires --print-api", file=sys.stderr)
        return 2
    if args.print_api:
        return emit_api(args.print_api, args.api_output)
    if args.check_api:
        return check_api()
    if args.no_tui:
        return run_no_tui(args)

    modules = discover_modules(with_status=True)
    initial_settings = Settings(policy=args.policy, lang=args.lang, backup=args.backup)
    request = curses.wrapper(
        lambda stdscr: AdditionsTui(stdscr, modules, initial_settings).run()
    )
    if request is None:
        return 0

    options = RunOptions(
        policy=request.settings.policy,
        backup=request.settings.backup,
        lang=request.settings.lang,
        selection_confirmed=True,
    )
    return execute(modules, request.actions, options)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
