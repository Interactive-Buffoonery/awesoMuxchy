#!/usr/bin/env python3
"""Generate the Linux wording contract from the pinned macOS catalogs."""

from __future__ import annotations

import json
import os
import plistlib
import subprocess
from pathlib import Path


EXPECTED_REFERENCE = "fed33ff47c559344fc6db6fa53f16e75fcc4a116"
ROOT = Path(__file__).resolve().parents[1]
REFERENCE = Path(
    os.environ.get(
        "AWESOMUX_MACOS_REFERENCE",
        "/home/sarah/Development/awesomux-macos-reference",
    )
)
OUTPUT = Path(
    os.environ.get(
        "AWESOMUX_TEXT_BASELINE_OUTPUT",
        str(ROOT / "shared/resources/text-baseline.json"),
    )
)


def git(*args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(REFERENCE), *args], text=True
    ).strip()


def require_reference() -> None:
    if git("rev-parse", "HEAD") != EXPECTED_REFERENCE:
        raise SystemExit("macOS reference is not at the pinned baseline")
    if git("status", "--short"):
        raise SystemExit("macOS reference is dirty; refusing to read it")


def catalog_entries() -> list[dict[str, object]]:
    relative = Path("Resources/Localizable.xcstrings")
    data = json.loads((REFERENCE / relative).read_text(encoding="utf-8"))
    entries: list[dict[str, object]] = []
    for key, value in sorted(data["strings"].items()):
        english = (
            value.get("localizations", {})
            .get("en", {})
            .get("stringUnit", {})
            .get("value", key)
        )
        entries.append(
            {
                "key": key,
                "english": english,
                "comment": value.get("comment"),
                "source": str(relative),
                "kind": "string",
            }
        )
    return entries


def plural_entries() -> list[dict[str, object]]:
    relative = Path("Resources/en.lproj/Localizable.stringsdict")
    with (REFERENCE / relative).open("rb") as handle:
        data = plistlib.load(handle)
    return [
        {
            "key": key,
            "english": value,
            "comment": None,
            "source": str(relative),
            "kind": "plural",
        }
        for key, value in sorted(data.items())
    ]


def main() -> None:
    require_reference()
    payload = {
        "schemaVersion": 1,
        "product": "awesoMux",
        "sourceRepository": "https://github.com/Interactive-Buffoonery/awesomux.git",
        "sourceCommit": EXPECTED_REFERENCE,
        "sourceLanguage": "en",
        "entries": catalog_entries(),
        "plurals": plural_entries(),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
