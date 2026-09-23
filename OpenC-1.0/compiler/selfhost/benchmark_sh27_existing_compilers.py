#!/usr/bin/env python3
"""Order-alternated guarded A/B of already fixed-point OpenC compilers."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import statistics

from benchmark_sh27_production import (
    MIB, ROOT, generate_language, require_disk_headroom, run_sample,
    sha256, validate_corpus,
)


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-27 paired compiler comparison requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument(
        "--workload", choices=("large_functions", "control_flow"),
        required=True,
    )
    parser.add_argument("--source-chunks", choices=("1", "2", "4", "auto"),
                        default="auto")
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 3 <= args.pairs <= 31:
        raise SystemExit("--pairs must be 3..31")
    baseline = args.baseline.resolve(strict=True)
    candidate = args.candidate.resolve(strict=True)
    if baseline == candidate or sha256(baseline) == sha256(candidate):
        raise SystemExit("baseline and candidate must be different compilers")
    corpus_path = ROOT / "benchmarks/sh27/CORPUS.json"
    corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
    validate_corpus(corpus)
    workload = next(
        item for item in corpus["workloads"] if item["id"] == args.workload
    )
    output = args.output.resolve()
    require_disk_headroom(output.parent)
    run_root = output.parent / (
        output.stem + "-runs-" +
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)
    source = generate_language(run_root / "corpus", "openc", workload)
    samples: dict[str, list[dict[str, object]]] = {
        "baseline": [], "candidate": [],
    }
    compilers = {"baseline": baseline, "candidate": candidate}
    chunks: int | str = (
        int(args.source_chunks) if args.source_chunks != "auto" else "auto"
    )
    for pair in range(args.pairs):
        order = ("baseline", "candidate") if pair % 2 == 0 else (
            "candidate", "baseline"
        )
        for name in order:
            sample = run_sample(
                tool="openc", executable=compilers[name],
                environment=dict(os.environ), input_record=source,
                sample_root=run_root / "pairs" / f"pair-{pair + 1:02d}" / name,
                sample_interval=0.01, max_private_bytes=512 * MIB,
                max_working_set_bytes=512 * MIB,
                max_output_bytes=2 * MIB, execution_timeout=30,
                openc_source_chunks=chunks,
            )
            samples[name].append(sample)
            print(
                f"pair {pair + 1}/{args.pairs} {name}: "
                f"{sample['elapsed_seconds']}s passed={sample['passed']}",
                flush=True,
            )
    deltas = [
        round(float(candidate_sample["elapsed_seconds"]) -
              float(baseline_sample["elapsed_seconds"]), 6)
        for baseline_sample, candidate_sample in zip(
            samples["baseline"], samples["candidate"]
        )
    ]
    output_hashes = {
        str(sample["output_sha256"])
        for group in samples.values() for sample in group
    }
    all_passed = all(
        bool(sample["passed"])
        for group in samples.values() for sample in group
    )
    exact = len(output_hashes) == 1 and "None" not in output_hashes
    median_delta = statistics.median(deltas)
    result = {
        "schema": "openc.sh27.existing_compiler_pair.v1",
        "status": "PASS" if all_passed and exact else "FAIL",
        "baseline": {"path": str(baseline), "sha256": sha256(baseline)},
        "candidate": {"path": str(candidate), "sha256": sha256(candidate)},
        "corpus_sha256": sha256(corpus_path),
        "workload": args.workload, "source_chunks": chunks,
        "pairs": args.pairs,
        "paired_delta_seconds": deltas,
        "median_paired_delta_seconds": median_delta,
        "candidate_wins": sum(delta < 0 for delta in deltas),
        "baseline_wins": sum(delta > 0 for delta in deltas),
        "all_compiles_executions_and_ram_guards_passed": all_passed,
        "all_executables_byte_exact": exact,
        "samples": samples,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"SH-27 paired existing compilers: {result['status']}; "
        f"median_delta={median_delta:.6f}s; report={output}", flush=True,
    )
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
