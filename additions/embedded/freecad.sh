#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="freecad"
MODULE_SECTION="embedded"
MODULE_TITLE="FreeCAD"
MODULE_TITLE_RU="FreeCAD"
MODULE_DESCRIPTION="Installs a CAD application for 3D modeling."
MODULE_DESCRIPTION_RU="Устанавливает CAD программу для 3D моделирования."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_PACKAGES=(freecad)
MODULE_TAGS=(3d)

install_steps() { true; }
delete_steps() { remove_packages freecad; }
status_steps() { package_installed freecad && return 0; return 5; }

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
