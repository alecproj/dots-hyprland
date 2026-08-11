# AGENTS.md

## Scope

These instructions apply to work under `additions/`. Do not refactor unrelated upstream end4/illogical-impulse files while implementing an additions module.

## Canonical references

Read these before changing the module platform or adding a module:

1. `additions/SPEC.md`
2. `./additions/setup-additions --print-api`
3. `additions/templates/module.sh`

The generated API is the canonical function and contract reference. Do not maintain a separate handwritten function list.

## Required workflow

Before editing:

```bash
./additions/setup-additions --check-api
./additions/setup-additions --print-api markdown >/tmp/additions-api-before.md
```

After editing:

```bash
python3 -m py_compile additions/*.py

while IFS= read -r -d '' file; do
  bash -n "$file"
done < <(find additions -type f -name '*.sh' -print0)

./additions/setup-additions --check-api
./additions/setup-additions --print-api markdown >/tmp/additions-api.md
./additions/setup-additions --print-api json >/tmp/additions-api.json
```

Run real package, sudo and systemd actions only on an Arch Linux test system or VM.

## Adding a module or application

Start from `additions/templates/module.sh`.

The module file may live anywhere under `additions/`, for example:

- `additions/modules/<MODULE_ID>.sh`;
- `additions/apps/<MODULE_ID>.sh`;
- `additions/embedded/<MODULE_ID>.sh`.

Register its exact path in the appropriate `SectionMeta.module_paths` tuple in
`additions/registry.py`. File location does not select the TUI section.

Requirements:

- filename stem equals `MODULE_ID`;
- ID and `MODULE_SECTION` are lowercase identifiers;
- `MODULE_SECTION` matches the registered section containing the module path;
- define English title and description;
- add Russian title/description only when useful;
- define `status_steps` and return exactly 0, 5 or 1;
- declare `MODULE_SUPPORTED_ACTIONS` when not all actions are supported;
- keep module-private helpers prefixed with `_`;
- source `lib/module.sh` and call `module_dispatch "$@"` last.

To add a TUI section, add one `SectionMeta` entry in `additions/registry.py`
with its English/Russian title and exact module paths. Do not add section-name
fallbacks or section translations to `tui.py` or `i18n.py`.

## Safety rules

Use public helpers from the generated API instead of duplicating logic.

Do not directly:

- call `pacman`, `yay` or `paru` for install/remove from module-specific code;
- edit managed files with `sed`, `awk` or ad hoc Python;
- write to `/etc` or `~/.config` without file/block helpers;
- enable or disable systemd units without systemd helpers;
- delete an untracked path;
- assume `hyprland.conf` exists;
- modify content outside `~/.config/hypr/custom/` for Hyprland customizations;
- suppress a failed verification to make a module appear successful.

Use:

- `install_packages` / `install_aur_packages`;
- `remove_packages` only for an explicitly removed primary package;
- `remove_managed_packages` for dependencies installed by the module;
- `install_file_user` / `install_file_sudo`;
- `write_file_user` / `write_file_sudo`;
- `managed_block` or `lua_block` for partial-file edits;
- `remove_managed_path` for reversible deletion;
- explicit system/user systemd helpers;
- `run_logged` or `run_confirmed` for external commands.

Install, delete and reinstall must be idempotent. Delete must preserve unrelated user data.

## API documentation rules

Every public function in `additions/lib/*.sh` must have exactly one adjacent-style `@api` documentation block:

```bash
# @api
# kind: function
# name: example_function
# signature: example_function ARG
# summary: Explain the stable behavior.
# returns: Document exit behavior.
# effects: Document filesystem/process/state effects.
# @end
```

Private runtime helpers must begin with a library-specific prefix such as `_files_`, `_module_`, `_systemd_` or `_confirm_`.

When adding metadata, callbacks, policies, commands, environment variables or exit codes, document them with the same `@api` format so `--print-api` includes them automatically.

Never edit generated API output. Edit source annotations or implementation.

## Module behavior

`install_steps` contains only unique module configuration. Package installation is automatic.

`delete_steps` removes only module-managed changes. Preserve user-created data unless the module description explicitly says an explicitly selected primary application package is removed.

`preflight_steps ACTION` may reject an unsafe environment before any changes.

`reinstall_steps` is optional. Prefer the generic delete/install sequence unless custom behavior is necessary.

Keep `MODULE_FILES`, package arrays, required commands, tags, supported actions and danger level accurate. These values are user-facing and included in AI API output.

## Localization

Keep runtime logic language-neutral.

Use:

- `MODULE_TITLE` and `MODULE_DESCRIPTION` for English;
- optional `MODULE_TITLE_RU` and `MODULE_DESCRIPTION_RU` for Russian;
- bilingual messages when calling `confirm_action` or `run_confirmed`.

Section titles and their translations belong only to `additions/registry.py`.

Do not assign UI language values to the process locale variable `LANG`. The additions language is `ADDITIONS_LANG` / `MODULE_LANG`.

## Code style

Shell:

- `#!/usr/bin/env bash`
- `set -euo pipefail`
- snake_case functions
- quoted expansions
- arrays for argument lists
- no `eval`
- ShellCheck-compatible structure
- readable multi-line commands

Python:

- stdlib only
- type hints
- dataclasses where useful
- explicit error handling
- deterministic generated output
- no hidden network access

## Change boundaries

A normal new module requires only its shell file and one path entry in `additions/registry.py`. A new section additionally requires one `SectionMeta` entry there.

Change the platform only when the required behavior is genuinely reusable across multiple modules. Add the reusable behavior to `lib/`, document it with `@api`, update the template or SPEC when relevant, and make `--check-api` pass.
