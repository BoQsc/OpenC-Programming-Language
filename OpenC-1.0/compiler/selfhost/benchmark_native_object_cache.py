"""Paired direct/native-object cold, unchanged and implementation-edit builds."""
from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import statistics
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured


LANES = ("cold", "warm", "edit", "null")


def comparison_order(pair: int, lane: str) -> tuple[str, str]:
    # This ordinal must not come from the reversed execution sequence:
    # reversing both parity terms otherwise fixes every lane to one order.
    if (pair + LANES.index(lane)) % 2 == 0:
        return ("direct", "candidate")
    return ("candidate", "direct")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--fixture", choices=("compiler", "medium"), default="compiler")
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--ordinary-build", action="store_true")
    parser.add_argument("--baseline-compiler", type=Path)
    parser.add_argument("--compare-cold", action="store_true",
                        help="pair two compilers' cold publications, with a same-baseline null control")
    parser.add_argument("--processor-affinity-mask", type=lambda raw: int(raw, 0),
                        help="optional harness mask inherited by measured children; default is unchanged")
    parser.add_argument("--enforce", action="store_true")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.pairs <= 31 or args.report.exists():
        parser.error("pairs must be 1..31 and report must not exist")
    compiler = args.compiler.resolve(strict=True)
    if args.compare_cold and (args.baseline_compiler is None or args.fixture != "medium"):
        parser.error("--compare-cold requires --baseline-compiler and --fixture medium")
    baseline = args.baseline_compiler.resolve(strict=True) if args.baseline_compiler else compiler
    if args.processor_affinity_mask is not None:
        if os.name != "nt" or args.processor_affinity_mask <= 0:
            parser.error("affinity requires Windows and a positive mask")
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.GetCurrentProcess.restype = wintypes.HANDLE
        kernel.SetProcessAffinityMask.argtypes = (wintypes.HANDLE, ctypes.c_size_t)
        kernel.SetProcessAffinityMask.restype = wintypes.BOOL
        if not kernel.SetProcessAffinityMask(kernel.GetCurrentProcess(), args.processor_affinity_mask):
            raise ctypes.WinError(ctypes.get_last_error())
    lanes_to_run = ("cold", "null") if args.compare_cold else LANES
    report = {"schema": "openc.sh27.native_cache_pairs.v2", "status": "FAIL",
              "pair_order_policy": "alternating_fixed_lane_ordinal",
              "compiler_sha256": sha256(compiler), "fixture": args.fixture,
              "ordinary_build": args.ordinary_build,
              "pairs": {lane: [] for lane in lanes_to_run}}
    if args.compare_cold:
        report["comparison"] = "cold_publication_between_compilers"
        report["baseline_compiler_sha256"] = sha256(baseline)
    report["inherited_processor_affinity_mask"] = (
        hex(args.processor_affinity_mask) if args.processor_affinity_mask is not None else None)
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

            def build(cached: bool, selected_prefix: Path = prefix, tool: Path = compiler) -> dict:
                nonlocal number
                number += 1
                output = root / f"p{number}.exe"
                if args.ordinary_build and cached:
                    output = selected_prefix.parent / "program.exe"
                timing = root / f"p{number}.json"
                command = [str(tool), "artifact", f"--project={project}",
                           "--kind=" + ("cached-exe" if cached else "exe"),
                           f"--output={output}", f"--timings={timing}"]
                if cached:
                    command += [f"--cache-prefix={selected_prefix}"]
                if args.ordinary_build:
                    command = [str(tool), "build", f"--project={project}",
                               f"--output={output}", f"--timings={timing}"]
                    if not cached: command.append("--no-cache")
                measured = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                assert measured["exit_code"] == 0 and not measured["memory_limit_exceeded"] and not measured["timed_out"], measured
                assert not measured["stdout_truncated"] and not measured["stderr_truncated"]
                timings = json.loads(timing.read_text())
                result = {"measurement": measured, "cache": timings.get("object_cache", {}),
                          "frontend": timings.get("frontend_cache", {}),
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
                lanes = lanes_to_run
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
                    order = comparison_order(pair, lane)
                    samples = {}
                    for side in order:
                        cached = side == "candidate" and lane != "null"
                        selected_prefix = cold_prefix if lane == "cold" else prefix
                        tool = compiler
                        if args.compare_cold:
                            tool = baseline if side == "direct" or lane == "null" else compiler
                            cached = True
                            selected_prefix = root / f"{lane}{pair}-{side}/objects"
                            selected_prefix.parent.mkdir()
                        samples[side] = build(cached, selected_prefix, tool)
                    assert samples["direct"]["sha256"] == samples["candidate"]["sha256"], (lane, pair)
                    cache = samples["candidate"]["cache"]
                    if lane == "cold": assert cache["hits"] == 0 and cache["misses"] == groups, (lane, pair, cache)
                    if lane == "warm": assert cache["hits"] == groups and cache["misses"] == 0, (lane, pair, cache)
                    if lane == "edit": assert cache["hits"] == groups - 1 and cache["misses"] == 1, (lane, pair, cache)
                    if lane in ("warm", "edit"):
                        expected = sum(map(len, data["modules"].values())) - (lane == "edit")
                        frontend = samples["candidate"]["frontend"]
                        assert frontend.get("predeclare_hits") == expected, (lane, pair, frontend)
                        assert frontend.get("resolution_hits") == expected, (lane, pair, frontend)
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
               for lane in ("warm", "edit") if lane in report["summary"]}}
        if args.compare_cold:
            report["checks"] = {
                "cold_gain_above_null": cold["paired_delta_seconds"] < -floor and
                    cold["candidate_wins"] > args.pairs / 2}
        report["status"] = "PASS" if not args.enforce or all(report["checks"].values()) else "FAIL"
    except Exception as error:
        report["error"] = repr(error)
    finally:
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ("status", "summary", "checks", "null_floor_seconds", "error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
