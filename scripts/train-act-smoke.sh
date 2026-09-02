#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dataset_root="${repo_root}/data/hf/high_quality_folding_base_only_sample"
trainer="${repo_root}/.venv/bin/lerobot-train"
steps="${STEPS:-2}"
device="${DEVICE:-mps}"

if [[ ! -x "${trainer}" ]]; then
  echo "Missing ${trainer}. Install requirements/training-macos.txt first." >&2
  exit 1
fi

if [[ ! -f "${dataset_root}/meta/info.json" ]]; then
  echo "Base-only dataset is missing. Run scripts/prepare-base-only-dataset.py first." >&2
  exit 1
fi

WANDB_MODE=disabled "${trainer}" \
  --dataset.repo_id=lerobot/high_quality_folding \
  --dataset.root="${dataset_root}" \
  --dataset.episodes='[0]' \
  --dataset.revision=c9eb858d4b84e520edecbda84a3534c3c1e78436 \
  --dataset.video_backend=pyav \
  --policy.type=act \
  --policy.device="${device}" \
  --policy.push_to_hub=false \
  --output_dir="${repo_root}/outputs/act-smoke" \
  --job_name=act-smoke \
  --steps="${steps}" \
  --batch_size=1 \
  --num_workers=0 \
  --log_freq=1 \
  --save_checkpoint=false \
  --wandb.enable=false
