#!/usr/bin/env python3
"""Verify the historical Electron archive and restore it without network access."""

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    archive = root / "reference/legacy-electron"
    manifest = json.loads((archive / "manifest.json").read_text())
    bundle = archive / manifest["bundle"]
    if hashlib.sha256(bundle.read_bytes()).hexdigest() != manifest["sha256"]:
        raise SystemExit("Electron archive checksum mismatch")
    with tempfile.TemporaryDirectory(prefix="awesomux-electron-restore-") as tmp:
        restored = Path(tmp) / "repository.git"
        subprocess.run(["git", "clone", "--mirror", str(bundle), str(restored)], check=True)

        def git(*args):
            return subprocess.check_output(["git", "-C", str(restored), *args], text=True).strip()

        subprocess.run(["git", "-C", str(restored), "fsck", "--full"], check=True)
        head = manifest["sourceHead"]
        checks = {
            "main revision": git("rev-parse", "refs/heads/main") == head,
            "source tree": git("rev-parse", head + "^{tree}") == manifest["sourceTree"],
            "tracked files": git("ls-tree", "-r", "--name-only", head).splitlines()
            == manifest["trackedFiles"],
            "reachable commits": int(git("rev-list", "--all", "--count"))
            == manifest["reachableCommitCount"],
        }
        for ref, revision in manifest["refs"].items():
            checks[ref] = git("rev-parse", ref) == revision
        failed = [name for name, passed in checks.items() if not passed]
        if failed:
            raise SystemExit("Electron archive restore mismatch: " + ", ".join(failed))
    print("Electron archive: checksum, offline restore, object integrity, refs, history and tree verified")


if __name__ == "__main__":
    main()
