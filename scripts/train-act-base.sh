#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dataset_root="${repo_root}/data/hf/high_quality_folding_base_only"
trainer="${repo_root}/.venv/bin/lerobot-train"
steps="${STEPS:-100000}"
batch_size="${BATCH_SIZE:-8}"
workers="${NUM_WORKERS:-4}"
device="${DEVICE:-mps}"
output_dir="${OUTPUT_DIR:-${repo_root}/outputs/act-base}"

if [[ ! -x "${trainer}" ]]; then
  echo "Missing ${trainer}. Install requirements/training-macos.txt first." >&2
  exit 1
fi

if [[ ! -f "${dataset_root}/meta/info.json" ]]; then
  echo "Full base-only dataset is missing. Follow the full-training README steps." >&2
  exit 1
fi

WANDB_MODE=disabled "${trainer}" \
  --dataset.repo_id=lerobot/high_quality_folding \
  --dataset.root="${dataset_root}" \
  --dataset.revision=c9eb858d4b84e520edecbda84a3534c3c1e78436 \
  --dataset.video_backend=pyav \
  --policy.type=act \
  --policy.device="${device}" \
  --policy.push_to_hub=false \
  --output_dir="${output_dir}" \
  --job_name=act-base \
  --steps="${steps}" \
  --batch_size="${batch_size}" \
  --num_workers="${workers}" \
  --log_freq=100 \
  --save_checkpoint=true \
  --save_freq=10000 \
  --wandb.enable=false

latest_config="$(find "${output_dir}/checkpoints" -path '*/pretrained_model/config.json' -type f | sort | tail -1)"
if [[ -z "${latest_config}" ]]; then
  echo "Training completed without a saved policy config." >&2
  exit 1
fi
"${repo_root}/.venv/bin/python" "${repo_root}/scripts/validate-base-policy.py" "${latest_config}"
