#!/usr/bin/env python3
"""Validate the committed wording contract and optional pinned-reference drift."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "shared/resources/text-baseline.json"
EXPECTED_REFERENCE = "fed33ff47c559344fc6db6fa53f16e75fcc4a116"


def fail(message: str) -> None:
    print(f"text-baseline: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_shape() -> None:
    data = json.loads(BASELINE.read_text(encoding="utf-8"))
    if data.get("schemaVersion") != 1:
        fail("unsupported schema version")
    if data.get("sourceCommit") != EXPECTED_REFERENCE:
        fail("source commit drift")
    entries = data.get("entries")
    if not isinstance(entries, list) or not entries:
        fail("string entries are missing")
    keys = [entry.get("key") for entry in entries]
    if keys != sorted(keys) or len(keys) != len(set(keys)):
        fail("string entries must be sorted and unique")
    if any(not entry.get("source") for entry in entries):
        fail("every string requires a source location")
    plurals = data.get("plurals")
    if not isinstance(plurals, list) or not plurals:
        fail("plural entries are missing")


def validate_reference_drift() -> None:
    reference = Path(
        os.environ.get(
            "AWESOMUX_MACOS_REFERENCE",
            "/home/sarah/Development/awesomux-macos-reference",
        )
    )
    if not reference.is_dir():
        return
    head = subprocess.check_output(
        ["git", "-C", str(reference), "rev-parse", "HEAD"], text=True
    ).strip()
    if head != EXPECTED_REFERENCE:
        fail("available reference is not at the pinned commit")
    if subprocess.check_output(
        ["git", "-C", str(reference), "status", "--short"], text=True
    ):
        fail("available reference is dirty")
    with tempfile.TemporaryDirectory(prefix="awesomux-text-baseline-") as tmp:
        generated = Path(tmp) / "text-baseline.json"
        env = os.environ.copy()
        env["AWESOMUX_MACOS_REFERENCE"] = str(reference)
        subprocess.run(
            [sys.executable, str(ROOT / "script/sync-text-baseline.py")],
            check=True,
            env={**env, "AWESOMUX_TEXT_BASELINE_OUTPUT": str(generated)},
        )
        if generated.read_bytes() != BASELINE.read_bytes():
            fail("wording drift; run ./script/sync-text-baseline.py")


def main() -> None:
    validate_shape()
    validate_reference_drift()
    print("text-baseline: valid")


if __name__ == "__main__":
    main()
