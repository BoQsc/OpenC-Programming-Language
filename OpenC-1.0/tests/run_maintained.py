#!/usr/bin/env python3
"""Build and execute every maintained OpenC program with recorded results."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from native_toolchain import resolve_native_compiler, validate_native_compiler

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
    parser.add_argument(
        "--compiler",
        type=Path,
        help="verified OpenC-native compiler; defaults to the installed toolchain",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT / "build-output" / "maintained-program-report.json",
    )
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    output_directory = args.report.resolve().parent / "maintained"
    output_directory.mkdir(parents=True, exist_ok=True)
    results = []
    for name, expected_exit, program_args, expected_stdout in CASES:
        project = ROOT / "programs" / name / "openc.project.json"
        executable = output_directory / f"{name}.exe"
        build_command = [
            str(compiler),
            "build",
            f"--project={project.resolve()}",
            f"--output={executable}",
        ]
        built = subprocess.run(
            build_command, cwd=ROOT, text=True, capture_output=True
        )
        run_command = [str(executable), *program_args]
        completed = (
            subprocess.run(
                run_command, cwd=ROOT, text=True, capture_output=True
            )
            if built.returncode == 0 and executable.is_file()
            else None
        )
        passed = (
            built.returncode == 0
            and completed is not None
            and completed.returncode == expected_exit
            and completed.stdout == expected_stdout
        )
        results.append(
            {
                "program": name,
                "build_command": build_command,
                "build_exit_code": built.returncode,
                "build_stdout": built.stdout,
                "build_stderr": built.stderr,
                "run_command": run_command,
                "expected_exit_code": expected_exit,
                "actual_exit_code": completed.returncode if completed else None,
                "expected_stdout": expected_stdout,
                "stdout": completed.stdout if completed else "",
                "stderr": completed.stderr if completed else "",
                "passed": passed,
            }
        )

    report = {
        "schema": "openc.maintained_program_execution.v2",
        "evidence_state": "EXECUTED",
        "compiler_under_test": {
            **native,
            "implementation_language": "OpenC",
        },
        "retained_d_seed_executed": False,
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
