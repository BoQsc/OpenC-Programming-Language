#!/usr/bin/env python3
"""Verify source archive structure, CRCs, paths, and internal manifest hashes."""
from __future__ import annotations
import argparse, hashlib, zipfile
from pathlib import Path, PurePosixPath

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    with zipfile.ZipFile(args.archive) as archive:
        bad = archive.testzip()
        if bad:
            raise SystemExit(f"CRC failure: {bad}")
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise SystemExit("duplicate archive path")
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts:
                raise SystemExit(f"unsafe archive path: {name}")
        manifests = [name for name in names if name.endswith("/MANIFEST.sha256")]
        if len(manifests) != 1:
            raise SystemExit("source archive must contain exactly one MANIFEST.sha256")
        manifest = manifests[0]
        prefix = manifest[:-len("MANIFEST.sha256")]
        for line in archive.read(manifest).decode("utf-8").splitlines():
            if not line.strip():
                continue
            expected, relative = line.split("  ", 1)
            member = prefix + relative
            if member not in names:
                raise SystemExit(f"manifest member missing: {member}")
            actual = hashlib.sha256(archive.read(member)).hexdigest()
            if actual != expected:
                raise SystemExit(f"manifest hash mismatch: {member}")
    print(f"sha256:{hashlib.sha256(args.archive.read_bytes()).hexdigest()}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
