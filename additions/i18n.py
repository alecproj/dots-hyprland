from __future__ import annotations

from typing import Any

SUPPORTED_LANGUAGES = ("en", "ru")

_MESSAGES: dict[str, dict[str, str]] = {
    "en": {
        "app_title": "dots-hyprland additions",
        "settings": "Settings",
        "additions": "Additions",
        "applications": "Applications",
        "skip_all": "Skip all",
        "install_all": "Install all",
        "reinstall_all": "Reinstall all",
        "policy": "Policy",
        "language": "Language",
        "backup": "Backup",
        "run": "Run selected actions",
        "run_count": "Run selected actions ({count})",
        "help": "Help",
        "quit": "Quit",
        "empty": "No modules found.",
        "selected": "Selected",
        "collapsed": "collapsed",
        "details_title": "Module details",
        "title": "Title",
        "description": "Description",
        "repo_packages": "Repository packages",
        "aur_packages": "AUR packages",
        "files": "Managed files",
        "danger": "Danger",
        "status": "Status",
        "module_id": "Module ID",
        "meta_error": "Metadata error",
        "none": "None",
        "close_hint": "Enter/q/Esc: close",
        "scroll_hint": "j/k or arrows: scroll | PgUp/PgDn: page | Home/End: edge",
        "main_help": "j/k: move | h/l: collapse/expand | Space: change | Enter: open | F1: help | F10: run | q: quit",
        "help_title": "Keyboard help",
        "help_navigation": "Navigation",
        "help_actions": "Module actions",
        "help_execution": "Execution",
        "help_nav_body": "j / Down — move down\nk / Up — move up\nh / Left — collapse current section\nl / Right — expand section or open module details\nEnter — activate the selected row\nSpace — toggle a section, setting, or module action",
        "help_action_body": "i — install\nd — delete\nr — reinstall\ns — skip",
        "help_execution_body": "F10 / Ctrl+S — run selected actions\nF1 / ? — open this help\nq / Esc — exit without execution",
        "unknown_module": "Unknown module: {module_id}",
        "unsupported_action": "Action {action} is not supported by module {module_id}.",
        "execution_title": "Execution",
        "execution_plan": "{count} selected action(s)",
        "log": "Log",
        "module_progress": "{current}/{total}",
        "packages": "Packages",
        "changes": "Changes",
        "no_managed_files": "no managed files",
        "managed_files_count": "{count} managed file(s)",
        "completed": "Completed",
        "skipped": "Skipped",
        "failed": "Failed",
        "summary": "Summary",
        "execution_stopped": "Execution stopped before all selected actions were processed.",
        "failure_prompt": "[c] continue  [s] stop  [l] open log: ",
        "cannot_open_log": "Cannot open log: {error}",
        "module_failed": "{title}: {message}",
        "result_installed": "installed",
        "result_deleted": "deleted",
        "result_skipped": "skipped",
        "result_failed": "failed",
        "failure_1": "module failed or one or more steps were declined",
        "failure_2": "invalid module usage",
        "failure_3": "required dependency is missing",
        "failure_4": "cancelled by user",
        "failure_5": "module is not installed",
        "failure_exit": "exit code {code}",
        "yes": "true",
        "no": "false",
        "status_installed": "installed",
        "status_not-installed": "not installed",
        "status_unknown": "unknown",
        "status_error": "error",
        "danger_low": "low",
        "danger_medium": "medium",
        "danger_high": "high",
        "action_install": "install",
        "action_delete": "delete",
        "action_reinstall": "reinstall",
        "action_skip": "skip",
        "policy_noconfirm": "no confirmations",
        "policy_confirm-local": "confirm local changes",
        "policy_confirm-all": "confirm every step",
    },
    "ru": {
        "app_title": "Дополнения dots-hyprland",
        "settings": "Настройки",
        "additions": "Дополнения",
        "applications": "Приложения",
        "skip_all": "Пропустить всё",
        "install_all": "Установить всё",
        "reinstall_all": "Переустановить всё",
        "policy": "Подтверждения",
        "language": "Язык",
        "backup": "Резервные копии",
        "run": "Запустить выбранные действия",
        "run_count": "Запустить выбранные действия ({count})",
        "help": "Справка",
        "quit": "Выход",
        "empty": "Модули не найдены.",
        "selected": "Выбрано",
        "collapsed": "свёрнуто",
        "details_title": "Информация о модуле",
        "title": "Название",
        "description": "Описание",
        "repo_packages": "Пакеты репозитория",
        "aur_packages": "Пакеты AUR",
        "files": "Управляемые файлы",
        "danger": "Опасность",
        "status": "Состояние",
        "module_id": "ID модуля",
        "meta_error": "Ошибка метаданных",
        "none": "Нет",
        "close_hint": "Enter/q/Esc: закрыть",
        "scroll_hint": "j/k или стрелки: прокрутка | PgUp/PgDn: страница | Home/End: край",
        "main_help": "j/k: выбор | h/l: свернуть/раскрыть | Space: изменить | Enter: открыть | F1: справка | F10: запуск | q: выход",
        "help_title": "Управление",
        "help_navigation": "Навигация",
        "help_actions": "Действия модулей",
        "help_execution": "Запуск",
        "help_nav_body": "j / Down — перейти вниз\nk / Up — перейти вверх\nh / Left — свернуть текущую секцию\nl / Right — раскрыть секцию или открыть информацию о модуле\nEnter — активировать выбранную строку\nSpace — изменить секцию, настройку или действие модуля",
        "help_action_body": "i — установить\nd — удалить\nr — переустановить\ns — пропустить",
        "help_execution_body": "F10 / Ctrl+S — выполнить выбранные действия\nF1 / ? — открыть справку\nq / Esc — выйти без выполнения",
        "unknown_module": "Неизвестный модуль: {module_id}",
        "unsupported_action": "Действие {action} не поддерживается модулем {module_id}.",
        "execution_title": "Выполнение",
        "execution_plan": "Выбрано действий: {count}",
        "log": "Лог",
        "module_progress": "{current}/{total}",
        "packages": "Пакеты",
        "changes": "Изменения",
        "no_managed_files": "нет управляемых файлов",
        "managed_files_count": "Управляемых файлов: {count}",
        "completed": "Выполнено",
        "skipped": "Пропущено",
        "failed": "Ошибки",
        "summary": "Итог",
        "execution_stopped": "Выполнение остановлено до обработки всех выбранных действий.",
        "failure_prompt": "[c] продолжить  [s] остановить  [l] открыть лог: ",
        "cannot_open_log": "Не удалось открыть лог: {error}",
        "module_failed": "{title}: {message}",
        "result_installed": "установлено",
        "result_deleted": "удалено",
        "result_skipped": "пропущено",
        "result_failed": "ошибка",
        "failure_1": "модуль завершился с ошибкой или один из шагов был отклонён",
        "failure_2": "неверный вызов модуля",
        "failure_3": "отсутствует необходимая зависимость",
        "failure_4": "выполнение отменено пользователем",
        "failure_5": "модуль не установлен",
        "failure_exit": "код завершения {code}",
        "yes": "да",
        "no": "нет",
        "status_installed": "установлено",
        "status_not-installed": "не установлено",
        "status_unknown": "неизвестно",
        "status_error": "ошибка",
        "danger_low": "низкая",
        "danger_medium": "средняя",
        "danger_high": "высокая",
        "action_install": "установка",
        "action_delete": "удаление",
        "action_reinstall": "переустановка",
        "action_skip": "пропуск",
        "policy_noconfirm": "без подтверждений",
        "policy_confirm-local": "подтверждать локальные изменения",
        "policy_confirm-all": "подтверждать каждый шаг",
    },
}


def normalize_lang(lang: str) -> str:
    return lang if lang in SUPPORTED_LANGUAGES else "en"


def tr(lang: str, key: str, **values: Any) -> str:
    language = normalize_lang(lang)
    template = _MESSAGES.get(language, {}).get(key)
    if template is None:
        template = _MESSAGES["en"].get(key, key)
    try:
        return template.format(**values)
    except (KeyError, ValueError):
        return template


def action_text(lang: str, action: str) -> str:
    return tr(lang, f"action_{action}")


def danger_text(lang: str, danger: str) -> str:
    return tr(lang, f"danger_{danger}")


def status_text(lang: str, status: str) -> str:
    return tr(lang, f"status_{status}")


def policy_text(lang: str, policy: str) -> str:
    return tr(lang, f"policy_{policy}")
