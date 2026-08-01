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
from typing import Callable

from registry import ModuleMeta
from state import LOG_DIR, ensure_state_dirs, mark_module

ProgressCallback = Callable[[str, str, str], None]
FailureCallback = Callable[[ModuleMeta, "RunResult", Path], str]


@dataclass
class RunResult:
    module_id: str
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
    with log_file.open("a", encoding="utf-8") as fh:
        fh.write(text)
        if text and not text.endswith("\n"):
            fh.write("\n")


def _read_log_segment(log_file: Path, offset: int) -> str:
    with log_file.open("r", encoding="utf-8", errors="replace") as fh:
        fh.seek(offset)
        return fh.read()


def _last_error(segment: str) -> str:
    for line in reversed(segment.splitlines()):
        if "[ERROR]" in line:
            return line.split("[ERROR]", 1)[1].strip()
    return ""


def _failure_message(returncode: int, segment: str) -> str:
    logged_error = _last_error(segment)
    if logged_error:
        return logged_error
    messages = {
        1: "module failed or one or more steps were declined",
        2: "invalid module usage",
        3: "required dependency is missing",
        4: "cancelled by user",
        5: "module is not installed",
    }
    return messages.get(returncode, f"exit code {returncode}")


def _terminal_width() -> int:
    return max(60, min(100, shutil.get_terminal_size(fallback=(80, 24)).columns))


def _print_rule(char: str = "-") -> None:
    print(char * _terminal_width())


def _print_wrapped(label: str, value: str) -> None:
    width = _terminal_width()
    prefix = f"{label}: "
    wrapped = textwrap.wrap(value, max(20, width - len(prefix))) or [""]
    print(prefix + wrapped[0])
    indent = " " * len(prefix)
    for line in wrapped[1:]:
        print(indent + line)


def print_execution_header(options: RunOptions, log_file: Path) -> None:
    _print_rule("=")
    print("dots-hyprland additions")
    _print_wrapped("Policy", options.policy)
    _print_wrapped("Backup", options.backup)
    _print_wrapped("Log", str(log_file))
    _print_rule("=")


def print_module_header(module: ModuleMeta, action: str) -> None:
    print()
    _print_rule()
    print(f"{module.title} [{module.id}]")
    _print_wrapped("Action", action)
    _print_wrapped("Section", module.section)
    _print_wrapped("Danger", module.danger)
    _print_wrapped("Description", module.description)
    packages = [*module.packages, *(f"{item} (AUR)" for item in module.aur_packages)]
    if packages:
        _print_wrapped("Packages", ", ".join(packages))
    if module.files:
        _print_wrapped("Files", ", ".join(module.files))
    _print_rule()


def _open_log(log_file: Path) -> None:
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
        print(f"Cannot open log: {exc}", file=sys.stderr)


def terminal_failure_prompt(module: ModuleMeta, result: RunResult, log_file: Path) -> str:
    print()
    print(f"Failed: {module.title}: {result.message}")
    while True:
        try:
            answer = input("[c]ontinue, [s]top, open [l]og: ").strip().lower()
        except EOFError:
            return "stop"
        if answer in {"c", "continue"}:
            return "continue"
        if answer in {"s", "stop", "q", "quit"}:
            return "stop"
        if answer in {"l", "log"}:
            _open_log(log_file)


def clear_terminal() -> None:
    if sys.stdout.isatty():
        print("\033[2J\033[H", end="", flush=True)


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

    _write_log(log_file, "dots-hyprland additions run")
    _write_log(log_file, f"policy={options.policy} backup={options.backup} lang={options.lang}")

    if options.terminal_output:
        print_execution_header(options, log_file)

    with tempfile.TemporaryDirectory(prefix="dots-additions-") as temp_dir:
        confirm_state_file = Path(temp_dir) / "confirm-state"
        confirm_state_file.write_text(options.policy + "\n", encoding="utf-8")

        for module in modules:
            action = actions.get(module.id, module.default_action)
            if action == "skip":
                result = RunResult(module.id, action, True, "skipped")
                skipped.append(result)
                mark_module(module.id, "skipped", "skip", success=True)
                if progress:
                    progress(module.id, action, "skipped")
                continue

            if options.terminal_output:
                print_module_header(module, action)

            if module.meta_error:
                result = RunResult(module.id, action, False, "failed", module.meta_error, 1)
                failed.append(result)
                mark_module(module.id, "failed", action, success=False, error=module.meta_error)
                if progress:
                    progress(module.id, action, "failed")
                decision = "continue"
                if failure_callback:
                    decision = failure_callback(module, result, log_file)
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

            log_offset = log_file.stat().st_size
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
                bufsize=1,
            )
            assert proc.stdout is not None
            for line in proc.stdout:
                _write_log(log_file, line)
            returncode = proc.wait()
            segment = _read_log_segment(log_file, log_offset)

            if returncode == 0:
                status = "deleted" if action == "delete" else "installed"
                result = RunResult(module.id, action, True, status, returncode=0)
                completed.append(result)
                if options.terminal_output:
                    print(f"[OK] {module.title}: {status}")
                if progress:
                    progress(module.id, action, status)
                continue

            message = _failure_message(returncode, segment)
            result = RunResult(module.id, action, False, "failed", message, returncode)
            failed.append(result)
            mark_module(module.id, "failed", action, success=False, error=message)
            if options.terminal_output:
                print(f"[FAILED] {module.title}: {message}")
            if progress:
                progress(module.id, action, "failed")

            if returncode == 4:
                stopped = True
                break

            decision = "continue"
            if failure_callback:
                decision = failure_callback(module, result, log_file)
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


def print_summary(summary: RunSummary) -> None:
    print()
    _print_rule("=")
    print("Summary")
    print(f"Log: {summary.log_file}")
    if summary.completed:
        print("\nCompleted:")
        for item in summary.completed:
            print(f"  {item.module_id}: {item.status}")
    if summary.skipped:
        print("\nSkipped:")
        for item in summary.skipped:
            print(f"  {item.module_id}")
    if summary.failed:
        print("\nFailed:")
        for item in summary.failed:
            print(f"  {item.module_id}: {item.message}")
    if summary.stopped:
        print("\nExecution stopped before all selected actions were processed.")
    _print_rule("=")


def exit_code(summary: RunSummary) -> int:
    return 1 if summary.failed else 0
