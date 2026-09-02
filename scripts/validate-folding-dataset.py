#!/usr/bin/env python3

"""Validate the pinned Hugging Face folding dataset metadata contract."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONTRACT = REPO_ROOT / "config" / "folding-dataset.json"
DEFAULT_DATASET = REPO_ROOT / "data" / "hf" / "high_quality_folding_sample"


def fail(message: str) -> None:
    raise ValueError(message)


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        fail(f"missing JSON file: {path}")
    with path.open(encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        fail(f"expected a JSON object: {path}")
    return value


def validate_local(
    contract: dict[str, Any], dataset_root: Path, camera_profile: str
) -> None:
    info = load_json(dataset_root / "meta" / "info.json")

    scalar_fields = (
        "codebase_version",
        "robot_type",
        "fps",
        "total_episodes",
        "total_frames",
    )
    for field in scalar_fields:
        if info.get(field) != contract.get(field):
            fail(
                f"{field} mismatch: expected {contract.get(field)!r}, "
                f"found {info.get(field)!r}"
            )

    features = info.get("features")
    if not isinstance(features, dict):
        fail("meta/info.json has no features object")

    expected_names = contract["action_names"]
    for feature_name in ("action", "observation.state"):
        feature = features.get(feature_name, {})
        if feature.get("shape") != [16]:
            fail(f"{feature_name} must have shape [16]")
        if feature.get("dtype") != "float32":
            fail(f"{feature_name} must use float32")
        if feature.get("names") != expected_names:
            fail(f"{feature_name} joint order does not match the pinned contract")

    expected_cameras = contract["cameras"]
    if camera_profile == "base-only":
        expected_cameras = {
            "observation.images.base": contract["cameras"]["observation.images.base"]
        }

    for camera_name, expected_shape in expected_cameras.items():
        camera = features.get(camera_name, {})
        if camera.get("dtype") != "video":
            fail(f"{camera_name} is missing or is not video")
        if camera.get("shape") != expected_shape:
            fail(
                f"{camera_name} shape mismatch: expected {expected_shape}, "
                f"found {camera.get('shape')}"
            )

    if camera_profile == "base-only":
        unexpected = {
            "observation.images.left_wrist",
            "observation.images.right_wrist",
        }.intersection(features)
        if unexpected:
            fail(f"base-only profile still contains cameras: {sorted(unexpected)}")

    print(f"local metadata: OK ({dataset_root})")
    print("action/state: 16D float32, right arm then left arm")
    if camera_profile == "base-only":
        print("cameras: base only")
    else:
        print("cameras: base + left_wrist + right_wrist")


def validate_online(contract: dict[str, Any]) -> None:
    query = urllib.parse.urlencode(
        {
            "dataset": contract["repo_id"],
            "config": "default",
            "split": "train",
        }
    )
    url = f"https://datasets-server.huggingface.co/first-rows?{query}"
    with urllib.request.urlopen(url, timeout=30) as response:
        preview = json.load(response)

    rows = preview.get("rows", [])
    if not rows:
        fail("Hugging Face Dataset Viewer returned no rows")
    row = rows[0].get("row", {})
    for feature_name in ("action", "observation.state"):
        value = row.get(feature_name)
        if not isinstance(value, list) or len(value) != 16:
            fail(f"online {feature_name} is not 16D")
    print(f"online preview: OK ({contract['repo_id']})")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--dataset-root", type=Path, default=DEFAULT_DATASET)
    parser.add_argument(
        "--camera-profile", choices=("all", "base-only"), default="all"
    )
    parser.add_argument("--online", action="store_true")
    args = parser.parse_args()

    try:
        contract = load_json(args.contract)
        validate_local(contract, args.dataset_root, args.camera_profile)
        if args.online:
            validate_online(contract)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
