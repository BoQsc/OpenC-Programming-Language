#!/usr/bin/env python3
"""Order-alternated, RAM-guarded edited-source cache comparison.

Both compiler revisions build one copied self-host project. Each pair applies a
new body edit, so a prior cache entry cannot turn the edit into a no-op hit.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import tempfile

from windows_process_measure import run_measured

MIB = 1024 * 1024


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(
    compiler: Path, project: Path, root: Path, cache_prefix: Path,
    name: str, pair: int,
) -> dict:
    prefix = root / f"{name}-{pair:02d}"
    executable = prefix.with_suffix(".exe")
    timings = prefix.with_suffix(".json")
    result = run_measured(
        [
            str(compiler), "artifact", f"--project={project}",
            "--kind=module-coff-set", f"--output={prefix}",
            f"--linked-exe={executable}", "--source-partitions=32",
            "--source-chunks=4", f"--cache-prefix={cache_prefix}",
            f"--timings={timings}",
        ],
        cwd=root, sample_interval=0.01, max_private_bytes=256 * MIB,
        max_working_set_bytes=64 * MIB,
        max_captured_output_bytes=MIB, timeout_seconds=120,
    )
    if result["exit_code"] != 0 or result["memory_limit_exceeded"] \
            or result["timed_out"] or not executable.is_file():
        raise RuntimeError(f"{name} pair {pair} failed: {result}")
    data = json.loads(timings.read_text(encoding="utf-8"))
    return {
        "elapsed_seconds": result["elapsed_seconds"],
        "compiler_total_ms": data["total_ms"],
        "phases_ms": data["phases_ms"],
        "object_cache": data["object_cache"],
        "exe_sha256": digest(executable),
        "peak_private_bytes": result["peak_private_bytes"],
        "peak_working_set_bytes": result["peak_working_set_bytes"],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 3 <= args.pairs <= 31:
        parser.error("pairs must be 3..31")
    baseline = args.baseline.resolve(strict=True)
    candidate = args.candidate.resolve(strict=True)
    if digest(baseline) == digest(candidate):
        parser.error("baseline and candidate must have different bytes")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    compiler_dir = Path(__file__).resolve().parent
    measurements: dict[str, list[dict]] = {"baseline": [], "candidate": []}
    with tempfile.TemporaryDirectory(prefix="openc-semantic-pairs-") as temp:
        root = Path(temp)
        project_dir = root / "project"
        shutil.copytree(compiler_dir / "source", project_dir / "source")
        project_data = json.loads(
            (compiler_dir / "openc.project.json").read_text(encoding="utf-8")
        )
        project_data["standard_library_directory"] = str(
            (compiler_dir / "../../standard_library").resolve(strict=True)
        )
        project_data["runtime_directory"] = str(
            (compiler_dir / "../../runtime").resolve(strict=True)
        )
        project_data["output_directory"] = str(root / "build")
        project = project_dir / "openc.project.json"
        project.write_text(json.dumps(project_data, indent=2) + "\n",
                           encoding="utf-8")
        cache = root / "cache"
        cache.mkdir()
        prefixes = {name: cache / name for name in measurements}
        for name, compiler in (("baseline", baseline),
                               ("candidate", candidate)):
            sample = build(compiler, project, root, prefixes[name],
                           name, 0)
            if sample["object_cache"]["hits"] != 0 or \
                    sample["object_cache"]["misses"] != 32:
                raise RuntimeError(f"{name} did not cold-seed 32 objects")
            print(f"seed {name}: {sample['elapsed_seconds']:.3f}s", flush=True)

        main_source = project_dir / "source" / "main.p"
        original = main_source.read_bytes()
        needle = b"return value >= 48 && value <= 57;"
        if original.count(needle) != 1:
            raise RuntimeError("expected self-host edit anchor exactly once")
        for pair in range(1, args.pairs + 1):
            replacement = (
                f"return value >= {47 - pair} && value <= {58 + pair};"
            ).encode("ascii")
            main_source.write_bytes(original.replace(needle, replacement, 1))
            order = ("baseline", "candidate") if pair % 2 else (
                "candidate", "baseline")
            for name in order:
                sample = build(
                    baseline if name == "baseline" else candidate,
                    project, root, prefixes[name], name, pair,
                )
                cache_result = sample["object_cache"]
                if cache_result["hits"] != 31 or cache_result["misses"] != 1:
                    raise RuntimeError(
                        f"{name} pair {pair} was not a one-partition edit: "
                        f"{cache_result}"
                    )
                measurements[name].append(sample)
                print(f"pair {pair}/{args.pairs} {name}: "
                      f"{sample['elapsed_seconds']:.3f}s", flush=True)
            if measurements["baseline"][-1]["exe_sha256"] != \
                    measurements["candidate"][-1]["exe_sha256"]:
                raise RuntimeError(f"pair {pair} output bytes differ")
            output.write_text(json.dumps({
                "schema": "openc.sh27.selective_semantic_cache.paired.v1",
                "status": "IN_PROGRESS", "pairs_complete": pair,
                "samples": measurements,
            }, indent=2) + "\n", encoding="utf-8")

    baseline_times = [s["elapsed_seconds"] for s in measurements["baseline"]]
    candidate_times = [s["elapsed_seconds"] for s in measurements["candidate"]]
    deltas = [c - b for b, c in zip(baseline_times, candidate_times)]
    baseline_median = statistics.median(baseline_times)
    candidate_median = statistics.median(candidate_times)
    candidate_wins = sum(delta < 0 for delta in deltas)
    gains = baseline_median > 0 and candidate_median <= baseline_median * .9 \
        and candidate_wins >= (args.pairs * 3 + 3) // 4
    selective = all(
        s["object_cache"]["flow_sources_skipped"] > 0 and
        s["object_cache"]["flow_sources_skipped"] ==
        s["object_cache"]["acceptance_sources_skipped"]
        for s in measurements["candidate"]
    )
    report = {
        "schema": "openc.sh27.selective_semantic_cache.paired.v1",
        "status": "PASS" if gains and selective else "FAIL",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "baseline_sha256": digest(baseline),
        "candidate_sha256": digest(candidate),
        "pairs": args.pairs,
        "baseline_median_seconds": baseline_median,
        "candidate_median_seconds": candidate_median,
        "candidate_wins": candidate_wins,
        "paired_deltas_seconds": deltas,
        "checks": {
            "at_least_10_percent_median_gain": gains,
            "candidate_skipped_unchanged_sources": selective,
            "all_outputs_exact": True,
            "all_processes_within_64_256_mib_caps": True,
        },
        "samples": measurements,
    }
    output.write_text(json.dumps(report, indent=2) + "\n",
                      encoding="utf-8")
    print(f"SH-27 selective semantic cache: {report['status']}; "
          f"medians={baseline_median:.3f}/{candidate_median:.3f}s; "
          f"candidate wins={candidate_wins}/{args.pairs}; report={output}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
