#!/usr/bin/env python3
"""Measure SH-20 native latency, resource, and 20-generation closure gates."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from windows_process_measure import run_measured


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "openc.sh20_native_stability.v1"
MIB = 1024 * 1024


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summary(samples: list[dict[str, object]]) -> dict[str, object]:
    elapsed = [float(sample["elapsed_seconds"]) for sample in samples]
    return {
        "runs": len(samples),
        "minimum_seconds": round(min(elapsed), 3),
        "median_seconds": round(statistics.median(elapsed), 3),
        "maximum_seconds": round(max(elapsed), 3),
        "raw_seconds": elapsed,
    }


def measured(
    command: list[str],
    *,
    sample_interval: float,
) -> dict[str, object]:
    return run_measured(
        command,
        cwd=ROOT,
        sample_interval=sample_interval,
        max_private_bytes=256 * MIB,
        max_working_set_bytes=64 * MIB,
        max_captured_output_bytes=4 * MIB,
    )


def command_version(compiler: Path) -> dict[str, object]:
    completed = subprocess.run(
        [str(compiler), "version"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return {
        "command": [str(compiler), "version"],
        "exit_code": completed.returncode,
        "output": (completed.stdout + completed.stderr).strip(),
    }


def public_build_command(
    compiler: Path,
    project: Path,
    executable: Path,
    timings: Path,
) -> list[str]:
    return [
        str(compiler),
        "build",
        f"--project={project}",
        f"--output={executable}",
        f"--timings={timings}",
    ]


def source_fingerprint(compiler: Path, project: Path, source: Path) -> str:
    digest = hashlib.sha256()
    for path in (compiler, project, source):
        digest.update(str(path.resolve()).encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\n")
    digest.update(b"target=windows-x86_64\nbackend=openc-native-pe32+\n")
    return digest.hexdigest()


def sample_passed(sample: dict[str, object]) -> bool:
    return (
        int(sample["exit_code"]) == 0
        and not bool(sample["memory_limit_exceeded"])
        and not bool(sample["stdout_truncated"])
        and not bool(sample["stderr_truncated"])
    )


def main() -> int:
    if os.name != "nt":
        raise SystemExit("the SH-20 native stability suite requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument(
        "--project",
        type=Path,
        default=ROOT / "compiler" / "selfhost" / "openc.project.json",
    )
    parser.add_argument(
        "--small-project",
        type=Path,
        default=ROOT / "demos" / "hello" / "openc.project.json",
    )
    parser.add_argument("--small-runs", type=int, default=5)
    parser.add_argument("--one-source-runs", type=int, default=5)
    parser.add_argument("--chain-runs", type=int, default=20)
    parser.add_argument("--sample-interval", type=float, default=0.05)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh20" / "stability.json",
    )
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()
    if min(args.small_runs, args.one_source_runs, args.chain_runs) < 1:
        raise SystemExit("all run counts must be positive")
    if args.sample_interval <= 0:
        raise SystemExit("--sample-interval must be positive")

    compiler = args.compiler.resolve()
    project = args.project.resolve()
    small_project = args.small_project.resolve()
    output = args.output.resolve()
    for required in (compiler, project, small_project):
        if not required.is_file():
            raise SystemExit(f"missing required input: {required}")

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_root = output.parent / f"{output.stem}-runs-{stamp}"
    run_root.mkdir(parents=True, exist_ok=False)

    small_samples: list[dict[str, object]] = []
    for run in range(args.small_runs):
        directory = run_root / "small" / f"run-{run + 1:02d}"
        directory.mkdir(parents=True, exist_ok=False)
        executable = directory / "hello.exe"
        timings = directory / "timings.json"
        command = public_build_command(compiler, small_project, executable, timings)
        sample = measured(command, sample_interval=args.sample_interval)
        sample |= {
            "run": run + 1,
            "command": command,
            "output_sha256": sha256(executable) if executable.is_file() else None,
            "timings": json.loads(timings.read_text(encoding="utf-8"))
            if timings.is_file()
            else None,
        }
        small_samples.append(sample)
        if not sample_passed(sample):
            break
    print(f"small clean builds: {len(small_samples)}/{args.small_runs}", flush=True)

    incremental = run_root / "one-source"
    incremental.mkdir(parents=True, exist_ok=False)
    incremental_project = incremental / "openc.project.json"
    incremental_source = incremental / "main.p"
    incremental_project.write_text(
        json.dumps(
            {
                "name": "sh20-one-source",
                "version": "1.0.0",
                "edition": "OpenC 1.0",
                "profile": "standard",
                "target": "windows-x86_64",
                "modules": {"sh20.main": ["main.p"]},
                "output_directory": "build",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    variants = (
        'import system.io;\n\ni32 main() { io.println("alpha"); return 0; }\n',
        'import system.io;\n\ni32 main() { io.println("bravo"); return 0; }\n',
    )
    incremental_source.write_text(variants[0], encoding="utf-8", newline="\n")
    warm_output = incremental / "warm.exe"
    warm_timings = incremental / "warm-timings.json"
    warm_command = public_build_command(
        compiler, incremental_project, warm_output, warm_timings
    )
    warm = measured(warm_command, sample_interval=args.sample_interval)
    warm["command"] = warm_command

    one_source_samples: list[dict[str, object]] = []
    fingerprint_outputs: dict[str, str] = {}
    prior_fingerprint = source_fingerprint(
        compiler, incremental_project, incremental_source
    )
    for run in range(args.one_source_runs):
        incremental_source.write_text(
            variants[(run + 1) % 2], encoding="utf-8", newline="\n"
        )
        fingerprint = source_fingerprint(
            compiler, incremental_project, incremental_source
        )
        executable = incremental / f"program-{run + 1:02d}.exe"
        timings = incremental / f"timings-{run + 1:02d}.json"
        command = public_build_command(
            compiler, incremental_project, executable, timings
        )
        sample = measured(command, sample_interval=args.sample_interval)
        output_hash = sha256(executable) if executable.is_file() else None
        previous_output = fingerprint_outputs.get(fingerprint)
        sample |= {
            "run": run + 1,
            "command": command,
            "changed_sources": ["main.p"],
            "previous_dependency_fingerprint": prior_fingerprint,
            "dependency_fingerprint": fingerprint,
            "fingerprint_changed": prior_fingerprint != fingerprint,
            "output_sha256": output_hash,
            "same_fingerprint_same_output": (
                output_hash is not None
                and (previous_output is None or previous_output == output_hash)
            ),
            "timings": json.loads(timings.read_text(encoding="utf-8"))
            if timings.is_file()
            else None,
        }
        if output_hash is not None:
            fingerprint_outputs[fingerprint] = output_hash
        one_source_samples.append(sample)
        prior_fingerprint = fingerprint
        if not sample_passed(sample):
            break
    print(
        f"changed one-source builds: {len(one_source_samples)}/{args.one_source_runs}",
        flush=True,
    )

    compiler_hash = sha256(compiler)
    chain_samples: list[dict[str, object]] = []
    chain_input = compiler
    for run in range(args.chain_runs):
        directory = run_root / "chain" / f"generation-{run + 1:02d}"
        directory.mkdir(parents=True, exist_ok=False)
        executable = directory / "openc.exe"
        timings = directory / "timings.json"
        command = public_build_command(
            chain_input, project, executable, timings
        )
        build_record = Path(str(executable) + ".build.json")
        sample = measured(command, sample_interval=args.sample_interval)
        output_hash = sha256(executable) if executable.is_file() else None
        sample |= {
            "run": run + 1,
            "generation": run + 1,
            "command": command,
            "input_sha256": sha256(chain_input),
            "output_sha256": output_hash,
            "output_bytes": executable.stat().st_size if executable.is_file() else None,
            "build_record": json.loads(build_record.read_text(encoding="utf-8"))
            if build_record.is_file()
            else None,
            "timings": json.loads(timings.read_text(encoding="utf-8"))
            if timings.is_file()
            else None,
        }
        chain_samples.append(sample)
        if not sample_passed(sample) or not executable.is_file():
            break
        chain_input = executable
        print(f"native chain: {run + 1}/{args.chain_runs}", flush=True)

    small_result = summary(small_samples)
    one_source_result = summary(one_source_samples)
    chain_result = summary(chain_samples)
    all_samples = [*small_samples, warm, *one_source_samples, *chain_samples]
    chain_hashes = {sample.get("output_sha256") for sample in chain_samples}
    checks = {
        "small_commands_passed": (
            len(small_samples) == args.small_runs
            and all(sample_passed(sample) for sample in small_samples)
        ),
        "small_median_at_most_500ms": (
            float(small_result["median_seconds"]) <= 0.5
        ),
        "one_source_warm_build_passed": sample_passed(warm),
        "one_source_commands_passed": (
            len(one_source_samples) == args.one_source_runs
            and all(sample_passed(sample) for sample in one_source_samples)
        ),
        "one_source_median_at_most_1s": (
            float(one_source_result["median_seconds"]) <= 1.0
        ),
        "one_source_fingerprint_changed": all(
            bool(sample["fingerprint_changed"]) for sample in one_source_samples
        ),
        "one_source_same_fingerprint_same_output": all(
            bool(sample["same_fingerprint_same_output"])
            for sample in one_source_samples
        ),
        "twenty_chained_native_rebuilds_passed": (
            args.chain_runs >= 20
            and len(chain_samples) == args.chain_runs
            and all(sample_passed(sample) for sample in chain_samples)
        ),
        "twenty_chained_outputs_close_exactly": chain_hashes == {compiler_hash},
        "twenty_chained_public_records_pass": all(
            isinstance(sample.get("build_record"), dict)
            and sample["build_record"].get("status") == "PASS"
            and sample["build_record"].get("backend") == "openc-x64-pe32"
            and sample["build_record"].get("tinycc_invoked") is False
            and sample["build_record"].get("dmd_invoked") is False
            and sample["build_record"].get("python_invoked") is False
            and sample["build_record"].get("external_assembler_invoked") is False
            and sample["build_record"].get("external_linker_invoked") is False
            for sample in chain_samples
        ),
        "all_runs_private_memory_at_most_256MiB": all(
            int(sample["peak_private_bytes"]) <= 256 * MIB
            for sample in all_samples
        ),
        "all_runs_working_set_at_most_64MiB": all(
            int(sample["peak_working_set_bytes"]) <= 64 * MIB
            for sample in all_samples
        ),
        "all_runs_output_capture_bounded": all(
            not bool(sample["stdout_truncated"])
            and not bool(sample["stderr_truncated"])
            for sample in all_samples
        ),
    }
    status = "PASS" if all(checks.values()) else "BLOCKED"
    result = {
        "schema": SCHEMA,
        "status": status,
        "measured_at_utc": datetime.now(timezone.utc)
        .isoformat()
        .replace("+00:00", "Z"),
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "logical_cpus": os.cpu_count(),
        },
        "tools": {"openc": command_version(compiler)},
        "inputs": {
            "compiler": str(compiler),
            "compiler_bytes": compiler.stat().st_size,
            "compiler_sha256": compiler_hash,
            "compiler_project": str(project),
            "small_project": str(small_project),
        },
        "guards": {
            "peak_private_max_bytes": 256 * MIB,
            "peak_working_set_max_bytes": 64 * MIB,
            "captured_output_max_bytes_per_stream": 4 * MIB,
        },
        "gates": {
            "small_clean_median_max_seconds": 0.5,
            "one_source_median_max_seconds": 1.0,
            "chained_native_rebuilds": 20,
        },
        "lanes": {
            "small_clean": {"summary": small_result, "samples": small_samples},
            "one_source": {
                "warm_build": warm,
                "summary": one_source_result,
                "samples": one_source_samples,
            },
            "native_chain": {"summary": chain_result, "samples": chain_samples},
        },
        "checks": checks,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"SH-20 native stability: {status}; "
        f"small median={small_result['median_seconds']}s; "
        f"one-source median={one_source_result['median_seconds']}s; "
        f"chain={len(chain_samples)}/{args.chain_runs}; report={output}",
        flush=True,
    )
    if args.enforce and status != "PASS":
        return 1
    return 0 if all(sample_passed(sample) for sample in all_samples) else 2


if __name__ == "__main__":
    raise SystemExit(main())
