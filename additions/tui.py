#!/usr/bin/env python3
from __future__ import annotations

import argparse
import curses
import sys
import textwrap
from dataclasses import dataclass
from typing import Any

from registry import ModuleMeta, discover_modules, module_by_id
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
LANGUAGES = ["en", "ru"]
BACKUPS = ["true", "false"]

UI = {
    "en": {
        "settings": "Settings:",
        "additions": "Additions:",
        "applications": "Applications:",
        "skip_all": "Skip all",
        "install_all": "Install all",
        "reinstall_all": "Reinstall all",
        "policy": "Policy",
        "language": "Language",
        "backup": "Backup",
        "help": "j/k or arrows: move | Space: cycle | i/d/r/s: action | Enter: details | F10/Ctrl+S: apply | q: quit",
        "empty": "No modules found.",
        "details_hint": "Press any key to close.",
    },
    "ru": {
        "settings": "Настройки:",
        "additions": "Дополнения:",
        "applications": "Приложения:",
        "skip_all": "Пропустить всё",
        "install_all": "Установить всё",
        "reinstall_all": "Переустановить всё",
        "policy": "Политика",
        "language": "Язык",
        "backup": "Backup",
        "help": "j/k или стрелки: выбор | Space: сменить | i/d/r/s: действие | Enter: детали | F10/Ctrl+S: применить | q: выход",
        "empty": "Модули не найдены.",
        "details_hint": "Нажми любую клавишу, чтобы закрыть.",
    },
}


@dataclass
class Settings:
    policy: str = "noconfirm"
    lang: str = "en"
    backup: str = "true"


@dataclass
class RunRequest:
    actions: dict[str, str]
    settings: Settings


@dataclass
class Row:
    kind: str
    label: str
    module: ModuleMeta | None = None
    setting: str | None = None


