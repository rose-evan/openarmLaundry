#!/usr/bin/env bash

set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

if [[ -z ${SETUP_EPOCH:-} ]]; then
  echo "SETUP_EPOCH is required so the newly imaged Jetson gets the correct time." >&2
  exit 1
fi

target_user=${SUDO_USER:-evan}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if ! id "${target_user}" >/dev/null 2>&1; then
  echo "Target user ${target_user} does not exist." >&2
  exit 1
fi

echo "Setting clock and enabling network time synchronization..."
date --set="@${SETUP_EPOCH}"
timedatectl set-timezone America/Los_Angeles
timedatectl set-ntp true
hwclock --systohc 2>/dev/null || true

apt_options=()
if timeout 2 bash -c '</dev/tcp/127.0.0.1/1080' 2>/dev/null; then
  echo "Using the temporary SSH SOCKS tunnel for package downloads."
  apt_options+=(
    -o Acquire::http::Proxy=socks5h://127.0.0.1:1080
    -o Acquire::https::Proxy=socks5h://127.0.0.1:1080
  )
fi

echo "Waiting for any first-boot package refresh to finish..."
for attempt in $(seq 1 120); do
  if ! pgrep -x apt-get >/dev/null && ! pgrep -x dpkg >/dev/null; then
    break
  fi
  if [[ ${attempt} -eq 120 ]]; then
    echo "Timed out waiting for the package manager after 10 minutes." >&2
    exit 1
  fi
  sleep 5
done

echo "Refreshing package metadata..."
apt-get "${apt_options[@]}" update

echo "Installing OpenArm development prerequisites..."
DEBIAN_FRONTEND=noninteractive apt-get "${apt_options[@]}" install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  can-utils \
  cmake \
  curl \
  ffmpeg \
  git \
  git-lfs \
  htop \
  jq \
  libopenblas-dev \
  libusb-1.0-0-dev \
  ninja-build \
  openssh-server \
  pkg-config \
  python3-dev \
  python3-pip \
  python3-venv \
  tmux \
  usbutils \
  v4l-utils

git lfs install --system

echo "Granting ${target_user} access to robot, camera, GPIO, and Docker devices..."
for group in dialout video plugdev docker i2c gpio; do
  if getent group "${group}" >/dev/null; then
    usermod -aG "${group}" "${target_user}"
  fi
done

echo "Configuring the NVIDIA container runtime..."
docker_config_tmp=$(mktemp)
if [[ -s /etc/docker/daemon.json ]]; then
  jq '.runtimes.nvidia //= {"args": [], "path": "nvidia-container-runtime"} | ."default-runtime" = "nvidia"' \
    /etc/docker/daemon.json >"${docker_config_tmp}"
else
  jq -n '{"runtimes":{"nvidia":{"args":[],"path":"nvidia-container-runtime"}},"default-runtime":"nvidia"}' \
    >"${docker_config_tmp}"
fi
install -o root -g root -m 0644 "${docker_config_tmp}" /etc/docker/daemon.json
rm -f "${docker_config_tmp}"

echo "Installing CUDA shell paths..."
install -o root -g root -m 0644 \
  "${repo_root}/config/jetson/cuda-paths.sh" \
  /etc/profile.d/openarm-cuda.sh

echo "Enabling services and MAXN_SUPER mode..."
systemctl enable --now ssh systemd-timesyncd
systemctl enable docker
systemctl restart docker
nvpmodel -m 2

echo "Provisioning complete. Reboot once verification has passed so new groups apply."
