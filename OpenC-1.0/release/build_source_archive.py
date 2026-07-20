#!/usr/bin/env python3
"""Create a deterministic OpenC source snapshot.

This program packages authored source. It does not compile, test, sign, or
publish the implementation.
"""
from __future__ import annotations
import argparse, hashlib, zipfile
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

def included_files(root: Path):
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if is_generated(root, path):
            continue
        yield path

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tree", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--version", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--archive-root")
    args = parser.parse_args()
    root = args.tree.resolve()
    archive_root = args.archive_root or f"OpenC-{args.version}"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in included_files(root):
            relative = path.relative_to(root).as_posix()
            info = zipfile.ZipInfo(f"{archive_root}/{relative}", date_time=EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o100755 if path.suffix in {".sh", ".py"} or path.parent.name == "bin" else 0o100644
            info.external_attr = (mode & 0xFFFF) << 16
            archive.writestr(info, path.read_bytes())
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(f"{digest}  {args.output.name}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
