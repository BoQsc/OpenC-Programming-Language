#!/usr/bin/env python3
"""Refresh byte counts and SHA-256 hashes in the authority index."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "AUTHORITY_INDEX.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    data = json.loads(INDEX.read_text(encoding="utf-8"))
    missing: list[str] = []
    updated = 0
    for section in ("authoritative", "project_authority"):
        for record in data.get(section, []):
            path = ROOT / record["path"]
            if not path.is_file():
                missing.append(record["path"])
                continue
            record["bytes"] = path.stat().st_size
            record["sha256"] = digest(path)
            updated += 1
    if missing:
        raise SystemExit("missing authority inputs: " + ", ".join(missing))
    data["version"] = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    INDEX.write_text(
        json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    print(f"authority index refreshed: {updated} records")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
