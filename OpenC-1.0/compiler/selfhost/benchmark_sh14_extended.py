#!/usr/bin/env python3
"""Measure the remaining SH-14 small, rebuild, scaling, and soak gates."""
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
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchmark_throughput_suite import clean_native_environment, measured_sample, sha256


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "openc.sh14_extended_suite.v1"
SCALING_BYTES = (262144, 524288, 1048576, 2097152)


def summary(samples: list[dict[str, object]]) -> dict[str, object]:
    values = [float(sample["elapsed_seconds"]) for sample in samples]
    return {
        "runs": len(samples),
        "minimum_seconds": round(min(values), 3),
        "median_seconds": round(statistics.median(values), 3),
        "maximum_seconds": round(max(values), 3),
        "raw_seconds": values,
    }


def command_version(command: list[str]) -> dict[str, object]:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return {
        "command": command,
        "exit_code": completed.returncode,
        "output": (completed.stdout + completed.stderr).strip(),
    }


def dependency_fingerprint(
    compiler: Path,
    project: Path,
    sources: list[Path],
    tcc: Path,
) -> dict[str, object]:
    inputs = [
        compiler,
        project,
        *sources,
        ROOT / "runtime" / "common" / "source" / "openc_runtime.c",
        ROOT / "runtime" / "common" / "source" / "openc_runtime.h",
        ROOT / "runtime" / "windows" / "source" / "openc_platform_windows.c",
        ROOT / "compiler" / "selfhost" / "native_runtime" / "openc_sh5_runtime.c",
        ROOT / "compiler" / "selfhost" / "native_runtime" / "openc_sh5_runtime.h",
        tcc,
    ]
    records: list[dict[str, object]] = []
    digest = hashlib.sha256()
    for path in inputs:
        resolved = path.resolve()
        label = (
            resolved.relative_to(ROOT).as_posix()
            if resolved.is_relative_to(ROOT)
            else str(resolved)
        )
        value = sha256(resolved)
        records.append(
            {"path": label, "bytes": resolved.stat().st_size, "sha256": value}
        )
        digest.update(label.encode("utf-8"))
        digest.update(b"\0")
        digest.update(value.encode("ascii"))
        digest.update(b"\n")
    for value in (
        "target=windows-x86_64-hosted",
        "backend=c11-tinycc-win64",
        "profile=standard",
    ):
        digest.update(value.encode("ascii"))
        digest.update(b"\n")
    return {
        "schema": "openc.exact_dependency_fingerprint.v1",
        "sha256": digest.hexdigest(),
        "target": "windows-x86_64-hosted",
        "backend": "c11-tinycc-win64",
        "profile": "standard",
        "inputs": records,
    }


def public_build_command(
    compiler: Path,
    project: Path,
    executable: Path,
    timing: Path,
) -> list[str]:
    return [
        str(compiler),
        "build",
        f"--project={project}",
        f"--output={executable}",
        f"--timings={timing}",
    ]


def self_build_command(
    compiler: Path,
    project: Path,
    executable: Path,
    tcc: Path,
) -> list[str]:
    return [
        str(compiler),
        "--windows-build",
        str(project),
        str(executable),
        str(executable) + ".openc.c",
        str(ROOT / "runtime"),
        str(ROOT / "compiler" / "selfhost" / "native_runtime"),
        str(executable) + ".build.json",
        str(tcc),
    ]


