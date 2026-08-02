# Спецификация `setup-additions`

## 1. Назначение

`additions/` — изолированная система установки дополнительных настроек и приложений для fork `dots-hyprland`.

Единственная пользовательская точка входа:

```bash
./additions/setup-additions
```

Система должна:

- показывать TUI без внешних Python-зависимостей;
- автоматически обнаруживать модули и приложения;
- выполнять только выбранные действия;
- быть идемпотентной;
- сохранять логи, состояние и резервные копии;
- удалять только управляемые изменения;
- предоставлять автоматически собранное API для разработки новых модулей;
- не заменять legacy `setup-custom.sh`, пока миграция не завершена.

Целевая система: Arch Linux, Bash, Python 3 stdlib, pacman, systemd и Hyprland end4/illogical-impulse с Lua-конфигурацией.

## 2. Архитектура

```text
Python stdlib curses
  TUI, локализация, registry, API generator, runner, state

Bash
  module runtime, packages, files, backup, confirmation,
  managed blocks, Lua, systemd and module-specific actions
```

Базовая реализация не зависит от `pip`, `npm`, `cargo`, Rich, Textual, dialog, whiptail или gum.

## 3. Структура

```text
AGENTS.md
additions/
  SPEC.md
  setup-additions
  tui.py
  runner.py
  registry.py
  state.py
  i18n.py
  module_api.py

  templates/
    module.sh

  lib/
    module.sh
    log.sh
    confirm.sh
    state.sh
    commands.sh
    backup.sh
    files.sh
    blocks.sh
    lua.sh
    packages.sh
    systemd.sh

  modules/
    *.sh

  apps/
    *.sh

  files/
    ...
```

`modules/` и `apps/` используют один контракт. Разница состоит только в расположении и стандартном значении `MODULE_SECTION`.

## 4. CLI

### 4.1 TUI

```bash
./additions/setup-additions
./additions/setup-additions --lang=ru
./additions/setup-additions --policy=confirm-local --backup=true
```

Переданные `--lang`, `--policy` и `--backup` становятся начальными значениями TUI.

### 4.2 Non-interactive

```bash
./additions/setup-additions \
  --no-tui \
  --install greetd-regreet,xdg-user-dirs \
  --policy=noconfirm \
  --backup=true \
  --lang=ru

./additions/setup-additions --no-tui --delete throne-vpn
./additions/setup-additions --no-tui --reinstall neovim
```

CLI отклоняет неизвестный модуль и действие, отсутствующее в `MODULE_SUPPORTED_ACTIONS`.

### 4.3 Автособираемое API

Markdown для промта нейросети:

```bash
./additions/setup-additions --print-api
./additions/setup-additions --print-api markdown
./additions/setup-additions --print-api markdown --api-output /tmp/additions-api.md
```

JSON для автоматизации:

```bash
./additions/setup-additions --print-api json
./additions/setup-additions --print-api json --api-output /tmp/additions-api.json
```

Проверка API и контрактов:

```bash
./additions/setup-additions --check-api
```

Генератор автоматически собирает:

- команды CLI и module runtime;
- metadata-переменные;
- callbacks;
- публичные функции `lib/*.sh`;
- confirmation policies;
- environment variables;
- exit codes;
- metadata всех текущих модулей;
- шаблон нового модуля;
- ошибки и коллизии.

Источники истины:

1. `# @api ... # @end` рядом с реализацией;
2. фактические определения shell-функций;
3. JSON команды `module.sh meta`;
4. `additions/templates/module.sh`.

Сгенерированный Markdown/JSON не хранится в репозитории и не редактируется вручную.

## 5. TUI

### 5.1 Возможности

- локализация `en` и `ru`;
- цвета curses;
- динамические секции;
- сворачивание секций;
- отдельная строка запуска;
- отдельное окно справки;
- прокручиваемое окно metadata;
- раздельные списки repository packages, AUR packages и managed files;
- отображение danger и status;
- поддержка индивидуального набора действий каждого модуля.

### 5.2 Навигация

```text
j / Down       вниз
k / Up         вверх
h / Left       свернуть секцию
l / Right      раскрыть секцию или открыть информацию
Enter          активировать строку
Space          сменить действие или значение
 i             install
 d             delete
 r             reinstall
 s             skip
F1 / ?         help
F10 / Ctrl+S   выполнить
q / Esc        выйти без выполнения
```

В модальном окне:

```text
j/k, arrows    прокрутка
PgUp/PgDn      страница
Home/End       начало/конец
Enter/q/Esc    закрыть
```

## 6. Registry

При запуске сканируются:

```text
additions/modules/*.sh
additions/apps/*.sh
```

