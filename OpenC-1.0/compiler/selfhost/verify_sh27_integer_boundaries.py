#!/usr/bin/env python3
"""Exercise integer-immediate encoding boundaries under the SH-27 RAM cap."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from benchmark_sh27_native_parallel import build
from benchmark_sh27_production import MIB, ROOT, require_disk_headroom, run_measured


PROJECT = ROOT / "tests/sh27_integer_literals/openc.project.json"


def execute(binary: Path) -> dict[str, object]:
    return run_measured(
        [str(binary)], cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=64 * 1024, timeout_seconds=15,
    )


def main() -> int:
    if os.name != "nt":
        raise SystemExit("integer-immediate boundary proof requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    runs = output.parent / (output.stem + "-runs")
    runs.mkdir(parents=True, exist_ok=False)
    samples: dict[str, dict[str, object]] = {}
    hashes: set[str] = set()
    for mode, parallel in (("serial", False), ("adaptive", True)):
        directory = runs / mode
        compilation = build(compiler, PROJECT, directory, parallel, True, "auto")
        execution = execute(directory / "program.exe") if compilation["passed"] else None
        samples[mode] = {"build": compilation, "execution": execution}
        if compilation["output_sha256"] is not None:
            hashes.add(str(compilation["output_sha256"]))
    passed = bool(
        len(hashes) == 1 and all(
            sample["build"]["passed"]
            and sample["execution"] is not None
            and sample["execution"]["exit_code"] == 0
            and not sample["execution"]["timed_out"]
            and not sample["execution"]["memory_limit_exceeded"]
            and sample["execution"]["stdout"] == ""
            and sample["execution"]["stderr"] == ""
            for sample in samples.values()
        )
    )
    report = {
        "schema": "openc.sh27.integer_boundaries.v1",
        "status": "PASS" if passed else "FAIL",
        "project": str(PROJECT),
        "serial_adaptive_binary_exact": len(hashes) == 1,
        "samples": samples,
    }
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 integer boundaries: {report['status']}; report={output}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
