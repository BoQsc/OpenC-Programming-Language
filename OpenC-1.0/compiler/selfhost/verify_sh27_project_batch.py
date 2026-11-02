#!/usr/bin/env python3
"""Compare serial and concurrent builds of four retained OpenC projects."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import statistics
import tempfile
import time
import traceback

from benchmark_sh27_production import ROOT, MIB, require_disk_headroom, sha256
from benchmark_sh27_representative import DEFAULT_SUITE, load_suite, stage_project
from windows_process_measure import run_measured


def measurement_passes(sample: dict, exit_code: int = 0) -> bool:
    return (sample["job_assigned_before_child_execution"] is True
            and sample["exit_code"] == exit_code and not sample["memory_limit_exceeded"]
            and not sample["timed_out"] and not sample["stdout_truncated"]
            and not sample["stderr_truncated"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=5)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 3 <= args.pairs <= 11 or args.output.exists():
        parser.error("pairs must be 3..11; output must not already exist")
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    require_disk_headroom(output.parent, 4 * 1024 * MIB)
    workloads = load_suite(DEFAULT_SUITE)["workloads"] + [{
        "id": "maintained_computation", "project": "programs/A_COMPUTATION/openc.project.json",
        "input_files": [], "run_arguments": [], "expected_stdout_utf8": "",
        "expected_stderr_utf8": "", "expected_exit_code": 32,
    }]
    report = {
        "schema": "openc.sh27.representative_project_batch.v1", "status": "FAIL",
        "compiler_sha256": sha256(compiler), "pairs": args.pairs,
        "projects": [w["id"] for w in workloads],
        "build_policy": "ordinary build; separate cold/warm/edit projects and caches for every side",
        "timing_basis": "parent perf_counter around compiler batch including bounded result capture; program execution follows timing",
        "limits": {"compiler_private_bytes": 256 * MIB,
                   "compiler_working_set_bytes": 64 * MIB,
                   "required_outer_job_private_bytes": 512 * MIB},
        "cases": {},
    }
    try:
        with tempfile.TemporaryDirectory(prefix="p4-", dir=ROOT / "build-output") as temporary:
            root = Path(temporary)

            def compile_one(record: dict, label: str) -> dict:
                project = Path(record["project"])
                binary = project.parent / "program.exe"
                timing = project.parent / (label + "-timings.json")
                command = [str(compiler), "build", f"--project={project}",
                           f"--output={binary}", f"--timings={timing}"]
                measured = run_measured(command, cwd=project.parent,
                    sample_interval=.01, max_private_bytes=256 * MIB,
                    max_working_set_bytes=64 * MIB, max_captured_output_bytes=MIB,
                    timeout_seconds=120)
                return {"command": command, "measurement": measured,
                        "binary": str(binary), "timing_path": str(timing)}

            def inspect_build(result: dict, workload: dict, category: str) -> None:
                assert measurement_passes(result["measurement"]), result
                binary = Path(result["binary"])
                result["sha256"] = sha256(binary)
                result["bytes"] = binary.stat().st_size
                result["timings"] = json.loads(Path(result["timing_path"]).read_text())
                if workload["id"] == "compiler_self_build":
                    cache = result["timings"]["object_cache"]
                    if category == "cold":
                        assert cache["hits"] == 0 and cache["misses"] >= 2, cache
                    elif category == "warm":
                        assert cache["hits"] >= 2 and cache["misses"] == 0, cache
                    elif category == "edit":
                        assert cache["hits"] >= 1 and cache["misses"] >= 1, cache
                    if category != "edit":
                        assert result["sha256"] == report["compiler_sha256"]
                ran = run_measured([str(binary), *workload["run_arguments"]],
                    cwd=binary.parent, sample_interval=.01, max_private_bytes=128 * MIB,
                    max_working_set_bytes=64 * MIB, max_captured_output_bytes=MIB,
                    timeout_seconds=30)
                result["execution"] = ran
                expected = workload["edit"]["expected_stdout_utf8"] if category == "edit" and "edit" in workload else workload["expected_stdout_utf8"]
                assert measurement_passes(ran, workload.get("expected_exit_code", 0)), ran
                assert ran["stdout"] == expected and ran["stderr"] == workload["expected_stderr_utf8"], ran

            for category_index, category in enumerate(("cold", "warm", "edit")):
                cases = []
                report["cases"][category] = cases
                for pair in range(args.pairs):
                    case = {"pair": pair + 1, "sides": {}}
                    cases.append(case)
                    groups = [["serial", "parallel"], ["null_a", "null_b"]]
                    if (pair + category_index) % 2:
                        groups = [list(reversed(g)) for g in reversed(groups)]
                    case["order"] = [side for group in groups for side in group]
                    for side in case["order"]:
                        records = []
                        side_record = {"projects": records}
                        case["sides"][side] = side_record
                        for index, workload in enumerate(workloads):
                            directory = root / f"{category_index}{pair}{side[0:1]}{side[-1:]}{index}"
                            project, source_tree = stage_project(workload, directory)
                            record = {"id": workload["id"], "project": str(project),
                                      "source_tree": source_tree}
                            records.append(record)
                            if category != "cold":
                                record["prime"] = compile_one(record, "prime")
                                assert measurement_passes(record["prime"]["measurement"]), record["prime"]
                                if category == "edit" and "edit" in workload:
                                    edit = workload["edit"]
                                    target = directory / edit["path"]
                                    original = target.read_bytes()
                                    marker = edit["old"].encode("utf-8")
                                    assert original.count(marker) == 1
                                    target.write_bytes(original.replace(marker, edit["new"].encode("utf-8"), 1))
                                    record["edit"] = {"path": edit["path"],
                                        "before_sha256": hashlib.sha256(original).hexdigest(),
                                        "after_sha256": sha256(target)}
                        started = time.perf_counter()
                        if side == "parallel":
                            with ThreadPoolExecutor(max_workers=4) as executor:
                                results = list(executor.map(lambda r: compile_one(r, "measured"), records))
                        else:
                            results = [compile_one(r, "measured") for r in records]
                        side_record["wall_seconds"] = time.perf_counter() - started
                        for record, result, workload in zip(records, results, workloads):
                            record["result"] = result
                            inspect_build(result, workload, category)
                    sides = case["sides"]
                    for index in range(4):
                        assert len({s["projects"][index]["result"]["sha256"] for s in sides.values()}) == 1
                    print(category, pair + 1, "four-project batch passed", flush=True)
            report["summary"] = {}
            for category, cases in report["cases"].items():
                serial = [c["sides"]["serial"]["wall_seconds"] for c in cases]
                parallel = [c["sides"]["parallel"]["wall_seconds"] for c in cases]
                null = [abs(c["sides"]["null_a"]["wall_seconds"] - c["sides"]["null_b"]["wall_seconds"]) for c in cases]
                delta = statistics.median(b - a for a, b in zip(serial, parallel))
                noise = statistics.median(null)
                summary = {"serial_median_seconds": statistics.median(serial),
                           "parallel_median_seconds": statistics.median(parallel),
                           "paired_delta_seconds": delta, "null_floor_seconds": noise,
                           "parallel_wins": sum(b < a for a, b in zip(serial, parallel)),
                           "within_five_percent_or_null": delta <= max(.05 * statistics.median(serial), noise)}
                report["summary"][category] = summary
            assert all(s["within_five_percent_or_null"] for s in report["summary"].values()), report["summary"]
            report["status"] = "PASS"
    except Exception as error:
        report["error"] = repr(error)
        report["traceback"] = traceback.format_exc()
    finally:
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("SH-27 retained four-project batches:", report["status"], report.get("error", ""), flush=True)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
