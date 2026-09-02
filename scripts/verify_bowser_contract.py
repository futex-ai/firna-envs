#!/usr/bin/env python3
"""Validate a Bowser runtime contract and one capability envelope."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SEMVER_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
FEATURE_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


@dataclass(frozen=True)
class RuntimeContract:
    """Typed Bowser version, envelope, and required feature contract."""

    bowser_version: str
    envelope_version: int
    required_features: tuple[str, ...]


def load_contract(path: Path) -> RuntimeContract:
    """Load and strictly validate the machine-readable contract."""
    document = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise ValueError("contract must be a JSON object")
    expected_keys = {
        "schema_version",
        "bowser_version",
        "envelope_version",
        "required_features",
    }
    if set(document) != expected_keys:
        raise ValueError("contract fields do not match schema version 1")
    if document["schema_version"] != 1:
        raise ValueError("unsupported contract schema version")
    bowser_version = document["bowser_version"]
    if not isinstance(bowser_version, str) or not SEMVER_PATTERN.fullmatch(bowser_version):
        raise ValueError("Bowser version must be semantic x.y.z")
    envelope_version = document["envelope_version"]
    if not isinstance(envelope_version, int) or isinstance(envelope_version, bool) or envelope_version < 1:
        raise ValueError("envelope version must be a positive integer")
    features = document["required_features"]
    if not isinstance(features, list) or not features:
        raise ValueError("required features must be a non-empty array")
    if any(not isinstance(feature, str) or not FEATURE_PATTERN.fullmatch(feature) for feature in features):
        raise ValueError("required feature names must use snake_case")
    if len(features) != len(set(features)):
        raise ValueError("required feature names must be unique")
    return RuntimeContract(bowser_version, envelope_version, tuple(features))


def verify_capabilities(contract: RuntimeContract, payload: Any) -> None:
    """Compare a real Bowser envelope with every centralized requirement."""
    if not isinstance(payload, dict):
        raise ValueError("capabilities must be a JSON object")
    if payload.get("envelope") != contract.envelope_version or payload.get("ok") is not True:
        raise ValueError("capability envelope version or status does not match")
    result = payload.get("result")
    if not isinstance(result, dict):
        raise ValueError("capability result must be an object")
    if result.get("version") != contract.bowser_version:
        raise ValueError("Bowser version does not match the runtime contract")
    features = result.get("features")
    if not isinstance(features, dict):
        raise ValueError("capability features must be an object")
    for feature in contract.required_features:
        if features.get(feature) is not True:
            raise ValueError(f"required Bowser feature is unavailable: {feature}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse the contract path and schema-only validation mode."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", type=Path)
    parser.add_argument("--contract-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Validate the contract and, normally, capabilities read from stdin."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        contract = load_contract(args.contract)
        if not args.contract_only:
            verify_capabilities(contract, json.load(sys.stdin))
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
