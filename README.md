# OpenArm Laundry

Research and experiments for teaching a bimanual OpenArm v1 system to fold laundry with open-source robot-learning tools.

## Current direction

The best-supported path is real-world imitation learning with [LeRobot](https://github.com/huggingface/lerobot):

1. Reproduce the data pipeline with an existing OpenArm shirt-folding dataset.
2. Verify the exact v1 joint, gripper, camera, and action mappings on hardware.
3. Collect a small set of clean, consistent demonstrations on the target setup.
4. Train a baseline policy, evaluate it from recorded rollouts, and collect targeted corrections.

See [docs/open-source-training-research.md](docs/open-source-training-research.md) for sources, compatibility notes, and a staged experiment plan.

## Repository status

This repository currently contains research and planning only. It does not yet contain robot-control code or a trained policy.

