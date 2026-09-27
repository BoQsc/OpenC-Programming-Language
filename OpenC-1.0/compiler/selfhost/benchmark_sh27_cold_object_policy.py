#!/usr/bin/env python3
"""Compare normal direct PE and cold source-partition COFF on one source tree."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import statistics
import tempfile
import time

from windows_process_measure import run_measured

MIB = 1024 * 1024


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(
    compiler: Path, project: Path, root: Path, pair: int,
    mode: str, cache_enabled: bool,
) -> dict:
    free_bytes = shutil.disk_usage(root).free
    deadline = time.monotonic() + 30
    while free_bytes < 256 * MIB and time.monotonic() < deadline:
        time.sleep(1)
        free_bytes = shutil.disk_usage(root).free
    if free_bytes < 256 * MIB:
        raise RuntimeError(
            f"SH27_DISK_HEADROOM: {free_bytes} free bytes before {mode} "
            f"pair {pair}; need 256 MiB"
        )
    sample_dir = root / f"{mode}-{pair:02d}"
    sample_dir.mkdir(exist_ok=False)
    prefix = sample_dir / "program"
    executable = prefix.with_suffix(".exe")
    timing = prefix.with_suffix(".json")
    command = [str(compiler), "artifact", f"--project={project}"]
    if mode == "direct":
        command += ["--kind=exe", f"--output={executable}",
                    "--source-chunks=4"]
    else:
        command += [
            "--kind=module-coff-set", f"--output={prefix}",
            f"--linked-exe={executable}", "--source-partitions=32",
            "--source-chunks=4",
        ]
        if cache_enabled:
            cache_dir = sample_dir / "cache"
            cache_dir.mkdir()
            command.append(f"--cache-prefix={cache_dir / 'cold'}")
    command.append(f"--timings={timing}")
    result = run_measured(
        command, cwd=root, sample_interval=0.01,
        max_private_bytes=256 * MIB,
        max_working_set_bytes=64 * MIB,
        max_captured_output_bytes=MIB, timeout_seconds=120,
    )
    if result["exit_code"] != 0 or result["memory_limit_exceeded"] \
            or result["timed_out"] or not executable.is_file():
        raise RuntimeError(f"{mode} pair {pair} failed: {result}")
    data = json.loads(timing.read_text(encoding="utf-8"))
    sample = {
        "disk_free_bytes_before": free_bytes,
        "elapsed_seconds": result["elapsed_seconds"],
        "compiler_total_ms": data["total_ms"],
        "phases_ms": data["phases_ms"],
        "native_parallel_profile": data["native_parallel_profile"],
        "object_cache": data.get("object_cache", {}),
        "exe_sha256": sha256(executable),
        "peak_private_bytes": result["peak_private_bytes"],
        "peak_working_set_bytes": result["peak_working_set_bytes"],
    }
    if sample_dir.resolve().parent != root.resolve() or sample_dir.is_symlink():
        raise RuntimeError("refusing to clean a sample outside the temp root")
    shutil.rmtree(sample_dir)
    return sample


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--baseline", type=Path,
                        help="compare two cold COFF compiler revisions")
    parser.add_argument("--compare-cache", action="store_true",
                        help="compare uncached and cached 32-object writers")
    parser.add_argument("--uncached", action="store_true",
                        help="with --baseline, compare uncached writers")
    parser.add_argument("--pairs", type=int, default=5)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 3 <= args.pairs <= 31:
        parser.error("pairs must be 3..31")
    compiler = args.compiler.resolve(strict=True)
    baseline = args.baseline.resolve(strict=True) if args.baseline else None
    if baseline is not None and args.compare_cache:
        parser.error("--baseline and --compare-cache are separate matrices")
    if args.uncached and baseline is None:
        parser.error("--uncached requires --baseline")
    if baseline is not None and sha256(baseline) == sha256(compiler):
        parser.error("baseline and candidate compiler bytes are identical")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(output.parent).free < 512 * MIB:
        raise SystemExit("SH27_DISK_HEADROOM: need 512 MiB before cold matrix")
    project = Path(__file__).resolve().parent / "openc.project.json"
    modes = ("baseline", "candidate") if baseline else (
        ("coff32_uncached", "coff32") if args.compare_cache
        else ("direct", "coff32"))
    samples: dict[str, list[dict]] = {name: [] for name in modes}
    with tempfile.TemporaryDirectory(prefix="openc-cold-policy-") as temp:
        root = Path(temp)
        for pair in range(1, args.pairs + 1):
            order = modes if pair % 2 else tuple(reversed(modes))
            for mode in order:
                cache_enabled = mode not in ("direct", "coff32_uncached") \
                    and not args.uncached
                sample = build(baseline if mode == "baseline" else compiler,
                               project, root, pair, mode, cache_enabled)
                if cache_enabled:
                    cache = sample["object_cache"]
                    if cache["hits"] != 0 or cache["misses"] != 32:
                        raise RuntimeError(f"pair {pair} was not cold: {cache}")
                samples[mode].append(sample)
                print(f"pair {pair}/{args.pairs} {mode}: "
                      f"{sample['elapsed_seconds']:.3f}s", flush=True)
            output.write_text(json.dumps({
                "schema": "openc.sh27.cold_object_policy.v1",
                "status": "IN_PROGRESS", "pairs_complete": pair,
                "samples": samples,
            }, indent=2) + "\n", encoding="utf-8")
    summary = {
        mode: {
            "median_seconds": statistics.median(
                s["elapsed_seconds"] for s in group),
            "median_phases_ms": {
                phase: statistics.median(s["phases_ms"][phase] for s in group)
                for phase in group[0]["phases_ms"]
            },
            "median_worker_wall_ms": statistics.median(
                s["native_parallel_profile"]["workers_wall_ms"]
                for s in group),
            "peak_private_bytes": max(s["peak_private_bytes"] for s in group),
            "peak_working_set_bytes": max(
                s["peak_working_set_bytes"] for s in group),
            "stable_output": len({s["exe_sha256"] for s in group}) == 1,
        }
        for mode, group in samples.items()
    }
    report = {
        "schema": "openc.sh27.cold_object_policy.v1",
        "status": "PASS" if all(x["stable_output"] for x in summary.values())
        else "FAIL",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "compiler_sha256": sha256(compiler),
        "baseline_sha256": sha256(baseline) if baseline else None,
        "cache_enabled": not args.uncached,
        "project": str(project),
        "pairs": args.pairs,
        "summary": summary,
        "samples": samples,
    }
    if baseline is not None:
        deltas = [c["elapsed_seconds"] - b["elapsed_seconds"]
                  for b, c in zip(samples["baseline"], samples["candidate"])]
        report["comparison"] = {
            "paired_deltas_seconds": deltas,
            "median_paired_delta_seconds": statistics.median(deltas),
            "candidate_wins": sum(delta < 0 for delta in deltas),
            "cross_revision_output_exact": summary["baseline"][
                "stable_output"] and summary["candidate"]["stable_output"]
                and samples["baseline"][0]["exe_sha256"] ==
                samples["candidate"][0]["exe_sha256"],
        }
        if not report["comparison"]["cross_revision_output_exact"]:
            report["status"] = "FAIL"
    if args.compare_cache:
        report["comparison"] = {
            "cached_minus_uncached_seconds": [
                c["elapsed_seconds"] - u["elapsed_seconds"]
                for u, c in zip(samples["coff32_uncached"], samples["coff32"])
            ],
            "output_exact": samples["coff32_uncached"][0]["exe_sha256"] ==
                samples["coff32"][0]["exe_sha256"],
        }
        if not report["comparison"]["output_exact"]:
            report["status"] = "FAIL"
    output.write_text(json.dumps(report, indent=2) + "\n",
                      encoding="utf-8")
    print(f"SH-27 cold policy: {report['status']}; "
          f"medians=" + "/".join(
              f"{name}:{summary[name]['median_seconds']:.3f}s"
              for name in modes) + f"; report={output}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
