#!/usr/bin/env python3
"""Compare two self-hosted OpenC revisions on one guarded Windows runner."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tempfile

from benchmark_sh27_production import (
    ROOT, MIB, generate_language, run_measured, run_sample, sha256,
    summarize, validate_corpus,
)


REPOSITORY = ROOT.parent
SCHEMA = "openc.sh27.paired_revision.v1"


def resolve_commit(value: str) -> str:
    completed = subprocess.run(
        ["git", "rev-parse", "--verify", "--end-of-options", f"{value}^{{commit}}"],
        cwd=REPOSITORY, capture_output=True, text=True, check=True,
    )
    return completed.stdout.strip()


def bootstrap(
    name: str, project_root: Path, seed: Path, run_root: Path,
) -> tuple[Path, dict[str, object]]:
    project = project_root / "compiler/selfhost/openc.project.json"
    if not project.is_file():
        raise RuntimeError(f"missing compiler project: {project}")
    current = seed
    samples: list[dict[str, object]] = []
    stages: list[Path] = []
    for number in (1, 2, 3):
        stage = run_root / "bootstrap" / name / f"stage{number}"
        stage.mkdir(parents=True, exist_ok=False)
        output = stage / "openc.exe"
        command = [
            str(current), "build", f"--project={project}",
            f"--output={output}", f"--timings={stage / 'timings.json'}",
        ]
        sample = run_measured(
            command, cwd=project_root, environment=dict(os.environ),
            sample_interval=0.01,
            max_private_bytes=512 * MIB,
            max_working_set_bytes=512 * MIB,
            max_captured_output_bytes=2 * MIB,
            timeout_seconds=180,
        )
        sample["command"] = command
        sample["stage"] = number
        sample["output_exists"] = output.is_file()
        sample["output_sha256"] = sha256(output) if output.is_file() else None
        sample["passed"] = bool(
            sample["exit_code"] == 0
            and not sample["timed_out"]
            and not sample["memory_limit_exceeded"]
            and not sample["stdout_truncated"]
            and not sample["stderr_truncated"]
            and sample["output_exists"]
        )
        samples.append(sample)
        print(f"{name} bootstrap {number}/3: {sample['passed']}", flush=True)
        if not sample["passed"]:
            raise RuntimeError(f"{name} bootstrap failed at stage {number}")
        stages.append(output)
        current = output
    fixed = stages[1].read_bytes() == stages[2].read_bytes()
    if not fixed:
        raise RuntimeError(f"{name} stage 2 and stage 3 are not byte exact")
    return stages[2], {
        "project": str(project), "samples": samples,
        "stage2_stage3_byte_exact": fixed,
        "stage3_sha256": sha256(stages[2]),
    }


def main() -> int:
    if os.name != "nt":
        raise SystemExit("paired revision benchmark requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--baseline-ref", default=os.environ.get("SH27_BASELINE_REF"),
        required="SH27_BASELINE_REF" not in os.environ,
    )
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument(
        "--pairs", type=int, default=int(os.environ.get("SH27_PAIRS", "11"))
    )
    parser.add_argument(
        "--workload", default=os.environ.get("SH27_WORKLOAD", "large_functions"),
        choices=("large_functions", "control_flow"),
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.pairs < 3 or args.pairs > 31:
        raise SystemExit("pairs must be 3..31")
    seed = args.seed.resolve()
    if not seed.is_file():
        raise SystemExit(f"missing retained seed: {seed}")
    baseline_commit = resolve_commit(args.baseline_ref)
    candidate_commit = resolve_commit("HEAD")
    if baseline_commit == candidate_commit:
        raise SystemExit("baseline and candidate resolve to the same commit")
    corpus_path = ROOT / "benchmarks/sh27/CORPUS.json"
    corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
    validate_corpus(corpus)
    workload = next(
        item for item in corpus["workloads"]
        if item["id"] == args.workload
    )
    output = args.output.resolve()
    run_root = output.parent / (
        output.stem + "-runs-" +
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="openc-sh27-pair-") as temporary:
        temporary_root = Path(temporary).resolve()
        baseline_tree = temporary_root / "baseline"
        created = False
        try:
            subprocess.run(
                ["git", "worktree", "add", "--detach", str(baseline_tree),
                 baseline_commit],
                cwd=REPOSITORY, capture_output=True, text=True, check=True,
            )
            created = True
            baseline_root = baseline_tree / "OpenC-1.0"
            baseline_compiler, baseline_bootstrap = bootstrap(
                "baseline", baseline_root, seed, run_root
            )
            candidate_compiler, candidate_bootstrap = bootstrap(
                "candidate", ROOT, seed, run_root
            )
            source = generate_language(
                run_root / "corpus" / "openc", "openc", workload
            )
            samples: dict[str, list[dict[str, object]]] = {
                "baseline": [], "candidate": [],
            }
            for pair in range(args.pairs):
                order = ("baseline", "candidate") if pair % 2 == 0 else (
                    "candidate", "baseline"
                )
                for name in order:
                    sample = run_sample(
                        tool="openc",
                        executable=(baseline_compiler if name == "baseline"
                                    else candidate_compiler),
                        environment=dict(os.environ),
                        input_record=source,
                        sample_root=(run_root / "pairs" /
                                     f"pair-{pair + 1:02d}" / name),
                        sample_interval=0.01,
                        max_private_bytes=512 * MIB,
                        max_working_set_bytes=512 * MIB,
                        max_output_bytes=2 * MIB,
                        execution_timeout=30,
                    )
                    samples[name].append(sample)
                    print(
                        f"pair {pair + 1}/{args.pairs} {name}: "
                        f"{sample['elapsed_seconds']}s passed={sample['passed']}",
                        flush=True,
                    )
        finally:
            if created:
                target = baseline_tree.resolve()
                if not target.is_relative_to(temporary_root):
                    raise RuntimeError("refusing to remove unexpected worktree path")
                subprocess.run(
                    ["git", "worktree", "remove", "--force", str(target)],
                    cwd=REPOSITORY, check=True, capture_output=True, text=True,
                )

    hashes = {
        str(sample["output_sha256"])
        for group in samples.values() for sample in group
    }
    all_passed = all(sample["passed"] for group in samples.values() for sample in group)
    byte_exact = len(hashes) == 1 and "None" not in hashes
    deltas = [
        round(float(candidate["elapsed_seconds"]) -
              float(baseline["elapsed_seconds"]), 6)
        for baseline, candidate in zip(samples["baseline"], samples["candidate"])
    ]
    result = {
        "schema": SCHEMA,
        "status": "PASS" if all_passed and byte_exact else "FAIL",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "host": {
            "system": platform.system(), "release": platform.release(),
            "machine": platform.machine(), "logical_cpus": os.cpu_count(),
            "runner_image_version": os.environ.get("ImageVersion"),
        },
        "baseline_commit": baseline_commit,
        "candidate_commit": candidate_commit,
        "seed": {"path": str(seed), "sha256": sha256(seed)},
        "corpus": {"path": str(corpus_path), "sha256": sha256(corpus_path)},
        "workload": workload,
        "source_tree": source["tree"],
        "cache_policy": "OS cache not flushed; order alternates every pair",
        "baseline_bootstrap": baseline_bootstrap,
        "candidate_bootstrap": candidate_bootstrap,
        "checks": {
            "all_compiles_executions_and_memory_guards_passed": all_passed,
            "all_program_outputs_byte_exact": byte_exact,
            "baseline_fixed_point": baseline_bootstrap["stage2_stage3_byte_exact"],
            "candidate_fixed_point": candidate_bootstrap["stage2_stage3_byte_exact"],
        },
        "comparison": {
            "pairs": args.pairs,
            "baseline": summarize(samples["baseline"]),
            "candidate": summarize(samples["candidate"]),
            "candidate_minus_baseline_seconds": deltas,
            "median_paired_delta_seconds": round(statistics.median(deltas), 6),
            "candidate_wins": sum(delta < 0 for delta in deltas),
            "ties": sum(delta == 0 for delta in deltas),
            "candidate_losses": sum(delta > 0 for delta in deltas),
            "output_sha256": next(iter(hashes)) if byte_exact else None,
        },
        "samples": samples,
    }
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 paired revisions: {result['status']}; report={output}")
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