class AdditionsTui:
    def __init__(self, stdscr: Any, modules: list[ModuleMeta]) -> None:
        self.stdscr = stdscr
        self.modules = modules
        self.settings = Settings()
        self.actions = {module.id: module.default_action for module in modules}
        self.cursor = 0
        self.scroll = 0

    @property
    def text(self) -> dict[str, str]:
        return UI[self.settings.lang]

    def rows(self) -> list[Row]:
        t = self.text
        rows: list[Row] = [
            Row("heading", t["settings"]),
            Row("button", t["skip_all"], setting="skip_all"),
            Row("button", t["install_all"], setting="install_all"),
            Row("button", t["reinstall_all"], setting="reinstall_all"),
            Row("toggle", f"{t['policy']}: {self.settings.policy}", setting="policy"),
            Row("toggle", f"{t['language']}: {self.settings.lang}", setting="language"),
            Row("toggle", f"{t['backup']}: {self.settings.backup}", setting="backup"),
            Row("blank", ""),
            Row("heading", t["additions"]),
        ]
        rows.extend(
            Row("module", self.module_label(module), module=module)
            for module in self.modules
            if module.section == "additions"
        )
        rows.extend((Row("blank", ""), Row("heading", t["applications"])))
        rows.extend(
            Row("module", self.module_label(module), module=module)
            for module in self.modules
            if module.section == "applications"
        )
        if not self.modules:
            rows.append(Row("info", t["empty"]))
        return rows

    @staticmethod
    def selectable_indexes(rows: list[Row]) -> list[int]:
        return [index for index, row in enumerate(rows) if row.kind in {"button", "toggle", "module"}]

    def module_label(self, module: ModuleMeta) -> str:
        action = self.actions.get(module.id, module.default_action)
        status = f" ({module.status})" if module.status not in {"unknown", "not-installed"} else ""
        return f"[{ACTION_KEYS[action]}] {module.title}{status}"

    def clamp_cursor(self) -> None:
        rows = self.rows()
        selectable = self.selectable_indexes(rows)
        if not selectable:
            self.cursor = 0
            return
        if self.cursor not in selectable:
            self.cursor = selectable[0]
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

    def activate(self) -> None:
        rows = self.rows()
        if not rows or self.cursor >= len(rows):
            return
        row = rows[self.cursor]
        if row.kind == "button":
            actions = {
                "skip_all": "skip",
                "install_all": "install",
                "reinstall_all": "reinstall",
            }
            if row.setting in actions:
                self.set_all(actions[row.setting])
            return
        if row.kind == "toggle":
            self.toggle(row.setting or "")
            return
        if row.kind == "module" and row.module:
            self.show_details(row.module)

    def toggle(self, setting: str) -> None:
        if setting == "policy":
            self.settings.policy = self.cycle_value(self.settings.policy, POLICIES)
        elif setting == "language":
            self.settings.lang = self.cycle_value(self.settings.lang, LANGUAGES)
        elif setting == "backup":
            self.settings.backup = self.cycle_value(self.settings.backup, BACKUPS)

    def set_all(self, action: str) -> None:
        for module in self.modules:
            self.actions[module.id] = action

    def current_module(self) -> ModuleMeta | None:
        rows = self.rows()
        if self.cursor >= len(rows):
            return None
        row = rows[self.cursor]
        return row.module if row.kind == "module" else None

    def set_action(self, action: str) -> None:
        module = self.current_module()
        if module:
            self.actions[module.id] = action

    def cycle_action(self) -> None:
        module = self.current_module()
        if module:
            current = self.actions.get(module.id, module.default_action)
            self.actions[module.id] = self.cycle_value(current, ACTIONS)
            return
        self.activate()

    def draw(self) -> None:
        self.stdscr.erase()
        height, width = self.stdscr.getmaxyx()
        rows = self.rows()
        self.clamp_cursor()
        visible_height = max(1, height - 2)
        if self.cursor < self.scroll:
            self.scroll = self.cursor
        if self.cursor >= self.scroll + visible_height:
            self.scroll = self.cursor - visible_height + 1

        for y, row in enumerate(rows[self.scroll : self.scroll + visible_height]):
            index = y + self.scroll
            attr = curses.A_NORMAL
            if row.kind == "heading":
                attr |= curses.A_BOLD
            if index == self.cursor and row.kind in {"button", "toggle", "module"}:
                attr |= curses.A_REVERSE
            try:
                self.stdscr.addstr(y, 0, row.label[: max(0, width - 1)], attr)
            except curses.error:
                pass

        try:
            self.stdscr.addstr(height - 1, 0, self.text["help"][: max(0, width - 1)], curses.A_DIM)
        except curses.error:
            pass
        self.stdscr.refresh()

    def show_details(self, module: ModuleMeta) -> None:
        height, width = self.stdscr.getmaxyx()
        win_h = max(8, min(height - 2, 20))
        win_w = max(40, min(width - 4, 82))
        y = max(0, (height - win_h) // 2)
        x = max(0, (width - win_w) // 2)
        win = curses.newwin(win_h, win_w, y, x)
        win.box()
        content = ["Title:", module.title, "", "Description:"]
        content.extend(textwrap.wrap(module.description, max(20, win_w - 4)) or [""])
        content.extend(("", "Packages:"))
        package_text = ", ".join(module.packages) if module.packages else "-"
        if module.aur_packages:
            package_text += f" | AUR: {', '.join(module.aur_packages)}"
        content.extend(textwrap.wrap(package_text, max(20, win_w - 4)) or [""])
        content.extend(("", "Files:"))
        content.extend((f"- {item}" for item in module.files) if module.files else ["-"])
        content.extend(("", f"Danger: {module.danger}", f"Status: {module.status}"))
        if module.meta_error:
            content.append(f"Meta error: {module.meta_error}")
        content.extend(("", self.text["details_hint"]))

        for index, line in enumerate(content[: win_h - 2], start=1):
            try:
                win.addstr(index, 2, line[: max(0, win_w - 4)])
            except curses.error:
                pass
        win.refresh()
        win.getch()

    def request(self) -> RunRequest:
        settings = Settings(
            policy=self.settings.policy,
            lang=self.settings.lang,
            backup=self.settings.backup,
        )
        return RunRequest(actions=dict(self.actions), settings=settings)

    def run(self) -> RunRequest | None:
        curses.curs_set(0)
        self.stdscr.keypad(True)
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
            elif key in (curses.KEY_RIGHT, ord("l"), 10, 13):
                self.activate()
            elif key in (curses.KEY_LEFT, ord("h")):
                continue
            elif key == ord(" "):
                self.cycle_action()
            elif key == ord("i"):
                self.set_action("install")
            elif key == ord("d"):
                self.set_action("delete")
            elif key == ord("r"):
                self.set_action("reinstall")
            elif key == ord("s"):
                self.set_action("skip")
            elif key in (curses.KEY_F10, 19):
                return self.request()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="dots-hyprland additions setup")
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
    print_summary(summary)
    return exit_code(summary)


def run_no_tui(args: argparse.Namespace) -> int:
    modules = discover_modules(with_status=False)
    by_id = module_by_id(modules)
    actions = {module.id: "skip" for module in modules}

    for action_name in ("install", "delete", "reinstall"):
        for module_id in parse_module_list(getattr(args, action_name)):
            if module_id not in by_id:
                print(f"Unknown module: {module_id}", file=sys.stderr)
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
    if args.no_tui:
        return run_no_tui(args)

    modules = discover_modules(with_status=True)
    request = curses.wrapper(lambda stdscr: AdditionsTui(stdscr, modules).run())
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
