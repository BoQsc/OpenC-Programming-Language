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
    MIB, ROOT, generate_language, require_disk_headroom, run_measured, run_sample,
    sha256, validate_corpus,
)


def run_selfhost_sample(
    compiler: Path, project: Path, sample_root: Path, chunks: int | str,
    expected_output_sha256: str,
) -> dict[str, object]:
    disk_free_before = require_disk_headroom(sample_root)
    sample_root.mkdir(parents=True, exist_ok=False)
    output = sample_root / "openc.exe"
    timing = sample_root / "timings.json"
    command = [
        str(compiler), "artifact", f"--project={project}", "--kind=exe",
        f"--output={output}", f"--report={sample_root / 'artifact.json'}",
        f"--timings={timing}", f"--source-chunks={chunks}",
    ]
    sample = run_measured(
        command, cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=180,
    )
    sample["command"] = command
    sample["disk_free_bytes_before"] = disk_free_before
    sample["output_sha256"] = sha256(output) if output.is_file() else None
    sample["output_bytes"] = output.stat().st_size if output.is_file() else None
    sample["compiler_timings"] = (
        json.loads(timing.read_text(encoding="utf-8"))
        if timing.is_file() else None
    )
    sample["fixed_point"] = sample["output_sha256"] == sha256(compiler)
    sample["matches_current_source_binary"] = (
        sample["output_sha256"] == expected_output_sha256
    )
    sample["passed"] = bool(
        sample["exit_code"] == 0 and not sample["timed_out"]
        and not sample["memory_limit_exceeded"]
        and not sample["stdout_truncated"] and not sample["stderr_truncated"]
        and isinstance(sample["compiler_timings"], dict)
        and sample["compiler_timings"].get("status") == "PASS"
        and sample["matches_current_source_binary"]
    )
    (sample_root / "measurement.json").write_text(
        json.dumps(sample, indent=2) + "\n", encoding="utf-8"
    )
    return sample


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-27 paired compiler comparison requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument(
        "--workload", choices=("large_functions", "control_flow", "selfhost"),
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
        corpus_hash: str | None = None
    else:
        corpus_path = ROOT / "benchmarks/sh27/CORPUS.json"
        corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
        validate_corpus(corpus)
        workload = next(
            item for item in corpus["workloads"] if item["id"] == args.workload
        )
        source = generate_language(run_root / "corpus", "openc", workload)
        corpus_hash = sha256(corpus_path)
    samples: dict[str, list[dict[str, object]]] = {
        "baseline": [], "candidate": [],
    }
    compilers = {"baseline": baseline, "candidate": candidate}
    candidate_hash = sha256(candidate)
    chunks: int | str = (
        int(args.source_chunks) if args.source_chunks != "auto" else "auto"
    )
    for pair in range(args.pairs):
        order = ("baseline", "candidate") if pair % 2 == 0 else (
            "candidate", "baseline"
        )
        for name in order:
            sample_root = run_root / "pairs" / f"pair-{pair + 1:02d}" / name
            if args.workload == "selfhost":
                sample = run_selfhost_sample(
                    compilers[name], project, sample_root, chunks,
                    candidate_hash,
                )
            else:
                sample = run_sample(
                    tool="openc", executable=compilers[name],
                    environment=dict(os.environ), input_record=source,
                    sample_root=sample_root,
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
    matches_current_source = bool(
        args.workload == "selfhost" and all(
            bool(sample["matches_current_source_binary"])
            for group in samples.values() for sample in group
        )
    )
    median_delta = statistics.median(deltas)
    result = {
        "schema": "openc.sh27.existing_compiler_pair.v1",
        "status": "PASS" if all_passed and exact else "FAIL",
        "baseline": {"path": str(baseline), "sha256": sha256(baseline)},
        "candidate": {"path": str(candidate), "sha256": sha256(candidate)},
        "corpus_sha256": corpus_hash,
        "source": source if args.workload == "selfhost" else None,
        "workload": args.workload, "source_chunks": chunks,
        "pairs": args.pairs,
        "paired_delta_seconds": deltas,
        "median_paired_delta_seconds": median_delta,
        "candidate_wins": sum(delta < 0 for delta in deltas),
        "baseline_wins": sum(delta > 0 for delta in deltas),
        "all_compiles_executions_and_ram_guards_passed": all_passed,
        "all_executables_byte_exact": exact if args.workload != "selfhost" else None,
        "all_self_builds_match_candidate_fixed_point": (
            matches_current_source if args.workload == "selfhost" else None
        ),
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
