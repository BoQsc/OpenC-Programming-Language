#!/usr/bin/env python3
"""Prove the no-thread flow launcher falls back to byte-exact serial chunks."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path

from benchmark_sh27_native_parallel import build
from benchmark_sh27_production import (
    MIB, ROOT, generate_language, require_disk_headroom, run_measured,
    sha256, validate_corpus,
)


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-27 flow fallback requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-compiler", type=Path, required=True)
    parser.add_argument("--candidate-compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    baseline = args.baseline_compiler.resolve(strict=True)
    candidate = args.candidate_compiler.resolve(strict=True)
    output = args.output.resolve()
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    run_root = output.parent / (
        output.stem + "-runs-" +
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)
    transition_dir = run_root / "transition"
    transition_dir.mkdir(parents=True, exist_ok=False)
    transition = transition_dir / "openc.exe"
    project = ROOT / "compiler/selfhost/openc.project.json"
    command = [
        str(baseline), "build", f"--project={project}",
        f"--output={transition}",
        f"--timings={transition_dir / 'timings.json'}",
    ]
    transition_sample = run_measured(
        command, cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=180,
    )
    transition_sample["command"] = command
    transition_sample["output_exists"] = transition.is_file()
    transition_sample["passed"] = bool(
        transition_sample["exit_code"] == 0
        and not transition_sample["timed_out"]
        and not transition_sample["memory_limit_exceeded"]
        and transition_sample["output_exists"]
    )
    if not transition_sample["passed"]:
        raise RuntimeError(f"fallback transition build failed: {transition_sample}")
    corpus = json.loads((ROOT / "benchmarks/sh27/CORPUS.json").read_text())
    validate_corpus(corpus)
    workload = next(
        item for item in corpus["workloads"]
        if item["id"] == "control_flow"
    )
    generated = generate_language(
        run_root / "sources", "openc", workload
    )
    source_project = Path(str(generated["project"]))
    fallback = build(
        transition, source_project, run_root / "fallback", True, True, "auto"
    )
    threaded = build(
        candidate, source_project, run_root / "threaded", True, True, "auto"
    )
    fallback_timing = fallback["compiler_timings"] or {}
    threaded_timing = threaded["compiler_timings"] or {}
    passed = bool(
        fallback["passed"] and threaded["passed"]
        and fallback["output_sha256"] == threaded["output_sha256"]
        and fallback_timing.get("parallel_source_chunks") == 2
        and fallback_timing.get("parallel_flow_workers") == 2
        and fallback_timing.get("flow_threads_launched") is False
        and threaded_timing.get("parallel_source_chunks") == 2
        and threaded_timing.get("parallel_flow_workers") == 2
        and threaded_timing.get("flow_threads_launched") is True
    )
    result = {
        "schema": "openc.sh27.flow_fallback.v1",
        "status": "PASS" if passed else "FAIL",
        "baseline_sha256": sha256(baseline),
        "candidate_sha256": sha256(candidate),
        "transition_sha256": sha256(transition),
        "transition_build": transition_sample,
        "fallback": fallback,
        "threaded": threaded,
        "byte_exact": fallback["output_sha256"] == threaded["output_sha256"],
    }
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 flow fallback: {result['status']}; report={output}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
