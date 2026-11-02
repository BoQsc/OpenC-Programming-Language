#!/usr/bin/env python3
"""Paired C:/D: placement diagnostic for one SH-27 compile workload.

This is a diagnostic, not a replacement for the pinned production corpus.
Each tool compiles the same generated sources on both volumes, with condition
order rotated per pair and normal process-tree RAM/output guards.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import statistics

from benchmark_sh27_production import ROOT, build_command, generate_language, sha256
from windows_process_measure import run_measured


MIB = 1024 * 1024


def summarize(values: list[float]) -> dict[str, object]:
    return {
        "runs": len(values),
        "median_seconds": round(statistics.median(values), 4),
        "raw_seconds": values,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--openc", required=True, type=Path)
    parser.add_argument("--dmd", required=True, type=Path)
    parser.add_argument("--corpus", default=ROOT / "benchmarks/sh27/CORPUS.json", type=Path)
    parser.add_argument("--workload", default="large_functions")
    parser.add_argument("--c-root", required=True, type=Path)
    parser.add_argument("--d-root", required=True, type=Path)
    parser.add_argument("--pairs", default=11, type=int)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.pairs < 3 or args.pairs > 31:
        raise SystemExit("--pairs must be 3..31")
    tools = {name: path.resolve() for name, path in (("openc", args.openc), ("dmd", args.dmd))}
    if not all(path.is_file() for path in tools.values()):
        raise SystemExit("both compiler executables are required")
    roots = {"c": args.c_root.resolve(), "d": args.d_root.resolve()}
    if roots["c"].anchor.lower() == roots["d"].anchor.lower():
        raise SystemExit("the diagnostic needs two different volumes")
    if any(path.exists() for path in roots.values()):
        raise SystemExit("both run roots must be new, unused directories")
    corpus_path = args.corpus.resolve()
    corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
    workload = next((w for w in corpus["workloads"] if w["id"] == args.workload), None)
    if workload is None:
        raise SystemExit(f"unknown workload: {args.workload}")
    inputs: dict[str, dict[str, object]] = {}
    for location, root in roots.items():
        inputs[location] = {}
        for tool in tools:
            inputs[location][tool] = generate_language(root / "corpus" / tool, tool, workload)
    for tool in tools:
        left = inputs["c"][tool]["sources"]
        right = inputs["d"][tool]["sources"]
        if [sha256(path) for path in left] != [sha256(path) for path in right]:
            raise SystemExit(f"generated {tool} sources differ across volumes")

    conditions = [(location, tool) for location in ("c", "d") for tool in ("openc", "dmd")]
    observations: dict[str, dict[str, list[dict[str, object]]]] = {
        location: {tool: [] for tool in tools} for location in roots
    }
    all_passed = True
    for pair in range(args.pairs):
        order = conditions[pair % 4 :] + conditions[: pair % 4]
        if pair % 2:
            order.reverse()
        for location, tool in order:
            directory = roots[location] / "samples" / f"pair-{pair + 1:02d}" / tool
            directory.mkdir(parents=True, exist_ok=False)
            executable = directory / "program.exe"
            timings = directory / "timings.json"
            command = build_command(
                tool, tools[tool], inputs[location][tool], executable, timings
            )
            built = run_measured(
                command, cwd=ROOT, sample_interval=0.01,
                max_private_bytes=512 * MIB,
                max_working_set_bytes=512 * MIB,
                max_captured_output_bytes=2 * MIB,
            )
            passed = (
                built["exit_code"] == 0 and not built["memory_limit_exceeded"]
                and not built["timed_out"] and executable.is_file()
            )
            executed: dict[str, object] | None = None
            if passed:
                executed = run_measured(
                    [str(executable)], cwd=directory, sample_interval=0.01,
                    max_private_bytes=64 * MIB,
                    max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB,
                )
                passed = (
                    executed["exit_code"] == 0
                    and not executed["memory_limit_exceeded"]
                    and not executed["timed_out"]
                )
            observation = {
                "pair": pair + 1,
                "location": location,
                "tool": tool,
                "command": command,
                "compile": built,
                "program": executed,
                "output_sha256": sha256(executable) if executable.is_file() else None,
                "passed": passed,
            }
            observations[location][tool].append(observation)
            all_passed = all_passed and passed
            if not passed:
                break
        print(f"storage-location pair {pair + 1}/{args.pairs}", flush=True)
        if not all_passed:
            break

    summaries: dict[str, dict[str, dict[str, object]]] = {
        location: {} for location in roots
    }
    ratios: dict[str, float] = {}
    paired_location_delta: dict[str, dict[str, object]] = {}
    if all_passed:
        for location in roots:
            for tool in tools:
                values = [float(o["compile"]["elapsed_seconds"]) for o in observations[location][tool]]
                summaries[location][tool] = summarize(values)
            ratios[location] = round(
                summaries[location]["openc"]["median_seconds"]
                / summaries[location]["dmd"]["median_seconds"], 4
            )
        for tool in tools:
            deltas = [
                round(float(d["compile"]["elapsed_seconds"]) - float(c["compile"]["elapsed_seconds"]), 4)
                for c, d in zip(observations["c"][tool], observations["d"][tool])
            ]
            paired_location_delta[tool] = summarize(deltas)

    report = {
        "schema": "openc.sh27.storage_location.v1",
        "status": "PASS" if all_passed else "FAIL",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "workload": args.workload,
        "corpus_sha256": sha256(corpus_path),
        "compilers": {name: {"path": str(path), "sha256": sha256(path)} for name, path in tools.items()},
        "roots": {name: str(path) for name, path in roots.items()},
        "pairs": args.pairs,
        "observations": observations,
        "summaries": summaries,
        "openc_to_dmd": ratios,
        "d_minus_c_paired_seconds": paired_location_delta,
    }
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"SH-27 storage-location diagnostic: {report['status']}; ratios={ratios}; report={output}", flush=True)
    return 0 if all_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