Для каждого файла выполняется:

```bash
./module.sh meta
```

Registry:

- ограничивает время `meta` и `status`;
- валидирует типы JSON, включая массивы;
- требует совпадение `MODULE_ID` с именем файла;
- обнаруживает дубли `MODULE_ID`;
- валидирует section, danger, action и supported actions;
- не позволяет одному повреждённому модулю уронить TUI;
- использует `status` как фактический источник состояния.

## 7. Module metadata

Обязательные:

```bash
MODULE_ID="example"
MODULE_TITLE="Example"
MODULE_DESCRIPTION="..."
```

Стандартные optional metadata:

```bash
MODULE_SECTION="additions"
MODULE_TITLE_RU="Пример"
MODULE_DESCRIPTION_RU="..."
MODULE_VERSION="1"
MODULE_DANGER="medium"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=()
MODULE_AUR_PACKAGES=()
MODULE_REQUIRED_COMMANDS=()
MODULE_FILES=()
MODULE_TAGS=()
MODULE_VERIFY=true
```

Ограничения:

- `MODULE_ID` и `MODULE_SECTION` — lowercase slug;
- `MODULE_DANGER`: `low`, `medium`, `high`;
- supported actions: `install`, `delete`, `reinstall`;
- `skip` является действием интерфейса и не указывается в supported actions;
- default action должен быть `skip` либо поддерживаемым действием;
- массивы не должны содержать пустые или повторяющиеся значения.

Локализация не должна раздувать модуль: достаточно английских title/description и, при необходимости, двух optional русских строк.

## 8. Module callbacks

```bash
status_steps
install_steps
delete_steps
reinstall_steps      # optional
preflight_steps      # optional, принимает ACTION
```

Требования:

- `status_steps` обязателен;
- `install_steps` обязателен, если поддерживается install;
- `delete_steps` обязателен, если поддерживается delete;
- generic reinstall требует install и delete;
- `reinstall_steps` может заменить generic reinstall;
- module-private helpers должны начинаться с `_`;
- имя callback или helper не должно совпадать с функцией из `lib/`.

`status_steps` возвращает:

```text
0  installed/configured
5  not installed/not configured
1  status check error
```

В конце каждого модуля:

```bash
source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
```

## 9. Runtime commands

```bash
./module.sh meta
./module.sh status
./module.sh install --policy=... --backup=... --lang=...
./module.sh delete --policy=... --backup=... --lang=...
./module.sh reinstall --policy=... --backup=... --lang=...
```

Install:

1. contract validation;
2. optional preflight;
3. repository packages;
4. AUR packages;
5. required commands;
6. `install_steps`;
7. `status_steps` verification;
8. state update.

Delete:

1. optional preflight;
2. `delete_steps`;
3. verification that status returns 5;
4. state update.

Reinstall:

- custom `reinstall_steps`, если он определён;
- иначе delete + install;
- финальная verification и один state result `reinstall`.

`MODULE_VERIFY=false` допустим только для особого случая, который невозможно проверить фактически. По умолчанию verification обязательна.

## 10. Exit codes

```text
0  success
1  generic failure, verification failure or declined required step
2  invalid usage or module contract
3  required dependency/source/unit missing
4  user cancelled
5  status: not installed
```

## 11. Confirmation

Policies:

```text
noconfirm
confirm-local
confirm-all
```

Scopes helpers:

```text
local
packages
all
```

`confirm-local`:

- подтверждает file/config/systemd/local changes;
- в TUI не повторяет подтверждение обычной установки пакетов;
- в `--no-tui` подтверждает packages, поскольку TUI-подтверждения не было.

`confirm-all` подтверждает все scopes.

Prompt:

```text
y  выполнить
n  отклонить шаг и завершить текущий module action с ошибкой
 a  выполнить и не спрашивать для оставшихся модулей run
q  отменить весь run
```

`a` сохраняется между module subprocess через runner state file.

## 12. Logging и runner

Runner:

- запускается только после завершения curses;
- выполняет модули последовательно;
- передаёт policy, backup и lang;
- показывает локализованный прогресс и цветные результаты;
- пишет stdout/stderr subprocess только в уникальный log file;
- не дублирует summary;
- обрабатывает ошибку запуска subprocess как обычный failed result;
- позволяет continue, stop или open log;
- останавливается на user cancellation;
- возвращает nonzero при failed/stopped.

Цвет ANSI отключается через:

```bash
NO_COLOR=1 ./additions/setup-additions ...
```

## 13. State и ownership

```text
~/.local/state/dots-hyprland-additions/
  state.json
  logs/
  backups/
```

