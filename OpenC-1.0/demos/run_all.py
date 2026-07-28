#!/usr/bin/env python3
"""Check or run every OpenC demo through the public native CLI."""
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
    results = []
    for name, expected_stdout in CASES.items():
        project = ROOT / "demos" / name / "openc.project.json"
        command = [
            str(compiler),
            "check" if args.check_only else "run",
            f"--project={project.resolve()}",
        ]
        completed = subprocess.run(
            command, cwd=ROOT, text=True, capture_output=True
        )
        passed = completed.returncode == 0 and (
            (args.check_only and completed.stdout == "OpenC check: PASS\n")
            or (not args.check_only and completed.stdout == expected_stdout)
        )
        results.append(
            {
                "demo": name,
                "public_cli_command": command,
                "command": "check" if args.check_only else "run",
                "exit_code": completed.returncode,
                "expected_stdout": expected_stdout if not args.check_only else None,
                "stdout": completed.stdout,
                "stderr": completed.stderr,
                "passed": passed,
            }
        )
        print(f"{name}: {'PASS' if passed else 'FAIL'}")
    report = {
        "schema": "openc.demo_execution.v1",
        "status": "PASS" if all(item["passed"] for item in results) else "FAIL",
        "mode": "PUBLIC_CHECK" if args.check_only else "PUBLIC_RUN",
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
