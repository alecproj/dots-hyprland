#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="spotify"
MODULE_SECTION="applications"
MODULE_TITLE="Spotify client"
MODULE_TITLE_RU="Spotify клиент"
MODULE_DESCRIPTION="Installs the Spotify client."
MODULE_DESCRIPTION_RU="Устанавливает клиент Spotify."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(spotify-launcher)
MODULE_TAGS=(music)

install_steps() { true; }
delete_steps() { remove_packages spotify-launcher; }
status_steps() { package_installed spotify-launcher && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
