# ТЗ: `setup-additions` для fork `dots-hyprland`

## 1. Цель

Реализовать систему дополнительных настроек и приложений для fork `dots-hyprland`, которая запускается отдельной командой:

```bash
./additions/setup-additions
```

Система должна открывать TUI-интерфейс, позволять пользователю выбрать действия для настроек, дополнений и приложений, а затем безопасно выполнить только выбранные операции.

Система не должна полностью заменять конфиги end4/illogical-impulse там, где достаточно локальной правки. Все изменения должны быть повторяемыми, откатываемыми и максимально изолированными.

## 2. Основное решение

Использовать гибридную архитектуру:

```text
Python stdlib curses — TUI, состояние, выбор действий, запуск модулей.
Bash — системные операции: pacman/yay, systemctl, копирование файлов, sudo, правка Lua.
```

Причина: Python уже доступен или легко ставится через `pacman`, `curses` не требует внешних Python-зависимостей, а Bash удобнее для системных операций Arch Linux.

Запрещено делать TUI на фреймворках, требующих дополнительных Python-пакетов, например Textual/Rich, на первом этапе реализации.

## 3. Структура проекта

В корне репозитория создать директорию:

```text
additions/
  setup-additions

  tui.py
  runner.py
  state.py
  registry.py

  lib/
    module.sh
    packages.sh
    confirm.sh
    backup.sh
    files.sh
    lua.sh
    systemd.sh
    log.sh

  modules/
    xdg-user-dirs.sh
    greetd-regreet.sh
    neovim.sh
    throne-vpn.sh

  apps/
    firefox.sh
    chromium.sh
    vesktop.sh
    libreoffice.sh

  files/
    greetd/
      config.toml
      regreet.toml

    hypr/
      throne-vpn-keybinds.lua
      kdeconnect-keybinds.lua

    systemd/
      example.service
```

`setup-additions` — единственная команда входа для пользователя.

## 4. Bootstrapping

Файл `additions/setup-additions` должен быть Bash-скриптом.

Обязанности:

1. Перейти в корень репозитория.
2. Проверить наличие `python3`.
3. Если `python3` отсутствует, предложить установить пакет `python` через `sudo pacman -S --needed python`.
4. Запустить:

```bash
python3 additions/tui.py "$@"
```

Скрипт не должен сам выполнять установку модулей.

## 5. TUI

TUI должен быть реализован на Python stdlib `curses`.

### 5.1 Разделы интерфейса

Главный экран должен содержать три секции:

```text
Settings:
  Skip all
  Reinstall all
  Install all
  Policy: noconfirm
  Language: en
  Backup: true

Additions:
  [I] Setup xdg-user-dirs
  [I] Setup Greetd Login Manager
  [S] Setup Neovim Editor
  [D] Setup Throne VPN

Applications:
  [I] Firefox Browser
  [S] LibreOffice
  [D] Vesktop
```

### 5.2 Действия

Для каждого модуля доступны действия:

```text
I — install
D — delete
R — reinstall
S — skip
```

Действие отображается слева от пункта:

```text
[I] Setup Greetd Login Manager
[D] Throne VPN
[S] Neovim Editor
[R] Firefox Browser
```

### 5.3 Навигация

Поддержать:

```text
j / Down      — вниз
k / Up        — вверх
h / Left      — назад / свернуть
l / Right     — раскрыть / открыть описание
Enter         — открыть описание выбранного пункта
i             — action install
d             — action delete
r             — action reinstall
s             — action skip
Space         — циклически сменить действие
q             — выход без выполнения
F10 / Ctrl+S  — применить выбранную конфигурацию
```

### 5.4 Settings

Пункты `Settings` должны работать как кнопки-переключатели.

`Policy`:

```text
noconfirm
confirm-local
confirm-all
```

`Language`:

```text
en
ru
```

На первом этапе язык влияет только на UI и описания модулей, если они есть.

`Backup`:

```text
true
false
```

`Skip all` устанавливает всем модулям действие `skip`.

`Install all` устанавливает всем модулям действие `install`.

