#!/usr/bin/env python3
"""Guarded alternating pairs of serial and native-parallel artifact builds."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import statistics

from benchmark_sh27_production import (
    MIB, ROOT, generate_language, require_disk_headroom, run_measured,
    sha256, summarize, validate_corpus,
)


def build(
    compiler: Path, project: Path, directory: Path, parallel: bool,
    retain_binary: bool, source_chunks: int | str,
    explicit_serial: bool = False,
) -> dict[str, object]:
    free_bytes = require_disk_headroom(directory)
    directory.mkdir(parents=True, exist_ok=False)
    output = directory / "program.exe"
    timing = directory / "timings.json"
    command = [
        str(compiler), "artifact", f"--project={project}", "--kind=exe",
        f"--output={output}", f"--report={directory / 'artifact.json'}",
        f"--timings={timing}",
    ]
    if parallel:
        command.append(f"--source-chunks={source_chunks}")
    elif explicit_serial:
        command.append("--source-chunks=1")
    sample = run_measured(
        command, cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=180,
    )
    sample["command"] = command
    sample["disk_free_bytes_before"] = free_bytes
    sample["output_exists_at_measurement"] = output.is_file()
    sample["output_sha256"] = sha256(output) if output.is_file() else None
    sample["output_bytes"] = output.stat().st_size if output.is_file() else None
    sample["compiler_timings"] = (
        json.loads(timing.read_text(encoding="utf-8"))
        if timing.is_file() else None
    )
    sample["passed"] = bool(
        sample["exit_code"] == 0 and not sample["timed_out"]
        and not sample["memory_limit_exceeded"]
        and not sample["stdout_truncated"] and not sample["stderr_truncated"]
        and sample["output_exists_at_measurement"]
        and isinstance(sample["compiler_timings"], dict)
        and sample["compiler_timings"].get("status") == "PASS"
    )
    sample["binary_retained"] = retain_binary
    if sample["passed"] and not retain_binary:
        target = output.resolve(strict=True)
        if target.parent != directory.resolve():
            raise RuntimeError("refusing to remove output outside sample directory")
        target.unlink()
    (directory / "measurement.json").write_text(
        json.dumps(sample, indent=2) + "\n", encoding="utf-8"
    )
    return sample


def main() -> int:
    if os.name != "nt":
        raise SystemExit("native parallel benchmark currently requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--workload", required=True, choices=(
        "selfhost", "many_files", "large_functions", "control_flow",
    ))
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--source-chunks", choices=("2", "4", "auto"), default="4")
    parser.add_argument("--require-gain", action="store_true",
                        help="fail unless a majority of pairs win and median delta is negative")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source_chunks: int | str = (
        args.source_chunks if args.source_chunks == "auto"
        else int(args.source_chunks)
    )
    if args.pairs < 3 or args.pairs > 31:
        raise SystemExit("pairs must be 3..31")
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    require_disk_headroom(output.parent)
    run_root = output.parent / (
        output.stem + "-runs-" +
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)
    if args.workload == "selfhost":
        project = ROOT / "compiler/selfhost/openc.project.json"
        source: dict[str, object] = {"project": str(project)}
    else:
        corpus = json.loads(
            (ROOT / "benchmarks/sh27/CORPUS.json").read_text(encoding="utf-8")
        )
        validate_corpus(corpus)
        workload = next(
            item for item in corpus["workloads"]
            if item["id"] == args.workload
        )
        source = generate_language(
            run_root / "sources" / args.workload, "openc", workload
        )
        project = Path(str(source["project"]))
        source = json.loads(json.dumps(source, default=str))
    samples: dict[str, list[dict[str, object]]] = {"serial": [], "parallel": []}
    checkpoint = output.with_name(output.stem + "-checkpoint.json")
    for pair in range(args.pairs):
        order = ("serial", "parallel") if pair % 2 == 0 else (
            "parallel", "serial"
        )
        for name in order:
            directory = run_root / "pairs" / f"pair-{pair + 1:02d}" / name
            result = build(
                compiler, project, directory, name == "parallel", pair == 0,
                source_chunks, explicit_serial=name == "serial",
            )
            samples[name].append(result)
            print(
                f"pair {pair + 1}/{args.pairs} {name}: "
                f"{result['elapsed_seconds']}s passed={result['passed']}",
                flush=True,
            )
            if not result["passed"]:
                raise RuntimeError(
                    f"{name} pair {pair + 1} failed; "
                    f"measurement={directory / 'measurement.json'}"
                )
        checkpoint.write_text(
            json.dumps({
                "schema": "openc.sh27.native_parallel_checkpoint.v1",
                "compiler_sha256": sha256(compiler),
                "workload": args.workload,
                "source_chunks": source_chunks,
                "pairs_requested": args.pairs,
                "pairs_completed": pair + 1,
                "samples": samples,
            }, indent=2, default=str) + "\n", encoding="utf-8",
        )
    hashes = {
        str(item["output_sha256"])
        for group in samples.values() for item in group
    }
    exact = len(hashes) == 1 and "None" not in hashes
    deltas = [
        round(float(parallel["elapsed_seconds"]) -
              float(serial["elapsed_seconds"]), 6)
        for serial, parallel in zip(samples["serial"], samples["parallel"])
    ]
    gain_passed = bool(
        statistics.median(deltas) < 0
        and sum(delta < 0 for delta in deltas) > args.pairs // 2
    )
    report = {
        "schema": "openc.sh27.native_parallel_paired.v1",
        "status": "PASS" if exact and (
            not args.require_gain or gain_passed
        ) else "FAIL",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "host": {
            "system": platform.system(), "release": platform.release(),
            "machine": platform.machine(), "logical_cpus": os.cpu_count(),
        },
        "compiler": {"path": str(compiler), "sha256": sha256(compiler)},
        "workload": args.workload, "source": source, "pairs": args.pairs,
        "source_chunks": source_chunks,
        "binary_retention": "first pair retained; later hashes recorded before removal",
        "checks": {
            "all_outputs_byte_exact": exact,
            "all_bounded_builds_passed": True,
            "parallel_gain_required": args.require_gain,
            "parallel_gain_passed": gain_passed,
        },
        "comparison": {
            "serial": summarize(samples["serial"]),
            "parallel": summarize(samples["parallel"]),
            "parallel_minus_serial_seconds": deltas,
            "median_paired_delta_seconds": round(statistics.median(deltas), 6),
            "parallel_wins": sum(delta < 0 for delta in deltas),
            "ties": sum(delta == 0 for delta in deltas),
            "parallel_losses": sum(delta > 0 for delta in deltas),
            "output_sha256": next(iter(hashes)) if exact else None,
        },
        "samples": samples,
    }
    output.write_text(
        json.dumps(report, indent=2, default=str) + "\n", encoding="utf-8"
    )
    print(f"SH-27 native parallel paired: {report['status']}; report={output}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
