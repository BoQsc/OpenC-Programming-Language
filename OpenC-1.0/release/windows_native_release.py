#!/usr/bin/env python3
"""Build and verify the complete SH-8 Windows-native release workflow."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from native_toolchain import resolve_native_compiler, validate_native_compiler


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name: str, command: list[str]) -> dict[str, object]:
    started = time.perf_counter()
    completed = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    result = {
        "name": name,
        "command": command,
        "exit_code": completed.returncode,
        "elapsed_seconds": round(time.perf_counter() - started, 3),
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "passed": completed.returncode == 0,
    }
    print(
        f"{name}: {'PASS' if result['passed'] else 'FAIL'} "
        f"({result['elapsed_seconds']}s)"
    )
    if completed.returncode != 0:
        if completed.stdout:
            print(completed.stdout, end="")
        if completed.stderr:
            print(completed.stderr, end="", file=sys.stderr)
    return result


def verifier_summary_checks(result: dict) -> dict[str, bool]:
    maintained = result.get("maintained_programs", [])
    return {
        "relocated_verifier_passed": result.get("status") == "PASS",
        "native_conformance_278": (
            result.get("conformance", {}).get("passed") == 278
            and result.get("conformance", {}).get("failed") == 0
        ),
        "maintained_programs_4": (
            len(maintained) == 4
            and all(item.get("passed") for item in maintained)
        ),
        "retained_d_seed_not_executed": (
            result.get("environment", {}).get("retained_d_seed_executed")
            is False
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "release-sh8",
    )
    parser.add_argument(
        "--verification-output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh8" / "release",
    )
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    output = args.output.resolve()
    verification_output = args.verification_output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    base = f"OpenC-{version}-sh8-windows-x86_64-standalone"
    archive_root = f"OpenC-{version}"
    archive_a = output / f"{base}-a.zip"
    archive_b = output / f"{base}-b.zip"
    tree_a = output / "a" / archive_root
    tree_b = output / "b" / archive_root
    force = ["--force"] if args.force else []
    tasks = []
    for suffix, tree, archive in (
        ("a", tree_a, archive_a),
        ("b", tree_b, archive_b),
    ):
        tasks.append(
            run(
                f"build_archive_{suffix}",
                [
                    sys.executable,
                    str(ROOT / "release" / "build_standalone_windows.py"),
                    "--compiler",
                    str(compiler),
                    "--version",
                    version,
                    "--output-tree",
                    str(tree),
                    "--archive",
                    str(archive),
                    *force,
                ],
            )
        )
        if not tasks[-1]["passed"]:
            break
    if len(tasks) == 2 and all(task["passed"] for task in tasks):
        tasks.append(
            run(
                "verify_relocated_release",
                [
                    sys.executable,
                    str(ROOT / "release" / "verify_standalone_windows.py"),
                    "--archive",
                    str(archive_a),
                    "--comparison-archive",
                    str(archive_b),
                    "--output",
                    str(verification_output),
                    *force,
                ],
            )
        )
    verifier_result_path = verification_output / "standalone-release-result.json"
    verifier_result = (
        json.loads(verifier_result_path.read_text(encoding="utf-8"))
        if verifier_result_path.is_file()
        else {}
    )
    checks = {
        "two_deterministic_archives_built": (
            archive_a.is_file() and archive_b.is_file()
        ),
        "archive_bytes_equal": (
            archive_a.is_file()
            and archive_b.is_file()
            and archive_a.read_bytes() == archive_b.read_bytes()
        ),
        **verifier_summary_checks(verifier_result),
    }
    passed = all(task["passed"] for task in tasks) and all(checks.values())
    result = {
        "schema": "openc.windows_native_release_workflow.v1",
        "milestone": "SH-8_NATIVE_DEVELOPER_AND_RELEASE_WORKFLOW",
        "status": "PASS" if passed else "FAIL",
        "completed_at_utc": datetime.now(timezone.utc)
        .isoformat()
        .replace("+00:00", "Z"),
        "native_compiler": native,
        "tasks": tasks,
        "checks": checks,
        "artifacts": {
            "archive_a": str(archive_a),
            "archive_b": str(archive_b),
            "archive_sha256": sha256(archive_a) if archive_a.is_file() else None,
            "archive_bytes_equal": checks["archive_bytes_equal"],
            "standalone_verifier_result": str(verifier_result_path),
        },
        "required_d_seed": False,
        "retained_d_seed_executed": False,
        "linux_and_freestanding_gate": False,
    }
    result_path = verification_output / "native-release-workflow-result.json"
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"SH-8 native release workflow: {result['status']}; "
        f"archive={result['artifacts']['archive_sha256']} "
        f"seed_executed=false result={result_path}"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
