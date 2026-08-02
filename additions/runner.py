from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import textwrap
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable, TextIO

from i18n import action_text, danger_text, policy_text, tr
from registry import ModuleMeta
from state import LOG_DIR, ensure_state_dirs, mark_module

ProgressCallback = Callable[[str, str, str], None]
FailureCallback = Callable[[ModuleMeta, "RunResult", Path, str], str]


@dataclass
class RunResult:
    module_id: str
    title: str
    action: str
    ok: bool
    status: str
    message: str = ""
    returncode: int = 0


@dataclass
class RunSummary:
    completed: list[RunResult]
    skipped: list[RunResult]
    failed: list[RunResult]
    log_file: Path
    stopped: bool = False


@dataclass
class RunOptions:
    policy: str = "noconfirm"
    backup: str = "true"
    lang: str = "en"
    stop_on_high_failure: bool = True
    terminal_output: bool = True
    selection_confirmed: bool = False


class Ansi:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"

    @staticmethod
    def enabled(stream: TextIO = sys.stdout) -> bool:
        return (
            stream.isatty()
            and os.environ.get("TERM", "") != "dumb"
            and "NO_COLOR" not in os.environ
        )

    @classmethod
    def paint(cls, text: str, *codes: str, stream: TextIO = sys.stdout) -> str:
        if not cls.enabled(stream) or not codes:
            return text
        return "".join(codes) + text + cls.RESET


def new_log_file() -> Path:
    ensure_state_dirs()
    stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S_%f")
    candidate = LOG_DIR / f"{stamp}.log"
    counter = 0
    while candidate.exists():
        counter += 1
        candidate = LOG_DIR / f"{stamp}_{counter}.log"
    candidate.touch(exist_ok=False)
    return candidate


def _write_log(log_file: Path, text: str) -> None:
    with log_file.open("a", encoding="utf-8") as file_handle:
        file_handle.write(text)
        if text and not text.endswith("\n"):
            file_handle.write("\n")


def _read_log_segment(log_file: Path, offset: int) -> str:
    with log_file.open("r", encoding="utf-8", errors="replace") as file_handle:
        file_handle.seek(offset)
        return file_handle.read()


def _last_error(segment: str) -> str:
    for line in reversed(segment.splitlines()):
        if "[ERROR]" in line:
            return line.split("[ERROR]", 1)[1].strip()
    return ""


def _failure_message(returncode: int, segment: str, lang: str) -> str:
    logged_error = _last_error(segment)
    if logged_error:
        return logged_error
    if returncode in {1, 2, 3, 4, 5}:
        return tr(lang, f"failure_{returncode}")
    return tr(lang, "failure_exit", code=returncode)


def _terminal_width() -> int:
    actual = shutil.get_terminal_size(fallback=(80, 24)).columns
    return max(24, min(100, actual))


def _print_rule(char: str = "─") -> None:
    print(char * _terminal_width())


def _wrap(value: str, indent: int = 2, first_prefix: str = "") -> list[str]:
    width = max(20, _terminal_width() - indent - len(first_prefix))
    wrapped = textwrap.wrap(value, width=width) or [""]
    lines = [(" " * indent) + first_prefix + wrapped[0]]
    continuation = " " * (indent + len(first_prefix))
    lines.extend(continuation + line for line in wrapped[1:])
    return lines


def _action_color(action: str) -> str:
    return {
        "install": Ansi.GREEN,
        "delete": Ansi.RED,
        "reinstall": Ansi.YELLOW,
        "skip": Ansi.DIM,
    }.get(action, Ansi.CYAN)


def _danger_color(danger: str) -> str:
    return {
        "low": Ansi.GREEN,
        "medium": Ansi.YELLOW,
        "high": Ansi.RED,
    }.get(danger, Ansi.YELLOW)


def print_execution_header(options: RunOptions, log_file: Path, selected_count: int) -> None:
    title = Ansi.paint(tr(options.lang, "app_title"), Ansi.BOLD, Ansi.CYAN)
    plan = tr(options.lang, "execution_plan", count=selected_count)
    policy = policy_text(options.lang, options.policy)
    backup = tr(options.lang, "yes" if options.backup == "true" else "no")

    _print_rule("═")
    print(title)
    print(f"{Ansi.paint(tr(options.lang, 'execution_title'), Ansi.BOLD)} · {plan}")
    print(f"{tr(options.lang, 'policy')}: {policy}  ·  {tr(options.lang, 'backup')}: {backup}")
    print(f"{tr(options.lang, 'log')}: {Ansi.paint(str(log_file), Ansi.DIM)}")
    _print_rule("═")


