#!/usr/bin/env python3
"""Guarded self-build proof for the serial project-cache ownership cut."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from benchmark_sh27_production import require_disk_headroom, sha256
from windows_process_measure import run_measured


MIB = 1024 * 1024
ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "compiler" / "selfhost" / "openc.project.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output_dir = args.output_dir.resolve()
    if output_dir.exists():
        raise SystemExit(f"refusing existing output directory: {output_dir}")
    require_disk_headroom(output_dir.parent)
    output_dir.mkdir(parents=True, exist_ok=False)
    output = output_dir / "openc.exe"
    timings = output_dir / "timings.json"
    command = [
        str(compiler), "artifact", f"--project={PROJECT}",
        "--kind=exe", f"--output={output}", f"--timings={timings}",
        "--source-chunks=4", "--owned-function-project-caches",
    ]
    measurement = run_measured(
        command,
        cwd=ROOT,
        sample_interval=0.01,
        max_private_bytes=256 * MIB,
        max_working_set_bytes=64 * MIB,
        max_captured_output_bytes=2 * MIB,
        timeout_seconds=120,
    )
    report: dict[str, object] = {
        "schema": "openc.sh27.owned_project_caches_selfbuild.v1",
        "status": "FAIL",
        "compiler": {"path": str(compiler), "sha256": sha256(compiler)},
        "project": {"path": str(PROJECT), "sha256": sha256(PROJECT)},
        "limits": {"private_bytes": 256 * MIB, "working_set_bytes": 64 * MIB},
        "command": command,
        "measurement": measurement,
    }
    complete = (
        measurement["exit_code"] == 0
        and not measurement["timed_out"]
        and not measurement["memory_limit_exceeded"]
        and not measurement["stdout_truncated"]
        and not measurement["stderr_truncated"]
        and output.is_file()
        and timings.is_file()
    )
    if complete:
        report["output_sha256"] = sha256(output)
        report["byte_exact_selfbuild"] = sha256(output) == sha256(compiler)
        report["timings"] = json.loads(timings.read_text(encoding="utf-8"))
        complete = (
            bool(report["byte_exact_selfbuild"])
            and report["timings"].get("owned_function_project_caches") is True
            and report["timings"].get("late_function_type_misses") == 0
        )
    report["status"] = "PASS" if complete else "FAIL"
    report_path = output_dir / "owned-project-caches-selfbuild.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 owned project caches self-build: {report['status']}; report={report_path}")
    return 0 if complete else 1


if __name__ == "__main__":
    sys.exit(main())
