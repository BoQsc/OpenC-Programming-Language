#!/usr/bin/env python3
"""Generate an exact SHA-256 manifest without compiling or executing OpenC."""
from __future__ import annotations
import argparse, hashlib
from pathlib import Path

EXCLUDED_NAMES = {"MANIFEST.sha256"}
EXCLUDED_PARTS = {".git", ".dub", ".cache", "__pycache__", "build-output"}
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

def files(root: Path):
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.name in EXCLUDED_NAMES:
            continue
        if is_generated(root, path):
            continue
        yield path

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output or root / "MANIFEST.sha256"
    lines = []
    for path in files(root):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(root).as_posix()}")
    output.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