def print_module_header(
    module: ModuleMeta,
    action: str,
    lang: str,
    current: int,
    total: int,
) -> None:
    title = module.title_for(lang)
    description = module.description_for(lang)
    progress = tr(lang, "module_progress", current=current, total=total)
    action_badge = Ansi.paint(action_text(lang, action).upper(), Ansi.BOLD, _action_color(action))
    danger_badge = Ansi.paint(
        danger_text(lang, module.danger).upper(),
        Ansi.BOLD,
        _danger_color(module.danger),
    )

    print()
    _print_rule()
    print(f"{Ansi.paint(progress, Ansi.BOLD, Ansi.BLUE)}  {action_badge}  {Ansi.paint(title, Ansi.BOLD)}")
    for line in _wrap(description):
        print(Ansi.paint(line, Ansi.DIM))

    if module.packages:
        print(f"  {tr(lang, 'repo_packages')}: {', '.join(module.packages)}")
    if module.aur_packages:
        print(f"  {tr(lang, 'aur_packages')}: {', '.join(module.aur_packages)}")

    changes = (
        tr(lang, "managed_files_count", count=len(module.files))
        if module.files
        else tr(lang, "no_managed_files")
    )
    print(f"  {tr(lang, 'changes')}: {changes}  ·  {tr(lang, 'danger')}: {danger_badge}")


def _open_log(log_file: Path, lang: str) -> None:
    pager = os.environ.get("PAGER", "").strip()
    if pager:
        command = [*shlex.split(pager), str(log_file)]
    elif shutil.which("less"):
        command = ["less", "-R", "+G", str(log_file)]
    else:
        command = ["cat", str(log_file)]
    try:
        subprocess.run(command, check=False)
    except OSError as exc:
        print(tr(lang, "cannot_open_log", error=exc), file=sys.stderr)


def terminal_failure_prompt(
    module: ModuleMeta,
    result: RunResult,
    log_file: Path,
    lang: str,
) -> str:
    while True:
        try:
            answer = input(Ansi.paint(tr(lang, "failure_prompt"), Ansi.BOLD, Ansi.YELLOW)).strip().lower()
        except (EOFError, KeyboardInterrupt):
            print()
            return "stop"
        if answer in {"c", "continue", "п", "продолжить"}:
            return "continue"
        if answer in {"s", "stop", "q", "quit", "о", "остановить", "в", "выход"}:
            return "stop"
        if answer in {"l", "log", "л", "лог"}:
            _open_log(log_file, lang)


def clear_terminal() -> None:
    if sys.stdout.isatty():
        print("\033[2J\033[H", end="", flush=True)


def _make_result(
    module: ModuleMeta,
    action: str,
    ok: bool,
    status: str,
    message: str = "",
    returncode: int = 0,
    lang: str = "en",
) -> RunResult:
    return RunResult(
        module_id=module.id,
        title=module.title_for(lang),
        action=action,
        ok=ok,
        status=status,
        message=message,
        returncode=returncode,
    )


def _print_result(module: ModuleMeta, result: RunResult, lang: str) -> None:
    if result.ok:
        status = tr(lang, f"result_{result.status}")
        badge = Ansi.paint("✓", Ansi.BOLD, Ansi.GREEN)
        print(f"  {badge} {module.title_for(lang)} — {status}")
        return
    badge = Ansi.paint("✗", Ansi.BOLD, Ansi.RED)
    message = tr(lang, "module_failed", title=module.title_for(lang), message=result.message)
    print(f"  {badge} {message}")


