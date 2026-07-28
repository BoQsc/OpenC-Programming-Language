#!/usr/bin/env python3
"""Measure and budget the OpenC-native complete conformance validation path."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from native_toolchain import resolve_native_compiler, validate_native_compiler
from performance_budget import load_budget, measurement_checks
from windows_process_measure import run_measured


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if os.name != "nt":
        raise SystemExit("native validation measurement is Windows-only")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "conformance" / "fixtures" / "MANIFEST.json",
    )
    parser.add_argument(
        "--conformance-report",
        type=Path,
        default=ROOT
        / "build-output"
        / "performance"
        / "native-validation"
        / "conformance-report.json",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT
        / "build-output"
        / "performance"
        / "native-validation"
        / "measurement.json",
    )
    parser.add_argument(
        "--budget",
        type=Path,
        default=ROOT / "compiler" / "selfhost" / "WINDOWS_NATIVE_BUDGETS.json",
    )
    parser.add_argument("--no-budget", action="store_true")
    parser.add_argument("--sample-interval", type=float, default=0.05)
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    manifest = args.manifest.resolve()
    conformance_report = args.conformance_report.resolve()
    report = args.report.resolve()
    if not manifest.is_file():
        raise SystemExit(f"missing conformance manifest: {manifest}")
    conformance_report.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(compiler),
        "validate",
        f"--manifest={manifest}",
        f"--output={conformance_report}",
    ]
    started_at = datetime.now(timezone.utc)
    measured = run_measured(
        command,
        cwd=ROOT,
        sample_interval=args.sample_interval,
    )
    conformance = (
        json.loads(conformance_report.read_text(encoding="utf-8"))
        if conformance_report.is_file()
        else {}
    )
    conformance_checks = {
        "native_result_schema": conformance.get("schema")
        == "openc.conformance_result.v2",
        "executed_native": conformance.get("evidence_state") == "EXECUTED_NATIVE",
        "fixtures_278_of_278": (
            conformance.get("total") == 278
            and conformance.get("passed") == 278
            and conformance.get("failed") == 0
            and conformance.get("infrastructure_failures") == 0
        ),
    }
    budget_document = None
    budget = None
    budget_checks: dict[str, bool] = {}
    if not args.no_budget:
        budget_document, budget = load_budget(args.budget.resolve(), "validation")
        budget_checks = measurement_checks(measured, budget)
    checks = {**conformance_checks, **budget_checks}
    status = "PASS" if measured["exit_code"] == 0 and all(checks.values()) else "FAIL"
    result = {
        "schema": "openc.native_validation_measurement.v1",
        "status": status,
        "measured_at_utc": started_at.isoformat().replace("+00:00", "Z"),
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
        },
        "native_compiler": native,
        "command": command,
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
        "conformance": {
            "report": str(conformance_report),
            "report_sha256": (
                sha256(conformance_report) if conformance_report.is_file() else None
            ),
            "total": conformance.get("total"),
            "passed": conformance.get("passed"),
            "failed": conformance.get("failed"),
            "infrastructure_failures": conformance.get("infrastructure_failures"),
        },
        "budget": budget,
        "budget_schema": budget_document.get("schema") if budget_document else None,
        "checks": checks,
        "retained_d_seed_executed": False,
    }
    report.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"native validation benchmark: {status}; "
        f"elapsed={result['measurement']['elapsed_seconds']}s "
        f"private={result['measurement']['peak_private_bytes']} "
        f"conformance={conformance.get('passed')}/{conformance.get('total')} "
        f"report={report}"
    )
    if status != "PASS":
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("native validation benchmark failed: " + ", ".join(failed))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
