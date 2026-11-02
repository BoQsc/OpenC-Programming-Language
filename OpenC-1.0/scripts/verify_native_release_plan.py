#!/usr/bin/env python3
"""Check that the native release plan contains the self-host compiler sources."""
from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath


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
    args = parser.parse_args()
    root = args.root.resolve(strict=True)
    try:
        result = verify(root, root / "release/SH21_NATIVE_RELEASE_PLAN.tsv")
    except (OSError, ValueError, KeyError, TypeError) as error:
        result = {"schema": "openc.native_release_source_coverage.v1", "status": "FAIL",
                  "error": str(error)}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
