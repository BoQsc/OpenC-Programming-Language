#!/usr/bin/env python3
"""Compare several fixed-point OpenC compilers in one guarded SH-27 batch.

Candidate executables are built and verified separately. This runner freezes one
corpus per workload, runs every compiler serially, and pairs each candidate
with an adjacent baseline sample. Rotating candidate order and alternating the
within-pair order reduce drift without spawning competing compiler jobs.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import statistics

from benchmark_sh27_production import (
    ROOT, MIB, generate_language, require_disk_headroom, run_sample, sha256,
    summarize, validate_corpus,
)


SCHEMA = "openc.sh27.candidate_matrix.v1"
DEFAULT_WORKLOADS = ("large_functions", "control_flow")
NULL_NAME = "__null__"


def candidate_spec(raw: str) -> tuple[str, Path]:
    name, separator, filename = raw.partition("=")
    if not separator or not name or not filename:
        raise argparse.ArgumentTypeError("candidate must be NAME=PATH")
    if not all(character.isalnum() or character in "-_" for character in name):
        raise argparse.ArgumentTypeError(
            "candidate name may contain only letters, digits, hyphens, underscores"
        )
    return name, Path(filename)


def compare_pairs(
    pairs: list[dict[str, dict[str, object]]],
    *,
    allow_binary_difference: bool,
    require_gain: bool,
    noise_floor_seconds: float = 0.0,
) -> dict[str, object]:
    baseline = [pair["baseline"] for pair in pairs]
    candidate = [pair["candidate"] for pair in pairs]
    all_passed = all(
        bool(sample["passed"])
        for sample in baseline + candidate
    )
    baseline_hashes = {sample.get("output_sha256") for sample in baseline}
    candidate_hashes = {sample.get("output_sha256") for sample in candidate}
    baseline_deterministic = len(baseline_hashes) == 1 and None not in baseline_hashes
    candidate_deterministic = len(candidate_hashes) == 1 and None not in candidate_hashes
    binary_exact = (
        baseline_deterministic and candidate_deterministic
        and baseline_hashes == candidate_hashes
    )
    program_output_exact = all(
        old.get("program_exit_code") == new.get("program_exit_code")
        and old.get("program_stdout_sha256") is not None
        and old.get("program_stdout_sha256") == new.get("program_stdout_sha256")
        and old.get("program_stderr_sha256") is not None
        and old.get("program_stderr_sha256") == new.get("program_stderr_sha256")
        for old, new in zip(baseline, candidate)
    )
    deltas = [
        round(
            float(new["elapsed_seconds"]) - float(old["elapsed_seconds"]),
            6,
        )
        for old, new in zip(baseline, candidate)
    ]
    median_delta = statistics.median(deltas)
    wins = sum(delta < 0 for delta in deltas)
    speed_gain = median_delta < 0 and wins > len(pairs) // 2
    signal_above_noise = median_delta < -noise_floor_seconds
    correctness = (
        all_passed and program_output_exact
        and baseline_deterministic and candidate_deterministic
        and (binary_exact or allow_binary_difference)
    )
    status = (
        "PASS" if correctness and (
            (speed_gain and signal_above_noise) or not require_gain
        ) else "FAIL"
    )
    return {
        "status": status,
        "checks": {
            "all_compiles_executions_and_memory_guards_passed": all_passed,
            "all_program_outputs_byte_exact": program_output_exact,
            "baseline_binary_deterministic": baseline_deterministic,
            "candidate_binary_deterministic": candidate_deterministic,
            "generated_binaries_byte_exact": binary_exact,
            "generated_binary_identity_required": not allow_binary_difference,
            "paired_speed_gain_required": require_gain,
            "paired_speed_gain_observed": speed_gain,
            "paired_gain_above_null_noise": signal_above_noise,
        },
        "baseline": summarize(baseline),
        "candidate": summarize(candidate),
        "candidate_minus_baseline_seconds": deltas,
        "median_paired_delta_seconds": round(median_delta, 6),
        "null_noise_floor_seconds": round(noise_floor_seconds, 6),
        "candidate_wins": wins,
        "ties": sum(delta == 0 for delta in deltas),
        "candidate_losses": sum(delta > 0 for delta in deltas),
        "baseline_output_sha256": (
            next(iter(baseline_hashes)) if baseline_deterministic else None
        ),
        "candidate_output_sha256": (
            next(iter(candidate_hashes)) if candidate_deterministic else None
        ),
    }


def main() -> int:
    if os.name != "nt":
        raise SystemExit("candidate matrix requires Windows")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument(
        "--candidate", type=candidate_spec, action="append", required=True,
        metavar="NAME=PATH",
    )
    parser.add_argument("--workload", action="append", metavar="ID")
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--allow-binary-difference", action="store_true")
    parser.add_argument("--require-gain", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.pairs < 3 or args.pairs > 31:
        parser.error("pairs must be 3..31")
    baseline = args.baseline.resolve()
    if not baseline.is_file():
        parser.error(f"missing baseline compiler: {baseline}")
    compilers: dict[str, Path] = {}
    for name, filename in args.candidate:
        if name in {"baseline", NULL_NAME} or name in compilers:
            parser.error(f"reserved or duplicate candidate name: {name}")
        path = filename.resolve()
        if not path.is_file():
            parser.error(f"missing candidate compiler: {path}")
        compilers[name] = path
    output = args.output.resolve()
    if output.exists():
        parser.error(f"refusing to replace existing report: {output}")
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    run_root = output.parent / (
        output.stem + "-runs-"
        + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)

    corpus_path = ROOT / "benchmarks/sh27/CORPUS.json"
    corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
    validate_corpus(corpus)
    workload_ids = args.workload or list(DEFAULT_WORKLOADS)
    if len(workload_ids) != len(set(workload_ids)):
        parser.error("duplicate workload ID")
    by_id = {str(item["id"]): item for item in corpus["workloads"]}
    missing = set(workload_ids) - set(by_id)
    if missing:
        parser.error(f"unknown workload IDs: {', '.join(sorted(missing))}")

    result: dict[str, object] = {
        "schema": SCHEMA,
        "status": "INCOMPLETE",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "logical_cpus": os.cpu_count(),
            "runner_image_version": os.environ.get("ImageVersion"),
        },
        "baseline": {"path": str(baseline), "sha256": sha256(baseline)},
        "candidates": {
            name: {"path": str(path), "sha256": sha256(path)}
            for name, path in compilers.items()
        },
        "corpus": {"path": str(corpus_path), "sha256": sha256(corpus_path)},
        "pairs_per_candidate_per_workload": args.pairs,
        "cache_policy": (
            "OS cache not flushed; candidate order rotates by pair; "
            "baseline/candidate order alternates within each adjacent pair; "
            "baseline-vs-baseline null control measures host jitter; "
            "all compiler jobs run serially"
        ),
        "limits": {
            "max_job_private_bytes": 512 * MIB,
            "max_working_set_bytes": 512 * MIB,
            "max_captured_output_bytes": 2 * MIB,
            "compiler_timeout_seconds": 120,
            "execution_timeout_seconds": 30,
        },
        "workloads": {},
    }
    try:
        for workload_id in workload_ids:
            workload = by_id[workload_id]
            source = generate_language(
                run_root / "corpus" / workload_id / "openc", "openc", workload
            )
            pairs_by_candidate: dict[str, list[dict[str, dict[str, object]]]] = {
                name: [] for name in [*compilers, NULL_NAME]
            }
            workload_result: dict[str, object] = {
                "definition": workload,
                "source_tree": source["tree"],
                "comparisons": {},
            }
            result["workloads"][workload_id] = workload_result
            names = [*compilers, NULL_NAME]
            for pair_index in range(args.pairs):
                rotated = names[pair_index % len(names):] + names[:pair_index % len(names)]
                for candidate_index, name in enumerate(rotated):
                    order = (
                        ("baseline", name)
                        if (pair_index + candidate_index) % 2 == 0
                        else (name, "baseline")
                    )
                    sample_pair: dict[str, dict[str, object]] = {}
                    for side in order:
                        executable = (
                            baseline if side == "baseline" or name == NULL_NAME
                            else compilers[name]
                        )
                        sample_root = (
                            run_root / "samples" / workload_id
                            / f"pair-{pair_index + 1:02d}" / name / side
                        )
                        sample = run_sample(
                            tool="openc", executable=executable,
                            environment=dict(os.environ), input_record=source,
                            sample_root=sample_root, sample_interval=0.01,
                            max_private_bytes=512 * MIB,
                            max_working_set_bytes=512 * MIB,
                            max_output_bytes=2 * MIB,
                            execution_timeout=30,
                            compiler_timeout=120,
                        )
                        sample_pair[
                            "baseline" if side == "baseline" else "candidate"
                        ] = sample
                        (sample_root / "measurement.json").write_text(
                            json.dumps(sample, indent=2) + "\n", encoding="utf-8"
                        )
                        print(
                            f"{workload_id} {pair_index + 1}/{args.pairs} "
                            f"{name} {side}: {sample['elapsed_seconds']}s "
                            f"passed={sample['passed']}",
                            flush=True,
                        )
                    pairs_by_candidate[name].append(sample_pair)
            null_pairs = pairs_by_candidate[NULL_NAME]
            null_deltas = [
                float(pair["candidate"]["elapsed_seconds"])
                - float(pair["baseline"]["elapsed_seconds"])
                for pair in null_pairs
            ]
            noise_floor = statistics.median(abs(delta) for delta in null_deltas)
            workload_result["noise_control"] = compare_pairs(
                null_pairs,
                allow_binary_difference=False,
                require_gain=False,
            )
            workload_result["noise_control"]["median_absolute_delta_seconds"] = round(
                noise_floor, 6
            )
            workload_result["noise_control"]["pairs"] = null_pairs
            for name in compilers:
                comparison = compare_pairs(
                    pairs_by_candidate[name],
                    allow_binary_difference=args.allow_binary_difference,
                    require_gain=args.require_gain,
                    noise_floor_seconds=noise_floor,
                )
                comparison["pairs"] = pairs_by_candidate[name]
                workload_result["comparisons"][name] = comparison
                print(
                    f"{workload_id} {name}: {comparison['status']}; "
                    f"paired median {comparison['median_paired_delta_seconds']}s; "
                    f"wins {comparison['candidate_wins']}/{args.pairs}; "
                    f"null noise {noise_floor:.6f}s; "
                    f"above noise={comparison['checks']['paired_gain_above_null_noise']}",
                    flush=True,
                )
        result["status"] = (
            "PASS" if all(
                comparison["status"] == "PASS"
                for lane in result["workloads"].values()
                for comparison in lane["comparisons"].values()
            ) else "FAIL"
        )
    finally:
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 candidate matrix: {result['status']}; report={output}")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
