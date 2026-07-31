from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable

from registry import ModuleMeta
from state import LOG_DIR, ensure_state_dirs, mark_module

ProgressCallback = Callable[[str, str, str], None]


@dataclass
class RunResult:
    module_id: str
    action: str
    ok: bool
    status: str
    message: str = ""


@dataclass
class RunSummary:
    completed: list[RunResult]
    skipped: list[RunResult]
    failed: list[RunResult]
    log_file: Path


@dataclass
class RunOptions:
    policy: str = "noconfirm"
    backup: str = "true"
    lang: str = "en"
    stop_on_high_failure: bool = True
    stream: bool = False


def new_log_file() -> Path:
    ensure_state_dirs()
    stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    return LOG_DIR / f"{stamp}.log"


def _write_log(log_file: Path, text: str) -> None:
    with log_file.open("a", encoding="utf-8") as fh:
        fh.write(text)
        if text and not text.endswith("\n"):
            fh.write("\n")


def run_actions(
    modules: list[ModuleMeta],
    actions: dict[str, str],
    options: RunOptions,
    progress: ProgressCallback | None = None,
) -> RunSummary:
    log_file = new_log_file()
    completed: list[RunResult] = []
    skipped: list[RunResult] = []
    failed: list[RunResult] = []

    _write_log(log_file, "dots-hyprland additions run")
    _write_log(log_file, f"policy={options.policy} backup={options.backup} lang={options.lang}")

    for module in modules:
        action = actions.get(module.id, module.default_action)
        if action == "skip":
            result = RunResult(module.id, action, True, "skipped")
            skipped.append(result)
            mark_module(module.id, "skipped", "skip", success=True)
            if progress:
                progress(module.id, action, "skipped")
            continue

        if module.meta_error:
            result = RunResult(module.id, action, False, "failed", module.meta_error)
            failed.append(result)
            mark_module(module.id, "failed", action, success=False, error=module.meta_error)
            if progress:
                progress(module.id, action, "failed")
            if module.danger == "high" and options.stop_on_high_failure:
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

        if options.stream:
            proc = subprocess.Popen(cmd, env=env)
            returncode = proc.wait()
        else:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
            )
            assert proc.stdout is not None
            for line in proc.stdout:
                _write_log(log_file, line)
                if progress:
                    progress(module.id, action, line.rstrip("\n")[:120])
            returncode = proc.wait()

        if returncode == 0:
            status = "deleted" if action == "delete" else "installed"
            result = RunResult(module.id, action, True, status)
            completed.append(result)
            if progress:
                progress(module.id, action, status)
        else:
            message = f"exit code {returncode}"
            result = RunResult(module.id, action, False, "failed", message)
            failed.append(result)
            mark_module(module.id, "failed", action, success=False, error=message)
            if progress:
                progress(module.id, action, "failed")
            if module.danger == "high" and options.stop_on_high_failure:
                break

    return RunSummary(completed=completed, skipped=skipped, failed=failed, log_file=log_file)


def print_summary(summary: RunSummary) -> None:
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


def exit_code(summary: RunSummary) -> int:
    return 1 if summary.failed else 0
