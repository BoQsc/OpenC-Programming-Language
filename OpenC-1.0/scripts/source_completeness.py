#!/usr/bin/env python3
"""Verify authored source inventory only.

This program never compiles or executes OpenC implementation code. A passing
result means required source files exist and are nonempty; it is not build or
conformance evidence.
"""
from pathlib import Path
import argparse, json

ROOT = Path(__file__).resolve().parents[1]

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--contract", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    contract_path = args.contract or root / "SOURCE_COMPLETENESS_CONTRACT.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    required_source = []
    for values in contract["groups"].values():
        required_source.extend(values)
    required_source = sorted(set(required_source))
    required_non_source = sorted(set(contract.get("required_non_source", [])))
    required = sorted(set(required_source + required_non_source))
    missing = [path for path in required if not (root / path).is_file()]
    empty = [path for path in required if (root / path).is_file() and (root / path).stat().st_size == 0]
    report = {
        "schema": "openc.source_completeness_result.v2",
        "version": contract["version"],
        "evidence_state": "STRUCTURAL_SOURCE_CHECK_ONLY",
        "claim": contract["claim"],
        "required_source_files": len(required_source),
        "required_non_source_files": len(required_non_source),
        "required_files": len(required),
        "missing": missing,
        "empty": empty,
        "source_complete_by_inventory": not missing and not empty,
    }
    text = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0 if report["source_complete_by_inventory"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
