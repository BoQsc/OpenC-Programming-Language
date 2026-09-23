#!/usr/bin/env python3
"""Guarded, order-alternated comparison of native flow-worker revisions."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import statistics

from benchmark_sh27_native_parallel import build
from benchmark_sh27_production import (
    ROOT, generate_language, require_disk_headroom, sha256, summarize,
    validate_corpus,
)
from verify_sh27_native_chunks import timing_accounting_valid


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-27 flow-worker comparison requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument(
        "--workload", required=True,
        choices=("selfhost", "large_functions", "control_flow"),
    )
    parser.add_argument("--source-chunks", choices=("2", "4", "auto"), default="auto")
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--require-gain", action="store_true")
    parser.add_argument("--max-regression-percent", type=float)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 3 <= args.pairs <= 31:
        raise SystemExit("pairs must be 3..31")
    if args.max_regression_percent is not None and not 0 <= args.max_regression_percent <= 100:
        raise SystemExit("max regression percent must be 0..100")
    baseline = args.baseline.resolve(strict=True)
    candidate = args.candidate.resolve(strict=True)
    if sha256(baseline) == sha256(candidate):
        raise SystemExit("baseline and candidate compiler bytes are identical")
    source_chunks: int | str = (
        "auto" if args.source_chunks == "auto" else int(args.source_chunks)
    )
    output = args.output.resolve()
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    run_root = output.parent / (
        output.stem + "-runs-" +
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)
    if args.workload == "selfhost":
        project = ROOT / "compiler/selfhost/openc.project.json"
    else:
        corpus = json.loads(
            (ROOT / "benchmarks/sh27/CORPUS.json").read_text(encoding="utf-8")
        )
        validate_corpus(corpus)
        workload = next(
            item for item in corpus["workloads"]
            if item["id"] == args.workload
        )
        generated = generate_language(
            run_root / "sources" / args.workload, "openc", workload
        )
        project = Path(str(generated["project"]))
    samples: dict[str, list[dict[str, object]]] = {
        "baseline": [], "candidate": [],
    }
    checkpoint = output.with_name(output.stem + "-checkpoint.json")
    for pair in range(args.pairs):
        order = ("baseline", "candidate") if pair % 2 == 0 else (
            "candidate", "baseline"
        )
        for name in order:
            directory = run_root / f"pair-{pair + 1:02d}" / name
            sample = build(
                baseline if name == "baseline" else candidate,
                project, directory, True, pair == 0, source_chunks,
            )
            samples[name].append(sample)
            print(
                f"pair {pair + 1}/{args.pairs} {name}: "
                f"{sample['elapsed_seconds']}s passed={sample['passed']}",
                flush=True,
            )
            if not sample["passed"]:
                raise RuntimeError(
                    f"{name} pair {pair + 1} failed; "
                    f"measurement={directory / 'measurement.json'}"
                )
        checkpoint.write_text(
            json.dumps({
                "schema": "openc.sh27.flow_parallel_checkpoint.v1",
                "pairs_completed": pair + 1,
                "samples": samples,
            }, indent=2) + "\n", encoding="utf-8",
        )
    baseline_hashes = {str(item["output_sha256"]) for item in samples["baseline"]}
    candidate_hashes = {str(item["output_sha256"]) for item in samples["candidate"]}
    each_revision_stable = (
        len(baseline_hashes) == 1 and len(candidate_hashes) == 1
        and "None" not in baseline_hashes and "None" not in candidate_hashes
    )
    cross_revision_exact = baseline_hashes == candidate_hashes
    candidate_flow_policy_valid = all(
        timing_accounting_valid(sample["compiler_timings"], True, source_chunks)
        for sample in samples["candidate"]
    )
    deltas = [
        round(float(candidate_sample["elapsed_seconds"]) -
              float(baseline_sample["elapsed_seconds"]), 6)
        for baseline_sample, candidate_sample in zip(
            samples["baseline"], samples["candidate"]
        )
    ]
    gained = statistics.median(deltas) < 0 and sum(
        delta < 0 for delta in deltas
    ) > args.pairs // 2
    median_delta = statistics.median(deltas)
    baseline_median = statistics.median(
        float(sample["elapsed_seconds"]) for sample in samples["baseline"]
    )
    nonregression_passed = (
        args.max_regression_percent is None or
        median_delta <= baseline_median * args.max_regression_percent / 100
    )
    passed = bool(
        each_revision_stable and candidate_flow_policy_valid
        and (args.workload == "selfhost" or cross_revision_exact)
        and (not args.require_gain or gained)
        and nonregression_passed
    )
    result = {
        "schema": "openc.sh27.flow_parallel_paired.v1",
        "status": "PASS" if passed else "FAIL",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "host": {
            "system": platform.system(), "release": platform.release(),
            "machine": platform.machine(), "logical_cpus": os.cpu_count(),
        },
        "baseline": {"path": str(baseline), "sha256": sha256(baseline)},
        "candidate": {"path": str(candidate), "sha256": sha256(candidate)},
        "workload": args.workload,
        "project": str(project),
        "source_chunks": source_chunks,
        "pairs": args.pairs,
        "checks": {
            "all_bounded_builds_passed": True,
            "each_revision_output_stable": each_revision_stable,
            "cross_revision_output_exact": cross_revision_exact,
            "candidate_flow_policy_valid": candidate_flow_policy_valid,
            "parallel_gain_required": args.require_gain,
            "parallel_gain_passed": gained,
            "max_regression_percent": args.max_regression_percent,
            "nonregression_passed": nonregression_passed,
        },
        "comparison": {
            "baseline": summarize(samples["baseline"]),
            "candidate": summarize(samples["candidate"]),
            "candidate_minus_baseline_seconds": deltas,
            "median_paired_delta_seconds": round(median_delta, 6),
            "candidate_wins": sum(delta < 0 for delta in deltas),
            "ties": sum(delta == 0 for delta in deltas),
            "candidate_losses": sum(delta > 0 for delta in deltas),
        },
        "samples": samples,
    }
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 flow-worker paired: {result['status']}; report={output}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
