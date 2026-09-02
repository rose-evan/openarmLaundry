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
.venv/bin/python scripts/prepare-base-only-dataset.py
.venv/bin/python scripts/validate-folding-dataset.py \
  --dataset-root data/hf/high_quality_folding_base_only_sample \
  --camera-profile base-only --online
scripts/train-act-smoke.sh
```

The download is about 265 MB and contains episode 0, the first local data shard,
and only the base-camera video. The preparation step creates a LeRobot-compatible
local view with both wrist-camera features removed from its schema. Training
artifacts are written below `outputs/`, which is git-ignored.
The training script is deliberately offline-only: it does not publish a model
or send metrics to Weights & Biases.

## Full base-camera training

The pinned full base-camera profile is about 36.8 GiB, compared with about
84.0 GiB for all three published cameras. It keeps all 1,200 episodes while
excluding both wrist streams:

```bash
scripts/download-base-folding-dataset.sh
.venv/bin/python scripts/prepare-base-only-dataset.py \
  --source data/hf/high_quality_folding_base_source \
  --destination data/hf/high_quality_folding_base_only
.venv/bin/python scripts/validate-folding-dataset.py \
  --dataset-root data/hf/high_quality_folding_base_only \
  --camera-profile base-only
scripts/train-act-base.sh
```

The full training default is 100,000 ACT optimization steps, batch size 8,
with a local checkpoint every 10,000 steps. Override these without editing the
script, for example `STEPS=1000 BATCH_SIZE=2 scripts/train-act-base.sh`. At the
end of training, the saved policy contract is checked to ensure it accepts only
the 16D robot state and the base-camera image and emits a 16D action.
