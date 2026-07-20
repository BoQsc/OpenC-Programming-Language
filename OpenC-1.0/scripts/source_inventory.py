#!/usr/bin/env python3
"""Generate a deterministic inventory of required authored source.

This is a structural source inventory. Build and execution evidence belongs in
DEVELOPMENT_STATE.json and VERIFICATION_STATUS.md.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--contract", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    root = args.root.resolve()
    contract_path = args.contract or root / "SOURCE_COMPLETENESS_CONTRACT.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    records = []
    missing = []
    empty = []

    for group, members in sorted(contract["groups"].items()):
        for relative in sorted(members):
            path = root / relative
            present = path.is_file()
            record = {
                "evidence_state": "AUTHORED_PRESENT" if present else "MISSING",
                "group": group,
                "path": relative,
                "present": present,
            }
            if present:
                record["bytes"] = path.stat().st_size
                record["sha256"] = digest(path)
                if record["bytes"] == 0:
                    empty.append(relative)
            else:
                missing.append(relative)
            records.append(record)

    result = {
        "schema": "openc.source_inventory.v2",
        "version": contract["version"],
        "evidence_state": "STRUCTURAL_SOURCE_INVENTORY",
        "files": records,
        "missing": missing,
        "empty": empty,
        "totals": {
            "files": len(records),
            "bytes": sum(record.get("bytes", 0) for record in records),
            "missing": len(missing),
            "empty": len(empty),
        },
    }
    text = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8", newline="\n")
    print(text, end="")
    return 0 if not missing and not empty else 1


if __name__ == "__main__":
    raise SystemExit(main())