State version 2 хранит:

- status;
- last action;
- last success/error;
- resources, которыми управляет конкретный module ID.

Примеры resource kinds:

```text
packages
aur_packages
managed_paths
created_paths
managed_blocks
system_services
user_services
```

`state.sh` предоставляет общий API. Модули не должны напрямую редактировать `state.json`.

## 14. Backup

Backup поддерживает files, directories и symlinks.

Новые имена backup содержат hash полного target path, поэтому пути вроде `/a_b/c` и `/a/b_c` не сталкиваются.

Правила:

- backup создаётся только перед реальным изменением существующего пути;
- backup не создаётся, если desired state уже достигнут;
- legacy backup names остаются читаемыми;
- restore сохраняет metadata через `cp -a`;
- при отсутствии backup путь удаляется только если state подтверждает, что module создал его;
- untracked path без backup никогда не удаляется.

## 15. Files и directories

Общие helpers поддерживают:

- user/sudo file installation;
- generated text files;
- user/sudo directories;
- user/sudo symlinks;
- restore/remove managed paths.

Модуль не должен напрямую применять `cp`, `install`, `ln`, `rm` к пользовательским или системным конфигам, если существующий helper решает задачу.

## 16. Managed blocks и Lua

Generic markers:

```text
# BEGIN additions:module-id
...
# END additions:module-id
```

Lua markers:

```lua
-- BEGIN additions:module-id
...
-- END additions:module-id
```

Generic helpers валидируют:

- duplicate start marker;
- end marker без start;
- незакрытый block.

При malformed markers операция завершается ошибкой и не переписывает файл.

Hyprland изменения выполняются только в `~/.config/hypr/custom/`. Предполагать наличие классического `hyprland.conf` запрещено.

## 17. Packages

Repository packages:

```bash
sudo pacman -S --needed --noconfirm
```

AUR helper preference:

```text
yay
paru
```

Runtime записывает только пакеты, отсутствовавшие перед install, как resources текущего модуля.

Разница удаления:

- `remove_packages` — удалить явно выбранный package независимо от ownership;
- `remove_managed_packages` — удалить только package, установленный этим module;
- `remove_managed_aur_packages` — аналогично для AUR.

Для shared dependencies использовать managed removal.

## 18. Systemd

Поддерживаются system и user units:

- existence/enabled checks;
- enable;
- disable-if-exists;
- start/restart;
- daemon-reload;
- confirmation и state tracking.

Для нового кода следует использовать explicit имена `enable_system_service`, `enable_user_service` и т. п. Старые `enable_service`, `service_exists`, `disable_service_if_exists` сохранены как deprecated aliases.

## 19. API collision rules

`--check-api` является обязательной проверкой перед commit.

Ошибки:

- duplicate shell function в `lib/`;
- public function без `@api`;
- `@api` для отсутствующей функции;
- module function с именем lib function;
- публичный module helper, не являющийся callback;
- duplicate module ID;
- ID не совпадает с filename;
- missing callback;
- invalid metadata;
- Bash syntax error.

Внутренние функции `lib/` должны начинаться с library prefix, например `_module_`, `_files_`, `_systemd_`.

## 20. Минимальный module template

Канонический шаблон:

```text
additions/templates/module.sh
```

Он автоматически включается в `--print-api`.

Добавление module состоит из одного `.sh` файла и optional payload в `additions/files/`.

## 21. Проверки перед commit

```bash
python3 -m py_compile additions/*.py

for file in \
  additions/setup-additions \
  additions/lib/*.sh \
  additions/modules/*.sh \
  additions/apps/*.sh \
  additions/templates/*.sh; do
  bash -n "$file"
done

./additions/setup-additions --check-api
./additions/setup-additions --print-api markdown >/tmp/additions-api.md
./additions/setup-additions --print-api json >/tmp/additions-api.json
```

Реальные install/delete/reinstall дополнительно проверяются на Arch VM.

## 22. Критерии готовности platform layer

Этап считается завершённым, когда:

1. API собирается без ручного списка функций.
2. `--check-api` проходит без ошибок.
3. Новый module создаётся по template без изменения Python/TUI.
4. Module может ограничить supported actions.
5. Install/delete/reinstall проходят runtime verification.
6. Helpers покрывают packages, commands, files, directories, symlinks, blocks, Lua и systemd.
7. Backup names не имеют path-flattening collision.
8. Function/module ID collisions обнаруживаются до выполнения.
9. State отслеживает ownership ресурсов.
10. SPEC и AGENTS указывают generated API как канонический справочник.

После этого `additions/` готов к наполнению реальными дополнениями и приложениями.
