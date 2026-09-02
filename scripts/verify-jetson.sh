#!/usr/bin/env bash

set -u

failures=0

check() {
  local label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'PASS  %s\n' "${label}"
  else
    printf 'FAIL  %s\n' "${label}"
    failures=$((failures + 1))
  fi
}

echo "Host: $(hostname) ($(uname -m))"
echo "OS: $(. /etc/os-release && printf '%s %s' "${NAME}" "${VERSION_ID}")"
echo "L4T: $(head -n 1 /etc/nv_tegra_release 2>/dev/null || echo unknown)"
echo "Power: $(nvpmodel -q 2>/dev/null | tr '\n' ' ')"
echo

check "SSH service active" systemctl is-active --quiet ssh
check "Docker service active" systemctl is-active --quiet docker
check "NVIDIA Docker runtime registered" bash -c "docker info --format '{{json .Runtimes}}' | grep -q nvidia"
check "Current user can use Docker" docker ps
check "CUDA compiler available" bash -lc 'command -v nvcc'
check "CAN utilities installed" command -v candump
check "Camera utilities installed" command -v v4l2-ctl
check "Git LFS installed" command -v git-lfs
check "Python virtual environments available" python3 -m venv --help
check "MAXN_SUPER selected" bash -c "nvpmodel -q 2>/dev/null | grep -q MAXN_SUPER"

echo
echo "CAN interfaces:"
ip -br link show type can 2>/dev/null || true
echo "Video devices:"
ls -1 /dev/video* 2>/dev/null || echo "none connected"
echo "Disk:"
df -h /

exit "${failures}"

