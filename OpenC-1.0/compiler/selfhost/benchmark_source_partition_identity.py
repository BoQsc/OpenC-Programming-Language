"""Paired guarded proof for preparing COFF identities once per source set.

Both compilers build the checked-out project without a cache. Pair order
alternates to avoid giving either compiler a consistent warm-host advantage.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics
import tempfile

from windows_process_measure import run_measured

MIB = 1024 * 1024


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def input_digest(project: Path) -> tuple[str, int]:
    source = project.parent / "source"
    paths = [project, *sorted(source.glob("*.p"))]
    hasher = hashlib.sha256()
    for path in paths:
        relative = path.relative_to(project.parent).as_posix().encode()
        data = path.read_bytes()
        hasher.update(len(relative).to_bytes(4, "little"))
        hasher.update(relative)
        hasher.update(len(data).to_bytes(8, "little"))
        hasher.update(data)
    return hasher.hexdigest(), len(paths) - 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--project", type=Path,
                        default=Path(__file__).with_name("openc.project.json"))
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--partitions", type=int, default=32)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.pairs <= 31 or not 2 <= args.partitions <= 32:
        parser.error("pairs must be 1..31 and partitions 2..32")
    compilers = {
        "baseline": args.baseline.resolve(strict=True),
        "candidate": args.candidate.resolve(strict=True),
    }
    project = args.project.resolve(strict=True)
    source_sha, source_count = input_digest(project)
    report = {
        "schema": "openc.sh27.source_partition_identity_pairs.v1",
        "status": "FAIL", "project": str(project),
        "project_input_sha256": source_sha,
        "source_files": source_count,
        "partitions": args.partitions,
        "pairs": args.pairs,
        "compiler_sha256": {k: digest(v) for k, v in compilers.items()},
        "samples": [],
    }
    try:
        with tempfile.TemporaryDirectory(prefix="openc-partition-pairs-") as temp:
            root = Path(temp)
            for pair in range(args.pairs):
                order = ("baseline", "candidate") if pair % 2 == 0 else (
                    "candidate", "baseline")
                runs = {}
                for name in order:
                    folder = root / f"pair-{pair + 1:02d}-{name}"
                    folder.mkdir()
                    prefix = folder / "part"
                    exe = folder / "program.exe"
                    timings = folder / "timings.json"
                    command = [
                        str(compilers[name]), "artifact", f"--project={project}",
                        "--kind=module-coff-set", f"--output={prefix}",
                        f"--linked-exe={exe}",
                        f"--source-partitions={args.partitions}",
                        "--source-chunks=1", f"--timings={timings}",
                    ]
                    measure = run_measured(
                        command, cwd=root, sample_interval=0.01,
                        max_private_bytes=256 * MIB,
                        max_working_set_bytes=64 * MIB,
                        max_captured_output_bytes=MIB, timeout_seconds=120,
                    )
                    if measure["exit_code"] != 0 or measure[
                        "memory_limit_exceeded"] or measure["timed_out"]:
                        raise RuntimeError(f"{name} pair {pair + 1}: {measure}")
                    manifest = json.loads((folder / "part.modules.json").read_text())
                    if manifest["status"] != "COMPLETE" or len(
                        manifest["partitions"]) != args.partitions:
                        raise RuntimeError(f"{name} pair {pair + 1}: incomplete COFF set")
                    timing = json.loads(timings.read_text())
                    runs[name] = {
                        "elapsed_seconds": measure["elapsed_seconds"],
                        "peak_private_bytes": measure["peak_private_bytes"],
                        "peak_working_set_bytes": measure["peak_working_set_bytes"],
                        "exe_sha256": digest(exe),
                        "objects_sha256": [p["sha256"] for p in manifest["partitions"]],
                        "phases_ms": timing.get("phases_ms", {}),
                    }
                if runs["baseline"]["exe_sha256"] != runs[
                    "candidate"]["exe_sha256"] or runs[
                    "baseline"]["objects_sha256"] != runs[
                    "candidate"]["objects_sha256"]:
                    raise RuntimeError(f"pair {pair + 1}: output differs")
                delta = runs["baseline"]["elapsed_seconds"] - runs[
                    "candidate"]["elapsed_seconds"]
                report["samples"].append({
                    "pair": pair + 1, "order": list(order), "runs": runs,
                    "saved_seconds": round(delta, 6),
                })
                print(f"pair {pair + 1}/{args.pairs}: saved {delta:.3f}s", flush=True)
        saved = [s["saved_seconds"] for s in report["samples"]]
        old = [s["runs"]["baseline"]["elapsed_seconds"] for s in report["samples"]]
        new = [s["runs"]["candidate"]["elapsed_seconds"] for s in report["samples"]]
        baseline_median = statistics.median(old)
        candidate_median = statistics.median(new)
        report["summary"] = {
            "baseline_median_seconds": baseline_median,
            "candidate_median_seconds": candidate_median,
            "paired_median_saved_seconds": statistics.median(saved),
            "median_speedup": baseline_median / candidate_median,
            "wins": sum(x > 0 for x in saved),
            "output_byte_exact": True,
        }
        report["status"] = "PASS" if min(saved) > 0 and (
            baseline_median - candidate_median) / baseline_median >= 0.20 else "FAIL"
    except Exception as exc:
        report["error"] = str(exc)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"],
                      "summary": report.get("summary"),
                      "error": report.get("error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
