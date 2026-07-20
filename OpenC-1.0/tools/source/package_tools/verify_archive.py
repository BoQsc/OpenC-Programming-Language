#!/usr/bin/env python3
"""Verify archive paths, CRCs, and optional SHA-256 manifest entries."""
from __future__ import annotations
import argparse, hashlib, zipfile
from pathlib import PurePosixPath, Path

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--manifest-name", default="MANIFEST.sha256")
    args = parser.parse_args()
    with zipfile.ZipFile(args.archive) as archive:
        bad = archive.testzip()
        if bad:
            raise SystemExit(f"CRC failure: {bad}")
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise SystemExit("archive contains duplicate paths")
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts:
                raise SystemExit(f"unsafe archive path: {name}")
        manifests = [name for name in names if name.endswith("/" + args.manifest_name)]
        for manifest_name in manifests:
            prefix = manifest_name[: -len(args.manifest_name)]
            for line in archive.read(manifest_name).decode("utf-8").splitlines():
                if not line.strip():
                    continue
                expected, relative = line.split("  ", 1)
                member = prefix + relative
                actual = hashlib.sha256(archive.read(member)).hexdigest()
                if actual != expected:
                    raise SystemExit(f"hash mismatch: {member}")
    print("archive verification: PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
