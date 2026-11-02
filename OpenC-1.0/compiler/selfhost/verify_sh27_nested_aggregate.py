#!/usr/bin/env python3
"""Prove a historical ref-to-value aggregate initializer defect is fixed."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from benchmark_sh27_native_parallel import build
from benchmark_sh27_production import MIB, ROOT, require_disk_headroom, run_measured
from verify_sh27_native_chunks import timing_accounting_valid


PROJECT = ROOT / "tests/sh27_nested_aggregate/openc.project.json"


def execute(binary: Path) -> dict[str, object]:
    return run_measured(
        [str(binary)], cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=64 * 1024, timeout_seconds=15,
    )


def main() -> int:
    if os.name != "nt":
        raise SystemExit("native aggregate proof requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    baseline = args.baseline.resolve(strict=True)
    candidate = args.candidate.resolve(strict=True)
    output = args.output.resolve()
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    runs = output.parent / (output.stem + "-runs")
    runs.mkdir(parents=True, exist_ok=False)
    baseline_build = build(baseline, PROJECT, runs / "baseline", False, True, 4)
    candidate_build = build(candidate, PROJECT, runs / "candidate", True, True, "auto")
    baseline_run = execute(runs / "baseline/program.exe") if baseline_build["passed"] else None
    candidate_run = execute(runs / "candidate/program.exe") if candidate_build["passed"] else None
    passed = bool(
        baseline_build["passed"] and candidate_build["passed"]
        and baseline_run is not None and candidate_run is not None
        and baseline_run["exit_code"] != 0
        and candidate_run["exit_code"] == 0
        and not baseline_run["timed_out"] and not candidate_run["timed_out"]
        and not baseline_run["memory_limit_exceeded"]
        and not candidate_run["memory_limit_exceeded"]
        and candidate_run["stdout"] == "" and candidate_run["stderr"] == ""
        and timing_accounting_valid(candidate_build["compiler_timings"], True, "auto")
    )
    report = {
        "schema": "openc.sh27.nested_aggregate.v1",
        "status": "PASS" if passed else "FAIL",
        "project": str(PROJECT),
        "baseline": {"build": baseline_build, "execution": baseline_run},
        "candidate": {"build": candidate_build, "execution": candidate_run},
    }
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 nested aggregate: {report['status']}; report={output}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
