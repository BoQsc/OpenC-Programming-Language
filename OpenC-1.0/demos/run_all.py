#!/usr/bin/env python3
"""Build and execute every OpenC demo with the verified native compiler."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from native_toolchain import resolve_native_compiler, validate_native_compiler


CASES = {
    "hello": (
        "Hello, OpenC!\n"
        "Welcome to the OpenC programming language.\n"
        "This is a demo of the Hosted I/O system.\n"
    ),
    "calculator": (
        "42 + 10 = 52\n"
        "42 - 10 = 32\n"
        "42 * 10 = 420\n"
        "42 / 10 = 4\n"
        "42 % 10 = 2\n"
    ),
    "types": (
        "Rectangle area: 5000\n"
        "Color code for green: 65280\n"
        "Color code for red: 16711680\n"
    ),
    "strings": (
        "String handling demo\n"
        "-------------------\n"
        "Printing multiple values: 1, 2, 3\n"
        "Newlines are supported\n"
        "via io.println.\n"
    ),
    "ownership": (
        "Ownership and resource demo\n"
        "file_open: opened descriptor 7\n"
        "File descriptor in use: 7\n"
        "file_close: closed descriptor 7\n"
    ),
    "unsafe": "Initial value: 0\nAfter unsafe write: 42\n",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT / "build-output" / "demos" / "demo-report.json",
    )
    parser.add_argument(
        "--check-only",
        action="store_true",
        help="build every demo without executing it",
    )
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    report_path = args.report.resolve()
    output_directory = report_path.parent / "executables"
    output_directory.mkdir(parents=True, exist_ok=True)
    results = []
    for name, expected_stdout in CASES.items():
        project = ROOT / "demos" / name / "openc.project.json"
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
        run_command = [str(executable)]
        executed = (
            subprocess.run(
                run_command, cwd=ROOT, text=True, capture_output=True
            )
            if not args.check_only
            and built.returncode == 0
            and executable.is_file()
            else None
        )
        passed = built.returncode == 0 and (
            args.check_only
            or (
                executed is not None
                and executed.returncode == 0
                and executed.stdout == expected_stdout
            )
        )
        results.append(
            {
                "demo": name,
                "build_command": build_command,
                "build_exit_code": built.returncode,
                "build_stdout": built.stdout,
                "build_stderr": built.stderr,
                "run_command": run_command if not args.check_only else None,
                "run_exit_code": executed.returncode if executed else None,
                "expected_stdout": expected_stdout if not args.check_only else None,
                "stdout": executed.stdout if executed else None,
                "stderr": executed.stderr if executed else None,
                "passed": passed,
            }
        )
        print(f"{name}: {'PASS' if passed else 'FAIL'}")
    report = {
        "schema": "openc.demo_execution.v1",
        "status": "PASS" if all(item["passed"] for item in results) else "FAIL",
        "mode": "CHECK_ONLY" if args.check_only else "BUILD_AND_EXECUTE",
        "compiler_under_test": {
            **native,
            "implementation_language": "OpenC",
        },
        "retained_d_seed_executed": False,
        "total": len(results),
        "passed": sum(item["passed"] for item in results),
        "failed": sum(not item["passed"] for item in results),
        "results": results,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"demos: {report['passed']}/{report['total']} passed; report={report_path}"
    )
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
