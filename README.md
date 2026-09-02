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

The public [`lerobot/high_quality_folding`](https://huggingface.co/datasets/lerobot/high_quality_folding)
dataset is pinned by commit and its 16-dimensional OpenArm schema has been
validated. A one-episode local sample also completes an ACT training smoke test
on Apple Silicon.

The published data uses three cameras (base, left wrist, and right wrist). The
current robot has one D455, so a policy trained on all three views is not yet
safe or input-compatible for physical rollout. See [docs/hardware.md](docs/hardware.md)
for the verified arm/bus mapping and rollout gates.

## Reproduce the offline smoke test

Python 3.12 is used on the Mac training host:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements/training-macos.txt
scripts/download-folding-sample.sh
.venv/bin/python scripts/validate-folding-dataset.py \
  --dataset-root data/hf/high_quality_folding_sample --online
scripts/train-act-smoke.sh
```

The download is about 545 MB and contains episode 0 plus the first local data
shard. Training artifacts are written below `outputs/`, which is git-ignored.
The training script is deliberately offline-only: it does not publish a model
or send metrics to Weights & Biases.