`Reinstall all` устанавливает всем модулям действие `reinstall`.

### 5.5 Описание модулей

При нажатии `Enter` на модуле открыть модальное окно или раскрытый блок с полным описанием:

```text
Title:
Setup Greetd Login Manager

Description:
Installs greetd, regreet and cage. Writes /etc/greetd/config.toml and
/etc/greetd/regreet.toml with backup. Disables conflicting display managers.
Enables greetd.service.

Packages:
greetd, greetd-regreet, cage

Files:
- /etc/greetd/config.toml
- /etc/greetd/regreet.toml

Danger:
high
```

## 6. Module registry

TUI не должен иметь жёстко прописанный список модулей.

При запуске он сканирует:

```text
additions/modules/*.sh
additions/apps/*.sh
```

Для каждого файла вызывает:

```bash
./module-name.sh meta
```

Модуль обязан вернуть JSON.

Пример:

```json
{
  "id": "greetd-regreet",
  "section": "additions",
  "title": "Setup Greetd Login Manager",
  "description": "Installs greetd, regreet and cage; configures regreet; enables greetd.service.",
  "packages": ["greetd", "greetd-regreet", "cage"],
  "danger": "high",
  "default_action": "skip"
}
```

Обязательные поля:

```text
id
section
title
description
default_action
```

Допустимые `section`:

```text
additions
applications
```

Допустимые `danger`:

```text
low
medium
high
```

## 7. Module contract

Каждый модуль — Bash-файл с одинаковым внешним контрактом:

```bash
./module.sh meta
./module.sh status
./module.sh install --policy=noconfirm --backup=true --lang=en
./module.sh delete --policy=confirm-local --backup=true --lang=en
./module.sh reinstall --policy=confirm-all --backup=true --lang=en
```

Каждый модуль не должен вручную реализовывать общий `case`.

В конце модуля подключается общий runtime:

```bash
source "$ROOT/additions/lib/module.sh"
module_dispatch "$@"
```

Пример структуры модуля:

```bash
#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="greetd-regreet"
MODULE_SECTION="additions"
MODULE_TITLE="Setup Greetd Login Manager"
MODULE_DESCRIPTION="Installs greetd, regreet and cage; configures regreet; enables greetd.service."
MODULE_DANGER="high"
MODULE_PACKAGES=(greetd greetd-regreet cage)

install_steps() {
  install_file_sudo "$ROOT/additions/files/greetd/config.toml" "/etc/greetd/config.toml"
  install_file_sudo "$ROOT/additions/files/greetd/regreet.toml" "/etc/greetd/regreet.toml"

  disable_service_if_exists sddm
  disable_service_if_exists gdm
  disable_service_if_exists ly
  enable_service greetd
}

delete_steps() {
  restore_backup_or_remove "/etc/greetd/config.toml"
  restore_backup_or_remove "/etc/greetd/regreet.toml"
  disable_service_if_exists greetd
}

status_steps() {
  systemctl is-enabled greetd >/dev/null 2>&1
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
```

## 8. Общий runtime модулей

Файл:

```text
additions/lib/module.sh
```

Обязанности:

1. Найти `ROOT`.
2. Распарсить аргументы:

   * `--policy=...`
   * `--backup=...`
   * `--lang=...`
3. Реализовать команды:

   * `meta`
   * `status`
   * `install`
   * `delete`
   * `reinstall`
4. Перед `install_steps` установить `MODULE_PACKAGES`.
5. После успешного действия обновить state.
6. Логировать все действия.
7. Корректно завершаться с кодом ошибки при падении.

Логика:

```bash
install:
  install_packages "${MODULE_PACKAGES[@]}"
  install_steps
  mark_installed "$MODULE_ID"

delete:
  delete_steps
  mark_deleted "$MODULE_ID"

reinstall:
  delete
  install
```

## 9. Idempotency

Повторный запуск `install` должен быть безопасным.

Требования:

1. Не переустанавливать уже установленные пакеты без необходимости.
2. Не дублировать Lua-блоки.
3. Не дублировать systemd unit overrides.
4. Не создавать повторные одинаковые записи.
5. Не ломать пользовательские изменения вне управляемых блоков.
6. Если файл уже существует и отличается, сначала создать backup.
7. Если файл уже соответствует желаемому состоянию, ничего не менять.

## 10. State

Состояние хранить в:

```text
~/.local/state/dots-hyprland-additions/
  state.json
  logs/
  backups/
```

Пример `state.json`:

```json
{
  "version": 1,
  "modules": {
    "greetd-regreet": {
      "status": "installed",
      "last_action": "install",
      "last_success": "2026-06-28T12:00:00+02:00"
    },
    "throne-vpn": {
      "status": "skipped",
      "last_action": "skip",
      "last_success": null
    }
  }
}
```

TUI может использовать `status` модулей для выбора дефолтного действия, но источником истины остаётся фактическая проверка через:

```bash
module.sh status
```

## 11. Backup

Файл:

```text
additions/lib/backup.sh
```

Все потенциально опасные изменения должны проходить через backup helper.

Backup хранить так:

```text
~/.local/state/dots-hyprland-additions/backups/
  greetd-regreet/
    2026-06-28_12-00-00/
      etc_greetd_config.toml
      etc_greetd_regreet.toml
```

Правило:

1. Если `Backup: true`, перед изменением существующего файла создать backup.
2. Если файл уже соответствует нужному содержимому, backup не создавать.
3. При `delete` восстановить backup, если он есть.
4. Если backup отсутствует, удалить только управляемый файл или управляемый блок.

## 12. Lua integration

Так как end4/illogical-impulse использует Lua-конфиги, запрещено предполагать классический `hyprland.conf`.

Все изменения Hyprland должны идти через:

```text
~/.config/hypr/custom/
```

Основной способ изменения — управляемые Lua-блоки.

Файл:

```text
additions/lib/lua.sh
```

Обязательные функции:

```bash
lua_block FILE MODULE_ID CONTENT
remove_lua_block FILE MODULE_ID
lua_block_exists FILE MODULE_ID
```

Формат блока:

```lua
-- BEGIN additions:throne-vpn
...
-- END additions:throne-vpn
```

Повторный `install` должен заменить существующий блок, а не добавить новый.

`delete` должен удалить только блок между маркерами.

Пример вызова:

```bash
lua_block "$HOME/.config/hypr/custom/keybinds.lua" "throne-vpn" '
-- Throne VPN keybinds
bind("SUPER", "V", function()
  hl.spawn("throne")
end)
'
```

Модуль не должен напрямую использовать `sed` для Lua-файлов. Только общий helper.

## 13. Package management

Файл:

```text
additions/lib/packages.sh
```

Функции:

```bash
package_installed NAME
install_packages PKG...
remove_packages PKG...
aur_helper
```

Поведение:

1. Для repo-пакетов использовать `sudo pacman -S --needed`.
2. Для AUR-пакетов использовать доступный helper.
3. Предпочтительный helper: `yay`.
4. Если AUR-helper отсутствует, модуль должен выдать понятную ошибку.
5. Установка пакетов учитывает текущий `policy`.

На первом этапе можно считать, что список пакетов модуля — repo-пакеты, если модуль явно не указал:

```bash
MODULE_AUR_PACKAGES=(...)
```

## 14. Confirmation policy

Файл:

```text
additions/lib/confirm.sh
```

Поддержать политики:

```text
noconfirm
confirm-local
confirm-all
```

Поведение:

### noconfirm

После выбора в TUI ничего не спрашивать.

### confirm-local

Спрашивать перед локальными опасными изменениями:

```text
- запись в /etc
- изменение ~/.config
- systemctl enable/disable
- удаление файлов
- восстановление backup
```

Не спрашивать перед обычной установкой пакетов, если она уже была подтверждена в TUI.

### confirm-all

Спрашивать перед каждым этапом:

```text
- install packages
- write file
- edit Lua block
- enable service
- disable service
- remove file
- restore backup
```

