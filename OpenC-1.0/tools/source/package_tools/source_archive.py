#!/usr/bin/env python3
"""Create a deterministic OpenC source archive.

This tool packages source only. It does not compile, test, sign, or publish it.
"""
from __future__ import annotations
import argparse, hashlib, os, zipfile
from pathlib import Path

EPOCH = (1980, 1, 1, 0, 0, 0)
EXCLUDED_PARTS = {".git", ".dub", "__pycache__", "build-output"}
EXCLUDED_SUFFIXES = {".dll", ".exe", ".exp", ".lib", ".obj", ".pdb", ".pyc"}

def is_generated(root: Path, path: Path) -> bool:
    relative = path.relative_to(root)
    parts = relative.parts
    return (
        any(part in EXCLUDED_PARTS for part in parts)
        or path.suffix.lower() in EXCLUDED_SUFFIXES
        or relative.as_posix() == "build/fixture_main.d"
        or (len(parts) >= 3 and parts[0] == "programs" and parts[2] == "build")
    )

def source_files(root: Path):
    for path in sorted(root.rglob("*")):
        if path.is_file() and not is_generated(root, path):
            yield path

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--prefix")
    args = parser.parse_args()
    root = args.root.resolve()
    prefix = args.prefix or root.name
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in source_files(root):
            relative = path.relative_to(root).as_posix()
            info = zipfile.ZipInfo(f"{prefix}/{relative}", EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o100644 & 0xFFFF) << 16
            archive.writestr(info, path.read_bytes())
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(f"{digest}  {args.output.name}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
