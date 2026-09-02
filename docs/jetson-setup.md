# Jetson Orin Nano Super setup

## Detected baseline

- Hostname: `openarm-jetson`
- User: `evan`
- Direct USB address: `192.168.55.1`
- OS: Ubuntu 22.04, L4T R36.4.4 (JetPack 6.2.1 generation)
- CUDA 12.6, cuDNN 9.3, TensorRT 10.3
- Storage: 128 GB microSD, approximately 91 GB initially free
- SSH and Docker installed

## Provisioning

From the repository root on the Jetson:

```bash
SETUP_EPOCH="$(date +%s)" sudo -E ./scripts/provision-jetson.sh
```

The script corrects the factory-image clock, installs robot-development prerequisites, grants the local user access to CAN/serial/camera/Docker devices, selects `MAXN_SUPER`, and configures NVIDIA as Docker's default runtime. It does not perform a blanket distribution upgrade or install a LeRobot/PyTorch combination that has not been validated for JetPack 6.2.1.

## Connection from the Mac

```bash
ssh openarm-jetson
```

The direct USB connection uses `192.168.55.1`. Internet access during initial provisioning is supplied through a temporary reverse SOCKS tunnel from the Mac and is not a permanent network configuration.

## LeRobot compatibility decision

Current LeRobot releases require Python 3.12 and PyTorch 2.7 or newer. Standard Linux CUDA wheels are not compatible with JetPack's L4T CUDA ABI. Keep the verified JetPack compute stack intact and use a Jetson-specific PyTorch/container build. Do not let a generic `pip install lerobot` replace the Jetson CUDA packages.

The next validated milestone is:

1. Verify the NVIDIA Docker runtime with a small CUDA container.
2. Select and pin a JetPack 6.2.1-compatible PyTorch/LeRobot image.
3. Test LeRobot imports and CUDA before attaching motors.
4. Connect and validate the OpenArm CAN adapters at conservative limits.