def generate_scaling_project(directory: Path, source_bytes: int) -> Path:
    directory.mkdir(parents=True, exist_ok=False)
    source_count = 32
    base_size, extra = divmod(source_bytes, source_count)
    names: list[str] = []
    function_index = 0
    for source_index in range(source_count):
        target = base_size + (1 if source_index < extra else 0)
        name = f"source_{source_index:02d}.p"
        names.append(name)
        pieces: list[str] = []
        if source_index == 0:
            pieces.append("import system.io;\n\ni32 main() { io.println(\"scale\"); return 0; }\n")
        # Keep enough semantic/lowering work in each byte-sized workload that
        # process startup and the Windows timer quantum cannot dominate the
        # doubling ratios. The remaining bytes still exercise lexer throughput.
        function_count = max(1, target // 256)
        for _ in range(function_count):
            pieces.append(
                f"usize scale_{function_index:06d}(usize value) "
                "{ return value + 1; }\n"
            )
            function_index += 1
        content = "".join(pieces)
        if len(content.encode("ascii")) > target:
            raise RuntimeError(f"scaling source header exceeds target: {name}")
        remaining = target - len(content.encode("ascii"))
        if remaining == 1:
            content += "\n"
        elif remaining == 2:
            content += " \n"
        elif remaining >= 3:
            content += "//" + ("s" * (remaining - 3)) + "\n"
        path = directory / name
        path.write_text(content, encoding="ascii", newline="\n")
        if path.stat().st_size != target:
            raise RuntimeError(f"scaling source size drift: {path}")
    project = {
        "name": f"sh14-scale-{source_bytes}",
        "version": "1.0.0",
        "edition": "OpenC 1.0",
        "profile": "standard",
        "target": "windows-x86_64",
        "modules": {"scale.main": names},
        "output_directory": "build",
    }
    project_path = directory / "openc.project.json"
    project_path.write_text(
        json.dumps(project, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    return project_path


def host_preflight() -> dict[str, object]:
    try:
        import psutil

        samples = [psutil.cpu_percent(interval=0.2) for _ in range(10)]
        available = int(psutil.virtual_memory().available)
        return {
            "cpu_percent_samples": samples,
            "cpu_percent_median": statistics.median(samples),
            "available_memory_bytes": available,
            "passed": statistics.median(samples) <= 50.0 and available >= 536870912,
        }
    except Exception as error:
        return {"passed": False, "error": str(error)}


def main() -> int:
    if os.name != "nt":
        raise SystemExit("the SH-14 extended suite currently requires Windows")
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
    parser.add_argument(
        "--small-project",
        type=Path,
        default=ROOT / "demos" / "hello" / "openc.project.json",
    )
    parser.add_argument("--small-runs", type=int, default=5)
    parser.add_argument("--incremental-runs", type=int, default=5)
    parser.add_argument("--scaling-runs", type=int, default=3)
    parser.add_argument("--soak-runs", type=int, default=20)
    parser.add_argument(
        "--reuse-soak-report",
        type=Path,
        help="reuse a prior passing 20-run soak while rerunning latency lanes",
    )
    parser.add_argument("--sample-interval", type=float, default=0.05)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh14" / "extended-suite.json",
    )
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()
    if min(
        args.small_runs,
        args.incremental_runs,
        args.scaling_runs,
        args.soak_runs,
    ) < 1:
        raise SystemExit("all run counts must be positive")

    compiler = args.compiler.resolve()
    project = args.project.resolve()
    tcc = args.tcc.resolve()
    small_project = args.small_project.resolve()
    output = args.output.resolve()
    distribution_tcc = compiler.parent / "third_party" / "tinycc-win64" / "tcc.exe"
    for required in (compiler, project, tcc, small_project, distribution_tcc):
        if not required.is_file():
            raise SystemExit(f"missing required input: {required}")

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_root = output.parent / f"{output.stem}-runs-{stamp}"
    run_root.mkdir(parents=True, exist_ok=False)
    public_environment, public_path = clean_native_environment(distribution_tcc)
    native_environment, native_path = clean_native_environment(tcc)
    preflight = host_preflight()
    if args.enforce and not bool(preflight.get("passed")):
        raise SystemExit(
            "SH-14 host preflight rejected background contention: "
            + json.dumps(preflight, sort_keys=True)
        )

    small_samples: list[dict[str, object]] = []
    for run in range(args.small_runs):
        directory = run_root / "small" / f"run-{run + 1:02d}"
        directory.mkdir(parents=True, exist_ok=False)
        executable = directory / "hello.exe"
        command = public_build_command(
            compiler, small_project, executable, directory / "timings.json"
        )
        sample = measured_sample(
            command,
            cwd=ROOT,
            environment=public_environment,
            sample_interval=args.sample_interval,
        )
        sample |= {
            "run": run + 1,
            "command": command,
            "output_sha256": sha256(executable) if executable.is_file() else None,
        }
        small_samples.append(sample)
        if int(sample["exit_code"]) != 0:
            break
    print(f"small lane complete: {len(small_samples)}/{args.small_runs}", flush=True)

    incremental_root = run_root / "incremental"
    incremental_root.mkdir(parents=True, exist_ok=False)
    incremental_project = incremental_root / "openc.project.json"
    incremental_source = incremental_root / "main.p"
    incremental_project.write_text(
        json.dumps(
            {
                "name": "sh14-incremental",
                "version": "1.0.0",
                "edition": "OpenC 1.0",
                "profile": "standard",
                "target": "windows-x86_64",
                "modules": {"incremental.main": ["main.p"]},
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
    incremental_output = incremental_root / "program.exe"
    warm_command = public_build_command(
        compiler, incremental_project, incremental_output,
        incremental_root / "warm-timings.json",
    )
    warm = measured_sample(
        warm_command,
        cwd=ROOT,
        environment=public_environment,
        sample_interval=args.sample_interval,
    )
    incremental_samples: list[dict[str, object]] = []
    previous_fingerprint = dependency_fingerprint(
        compiler, incremental_project, [incremental_source], distribution_tcc
    )
    fingerprint_outputs: dict[str, str] = {}
    for run in range(args.incremental_runs):
        variant = variants[(run + 1) % 2]
        incremental_source.write_text(variant, encoding="utf-8", newline="\n")
        current_fingerprint = dependency_fingerprint(
            compiler, incremental_project, [incremental_source], distribution_tcc
        )
        command = public_build_command(
            compiler,
            incremental_project,
            incremental_output,
            incremental_root / f"timings-{run + 1:02d}.json",
        )
        sample = measured_sample(
            command,
            cwd=ROOT,
            environment=public_environment,
            sample_interval=args.sample_interval,
        )
        output_hash = sha256(incremental_output) if incremental_output.is_file() else None
        sample |= {
            "run": run + 1,
            "command": command,
            "changed_sources": ["main.p"],
            "previous_dependency_fingerprint": previous_fingerprint["sha256"],
            "dependency_fingerprint": current_fingerprint,
            "fingerprint_changed": (
                previous_fingerprint["sha256"] != current_fingerprint["sha256"]
            ),
            "output_sha256": output_hash,
        }
        if output_hash is not None:
            prior_output = fingerprint_outputs.get(str(current_fingerprint["sha256"]))
            sample["same_fingerprint_same_output"] = (
                prior_output is None or prior_output == output_hash
            )
            fingerprint_outputs[str(current_fingerprint["sha256"])] = output_hash
        incremental_samples.append(sample)
        previous_fingerprint = current_fingerprint
        if int(sample["exit_code"]) != 0:
            break
    print(
        f"one-source lane complete: {len(incremental_samples)}/{args.incremental_runs}",
        flush=True,
    )

    scaling_lanes: dict[str, dict[str, object]] = {}
    for source_bytes in SCALING_BYTES:
        workload = run_root / "scaling" / f"bytes-{source_bytes}"
        scaling_project = generate_scaling_project(workload, source_bytes)
        samples: list[dict[str, object]] = []
        for run in range(args.scaling_runs):
            directory = workload / "runs" / f"run-{run + 1:02d}"
            directory.mkdir(parents=True, exist_ok=False)
            executable = directory / "scale.exe"
            command = public_build_command(
                compiler, scaling_project, executable, directory / "timings.json"
            )
            sample = measured_sample(
                command,
                cwd=ROOT,
                environment=public_environment,
                sample_interval=args.sample_interval,
            )
            sample |= {"run": run + 1, "command": command}
            samples.append(sample)
            if int(sample["exit_code"]) != 0:
                break
        scaling_lanes[str(source_bytes)] = {
            "source_bytes": source_bytes,
            "source_files": 32,
            "summary": summary(samples),
            "samples": samples,
        }
        print(
            f"scaling {source_bytes} bytes complete: {len(samples)}/{args.scaling_runs}",
            flush=True,
        )

    compiler_hash = sha256(compiler)
    soak_samples: list[dict[str, object]] = []
    reused_soak: dict[str, object] | None = None
    if args.reuse_soak_report is not None:
        reuse_path = args.reuse_soak_report.resolve()
        reused_soak = json.loads(reuse_path.read_text(encoding="utf-8"))
        if reused_soak.get("schema") != SCHEMA:
            raise SystemExit(f"incompatible soak report: {reuse_path}")
        reuse_checks = reused_soak.get("checks", {})
        required_reuse_checks = (
            "host_preflight_not_contended",
            "soak_20_consecutive_passed",
            "soak_executable_closure",
            "soak_generated_source_closure",
            "soak_private_memory_at_most_256MiB",
            "soak_working_set_at_most_32MiB",
            "backend_attribution_present",
        )
        if not all(bool(reuse_checks.get(name)) for name in required_reuse_checks):
            raise SystemExit(f"reused soak report does not pass its gates: {reuse_path}")
        soak_samples = list(reused_soak["lanes"]["closure_soak"]["samples"])
        print(f"reused passing soak: {len(soak_samples)} runs from {reuse_path}", flush=True)
    else:
        soak_input = compiler
        for run in range(args.soak_runs):
            directory = run_root / "soak" / f"run-{run + 1:02d}"
            directory.mkdir(parents=True, exist_ok=False)
            executable = directory / "openc.exe"
            generated = Path(str(executable) + ".openc.c")
            command = self_build_command(soak_input, project, executable, tcc)
            sample = measured_sample(
                command,
                cwd=ROOT,
                environment=native_environment,
                sample_interval=args.sample_interval,
            )
            sample |= {
                "run": run + 1,
                "command": command,
                "input_sha256": sha256(soak_input),
                "output_sha256": sha256(executable) if executable.is_file() else None,
                "generated_sha256": sha256(generated) if generated.is_file() else None,
            }
            soak_samples.append(sample)
            if int(sample["exit_code"]) != 0 or not executable.is_file():
                break
            soak_input = executable
            print(f"soak {run + 1}/{args.soak_runs}", flush=True)

    small_summary = summary(small_samples)
    incremental_summary = summary(incremental_samples)
    scaling_ratios: list[dict[str, object]] = []
    previous_size: int | None = None
    previous_median: float | None = None
    for source_bytes in SCALING_BYTES:
        median = float(scaling_lanes[str(source_bytes)]["summary"]["median_seconds"])
        if previous_size is not None and previous_median is not None:
            scaling_ratios.append(
                {
                    "from_source_bytes": previous_size,
                    "to_source_bytes": source_bytes,
                    "ratio": round(median / previous_median, 3),
                }
            )
        previous_size = source_bytes
        previous_median = median

    soak_output_hashes = {sample.get("output_sha256") for sample in soak_samples}
    soak_generated_hashes = {sample.get("generated_sha256") for sample in soak_samples}
    timing_record = run_root / "soak" / "run-01" / "openc-build.timings.json"
    if reused_soak is not None:
        timing = dict(reused_soak["lanes"]["backend_attribution"])
    else:
        timing = json.loads(timing_record.read_text(encoding="utf-8")) if timing_record.is_file() else {}
    phases = timing.get("phases_ms", {})
    owned = timing.get("compiler_owned", {})
    checks = {
        "host_preflight_not_contended": bool(preflight.get("passed")),
        "small_all_commands_passed": (
            len(small_samples) == args.small_runs
            and all(int(sample["exit_code"]) == 0 for sample in small_samples)
        ),
        "small_median_at_most_250ms": float(small_summary["median_seconds"]) <= 0.250,
        "small_each_at_most_500ms": float(small_summary["maximum_seconds"]) <= 0.500,
        "incremental_warm_build_passed": int(warm["exit_code"]) == 0,
        "incremental_all_commands_passed": (
            len(incremental_samples) == args.incremental_runs
            and all(int(sample["exit_code"]) == 0 for sample in incremental_samples)
        ),
        "incremental_median_at_most_1s": (
            float(incremental_summary["median_seconds"]) <= 1.0
        ),
        "incremental_exact_fingerprints_changed": all(
            bool(sample.get("fingerprint_changed")) for sample in incremental_samples
        ),
        "incremental_same_fingerprint_same_output": all(
            bool(sample.get("same_fingerprint_same_output"))
            for sample in incremental_samples
        ),
        "scaling_all_commands_passed": all(
            len(lane["samples"]) == args.scaling_runs
            and all(int(sample["exit_code"]) == 0 for sample in lane["samples"])
            for lane in scaling_lanes.values()
        ),
        "scaling_each_doubling_at_most_2_4x": all(
            float(record["ratio"]) <= 2.4 for record in scaling_ratios
        ),
        "soak_20_consecutive_passed": (
            len(soak_samples) == args.soak_runs
            and args.soak_runs >= 20
            and all(int(sample["exit_code"]) == 0 for sample in soak_samples)
        ),
        "soak_executable_closure": soak_output_hashes == {compiler_hash},
        "soak_generated_source_closure": (
            len(soak_generated_hashes) == 1 and None not in soak_generated_hashes
        ),
        "soak_private_memory_at_most_256MiB": all(
            int(sample["peak_private_bytes"]) <= 268435456 for sample in soak_samples
        ),
        "soak_working_set_at_most_32MiB": all(
            int(sample["peak_working_set_bytes"]) <= 33554432 for sample in soak_samples
        ),
        "backend_attribution_present": (
            all(name in phases for name in ("project_load", "declarations", "resolution", "lowering_and_c_emission", "tinycc"))
            and all(name in owned for name in ("lex_parse_ms", "index_ms", "ir_lower_ms", "c_emit_ms"))
        ),
    }
    status = "PASS" if all(checks.values()) else "BLOCKED"
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
            "preflight": preflight,
        },
        "tools": {
            "openc": command_version([str(compiler), "version"]),
            "tinycc": command_version([str(tcc), "-v"]),
        },
        "environment": {
            "public_child_path": public_path,
            "native_child_path": native_path,
        },
        "gates": {
            "small_median_max_seconds": 0.250,
            "small_each_max_seconds": 0.500,
            "one_source_median_max_seconds": 1.0,
            "scaling_doubling_max_ratio": 2.4,
            "soak_required_runs": 20,
            "peak_private_max_bytes": 268435456,
            "peak_working_set_max_bytes": 33554432,
        },
        "lanes": {
            "small_clean_build": {"summary": small_summary, "samples": small_samples},
            "one_source_rebuild": {
                "warm_build": warm,
                "summary": incremental_summary,
                "samples": incremental_samples,
            },
            "scaling": {"workloads": scaling_lanes, "doubling_ratios": scaling_ratios},
            "closure_soak": {"summary": summary(soak_samples), "samples": soak_samples},
            "backend_attribution": timing,
        },
        "reused_soak_report": (
            str(args.reuse_soak_report.resolve())
            if args.reuse_soak_report is not None
            else None
        ),
        "checks": checks,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(
        f"SH-14 extended suite: {status}; small median={small_summary['median_seconds']}s; "
        f"one-source median={incremental_summary['median_seconds']}s; "
        f"scaling max={max(float(item['ratio']) for item in scaling_ratios):.3f}x; "
        f"soak={len(soak_samples)}/{args.soak_runs}; report={output}"
    )
    if args.enforce and status != "PASS":
        return 1
    return 0 if all(int(sample["exit_code"]) == 0 for sample in soak_samples) else 2


if __name__ == "__main__":
    raise SystemExit(main())
