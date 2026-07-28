#!/usr/bin/env python3
"""Measure a native OpenC compiler rebuilding the self-hosted compiler."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import sys

from performance_budget import load_budget, measurement_checks
from windows_process_measure import run_measured


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from native_toolchain import resolve_native_compiler


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def clean_child_environment(tcc: Path) -> tuple[dict[str, str], list[str]]:
    environment = os.environ.copy()
    system_root = Path(environment.get("SystemRoot", r"C:\Windows"))
    path_entries = [str(system_root / "System32"), str(tcc.parent)]
    environment["PATH"] = os.pathsep.join(path_entries)
    for name in (
        "DC",
        "DMD",
        "DUB",
        "DFLAGS",
        "PYTHONHOME",
        "PYTHONPATH",
        "VIRTUAL_ENV",
    ):
        environment.pop(name, None)
    return environment, path_entries


def main() -> int:
    if os.name != "nt":
        raise SystemExit("native self-rebuild measurement is Windows-only")

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--compiler",
        type=Path,
        help="verified OpenC-native compiler; defaults to the installed toolchain",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=ROOT / "compiler" / "selfhost" / "openc.project.json",
    )
    parser.add_argument(
        "--tcc",
        type=Path,
        default=ROOT / "third_party" / "tinycc-win64" / "tcc.exe",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT
        / "build-output"
        / "performance"
        / "native-self-rebuild"
        / "openc.exe",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT
        / "build-output"
        / "performance"
        / "native-self-rebuild"
        / "measurement.json",
    )
    parser.add_argument(
        "--budget",
        type=Path,
        default=ROOT / "compiler" / "selfhost" / "WINDOWS_NATIVE_BUDGETS.json",
    )
    parser.add_argument("--no-budget", action="store_true")
    parser.add_argument("--sample-interval", type=float, default=0.1)
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    project = args.project.resolve()
    tcc = args.tcc.resolve()
    output = args.output.resolve()
    report = args.report.resolve()
    for required in (compiler, project, tcc):
        if not required.is_file():
            raise SystemExit(f"missing required input: {required}")
    if args.sample_interval <= 0:
        raise SystemExit("--sample-interval must be positive")

    output.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    generated = Path(str(output) + ".openc.c")
    record = Path(str(output) + ".build.json")
    environment, child_path = clean_child_environment(tcc)
    command = [
        str(compiler),
        "--windows-build",
        str(project),
        str(output),
        str(generated),
        str(ROOT / "runtime"),
        str(ROOT / "compiler" / "selfhost" / "native_runtime"),
        str(record),
        str(tcc),
    ]

    started_at = datetime.now(timezone.utc)
    measured = run_measured(
        command,
        cwd=ROOT,
        environment=environment,
        sample_interval=args.sample_interval,
    )

    artifacts: dict[str, object] = {}
    for name, path in (
        ("compiler_input", compiler),
        ("project_input", project),
        ("output_executable", output),
        ("generated_c", generated),
        ("build_record", record),
    ):
        artifacts[name] = {
            "path": str(path),
            "present": path.is_file(),
            "bytes": path.stat().st_size if path.is_file() else 0,
            "sha256": sha256(path) if path.is_file() else None,
        }
    budget_document = None
    budget = None
    checks = {
        "output_executable_present": output.is_file(),
        "generated_c_present": generated.is_file(),
        "native_build_record_present": record.is_file(),
        "output_compiler_byte_equal_to_input": (
            output.is_file() and output.read_bytes() == compiler.read_bytes()
        ),
    }
    if not args.no_budget:
        budget_document, budget = load_budget(
            args.budget.resolve(), "self_rebuild"
        )
        checks.update(measurement_checks(measured, budget))
    status = (
        "PASS"
        if measured["exit_code"] == 0 and all(checks.values())
        else "FAIL"
    )
    result = {
        "schema": "openc.native_self_rebuild_measurement.v2",
        "status": status,
        "measured_at_utc": started_at.isoformat().replace("+00:00", "Z"),
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
        },
        "command": command,
        "environment": {
            "child_path": child_path,
            "dmd_available_to_native_build": False,
            "dub_available_to_native_build": False,
            "python_available_to_native_build": False,
        },
        "measurement": {
            key: value
            for key, value in measured.items()
            if key not in {"exit_code", "stdout", "stderr"}
        },
        "process": {
            "exit_code": measured["exit_code"],
            "stdout": measured["stdout"],
            "stderr": measured["stderr"],
        },
        "artifacts": artifacts,
        "budget": budget,
        "budget_schema": budget_document.get("schema") if budget_document else None,
        "checks": checks,
        "retained_d_seed_executed": False,
    }
    report.write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"native self-rebuild benchmark: {status}; "
        f"elapsed={result['measurement']['elapsed_seconds']}s "
        f"private={result['measurement']['peak_private_bytes']} "
        f"report={report}"
    )
    if status != "PASS":
        failed = [name for name, passed in checks.items() if not passed]
        if measured["stderr"]:
            print(measured["stderr"], end="", file=os.sys.stderr)
        raise SystemExit("native self-rebuild benchmark failed: " + ", ".join(failed))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
