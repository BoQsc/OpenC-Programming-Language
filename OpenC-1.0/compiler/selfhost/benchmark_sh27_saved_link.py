"""Pair authenticated native relinks of one immutable COFF object set."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import statistics
import tempfile

from benchmark_sh27_production import MIB, require_disk_headroom, sha256
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--object-root", type=Path, default=Path.cwd())
    parser.add_argument("--entry", required=True)
    parser.add_argument("--expected-exe", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-gain", action="store_true")
    args = parser.parse_args()
    if not 1 <= args.pairs <= 31:
        parser.error("pairs must be 1..31")
    output = args.output.resolve()
    if output.exists():
        parser.error("refusing to replace an existing report")
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    compilers = {name: path.resolve(strict=True) for name, path in
                 (("baseline", args.baseline), ("candidate", args.candidate))}
    manifest_path = args.manifest.resolve(strict=True)
    if manifest_path.stat().st_size > MIB:
        parser.error("manifest exceeds 1 MiB")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("status") != "COMPLETE":
        parser.error("input object set is not COMPLETE")
    units = manifest.get("partitions", manifest.get("modules", []))
    if not 1 <= len(units) <= 64:
        parser.error("object count must be 1..64")
    inputs = []
    records = []
    for unit in units:
        path = (args.object_root / unit["object"]).resolve(strict=True)
        if path.stat().st_size > 16 * MIB or sha256(path) != unit["sha256"]:
            parser.error(f"object authentication failed: {path.name}")
        inputs += [f"--object={path}", f"--sha256={unit['sha256']}"]
        records.append({"path": str(path), "sha256": unit["sha256"],
                        "bytes": path.stat().st_size})
    expected = sha256(args.expected_exe.resolve(strict=True))
    report = {"schema": "openc.sh27.saved_link_pairs.v1", "status": "INCOMPLETE",
              "compilers": {name: {"path": str(path), "sha256": sha256(path)}
                            for name, path in compilers.items()},
              "manifest_sha256": sha256(manifest_path), "objects": records,
              "entry": args.entry, "expected_exe_sha256": expected,
              "limits": {"private_bytes": 256 * MIB, "working_set_bytes": 64 * MIB},
              "pairs": [], "null_pairs": []}
    try:
        for pair in range(args.pairs):
            # Rotate real/null order and reverse adjacent process order.
            names = ("candidate", "null") if pair % 2 == 0 else ("null", "candidate")
            for ordinal, name in enumerate(names):
                samples = {}
                order = ("baseline", "candidate") if (pair + ordinal) % 2 == 0 else ("candidate", "baseline")
                for side in order:
                    compiler = compilers[side] if name != "null" else compilers["baseline"]
                    with tempfile.TemporaryDirectory(prefix="sl-") as temporary:
                        directory = Path(temporary)
                        executable = directory / "program.exe"
                        result = run_measured(
                            [str(compiler), "module-coff-link", f"--entry={args.entry}",
                             f"--output={executable}", *inputs],
                            cwd=args.object_root.resolve(), sample_interval=0.01,
                            max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                            max_captured_output_bytes=MIB, timeout_seconds=120)
                        digest = sha256(executable) if executable.is_file() else None
                        passed = (result["exit_code"] == 0 and
                                  not result["memory_limit_exceeded"] and not result["timed_out"] and
                                  not result["stdout_truncated"] and not result["stderr_truncated"] and
                                  digest == expected)
                        samples[side] = {"measurement": result, "exe_sha256": digest,
                                         "passed": passed}
                        if not passed:
                            report["failed_sample"] = {"pair": pair + 1, "lane": name,
                                                       "side": side, **samples[side]}
                            raise RuntimeError(f"failed {name} pair {pair + 1} {side}")
                delta = samples["candidate"]["measurement"]["elapsed_seconds"] - samples["baseline"]["measurement"]["elapsed_seconds"]
                record = {"pair": pair + 1, "order": list(order),
                          "delta_seconds": round(delta, 6), "samples": samples}
                report["null_pairs" if name == "null" else "pairs"].append(record)
                output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
                print(f"saved-link {pair + 1}/{args.pairs} {name}: {delta:+.6f}s", flush=True)
        deltas = [p["delta_seconds"] for p in report["pairs"]]
        null = statistics.median(abs(p["delta_seconds"]) for p in report["null_pairs"])
        baseline = statistics.median(p["samples"]["baseline"]["measurement"]["elapsed_seconds"] for p in report["pairs"])
        candidate = statistics.median(p["samples"]["candidate"]["measurement"]["elapsed_seconds"] for p in report["pairs"])
        median = statistics.median(deltas)
        report["summary"] = {"baseline_seconds": baseline, "candidate_seconds": candidate,
                             "paired_delta_seconds": median, "null_floor_seconds": null,
                             "candidate_wins": sum(x < 0 for x in deltas),
                             "speedup": baseline / candidate}
        report["checks"] = {
            "all_relinks_exact_and_guarded": len(report["pairs"]) == args.pairs,
            "input_objects_unchanged": all(sha256(Path(r["path"])) == r["sha256"] for r in records),
            "gain_above_null_floor": median < -null and sum(x < 0 for x in deltas) > args.pairs / 2,
        }
        passed = report["checks"]["all_relinks_exact_and_guarded"] and report["checks"]["input_objects_unchanged"]
        if args.require_gain:
            passed = passed and report["checks"]["gain_above_null_floor"]
        report["status"] = "PASS" if passed else "FAIL"
    except Exception as error:
        report["status"] = "FAIL"
        report["error"] = str(error)
    finally:
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report.get(key) for key in ("status", "summary", "error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
