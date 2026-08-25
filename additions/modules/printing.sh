#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="printing"
MODULE_SECTION="additions"
MODULE_TITLE="Printing support"
MODULE_TITLE_RU="Поддержка печати"
MODULE_DESCRIPTION="Installs CUPS, the printer configuration GUI and IPP-over-USB support, then enables the CUPS and Avahi system services. Printer vendor drivers are installed separately."
MODULE_DESCRIPTION_RU="Устанавливает CUPS, графическую настройку принтеров и поддержку IPP-over-USB, затем включает системные службы CUPS и Avahi. Драйверы производителей устанавливаются отдельно."
MODULE_VERSION="1"
MODULE_DANGER="low"
MODULE_DEFAULT_ACTION="skip"
MODULE_SUPPORTED_ACTIONS=(install delete reinstall)
MODULE_PACKAGES=(cups system-config-printer ipp-usb)
MODULE_REQUIRED_COMMANDS=(lpstat)
MODULE_TAGS=(printing printer cups ipp usb network)

install_steps() {
  enable_system_service cups
  start_system_service cups
  enable_system_service avahi-daemon
  start_system_service avahi-daemon
}

delete_steps() {
  if state_has_resource system_services "cups.service"; then
    disable_system_service_if_exists cups
  fi
  if state_has_resource system_services "avahi-daemon.service"; then
    disable_system_service_if_exists avahi-daemon
  fi
  remove_managed_packages "${MODULE_PACKAGES[@]}"
}

status_steps() {
  package_installed cups || return 5
  package_installed system-config-printer || return 5
  package_installed ipp-usb || return 5
  system_service_enabled cups || return 5
  system_service_enabled avahi-daemon || return 5
  return 0
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
