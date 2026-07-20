#!/usr/bin/env python3
"""Build and execute every maintained OpenC program with recorded results."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

CASES = (
    ("A_COMPUTATION", 32, (), ""),
    ("B_FLOW_OWNERSHIP", 0, (), ""),
    ("C_UNSAFE_BOUNDARY", 30, (), ""),
    (
        "D_HOSTED_CLI",
        0,
        ("alpha", "two words"),
        "arguments: 2\n0: alpha\n1: two words\n",
    ),
)


def main() -> int:
    parser = argparse.ArgumentParser()
    default_compiler = ROOT / "compiler" / ("openc.exe" if os.name == "nt" else "openc")
    parser.add_argument("--compiler", type=Path, default=default_compiler)
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT / "build-output" / "maintained-program-report.json",
    )
    args = parser.parse_args()

    results = []
    for name, expected_exit, program_args, expected_stdout in CASES:
        project = ROOT / "programs" / name / "openc.project.json"
        command = [
            str(args.compiler.resolve()),
            "run",
            f"--project={project.resolve()}",
            *program_args,
        ]
        completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
        passed = (
            completed.returncode == expected_exit
            and completed.stdout == expected_stdout
        )
        results.append(
            {
                "program": name,
                "command": command,
                "expected_exit_code": expected_exit,
                "actual_exit_code": completed.returncode,
                "expected_stdout": expected_stdout,
                "stdout": completed.stdout,
                "stderr": completed.stderr,
                "passed": passed,
            }
        )

    report = {
        "schema": "openc.maintained_program_execution.v1",
        "evidence_state": "EXECUTED",
        "total": len(results),
        "passed": sum(result["passed"] for result in results),
        "failed": sum(not result["passed"] for result in results),
        "results": results,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"maintained programs: {report['passed']}/{report['total']} passed; "
        f"report={args.report}"
    )
    return 0 if report["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