Во время выполнения при любом prompt должна быть возможность выбрать:

```text
y — да
n — нет
a — да для всех последующих действий
q — остановить выполнение
```

Если пользователь нажал `a`, текущая политика временно становится `noconfirm`.

## 15. Logging

Файл:

```text
additions/lib/log.sh
```

Логи хранить в:

```text
~/.local/state/dots-hyprland-additions/logs/
```

Формат:

```text
2026-06-28_12-00-00.log
```

Логировать:

```text
- выбранные действия
- запуск каждого модуля
- установку пакетов
- изменения файлов
- systemctl действия
- ошибки
```

TUI после выполнения должен показать итог:

```text
Completed:
  greetd-regreet: installed
  xdg-user-dirs: installed

Skipped:
  neovim

Failed:
  throne-vpn: yay not found
```

## 16. Runner

Файл:

```text
additions/runner.py
```

Обязанности:

1. Получить выбранную конфигурацию из TUI.
2. Запустить модули последовательно.
3. Передать каждому модулю:

   * action
   * policy
   * backup
   * lang
4. Показывать прогресс.
5. Сохранять stdout/stderr в лог.
6. Не продолжать выполнение после критической ошибки, если модуль помечен `danger=high`, кроме случаев, когда пользователь явно выбрал продолжение.

Пример запуска:

```bash
additions/modules/greetd-regreet.sh install --policy=confirm-local --backup=true --lang=en
```

## 17. Applications

`Applications` реализуются тем же механизмом, что и `Additions`.

Разница только в расположении файлов:

```text
additions/apps/*.sh
```

И в `MODULE_SECTION`:

```bash
MODULE_SECTION="applications"
```

Пример:

```bash
MODULE_ID="firefox"
MODULE_SECTION="applications"
MODULE_TITLE="Firefox Browser"
MODULE_DESCRIPTION="Installs Firefox browser from official Arch repositories."
MODULE_PACKAGES=(firefox)
MODULE_DANGER="low"

install_steps() {
  true
}

delete_steps() {
  remove_packages firefox
}

status_steps() {
  pacman -Q firefox >/dev/null 2>&1
}
```

## 18. Минимальные модули первого этапа

Реализовать сначала:

```text
additions/modules/xdg-user-dirs.sh
additions/modules/greetd-regreet.sh
additions/modules/neovim.sh
additions/modules/throne-vpn.sh

additions/apps/firefox.sh
additions/apps/libreoffice.sh
```

### xdg-user-dirs

Должен:

1. Установить `xdg-user-dirs`.
2. Запустить `xdg-user-dirs-update`.
3. Не перетирать пользовательские директории без необходимости.

### greetd-regreet

Должен:

1. Установить `greetd`, `greetd-regreet`, `cage`.
2. Создать backup существующих `/etc/greetd/*`.
3. Установить конфиги из `additions/files/greetd/`.
4. Отключить конфликтующие login managers, если они включены.
5. Включить `greetd.service`.

### neovim

Должен:

1. Установить `neovim`.
2. Поставить нужные зависимости.
3. Настроить конфиг без удаления пользовательских данных без backup.
4. Уметь повторно обновляться.

### throne-vpn

Должен:

1. Проверить наличие Throne.
2. Если Throne отсутствует, установить его выбранным способом, если способ определён.
3. Добавить Lua-блоки для биндов или автозапуска, если они нужны.
4. Не ломать существующую конфигурацию Throne.

## 19. Error handling

Каждый модуль должен завершаться с кодами:

```text
0 — success
1 — generic error
2 — invalid usage
3 — dependency missing
4 — user cancelled
5 — status not installed
```

`status` возвращает:

```text
0 — installed/configured
5 — not installed/not configured
1 — error while checking
```

TUI не должен падать при ошибке одного модуля. Он должен показать ошибку и предложить:

```text
continue
stop
open log
```

## 20. Подсветка листингов

Все shell-файлы должны быть отформатированы единообразно.

Требования:

1. Shebang:

```bash
#!/usr/bin/env bash
```

2. В начале:

