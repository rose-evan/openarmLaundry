#!/usr/bin/env python3

"""Reject a trained policy unless its saved feature contract is base-only."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


EXPECTED_INPUTS = {
    "observation.state": ("STATE", [16]),
    "observation.images.base": ("VISUAL", [3, 480, 640]),
}
EXPECTED_OUTPUTS = {"action": ("ACTION", [16])}


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def validate_features(
    actual: Any, expected: dict[str, tuple[str, list[int]]], label: str
) -> None:
    if not isinstance(actual, dict):
        raise ValueError(f"policy has no {label} feature object")
    if set(actual) != set(expected):
        raise ValueError(
            f"{label} keys mismatch: expected {sorted(expected)}, found {sorted(actual)}"
        )
    for name, (feature_type, shape) in expected.items():
        if actual[name].get("type") != feature_type:
            raise ValueError(f"{name} must have type {feature_type}")
        if actual[name].get("shape") != shape:
            raise ValueError(f"{name} must have shape {shape}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    try:
        config = load_json(args.config)
        validate_features(config.get("input_features"), EXPECTED_INPUTS, "input")
        validate_features(config.get("output_features"), EXPECTED_OUTPUTS, "output")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"policy validation failed: {error}", file=sys.stderr)
        return 1
    print(f"base-only policy contract: OK ({args.config})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
