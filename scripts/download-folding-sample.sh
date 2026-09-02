#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="${repo_root}/data/hf/high_quality_folding_sample"
revision="c9eb858d4b84e520edecbda84a3534c3c1e78436"
hf_cli="${repo_root}/.venv/bin/hf"

if [[ ! -x "${hf_cli}" ]]; then
  echo "Missing ${hf_cli}. Install requirements/training-macos.txt first." >&2
  exit 1
fi

"${hf_cli}" download lerobot/high_quality_folding \
  --repo-type dataset \
  --revision "${revision}" \
  --local-dir "${destination}" \
  --include \
    README.md \
    'meta/*' \
    data/chunk-000/file-000.parquet \
    videos/chunk-000/observation.images.base/file-000.mp4 \
    videos/chunk-000/observation.images.left_wrist/file-000.mp4 \
    videos/chunk-000/observation.images.right_wrist/file-000.mp4

echo "Dataset sample ready at ${destination}"