```bash
set -euo pipefail
```

3. Имена функций:

```bash
snake_case
```

4. Глобальные переменные модуля:

```bash
MODULE_ID
MODULE_TITLE
MODULE_DESCRIPTION
MODULE_PACKAGES
```

5. ShellCheck-совместимый стиль.
6. Не использовать неочевидные one-liner’ы.
7. Не смешивать tabs/spaces.
8. Все пользовательские сообщения проходят через общие функции `log_info`, `log_warn`, `log_error`.

## 21. CLI-режим без TUI

`setup-additions` должен поддерживать non-interactive режим:

```bash
./additions/setup-additions --no-tui --install greetd-regreet,xdg-user-dirs --policy=noconfirm
./additions/setup-additions --no-tui --delete throne-vpn
./additions/setup-additions --no-tui --reinstall neovim
```

Это нужно для отладки и автоматизации.

На первом этапе достаточно реализовать:

```bash
--no-tui
--install MODULE_ID
--delete MODULE_ID
--reinstall MODULE_ID
--policy POLICY
--backup true|false
--lang en|ru
```

## 22. Совместимость

Целевая система:

```text
Arch Linux
Hyprland end4 / illogical-impulse
Python 3
Bash
pacman
systemd
```

Система не должна требовать:

```text
pip
npm
cargo
Textual
Rich
dialog
whiptail
gum
```

Допустимо использовать эти инструменты позже как optional enhancement, но не как базовую зависимость.

## 23. Что не входит в первый этап

Не реализовывать в первой версии:

```text
- GUI
- красивую тему TUI
- параллельную установку модулей
- сложный dependency graph между модулями
- полноценный package profile manager
- поддержку дистрибутивов кроме Arch
- автоматическую миграцию всех старых custom modules
```

## 24. Этапы реализации

### Этап 1: каркас

1. Создать `additions/setup-additions`.
2. Создать `tui.py`.
3. Реализовать сканирование модулей.
4. Реализовать `meta`.
5. Показать список Settings/Additions/Applications.

### Этап 2: module runtime

1. Создать `lib/module.sh`.
2. Создать `lib/packages.sh`.
3. Создать `lib/confirm.sh`.
4. Создать `lib/log.sh`.
5. Реализовать общий `module_dispatch`.

### Этап 3: state и runner

1. Создать `state.py`.
2. Создать `runner.py`.
3. Сохранять результаты выполнения.
4. Показывать итоговый экран.

### Этап 4: Lua helpers

1. Создать `lib/lua.sh`.
2. Реализовать `lua_block`.
3. Реализовать `remove_lua_block`.
4. Покрыть повторный install/delete.

### Этап 5: первые модули

1. Перенести `xdg-user-dirs`.
2. Перенести `greetd-regreet`.
3. Перенести `neovim`.
4. Добавить `throne-vpn`.
5. Добавить первые apps.

### Этап 6: cleanup старых custom scripts

После проверки новой системы старые линейные custom-модули можно оставить как legacy или постепенно удалить.

## 25. Критерии готовности

Реализация считается готовой, если:

1. `./additions/setup-additions` открывает TUI на чистой системе.
2. Пользователь может выбрать install/delete/reinstall/skip для каждого пункта.
3. Все выбранные действия выполняются последовательно.
4. Повторный запуск install не дублирует настройки.
5. Lua-блоки не дублируются.
6. Delete удаляет только управляемые изменения.
7. Backup создаётся перед опасными изменениями.
8. Logs сохраняются.
9. Ошибки видны пользователю.
10. Есть CLI-режим без TUI.
11. Добавление нового модуля требует только создания одного `.sh` файла с метаданными и функциями `install_steps/delete_steps/status_steps`.

## 26. Главный принцип

Модуль описывает только то, что уникально для конкретного дополнения.

Всё общее должно находиться в `additions/lib/`:

```text
установка пакетов
подтверждения
backup
логирование
правка Lua
systemd
копирование файлов
state
dispatch
```

Запрещено копировать одинаковую логику install/delete/reinstall/status в каждый модуль.
