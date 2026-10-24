"""Paired direct/native-object cold, unchanged and implementation-edit builds."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import statistics
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--fixture", choices=("compiler", "medium"), default="compiler")
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--ordinary-build", action="store_true")
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.pairs <= 31 or args.report.exists():
        parser.error("pairs must be 1..31 and report must not exist")
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.native_cache_pairs.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "fixture": args.fixture,
              "ordinary_build": args.ordinary_build,
              "pairs": {lane: [] for lane in ("cold", "warm", "edit", "null")}}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    try:
        parent = ROOT / "build-output"
        parent.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="np-", dir=parent) as temporary:
            root = Path(temporary)
            project_dir = root / "project"
            project_dir.mkdir()
            if args.fixture == "compiler":
                canonical = ROOT / "compiler/selfhost"
                shutil.copytree(canonical / "source", project_dir / "source")
                data = json.loads((canonical / "openc.project.json").read_text())
                for name in ("standard_library_directory", "runtime_directory"):
                    data[name] = str((canonical / data[name]).resolve())
                data["output_directory"] = "build"
                edited = project_dir / "source/main.p"
                old = b"return value >= 48 && value <= 57;"
            else:
                modules = {name: [] for name in ("alpha", "beta", "gamma", "zapp")}
                for module, (name, paths) in enumerate(modules.items()):
                    for file in range(6):
                        path = f"m{module}_{file}.p"
                        paths.append(path)
                        source = ""
                        if module == 3 and file == 0:
                            source = ("import alpha; import beta; import gamma;\n"
                                      "i32 main() { return alpha.f0_0_0(1) + beta.f1_0_0(1) + gamma.f2_0_0(1) + f3_0_0(1); }\n")
                        for function in range(128):
                            source += (f"export i32 f{module}_{file}_{function}(i32 x) {{ "
                                       "i32 a = x + 1; i32 b = a * 2; return b + 2; }\n")
                        (project_dir / path).write_text(source, encoding="utf-8")
                data = {"name": "native-cache-medium", "version": "0.1.0",
                        "edition": "OpenC 1.0", "profile": "standard",
                        "target": "windows-x86_64", "modules": modules}
                edited = project_dir / "m0_0.p"
                old = b"return b + 2;"
            project = project_dir / "openc.project.json"
            project.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            original = edited.read_bytes()
            assert original.count(old) >= 1
            prefix = root / "cache/objects"
            prefix.parent.mkdir()
            number = 0

            def build(cached: bool, selected_prefix: Path = prefix) -> dict:
                nonlocal number
                number += 1
                output = root / f"p{number}.exe"
                if args.ordinary_build and cached:
                    output = selected_prefix.parent / "program.exe"
                timing = root / f"p{number}.json"
                command = [str(compiler), "artifact", f"--project={project}",
                           "--kind=" + ("cached-exe" if cached else "exe"),
                           f"--output={output}", f"--timings={timing}"]
                if cached:
                    command += [f"--cache-prefix={selected_prefix}"]
                if args.ordinary_build:
                    command = [str(compiler), "build", f"--project={project}",
                               f"--output={output}", f"--timings={timing}"]
                    if not cached: command.append("--no-cache")
                measured = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                assert measured["exit_code"] == 0 and not measured["memory_limit_exceeded"] and not measured["timed_out"], measured
                assert not measured["stdout_truncated"] and not measured["stderr_truncated"]
                timings = json.loads(timing.read_text())
                result = {"measurement": measured, "cache": timings.get("object_cache", {}),
                          "phases_ms": timings.get("phases_ms"), "sha256": sha256(output)}
                output.unlink()
                timing.unlink()
                return result

            # Prime source pages and the reusable base cache outside timing.
            report["preheat"] = build(False)
            report["prime"] = build(True)
            groups = report["prime"]["cache"]["misses"]
            assert groups >= 2 and report["prime"]["cache"]["hits"] == 0
            assert report["prime"]["cache"]["publish_failures"] == 0
            assert report["prime"]["sha256"] == report["preheat"]["sha256"]
            for pair in range(args.pairs):
                lanes = ("cold", "warm", "edit", "null")
                if pair % 2: lanes = tuple(reversed(lanes))
                for lane in lanes:
                    edited.write_bytes(original)
                    if lane in ("warm", "edit"):
                        # The bounded bundle retains the latest generation.
                        # Restore its base input outside the measured pair;
                        # undoing the preceding edit is itself a source edit.
                        primed = build(True)
                        assert primed["sha256"] == report["preheat"]["sha256"]
                    if lane == "edit":
                        new = (f"return value >= 48 && value <= {58 + pair};" if args.fixture == "compiler"
                               else f"return b + {3 + pair};").encode()
                        edited.write_bytes(original.replace(old, new, 1))
                    cold_prefix = root / f"cold{pair}/objects"
                    if lane == "cold": cold_prefix.parent.mkdir()
                    order = ("direct", "candidate") if (pair + lanes.index(lane)) % 2 == 0 else ("candidate", "direct")
                    samples = {}
                    for side in order:
                        cached = side == "candidate" and lane != "null"
                        samples[side] = build(cached, cold_prefix if lane == "cold" else prefix)
                    assert samples["direct"]["sha256"] == samples["candidate"]["sha256"], (lane, pair)
                    cache = samples["candidate"]["cache"]
                    if lane == "cold": assert cache["hits"] == 0 and cache["misses"] == groups, (lane, pair, cache)
                    if lane == "warm": assert cache["hits"] == groups and cache["misses"] == 0, (lane, pair, cache)
                    if lane == "edit": assert cache["hits"] == groups - 1 and cache["misses"] == 1, (lane, pair, cache)
                    delta = samples["candidate"]["measurement"]["elapsed_seconds"] - samples["direct"]["measurement"]["elapsed_seconds"]
                    report["pairs"][lane].append({"pair": pair + 1, "order": order,
                        "delta_seconds": delta, "samples": samples})
                    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
                    print(f"native-cache {args.fixture} {pair + 1}/{args.pairs} {lane}: {delta:+.6f}s", flush=True)
            edited.write_bytes(original)
            assert sha256(compiler) == report["compiler_sha256"]
        report["summary"] = {}
        for lane, records in report["pairs"].items():
            report["summary"][lane] = {
                "direct_seconds": statistics.median(r["samples"]["direct"]["measurement"]["elapsed_seconds"] for r in records),
                "candidate_seconds": statistics.median(r["samples"]["candidate"]["measurement"]["elapsed_seconds"] for r in records),
                "paired_delta_seconds": statistics.median(r["delta_seconds"] for r in records),
                "candidate_wins": sum(r["delta_seconds"] < 0 for r in records)}
        report["null_floor_seconds"] = statistics.median(abs(r["delta_seconds"]) for r in report["pairs"]["null"])
        floor = report["null_floor_seconds"]
        cold = report["summary"]["cold"]
        report["checks"] = {
            "cold_within_five_percent_or_null": cold["paired_delta_seconds"] <= max(
                0.05 * cold["direct_seconds"], floor),
            **{f"{lane}_gain_above_null": report["summary"][lane]["paired_delta_seconds"] < -floor
               and report["summary"][lane]["candidate_wins"] > args.pairs / 2
               for lane in ("warm", "edit")}}
        report["status"] = "PASS" if not args.enforce or all(report["checks"].values()) else "FAIL"
    except Exception as error:
        report["error"] = repr(error)
    finally:
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ("status", "summary", "checks", "null_floor_seconds", "error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
