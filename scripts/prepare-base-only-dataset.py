#!/usr/bin/env python3

"""Create a local LeRobot dataset view containing only the base camera."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

import pandas as pd


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = REPO_ROOT / "data" / "hf" / "high_quality_folding_sample"
DEFAULT_DESTINATION = REPO_ROOT / "data" / "hf" / "high_quality_folding_base_only_sample"
BASE_CAMERA = "observation.images.base"
REMOVED_CAMERAS = (
    "observation.images.left_wrist",
    "observation.images.right_wrist",
)


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def link_or_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.link(source, destination)
    except OSError:
        shutil.copy2(source, destination)


def copy_tree(source: Path, destination: Path) -> None:
    if not source.is_dir():
        raise FileNotFoundError(source)
    for path in source.rglob("*"):
        if path.is_file():
            link_or_copy(path, destination / path.relative_to(source))


def strip_episode_metadata(episodes_root: Path) -> None:
    prefixes = tuple(
        prefix
        for camera in REMOVED_CAMERAS
        for prefix in (f"videos/{camera}/", f"stats/{camera}/")
    )
    for parquet_path in episodes_root.rglob("*.parquet"):
        frame = pd.read_parquet(parquet_path)
        removed_columns = [
            column for column in frame.columns if column.startswith(prefixes)
        ]
        frame.drop(columns=removed_columns).to_parquet(parquet_path, index=False)


def validate_existing(destination: Path) -> bool:
    try:
        info = load_json(destination / "meta" / "info.json")
    except (OSError, ValueError, json.JSONDecodeError):
        return False
    features = info.get("features", {})
    return (
        BASE_CAMERA in features
        and all(camera not in features for camera in REMOVED_CAMERAS)
        and (destination / "videos" / BASE_CAMERA).is_dir()
    )


def build(source: Path, destination: Path) -> None:
    if destination.exists():
        if validate_existing(destination):
            print(f"base-only dataset already ready at {destination}")
            return
        raise FileExistsError(
            f"destination exists but is not a valid base-only dataset: {destination}"
        )

    info_path = source / "meta" / "info.json"
    info = load_json(info_path)
    features = info.get("features")
    if not isinstance(features, dict) or BASE_CAMERA not in features:
        raise ValueError(f"source dataset has no {BASE_CAMERA} feature")
    for camera in REMOVED_CAMERAS:
        if camera not in features:
            raise ValueError(f"source dataset has no {camera} feature")

    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(
        tempfile.mkdtemp(prefix=f".{destination.name}-", dir=destination.parent)
    )
    try:
        copy_tree(source / "meta", temporary / "meta")
        copy_tree(source / "data", temporary / "data")
        copy_tree(
            source / "videos" / BASE_CAMERA,
            temporary / "videos" / BASE_CAMERA,
        )

        derived_info = load_json(temporary / "meta" / "info.json")
        for camera in REMOVED_CAMERAS:
            derived_info["features"].pop(camera, None)
        write_json(temporary / "meta" / "info.json", derived_info)

        stats_path = temporary / "meta" / "stats.json"
        if stats_path.is_file():
            stats = load_json(stats_path)
            for camera in REMOVED_CAMERAS:
                stats.pop(camera, None)
            write_json(stats_path, stats)

        strip_episode_metadata(temporary / "meta" / "episodes")
        temporary.rename(destination)
    except Exception:
        shutil.rmtree(temporary, ignore_errors=True)
        raise

    print(f"base-only dataset ready at {destination}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--destination", type=Path, default=DEFAULT_DESTINATION)
    args = parser.parse_args()
    try:
        build(args.source.resolve(), args.destination.resolve())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"base-only dataset preparation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
