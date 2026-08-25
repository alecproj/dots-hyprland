#!/usr/bin/env bash
set -euo pipefail

MODULE_ID="virtualization"
MODULE_SECTION="additions"
MODULE_TITLE="Setup QEMU/KVM with bridge networking"
MODULE_TITLE_RU="Настройка QEMU/KVM с bridge-сетью"
MODULE_DESCRIPTION="Installs QEMU/KVM, libvirt and configures a NetworkManager bridge br0."
MODULE_DESCRIPTION_RU="Устанавливает QEMU/KVM, libvirt и настраивает bridge br0 через NetworkManager."
MODULE_VERSION="1"
MODULE_DANGER="high"
MODULE_DEFAULT_ACTION="skip"

MODULE_PACKAGES=(
  qemu-desktop
  libvirt
  virt-manager
  dnsmasq
  freerdp
)

MODULE_REQUIRED_COMMANDS=(
  nmcli
  virsh
  systemctl
)

MODULE_FILES=(
  "$HOME/VMS"
)

find_ethernet_interface() {
  nmcli -t -f DEVICE,TYPE,STATE device \
    | awk -F: '
      $2=="ethernet" && $3=="connected" {
        print $1
        exit
      }
    '
}

bridge_exists() {
  nmcli connection show br0 >/dev/null 2>&1
}

create_bridge() {
  local iface="$1"

  run_confirmed local \
    "Create br0 bridge" \
    "Создать bridge br0" \
    -- sudo nmcli connection add \
      type bridge \
      ifname br0 \
      con-name br0

  run_confirmed local \
    "Configure bridge DHCP" \
    "Настроить DHCP для bridge" \
    -- sudo nmcli connection modify br0 \
      ipv4.method auto \
      ipv6.method auto

  run_confirmed local \
    "Attach ethernet interface $iface to br0" \
    "Добавить Ethernet интерфейс $iface в br0" \
    -- sudo nmcli connection add \
      type ethernet \
      ifname "$iface" \
      master br0 \
      con-name "br0-$iface"
}

configure_libvirt() {
  run_confirmed local \
    "Enable libvirt service" \
    "Включить сервис libvirt" \
    -- sudo systemctl enable --now libvirtd

  mkdir -p "$HOME/VMS"

  sudo usermod -aG libvirt,kvm "$USER"
}

install_steps() {
  local iface

  iface="$(find_ethernet_interface || true)"

  if [[ -z "$iface" ]]; then
    die 3 "No connected ethernet interface found. Wi-Fi bridge is not supported."
  fi

  log_info "Detected ethernet interface: $iface"

  if ! bridge_exists; then
    create_bridge "$iface"
  else
    log_info "Bridge br0 already exists"
  fi

  run_confirmed local \
    "Activate bridge br0" \
    "Активировать bridge br0" \
    -- sudo nmcli connection up br0

  configure_libvirt
}

delete_steps() {
  local iface

  while read -r iface; do
    [[ -z "$iface" ]] && continue

    run_confirmed local \
      "Remove bridge connection $iface" \
      "Удалить соединение bridge $iface" \
      -- sudo nmcli connection delete "$iface" || true

  done < <(
    nmcli -t -f NAME connection show \
      | grep '^br0-' || true
  )

  if bridge_exists; then
    run_confirmed local \
      "Remove br0 bridge" \
      "Удалить bridge br0" \
      -- sudo nmcli connection delete br0 || true
  fi
}

status_steps() {
  bridge_exists || return 5

  systemctl is-enabled libvirtd >/dev/null 2>&1 || return 5

  groups "$USER" | grep -q libvirt || return 5
  groups "$USER" | grep -q kvm || return 5
}

source "$(dirname "$0")/../lib/module.sh"
module_dispatch "$@"
