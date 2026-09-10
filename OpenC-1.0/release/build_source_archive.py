#!/usr/bin/env python3
"""Create a deterministic OpenC source snapshot.

This program packages authored source. It does not compile, test, sign, or
publish the implementation.
"""
from __future__ import annotations
import argparse, hashlib, os, shutil, zipfile
from pathlib import Path

EPOCH = (1980, 1, 1, 0, 0, 0)
EXCLUDED_PARTS = {".git", ".dub", "__pycache__", "build-output"}
EXCLUDED_SUFFIXES = {".dll", ".exe", ".exp", ".lib", ".obj", ".pdb", ".pyc"}

def is_generated(root: Path, path: Path) -> bool:
    relative = path.relative_to(root)
    parts = relative.parts
    if parts and parts[0] == "third_party":
        return False
    return (
        any(part in EXCLUDED_PARTS for part in parts)
        or path.suffix.lower() in EXCLUDED_SUFFIXES
        or relative.as_posix() in {"build/fixture_main.d", "build/test-report.json"}
        or relative.as_posix() == "build/openc-build-record.json"
        or relative.as_posix().startswith("build/generated/")
        or (len(parts) >= 3 and parts[0] == "programs" and parts[2] == "build")
    )

def included_files(root: Path):
    root = root.resolve()
    for directory, directories, files in os.walk(root, topdown=True):
        current = Path(directory)
        relative = current.relative_to(root)
        # Prune ignored trees before walking them.  Building one giant sorted
        # rglob list retained every historical build artifact in memory even
        # though those paths were discarded immediately afterwards.
        directories[:] = sorted(
            name
            for name in directories
            if name not in EXCLUDED_PARTS
            and not (
                len(relative.parts) == 2
                and relative.parts[0] == "programs"
                and name == "build"
            )
            and not (
                relative.as_posix() == "build" and name == "generated"
            )
        )
        for name in sorted(files):
            path = current / name
            if not is_generated(root, path):
                yield path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()

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
            with path.open("rb") as source, archive.open(
                info, "w", force_zip64=True
            ) as destination:
                shutil.copyfileobj(source, destination, length=1024 * 1024)
    digest = sha256(args.output)
    print(f"{digest}  {args.output.name}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
