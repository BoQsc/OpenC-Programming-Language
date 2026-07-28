#!/usr/bin/env python3
"""SH-10 native-first Windows development and verification workflow."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

from native_toolchain import (
    ROOT,
    compiler_source_fingerprint,
    digest_paths,
    installed_provenance,
    resolve_native_compiler,
    validate_native_compiler,
)


FIXTURE_COUNT = 278
DEFAULT_OUTPUT = ROOT / "build-output" / "windows-native-workflow"
BUDGET_PATH = ROOT / "compiler" / "selfhost" / "WINDOWS_NATIVE_BUDGETS.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_task(name: str, command: list[str], output: Path) -> dict[str, object]:
    started = time.perf_counter()
    completed = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    elapsed = round(time.perf_counter() - started, 3)
    record = {
        "name": name,
        "command": command,
        "exit_code": completed.returncode,
        "elapsed_seconds": elapsed,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "passed": completed.returncode == 0,
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / f"{name}.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"{name}: {'PASS' if record['passed'] else 'FAIL'} ({elapsed}s)")
    if completed.returncode != 0:
        if completed.stdout:
            print(completed.stdout, end="")
        if completed.stderr:
            print(completed.stderr, end="", file=sys.stderr)
    return record


def conformance_fingerprint(compiler: Path) -> str:
    return digest_paths(
        ROOT,
        [
            compiler,
            ROOT / "conformance" / "fixtures",
            ROOT / "runtime" / "common" / "source",
            ROOT / "runtime" / "windows" / "source",
            ROOT / "compiler" / "selfhost" / "native_runtime",
            ROOT / "third_party" / "tinycc-win64" / "tcc.exe",
        ],
    )


def valid_conformance_report(path: Path) -> bool:
    if not path.is_file():
        return False
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return (
        report.get("schema") == "openc.conformance_result.v2"
        and report.get("evidence_state") == "EXECUTED_NATIVE"
        and report.get("total") == FIXTURE_COUNT
        and report.get("passed") == FIXTURE_COUNT
        and report.get("failed") == 0
        and report.get("infrastructure_failures") == 0
    )


def load_budgets() -> dict:
    data = json.loads(BUDGET_PATH.read_text(encoding="utf-8"))
    if data.get("schema") != "openc.windows_native_performance_budgets.v1":
        raise SystemExit(f"invalid SH-8 budget schema: {BUDGET_PATH}")
    return data


def native_conformance(
    compiler: Path,
    output: Path,
    force: bool,
) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    cache_path = output / "conformance-cache.json"
    report_path = output / "conformance-report.json"
    fingerprint = conformance_fingerprint(compiler)
    cache = {}
    if cache_path.is_file():
        try:
            cache = json.loads(cache_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            cache = {}
    started = time.perf_counter()
    cache_hit = (
        not force
        and cache.get("fingerprint") == fingerprint
        and cache.get("status") == "PASS"
        and valid_conformance_report(report_path)
        and cache.get("report_sha256") == sha256(report_path)
    )
    command = [
        str(compiler),
        "validate",
        f"--manifest={ROOT / 'conformance' / 'fixtures' / 'MANIFEST.json'}",
        f"--output={report_path}",
    ]
    completed = None
    if not cache_hit:
        completed = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            encoding="utf-8",
        )
    elapsed = round(time.perf_counter() - started, 3)
    passed = (
        (cache_hit or (completed is not None and completed.returncode == 0))
        and valid_conformance_report(report_path)
    )
    budget = load_budgets()["budgets"]["daily_cache_hit"]
    cache_budget_passed = (
        not cache_hit
        or elapsed <= float(budget["max_elapsed_seconds"])
    )
    passed = passed and cache_budget_passed
    record = {
        "name": "native_conformance",
        "command": command,
        "exit_code": 0 if cache_hit else completed.returncode,
        "elapsed_seconds": elapsed,
        "execution": "CACHE_HIT" if cache_hit else "EXECUTED_NATIVE",
        "fixtures_executed": 0 if cache_hit else FIXTURE_COUNT,
        "fingerprint": fingerprint,
        "report": str(report_path),
        "report_sha256": sha256(report_path) if report_path.is_file() else None,
        "cache_hit_budget": budget,
        "cache_hit_budget_passed": cache_budget_passed,
        "stdout": "" if cache_hit else completed.stdout,
        "stderr": "" if cache_hit else completed.stderr,
        "passed": passed,
        "retained_d_seed_executed": False,
    }
    if passed:
        cache_path.write_text(
            json.dumps(
                {
                    "schema": "openc.native_conformance_cache.v1",
                    "status": "PASS",
                    "fingerprint": fingerprint,
                    "report_sha256": record["report_sha256"],
                    "fixture_count": FIXTURE_COUNT,
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
    (output / "native_conformance.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        "native_conformance: "
        f"{'PASS' if passed else 'FAIL'} "
        f"({record['execution']}, {elapsed}s, "
        f"fixtures_executed={record['fixtures_executed']})"
    )
    if completed is not None and completed.returncode != 0:
        print(completed.stdout, end="")
        print(completed.stderr, end="", file=sys.stderr)
    return record


def update_cache_from_benchmark(output: Path, benchmark_report: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    measurement = json.loads(benchmark_report.read_text(encoding="utf-8"))
    source_report = Path(measurement["conformance"]["report"])
    target_report = output / "conformance-report.json"
    shutil.copyfile(source_report, target_report)
    compiler = Path(measurement["native_compiler"]["compiler"])
    fingerprint = conformance_fingerprint(compiler)
    (output / "conformance-cache.json").write_text(
        json.dumps(
            {
                "schema": "openc.native_conformance_cache.v1",
                "status": "PASS",
                "fingerprint": fingerprint,
                "report_sha256": sha256(target_report),
                "fixture_count": FIXTURE_COUNT,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )


def audit_seed(args: argparse.Namespace, compiler: Path, output: Path) -> int:
    seed = args.seed.resolve()
    if not seed.is_file():
        raise SystemExit(f"missing retained D seed: {seed}")
    tasks = []
    for script in (
        "semantic_declaration_parity.py",
        "semantic_resolution_parity.py",
        "semantic_flow_safety_parity.py",
        "semantic_ir_parity.py",
    ):
        name = f"audit_{Path(script).stem}"
        command = [
            sys.executable,
            str(ROOT / "compiler" / "selfhost" / script),
            "--stage0",
            str(seed),
            "--stage1",
            str(compiler),
            "--output",
            str(output / name),
        ]
        tasks.append(run_task(name, command, output / "tasks"))
    report = {
        "schema": "openc.optional_d_seed_audit.v1",
        "status": "PASS" if all(task["passed"] for task in tasks) else "FAIL",
        "required_by_daily_or_release": False,
        "retained_d_seed_executed": True,
        "seed": str(seed),
        "native_compiler": str(compiler),
        "tasks": tasks,
    }
    output.mkdir(parents=True, exist_ok=True)
    (output / "optional-seed-audit.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(f"optional D-seed audit: {report['status']}")
    return 0 if report["status"] == "PASS" else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("daily", "full", "audit-seed"))
    parser.add_argument("--compiler", type=Path)
    parser.add_argument(
        "--seed",
        type=Path,
        default=ROOT / "compiler" / "openc.exe",
        help="used only by the explicit audit-seed mode",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--force-conformance", action="store_true")
    parser.add_argument("--sample-interval", type=float, default=0.05)
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    provenance = installed_provenance(compiler)
    current_fingerprint = compiler_source_fingerprint(ROOT)
    if provenance.get("compiler_source_fingerprint") != current_fingerprint:
        raise SystemExit(
            "the native toolchain does not match the current compiler source. "
            "Rebuild closure and install its Stage-3 distribution before testing."
        )
    output = args.output.resolve()
    if args.mode == "audit-seed":
        return audit_seed(args, compiler, output / "audit-seed")

    output.mkdir(parents=True, exist_ok=True)
    task_output = output / "tasks"
    started_at = datetime.now(timezone.utc)
    started = time.perf_counter()
    tasks = []
    commands = (
        (
            "native_plan",
            [
                sys.executable,
                str(ROOT / "scripts" / "generate_native_conformance_plan.py"),
                "--check",
            ],
        ),
        (
            "structure",
            [sys.executable, str(ROOT / "scripts" / "validate_structure.py")],
        ),
        (
            "source_completeness",
            [sys.executable, str(ROOT / "scripts" / "source_completeness.py")],
        ),
        (
            "coverage",
            [
                sys.executable,
                str(ROOT / "scripts" / "complete_conformance_coverage.py"),
                "--check",
            ],
        ),
        (
            "python_source_tests",
            [
                sys.executable,
                "-m",
                "unittest",
                "discover",
                "-s",
                "tests/python",
                "-p",
                "test_*.py",
            ],
        ),
    )
    for name, command in commands:
        tasks.append(run_task(name, command, task_output))

    performance: dict[str, object] = {}
    if args.mode == "full":
        validation_report = output / "performance" / "validation-measurement.json"
        validation_conformance = (
            output / "performance" / "validation-conformance-report.json"
        )
        validation = run_task(
            "budgeted_native_validation",
            [
                sys.executable,
                str(
                    ROOT
                    / "compiler"
                    / "selfhost"
                    / "benchmark_windows_validate.py"
                ),
                "--compiler",
                str(compiler),
                "--conformance-report",
                str(validation_conformance),
                "--report",
                str(validation_report),
                "--sample-interval",
                str(args.sample_interval),
            ],
            task_output,
        )
        tasks.append(validation)
        if validation["passed"]:
            update_cache_from_benchmark(output, validation_report)
            performance["validation"] = json.loads(
                validation_report.read_text(encoding="utf-8")
            )
        rebuild_report = output / "performance" / "rebuild-measurement.json"
        rebuild_output = output / "performance" / "self-rebuild" / "openc.exe"
        rebuild = run_task(
            "budgeted_native_self_rebuild",
            [
                sys.executable,
                str(
                    ROOT
                    / "compiler"
                    / "selfhost"
                    / "benchmark_windows_rebuild.py"
                ),
                "--compiler",
                str(compiler),
                "--output",
                str(rebuild_output),
                "--report",
                str(rebuild_report),
                "--sample-interval",
                str(args.sample_interval),
            ],
            task_output,
        )
        tasks.append(rebuild)
        if rebuild["passed"]:
            performance["self_rebuild"] = json.loads(
                rebuild_report.read_text(encoding="utf-8")
            )
    else:
        tasks.append(
            native_conformance(
                compiler,
                output,
                force=args.force_conformance,
            )
        )

    maintained_report = output / "maintained-program-report.json"
    tasks.append(
        run_task(
            "native_cli",
            [
                sys.executable,
                str(ROOT / "scripts" / "verify_sh9_cli.py"),
                "--compiler",
                str(compiler),
                "--output",
                str(output / "native-cli"),
            ],
            task_output,
        )
    )
    tasks.append(
        run_task(
            "native_project_workflow",
            [
                sys.executable,
                str(ROOT / "scripts" / "verify_sh10_project_workflow.py"),
                "--compiler",
                str(compiler),
                "--output",
                str(output / "native-project-workflow"),
            ],
            task_output,
        )
    )
    tasks.append(
        run_task(
            "maintained_programs",
            [
                sys.executable,
                str(ROOT / "tests" / "run_maintained.py"),
                "--compiler",
                str(compiler),
                "--report",
                str(maintained_report),
            ],
            task_output,
        )
    )
    demo_report = output / "demo-report.json"
    tasks.append(
        run_task(
            "demos",
            [
                sys.executable,
                str(ROOT / "demos" / "run_all.py"),
                "--compiler",
                str(compiler),
                "--report",
                str(demo_report),
            ],
            task_output,
        )
    )
    passed = all(task["passed"] for task in tasks)
    result = {
        "schema": "openc.windows_native_workflow.v3",
        "milestone": "SH-10_NATIVE_PROJECT_WORKFLOW_COMPLETENESS",
        "mode": args.mode.upper(),
        "status": "PASS" if passed else "FAIL",
        "started_at_utc": started_at.isoformat().replace("+00:00", "Z"),
        "elapsed_seconds": round(time.perf_counter() - started, 3),
        "compiler_under_test": {
            **native,
            "implementation_language": "OpenC",
            "source_fingerprint": current_fingerprint,
        },
        "toolchain_provenance": provenance,
        "tasks": tasks,
        "performance": performance,
        "required_d_seed": False,
        "retained_d_seed_executed": False,
        "linux_and_freestanding_gate": False,
    }
    result_path = output / f"{args.mode}-workflow-result.json"
    result_path.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"SH-10 {args.mode} workflow: {result['status']}; "
        f"compiler=OpenC-native tasks={sum(task['passed'] for task in tasks)}/"
        f"{len(tasks)} seed_executed=false result={result_path}"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
