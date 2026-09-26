"""Falsify saved-COFF pre-allocation size guards under a small Windows Job.

Usage: python test_coff_bounded_reader.py COMPILER --report REPORT.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import tempfile

from windows_process_measure import run_measured

MIB = 1024 * 1024
OBJECT_LIMIT = 8 * MIB - 4


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(64 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    records = []
    with tempfile.TemporaryDirectory(prefix="openc-coff-size-") as temp:
        root = Path(temp)
        for name, size, expected in (
            ("oversized", 128 * MIB, "OPENC-COFF-LINK-SAVED"),
            ("boundary_plus_one", OBJECT_LIMIT + 1, "OPENC-COFF-LINK-SAVED"),
            ("exact_boundary", OBJECT_LIMIT, "OPENC-COFF-LINK-PARSE"),
        ):
            object_path = root / f"{name}.obj"
            with object_path.open("wb") as stream:
                stream.truncate(size)
            # At the accepted boundary authenticate all bytes so the COFF
            # parser, not the hash gate, proves that the read completed.
            expected_hash = sha256(object_path) if size == OBJECT_LIMIT else "0" * 64
            output = root / f"{name}.exe"
            result = run_measured(
                [str(compiler), "module-coff-link", "--entry=$openc$" + "0" * 64,
                 f"--output={output}", f"--object={object_path}",
                 f"--sha256={expected_hash}"],
                cwd=root, sample_interval=0.01,
                max_private_bytes=64 * MIB,
                max_working_set_bytes=64 * MIB,
                max_captured_output_bytes=MIB, timeout_seconds=20,
            )
            passed = (
                result["exit_code"] == 1
                and expected in str(result["stderr"])
                and not result["memory_limit_exceeded"]
                and not result["timed_out"]
                and not output.exists()
            )
            records.append({"name": name, "file_bytes": size,
                            "expected_rejection": expected,
                            "passed": passed, "measurement": result})
    passed = all(record["passed"] for record in records)
    report = {"schema": "openc.sh27.coff_preallocation_bound.v1",
              "status": "PASS" if passed else "FAIL",
              "compiler": str(compiler), "compiler_sha256": sha256(compiler),
              "private_limit_bytes": 64 * MIB,
              "working_set_limit_bytes": 64 * MIB,
              "cases": records}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"saved COFF pre-allocation bound: {report['status']} ({len(records)} cases)")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
