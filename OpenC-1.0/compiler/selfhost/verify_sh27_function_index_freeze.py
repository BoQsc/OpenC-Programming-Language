#!/usr/bin/env python3
"""Exact valid/invalid proof for the five-array prepared index boundary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from benchmark_sh27_production import require_disk_headroom, sha256
from windows_process_measure import run_measured


MIB = 1024 * 1024
ROOT = Path(__file__).resolve().parents[2]
CASES = (
    ("calls", "sh27_function_index_calls", 0),
    ("duplicate", "sh27_function_index_duplicate", 1),
    ("cycle", "sh27_function_index_cycle", 1),
    ("invalid", "sh27_prepared_source_invalid", 1),
)


def run(command: list[str]) -> dict[str, object]:
    return run_measured(
        command, cwd=ROOT, sample_interval=0.01,
        max_private_bytes=256 * MIB,
        max_working_set_bytes=64 * MIB,
        max_captured_output_bytes=2 * MIB,
        timeout_seconds=30,
    )


def complete(measurement: dict[str, object], exit_code: int) -> bool:
    return (
        measurement["exit_code"] == exit_code
        and not measurement["timed_out"]
        and not measurement["memory_limit_exceeded"]
        and not measurement["stdout_truncated"]
        and not measurement["stderr_truncated"]
    )


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
    report: dict[str, object] = {
        "schema": "openc.sh27.function_index_freeze.v1",
        "status": "FAIL",
        "compiler": {"path": str(compiler), "sha256": sha256(compiler)},
        "cases": [],
    }
    passed = True
    for name, directory, expected_exit in CASES:
        project = ROOT / "tests" / directory / "openc.project.json"
        item: dict[str, object] = {
            "name": name, "project_sha256": sha256(project), "modes": {},
        }
        for mode in ("default", "prepared"):
            output = output_dir / f"{name}-{mode}.exe"
            timings = output_dir / f"{name}-{mode}.timings.json"
            command = [
                str(compiler), "artifact", f"--project={project}",
                "--kind=exe", f"--output={output}",
                f"--timings={timings}", "--source-chunks=1",
            ]
            if mode == "prepared":
                command.append("--owned-function-project-caches")
            measured = run(command)
            mode_record: dict[str, object] = {
                "command": command, "measurement": measured,
                "complete": complete(measured, expected_exit),
            }
            if expected_exit == 0 and output.is_file():
                mode_record["output_sha256"] = sha256(output)
                mode_record["program"] = run([str(output)])
            if timings.is_file():
                mode_record["timings"] = json.loads(
                    timings.read_text(encoding="utf-8")
                )
            item["modes"][mode] = mode_record
        default = item["modes"]["default"]
        prepared = item["modes"]["prepared"]
        item["diagnostics_exact"] = all(
            default["measurement"][key] == prepared["measurement"][key]
            for key in ("exit_code", "stdout", "stderr")
        )
        item["passed"] = (
            default["complete"] and prepared["complete"]
            and item["diagnostics_exact"]
        )
        if expected_exit == 0:
            item["passed"] = (
                item["passed"]
                and default.get("output_sha256") == prepared.get("output_sha256")
                and all(
                    complete(mode_record["program"], 0)
                    for mode_record in (default, prepared)
                    if "program" in mode_record
                )
                and "program" in default and "program" in prepared
                and all(
                    default["program"][key] == prepared["program"][key]
                    for key in ("exit_code", "stdout", "stderr")
                )
                and prepared.get("timings", {}).get("prepared_function_calls", 0) >= 2
            )
        passed = passed and bool(item["passed"])
        report["cases"].append(item)
    report["status"] = "PASS" if passed else "FAIL"
    path = output_dir / "function-index-freeze.json"
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 function index freeze: {report['status']}; report={path}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