def run_actions(
    modules: list[ModuleMeta],
    actions: dict[str, str],
    options: RunOptions,
    progress: ProgressCallback | None = None,
    failure_callback: FailureCallback | None = None,
) -> RunSummary:
    log_file = new_log_file()
    completed: list[RunResult] = []
    skipped: list[RunResult] = []
    failed: list[RunResult] = []
    stopped = False
    selected_modules = [
        module
        for module in modules
        if actions.get(module.id, module.default_action) != "skip"
    ]

    _write_log(log_file, "dots-hyprland additions run")
    _write_log(log_file, f"policy={options.policy} backup={options.backup} lang={options.lang}")
    _write_log(
        log_file,
        "selected=" + ",".join(
            f"{module.id}:{actions.get(module.id, module.default_action)}"
            for module in selected_modules
        ),
    )

    if options.terminal_output:
        print_execution_header(options, log_file, len(selected_modules))

    with tempfile.TemporaryDirectory(prefix="dots-additions-") as temp_dir:
        confirm_state_file = Path(temp_dir) / "confirm-state"
        confirm_state_file.write_text(options.policy + "\n", encoding="utf-8")
        selected_index = 0

        for module in modules:
            action = actions.get(module.id, module.default_action)
            if action == "skip":
                result = _make_result(module, action, True, "skipped", lang=options.lang)
                skipped.append(result)
                mark_module(module.id, "skipped", "skip", success=True)
                if progress:
                    progress(module.id, action, "skipped")
                continue

            selected_index += 1
            if options.terminal_output:
                print_module_header(module, action, options.lang, selected_index, len(selected_modules))

            if action not in module.supported_actions:
                message = f"unsupported action: {action}"
                result = _make_result(module, action, False, "failed", message, 2, options.lang)
                failed.append(result)
                mark_module(module.id, "failed", action, success=False, error=message)
                if options.terminal_output:
                    _print_result(module, result, options.lang)
                if progress:
                    progress(module.id, action, "failed")
                decision = "continue"
                if failure_callback:
                    decision = failure_callback(module, result, log_file, options.lang)
                if decision != "continue":
                    stopped = True
                    break
                continue

            if module.meta_error:
                result = _make_result(module, action, False, "failed", module.meta_error, 1, options.lang)
                failed.append(result)
                mark_module(module.id, "failed", action, success=False, error=module.meta_error)
                if options.terminal_output:
                    _print_result(module, result, options.lang)
                if progress:
                    progress(module.id, action, "failed")
                decision = "continue"
                if failure_callback:
                    decision = failure_callback(module, result, log_file, options.lang)
                elif module.danger == "high" and options.stop_on_high_failure:
                    decision = "stop"
                if decision != "continue":
                    stopped = True
                    break
                continue

            cmd = [
                str(module.path),
                action,
                f"--policy={options.policy}",
                f"--backup={options.backup}",
                f"--lang={options.lang}",
            ]
            _write_log(log_file, "")
            _write_log(log_file, f"==> {module.id}: {' '.join(cmd)}")
            if progress:
                progress(module.id, action, "running")

            env = os.environ.copy()
            env["ADDITIONS_LOG_FILE"] = str(log_file)
            env["ADDITIONS_LOG_STDOUT"] = "0"
            env["ADDITIONS_CONFIRM_STATE_FILE"] = str(confirm_state_file)
            env["ADDITIONS_SELECTION_CONFIRMED"] = "1" if options.selection_confirmed else "0"
            env["ADDITIONS_RUNNER_CONTEXT"] = "1"

            log_offset = log_file.stat().st_size
            try:
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    errors="replace",
                    env=env,
                    bufsize=1,
                )
            except OSError as exc:
                message = str(exc)
                _write_log(log_file, f"[ERROR] Cannot start {module.id}: {message}")
                result = _make_result(module, action, False, "failed", message, 1, options.lang)
                failed.append(result)
                mark_module(module.id, "failed", action, success=False, error=message)
                if options.terminal_output:
                    _print_result(module, result, options.lang)
                decision = "continue"
                if failure_callback:
                    decision = failure_callback(module, result, log_file, options.lang)
                elif module.danger == "high" and options.stop_on_high_failure:
                    decision = "stop"
                if decision != "continue":
                    stopped = True
                    break
                continue

            assert process.stdout is not None
            for line in process.stdout:
                _write_log(log_file, line)
            returncode = process.wait()
            segment = _read_log_segment(log_file, log_offset)

            if returncode == 0:
                status = "deleted" if action == "delete" else "installed"
                result = _make_result(module, action, True, status, lang=options.lang)
                completed.append(result)
                if options.terminal_output:
                    _print_result(module, result, options.lang)
                if progress:
                    progress(module.id, action, status)
                continue

            message = _failure_message(returncode, segment, options.lang)
            result = _make_result(module, action, False, "failed", message, returncode, options.lang)
            failed.append(result)
            mark_module(module.id, "failed", action, success=False, error=message)
            if options.terminal_output:
                _print_result(module, result, options.lang)
            if progress:
                progress(module.id, action, "failed")

            if returncode == 4:
                stopped = True
                break

            decision = "continue"
            if failure_callback:
                decision = failure_callback(module, result, log_file, options.lang)
            elif module.danger == "high" and options.stop_on_high_failure:
                decision = "stop"
            if decision != "continue":
                stopped = True
                break

    return RunSummary(
        completed=completed,
        skipped=skipped,
        failed=failed,
        log_file=log_file,
        stopped=stopped,
    )


def print_summary(summary: RunSummary, lang: str = "en") -> None:
    print()
    _print_rule("═")
    print(Ansi.paint(tr(lang, "summary"), Ansi.BOLD, Ansi.CYAN))
    print(f"{tr(lang, 'log')}: {summary.log_file}")

    if summary.completed:
        print(f"\n{Ansi.paint(tr(lang, 'completed'), Ansi.BOLD, Ansi.GREEN)}:")
        for item in summary.completed:
            status = tr(lang, f"result_{item.status}")
            print(f"  ✓ {item.title} [{item.module_id}] — {status}")

    if summary.skipped:
        print(f"\n{Ansi.paint(tr(lang, 'skipped'), Ansi.BOLD, Ansi.YELLOW)}:")
        for item in summary.skipped:
            print(f"  · {item.title} [{item.module_id}]")

    if summary.failed:
        print(f"\n{Ansi.paint(tr(lang, 'failed'), Ansi.BOLD, Ansi.RED)}:")
        for item in summary.failed:
            print(f"  ✗ {item.title} [{item.module_id}] — {item.message}")

    if summary.stopped:
        print(f"\n{Ansi.paint(tr(lang, 'execution_stopped'), Ansi.YELLOW)}")
    _print_rule("═")


def exit_code(summary: RunSummary) -> int:
    return 1 if summary.failed or summary.stopped else 0
