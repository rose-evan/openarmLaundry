# Hardware contract

Snapshot: 2026-09-01

## Robot

- OpenArm v1, two follower arms, eight motors per arm.
- Robot-left arm: `can1`.
- Robot-right arm: `can2`.
- Both buses: CAN FD, 1 Mbit/s arbitration, 5 Mbit/s data.
- Both arms completed the official v1 automatic zero-position calibration.
- Dataset/action order is right arm first, then left arm. Therefore dimensions
  `0..7` map to `can2` and dimensions `8..15` map to `can1`.

Do not replay dataset vectors through the low-level `openarm_can` API. The
dataset stores the LeRobot OpenArm joint convention in degrees. Physical
deployment must use the pinned LeRobot OpenArm adapter plus explicit joint,
velocity, and workspace clamps.

## Compute

- NVIDIA Jetson Orin Nano Super.
- Ubuntu 22.04, L4T R36.4.4 / JetPack 6.2.1 generation.
- CUDA 12.6, cuDNN 9.3, TensorRT 10.3.
- Python 3.10.12 on the host.

The Jetson CUDA stack must not be replaced by generic Linux CUDA wheels.
Training can run on another machine; the Jetson is the intended hardware I/O
and guarded-inference host.

## Cameras

Connected camera:

- Intel RealSense D455, serial `236323062043`.
- Current RGB node: `/dev/video4` at 1280x720/30 FPS. The numeric video node is
  not stable and must be replaced with a serial-based udev symlink.

The pinned folding dataset requires three synchronized RGB inputs:

- `observation.images.base`: 640x480/30 FPS.
- `observation.images.left_wrist`: 1280x720/30 FPS.
- `observation.images.right_wrist`: 1280x720/30 FPS.

The current training profile intentionally retains only
`observation.images.base` from the public dataset. This matches the number of
cameras on the robot, although physical evaluation still requires matching the
published base-camera viewpoint as closely as possible. A policy trained using
all three original camera keys is not compatible with this setup.

## Safety gates for physical rollout

- Operator at the E-stop and workspace clear.
- Read-only motor discovery succeeds on all 16 IDs.
- All commanded actions pass per-joint position and velocity clamps.
- First rollout uses no garment, reduced speed, and a short time limit.
- Camera keys, dimensions, and left/right mapping match the trained policy.
- Every rollout is recorded and torque is disabled on process exit or timeout.
