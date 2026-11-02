#!/usr/bin/env python3
"""Check that the native release plan contains the self-host compiler sources."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            result.update(chunk)
    return result.hexdigest()


def verify_archive(path: Path, prefix: str, *, standalone: bool,
                   source_root: Path | None = None, source_entries: set[str] | None = None) -> dict:
    if path.stat().st_size > 64 * 1024 * 1024:
        raise ValueError(f"archive exceeds 64 MiB: {path.name}")
    manifest_name = "STANDALONE-MANIFEST.sha256" if standalone else "MANIFEST.sha256"
    with zipfile.ZipFile(path) as archive:
        members = archive.infolist()
        names = [item.filename for item in members]
        if not members or len(members) > 8192 or len({n.casefold() for n in names}) != len(names):
            raise ValueError(f"empty, oversized or duplicate archive: {path.name}")
        if sum(item.file_size for item in members) > 64 * 1024 * 1024:
            raise ValueError(f"archive expanded size exceeds 64 MiB: {path.name}")
        for item in members:
            name = item.filename
            member = PurePosixPath(name)
            if (item.file_size > 16 * 1024 * 1024 or not name.startswith(prefix)
                    or "\\" in name or ":" in name or ".." in member.parts
                    or member.is_absolute() or member.as_posix() != name or item.is_dir()):
                raise ValueError(f"unsafe archive member: {name}")
        manifest = prefix + manifest_name
        listed = set()
        for line in archive.read(manifest).decode("utf-8").splitlines():
            expected, name = line.split("  ", 1)
            if name in listed or name == manifest_name or prefix + name not in names:
                raise ValueError(f"invalid manifest entry: {name}")
            listed.add(name)
            content = archive.read(prefix + name)
            if hashlib.sha256(content).hexdigest() != expected:
                raise ValueError(f"manifest checksum differs: {name}")
            relative = PurePosixPath(name)
            if standalone and (relative.suffix.lower() in {".c", ".d", ".h", ".py", ".pyc"}
                    or relative.name.lower() in {"dub.json", "dub.selections.json"}
                    or "tinycc-win64" in {part.lower() for part in relative.parts}):
                raise ValueError(f"historical toolchain payload in standalone: {name}")
            if source_root is not None:
                authored = source_root / name
                if authored.stat().st_size != len(content) or digest(authored) != expected:
                    raise ValueError(f"source archive differs from authored input: {name}")
        if {prefix + name for name in listed} != set(names) - {manifest}:
            raise ValueError(f"manifest does not cover every member: {path.name}")
        if source_entries is not None and listed | {manifest_name} != source_entries:
            raise ValueError("source archive membership differs from the release plan")
    return {"sha256": digest(path), "manifest_entries": len(listed)}


def verify_archives(root: Path, directory: Path) -> dict:
    entries = set((root / "release/SH21_NATIVE_RELEASE_PLAN.tsv").read_text(encoding="utf-8").splitlines()[1:])
    prefix = "OpenC-" + (root / "VERSION").read_text(encoding="utf-8").strip() + "/"
    results = {}
    for kind in ("standalone", "source"):
        for side in ("a", "b"):
            name = f"{kind}-{side}.zip"
            results[name] = verify_archive(directory / name, prefix, standalone=kind == "standalone",
                source_root=root if kind == "source" else None,
                source_entries=entries if kind == "source" else None)
        if results[f"{kind}-a.zip"]["sha256"] != results[f"{kind}-b.zip"]["sha256"]:
            raise ValueError(f"independent {kind} archives differ")
    return results


def verify(root: Path, plan: Path) -> dict:
    if plan.stat().st_size > 4 * 1024 * 1024:
        raise ValueError("release plan exceeds 4 MiB")
    lines = plan.read_text(encoding="utf-8").splitlines()
    header = lines[0].split("\t") if lines else []
    if len(header) != 3 or header[:2] != ["openc.native_release_plan.v1", "1"]:
        raise ValueError("invalid native release plan header")
    entries = lines[1:]
    if not header[2].isdigit() or int(header[2]) != len(entries):
        raise ValueError("native release plan count differs from its entries")
    if len(set(entries)) != len(entries):
        raise ValueError("duplicate native release plan entry")
    for name in entries:
        path = PurePosixPath(name)
        if (not name or "\\" in name or path.is_absolute() or ":" in name
                or ".." in path.parts or path.as_posix() != name):
            raise ValueError(f"noncanonical release path: {name}")
        target = (root / name).resolve()
        if not target.is_relative_to(root) or not target.is_file():
            raise ValueError(f"missing or external release input: {name}")
    project = root / "compiler/selfhost/openc.project.json"
    data = json.loads(project.read_text(encoding="utf-8"))
    sources = {
        (project.parent / name).resolve().relative_to(root).as_posix()
        for group in data["modules"].values() for name in group
    }
    missing = sorted(sources - set(entries))
    if missing:
        raise ValueError("compiler sources absent from release plan: " + ", ".join(missing))
    contract = json.loads((root / "SOURCE_COMPLETENESS_CONTRACT.json").read_text(encoding="utf-8"))
    registered = {name for group in contract["groups"].values() for name in group}
    missing = sorted(sources - registered)
    if missing:
        raise ValueError("compiler sources absent from source completeness contract: " + ", ".join(missing))
    return {"schema": "openc.native_release_source_coverage.v1", "status": "PASS",
            "plan_entries": len(entries), "compiler_sources": len(sources),
            "missing_compiler_sources": []}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--archives", type=Path, help="independently verify both native archive pairs")
    args = parser.parse_args()
    root = args.root.resolve(strict=True)
    try:
        result = verify(root, root / "release/SH21_NATIVE_RELEASE_PLAN.tsv")
        if args.archives:
            result["archives"] = verify_archives(root, args.archives.resolve(strict=True))
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        result = {"schema": "openc.native_release_source_coverage.v1", "status": "FAIL",
                  "error": str(error)}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
