#!/usr/bin/env bash

set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  interfaces=(can1 can2)
else
  interfaces=("$@")
fi

for interface in "${interfaces[@]}"; do
  device_path="/sys/class/net/${interface}"
  if [[ ! -e ${device_path} ]]; then
    echo "CAN interface ${interface} does not exist." >&2
    exit 1
  fi

  driver_path=$(readlink -f "${device_path}/device/driver" 2>/dev/null || true)
  driver=${driver_path##*/}
  if [[ ${driver} != pcan && -r /proc/pcan ]] && \
    awk -v name="${interface}" \
      '$2 == "usbfd" && $3 == name { found = 1 } END { exit !found }' \
      /proc/pcan; then
    driver=pcan
  fi
  if [[ ${driver} != pcan ]]; then
    echo "Refusing to configure ${interface}: expected pcan driver, found ${driver:-unknown}." >&2
    exit 1
  fi

  ip link set "${interface}" down 2>/dev/null || true
  ip link set "${interface}" type can \
    bitrate 1000000 \
    dbitrate 5000000 \
    fd on \
    restart-ms 100
  ip link set "${interface}" up
done

ip -details -brief link show type can
