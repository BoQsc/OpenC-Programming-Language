#!/usr/bin/env python3
"""Produce reproducible same-host OpenC/D clean-build comparison evidence."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
from typing import Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))
from windows_process_measure import run_measured


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "openc.throughput_suite.v1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_fingerprint(paths: Iterable[Path]) -> dict[str, object]:
    records: list[dict[str, object]] = []
    digest = hashlib.sha256()
    for path in sorted({item.resolve() for item in paths}, key=lambda item: str(item).lower()):
        relative = path.relative_to(ROOT).as_posix()
        content_hash = sha256(path)
        records.append({"path": relative, "bytes": path.stat().st_size, "sha256": content_hash})
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(content_hash.encode("ascii"))
        digest.update(b"\n")
    return {"sha256": digest.hexdigest(), "files": len(records), "records": records}


def command_version(command: list[str], cwd: Path) -> dict[str, object]:
    completed = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
    )
    return {
        "command": command,
        "exit_code": completed.returncode,
        "output": (completed.stdout + completed.stderr).strip(),
    }


def clean_native_environment(tcc: Path) -> tuple[dict[str, str], list[str]]:
    environment = os.environ.copy()
    system_root = Path(environment.get("SystemRoot", r"C:\Windows"))
    path_entries = [str(system_root / "System32"), str(tcc.parent)]
    environment["PATH"] = os.pathsep.join(path_entries)
    for name in ("DC", "DMD", "DUB", "DFLAGS", "PYTHONHOME", "PYTHONPATH", "VIRTUAL_ENV"):
        environment.pop(name, None)
    return environment, path_entries


def summarize(samples: list[dict[str, object]]) -> dict[str, object]:
    elapsed = [float(sample["elapsed_seconds"]) for sample in samples]
    return {
        "runs": len(samples),
        "minimum_seconds": round(min(elapsed), 3),
        "median_seconds": round(statistics.median(elapsed), 3),
        "maximum_seconds": round(max(elapsed), 3),
        "raw_seconds": elapsed,
    }


def evaluate(
    openc_summary: dict[str, object],
    d_summary: dict[str, object],
    *,
    median_limit: float,
    every_limit: float,
    ratio_limit: float,
) -> dict[str, bool]:
    openc_median = float(openc_summary["median_seconds"])
    d_median = float(d_summary["median_seconds"])
    return {
        "openc_clean_median_within_absolute_gate": openc_median <= median_limit,
        "every_openc_clean_run_within_absolute_gate": (
            float(openc_summary["maximum_seconds"]) <= every_limit
        ),
        "openc_median_within_d_ratio_gate": (
            d_median > 0 and openc_median / d_median <= ratio_limit
        ),
    }


def measured_sample(
    command: list[str],
    *,
    cwd: Path,
    environment: dict[str, str] | None,
    sample_interval: float,
) -> dict[str, object]:
    measured = run_measured(
        command,
        cwd=cwd,
        environment=environment,
        sample_interval=sample_interval,
    )
    return {
        key: value
        for key, value in measured.items()
        if key not in {"stdout", "stderr"}
    } | {
        "stdout": str(measured["stdout"]),
        "stderr": str(measured["stderr"]),
    }


def main() -> int:
    if os.name != "nt":
        raise SystemExit("the SH-14 same-host suite currently requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
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
    parser.add_argument("--dub", default="dub")
    parser.add_argument("--d-root", type=Path, default=ROOT / "compiler")
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh14" / "throughput-suite.json",
    )
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--sample-interval", type=float, default=0.05)
    parser.add_argument("--median-limit", type=float, default=30.0)
    parser.add_argument("--every-limit", type=float, default=45.0)
    parser.add_argument("--ratio-limit", type=float, default=1.25)
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()
    if args.runs < 1 or args.sample_interval <= 0:
        raise SystemExit("--runs and --sample-interval must be positive")

    compiler = args.compiler.resolve()
    project = args.project.resolve()
    tcc = args.tcc.resolve()
    d_root = args.d_root.resolve()
    output = args.output.resolve()
    dub = shutil.which(args.dub)
    for required in (compiler, project, tcc, d_root / "dub.json"):
        if not required.is_file():
            raise SystemExit(f"missing required input: {required}")
    if dub is None:
        raise SystemExit(f"D comparator executable not found: {args.dub}")

    run_stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_root = output.parent / f"{output.stem}-runs-{run_stamp}"
    run_root.mkdir(parents=True, exist_ok=True)
    native_environment, native_path = clean_native_environment(tcc)
    openc_samples: list[dict[str, object]] = []
    d_samples: list[dict[str, object]] = []
    for run in range(args.runs):
        directory = run_root / f"openc-{run + 1:02d}"
        directory.mkdir(parents=True, exist_ok=False)
        executable = directory / "openc.exe"
        generated = Path(str(executable) + ".openc.c")
        record = Path(str(executable) + ".build.json")
        command = [
            str(compiler),
            "--windows-build",
            str(project),
            str(executable),
            str(generated),
            str(ROOT / "runtime"),
            str(ROOT / "compiler" / "selfhost" / "native_runtime"),
            str(record),
            str(tcc),
        ]
        sample = measured_sample(
            command,
            cwd=ROOT,
            environment=native_environment,
            sample_interval=args.sample_interval,
        )
        sample["run"] = run + 1
        sample["command"] = command
        sample["output_sha256"] = sha256(executable) if executable.is_file() else None
        sample["generated_sha256"] = sha256(generated) if generated.is_file() else None
        openc_samples.append(sample)
        if int(sample["exit_code"]) != 0:
            break

    for run in range(args.runs):
        command = [
            dub,
            "build",
            f"--root={d_root}",
            "--config=compiler",
            "--build=release",
            "--temp-build",
            "--force",
            "--non-interactive",
        ]
        sample = measured_sample(
            command,
            cwd=ROOT,
            environment=os.environ.copy(),
            sample_interval=args.sample_interval,
        )
        sample["run"] = run + 1
        sample["command"] = command
        d_samples.append(sample)
        if int(sample["exit_code"]) != 0:
            break

    commands_passed = (
        len(openc_samples) == args.runs
        and len(d_samples) == args.runs
        and all(int(sample["exit_code"]) == 0 for sample in openc_samples + d_samples)
    )
    openc_summary = summarize(openc_samples)
    d_summary = summarize(d_samples)
    gate_checks = evaluate(
        openc_summary,
        d_summary,
        median_limit=args.median_limit,
        every_limit=args.every_limit,
        ratio_limit=args.ratio_limit,
    )
    hashes = {sample["output_sha256"] for sample in openc_samples}
    generated_hashes = {sample["generated_sha256"] for sample in openc_samples}
    checks = {
        "all_commands_passed": commands_passed,
        "openc_outputs_byte_identical": len(hashes) == 1 and None not in hashes,
        "openc_generated_sources_byte_identical": (
            len(generated_hashes) == 1 and None not in generated_hashes
        ),
        **gate_checks,
    }
    status = "PASS" if all(checks.values()) else "BLOCKED"
    inputs = [project, *sorted((ROOT / "compiler" / "selfhost" / "source").glob("*.p"))]
    d_inputs = [
        *sorted((ROOT / "compiler" / "source").rglob("*.d")),
        *sorted((ROOT / "runtime").rglob("*.d")),
        *sorted((ROOT / "standard_library" / "source").rglob("*.d")),
        *sorted((ROOT / "tools" / "source").rglob("*.d")),
    ]
    result = {
        "schema": SCHEMA,
        "status": status,
        "measured_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "logical_cpus": os.cpu_count(),
        },
        "tools": {
            "openc": command_version([str(compiler), "version"], ROOT),
            "tinycc": command_version([str(tcc), "-v"], ROOT),
            "dub": command_version([dub, "--version"], ROOT),
        },
        "inputs": {
            "openc": tree_fingerprint(inputs),
            "d_reference": tree_fingerprint(d_inputs),
        },
        "environment": {"openc_child_path": native_path},
        "gates": {
            "clean_median_max_seconds": args.median_limit,
            "clean_each_run_max_seconds": args.every_limit,
            "relative_to_d_median_max": args.ratio_limit,
        },
        "lanes": {
            "openc_clean_self_rebuild": {"summary": openc_summary, "samples": openc_samples},
            "d_reference_forced_release": {"summary": d_summary, "samples": d_samples},
        },
        "checks": checks,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    ratio = float(openc_summary["median_seconds"]) / float(d_summary["median_seconds"])
    print(
        f"SH-14 throughput suite: {status}; "
        f"OpenC median={openc_summary['median_seconds']}s; "
        f"D median={d_summary['median_seconds']}s; ratio={ratio:.3f}; report={output}"
    )
    if not commands_passed:
        return 2
    if args.enforce and status != "PASS":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
