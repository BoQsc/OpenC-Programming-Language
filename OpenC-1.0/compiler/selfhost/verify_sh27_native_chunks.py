#!/usr/bin/env python3
"""Guarded byte-equivalence proof for the experimental native source chunks."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil

from benchmark_sh27_production import (
    MIB, ROOT, generate_language, require_disk_headroom, run_measured,
    sha256, validate_corpus,
)


def timing_accounting_valid(
    timing: object, chunked: bool, source_chunks: int | str,
) -> bool:
    if not isinstance(timing, dict):
        return False
    if source_chunks == "auto":
        files = timing.get("source_files", 0)
        size = timing.get("source_bytes", 0)
        selected = (
            4 if files >= 4 and 524288 <= size <= 3145728
            else 2 if files >= 2 and 196608 <= size <= 4194304
            else 1
        )
    else:
        selected = source_chunks
    expected_chunks = (
        selected if chunked and timing.get("source_files", 0) >= selected
        and selected != 1
        else 0
    )
    return bool(
        timing.get("status") == "PASS"
        and timing.get("parallel_source_chunks") == expected_chunks
        and timing.get("source_chunks_policy") == (
            "auto" if chunked and source_chunks == "auto"
            else "explicit_or_default"
        )
        and timing.get("phase_accounting") == (
            "wall_elapsed_with_acceptance_in_lowering"
            if expected_chunks else "wall_elapsed_with_acceptance_in_validation"
        )
        and timing.get("validation_profile", {}).get("acceptance_time_basis") == (
            "summed_worker_elapsed" if expected_chunks else "wall_elapsed"
        )
    )


def measured_build(
    compiler: Path, project: Path, output: Path, chunked: bool,
    source_chunks: int | str = 4,
) -> dict[str, object]:
    output.parent.mkdir(parents=True, exist_ok=False)
    disk_free_before = require_disk_headroom(output)
    timing = output.parent / "timings.json"
    if chunked:
        command = [
            str(compiler), "artifact", f"--project={project}", "--kind=exe",
            f"--output={output}", f"--source-chunks={source_chunks}",
            f"--report={output.parent / 'artifact.json'}",
            f"--timings={timing}",
        ]
    else:
        command = [
            str(compiler), "build", f"--project={project}",
            f"--output={output}",
            f"--timings={timing}",
        ]
    sample = run_measured(
        command, cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=180,
    )
    sample["command"] = command
    sample["disk_free_bytes_before"] = disk_free_before
    sample["output_exists"] = output.is_file()
    sample["output_sha256"] = sha256(output) if output.is_file() else None
    sample["output_bytes"] = output.stat().st_size if output.is_file() else None
    sample["compiler_timings"] = (
        json.loads(timing.read_text(encoding="utf-8"))
        if timing.is_file() else None
    )
    sample["timing_accounting_valid"] = timing_accounting_valid(
        sample["compiler_timings"], chunked, source_chunks
    )
    sample["passed"] = bool(
        sample["exit_code"] == 0
        and not sample["timed_out"]
        and not sample["memory_limit_exceeded"]
        and not sample["stdout_truncated"]
        and not sample["stderr_truncated"]
        and sample["output_exists"]
        and sample["timing_accounting_valid"]
    )
    (output.parent / "measurement.json").write_text(
        json.dumps(sample, indent=2) + "\n", encoding="utf-8"
    )
    return sample


def main() -> int:
    if os.name != "nt":
        raise SystemExit("native source chunk proof currently requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-chunks", choices=("2", "4", "auto"), default="4")
    args = parser.parse_args()
    source_chunks: int | str = (
        args.source_chunks if args.source_chunks == "auto"
        else int(args.source_chunks)
    )
    compiler = args.compiler.resolve()
    if not compiler.is_file():
        raise SystemExit(f"missing compiler: {compiler}")
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    run_root = output.parent / (
        output.stem + "-runs-" +
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)
    corpus = json.loads((ROOT / "benchmarks/sh27/CORPUS.json").read_text())
    validate_corpus(corpus)
    workloads: list[tuple[str, Path]] = [
        ("selfhost", ROOT / "compiler/selfhost/openc.project.json")
    ]
    for workload in corpus["workloads"]:
        if workload["id"] not in {
            "small_single_file", "many_files", "large_functions", "control_flow"
        }:
            continue
        generated = generate_language(
            run_root / "sources" / str(workload["id"]), "openc", workload
        )
        workloads.append((str(workload["id"]), Path(generated["project"])))
    results: dict[str, object] = {}
    passed = True
    for name, project in workloads:
        serial = measured_build(
            compiler, project, run_root / name / "serial" / "program.exe", False
        )
        chunked = measured_build(
            compiler, project, run_root / name / "chunked" / "program.exe", True,
            source_chunks,
        )
        exact = bool(
            serial["passed"] and chunked["passed"]
            and serial["output_sha256"] == chunked["output_sha256"]
            and serial["output_bytes"] == chunked["output_bytes"]
        )
        results[name] = {
            "serial": serial, "chunked": chunked, "byte_exact": exact
        }
        passed = passed and exact
        print(
            f"{name}: exact={exact} serial_job_peak={serial['peak_job_private_bytes']} "
            f"chunked_job_peak={chunked['peak_job_private_bytes']}", flush=True
        )
    invalid_root = run_root / "invalid_control_flow"
    shutil.copytree(run_root / "sources" / "control_flow", invalid_root)
    invalid_source = invalid_root / "source_0002.p"
    original = invalid_source.read_text(encoding="ascii")
    needle = "value = value + 97;"
    if needle not in original:
        raise RuntimeError("control-flow diagnostic fixture shape changed")
    invalid_source.write_text(
        original.replace(needle, "value = value + true;", 1),
        encoding="ascii", newline="\n",
    )
    invalid_project = invalid_root / "openc.project.json"
    invalid_serial = measured_build(
        compiler, invalid_project,
        run_root / "invalid" / "serial" / "program.exe", False,
    )
    invalid_chunked = measured_build(
        compiler, invalid_project,
        run_root / "invalid" / "chunked" / "program.exe", True,
        source_chunks,
    )
    serial_diagnostics = str(invalid_serial["stdout"])
    chunked_diagnostics = str(invalid_chunked["stdout"]).replace(
        "OpenC Windows artifact: FAIL (exe)\n", ""
    )
    diagnostic_exact = bool(
        invalid_serial["exit_code"] != 0
        and invalid_chunked["exit_code"] != 0
        and not invalid_serial["memory_limit_exceeded"]
        and not invalid_chunked["memory_limit_exceeded"]
        and not invalid_serial["stdout_truncated"]
        and not invalid_chunked["stdout_truncated"]
        and not invalid_serial["stderr_truncated"]
        and not invalid_chunked["stderr_truncated"]
        and serial_diagnostics
        and serial_diagnostics == chunked_diagnostics
        and invalid_serial["stderr"] == invalid_chunked["stderr"]
    )
    results["invalid_control_flow"] = {
        "serial": invalid_serial, "chunked": invalid_chunked,
        "diagnostic_exact": diagnostic_exact,
    }
    passed = passed and diagnostic_exact
    print(f"invalid_control_flow: diagnostic_exact={diagnostic_exact}", flush=True)

    # Separate source chunks can reject simultaneously. The user-visible
    # diagnostic stream must still match source-order serial validation.
    two_invalid_root = run_root / "two_invalid_control_flow"
    shutil.copytree(run_root / "sources" / "control_flow", two_invalid_root)
    for name, needle in (
        ("source_0000.p", "value = value + 4;"),
        ("source_0001.p", "value = value + 2;"),
    ):
        source_path = two_invalid_root / name
        original = source_path.read_text(encoding="ascii")
        if needle not in original:
            raise RuntimeError(f"two-error fixture shape changed: {name}")
        source_path.write_text(
            original.replace(needle, "value = value + true;", 1),
            encoding="ascii", newline="\n",
        )
    two_invalid_project = two_invalid_root / "openc.project.json"
    two_invalid_serial = measured_build(
        compiler, two_invalid_project,
        run_root / "two_invalid" / "serial" / "program.exe", False,
    )
    two_invalid_parallel = [
        measured_build(
            compiler, two_invalid_project,
            run_root / "two_invalid" / f"chunked-{index:02d}" / "program.exe",
            True, source_chunks,
        )
        for index in range(5)
    ]
    two_serial_diagnostics = str(two_invalid_serial["stdout"])
    two_invalid_exact = bool(
        two_invalid_serial["exit_code"] != 0
        and two_serial_diagnostics
        and all(
            sample["exit_code"] != 0
            and not sample["memory_limit_exceeded"]
            and not sample["stdout_truncated"]
            and not sample["stderr_truncated"]
            and str(sample["stdout"]).replace(
                "OpenC Windows artifact: FAIL (exe)\n", ""
            ) == two_serial_diagnostics
            and sample["stderr"] == two_invalid_serial["stderr"]
            for sample in two_invalid_parallel
        )
    )
    results["two_invalid_control_flow"] = {
        "serial": two_invalid_serial,
        "chunked_repetitions": two_invalid_parallel,
        "diagnostic_exact": two_invalid_exact,
    }
    passed = passed and two_invalid_exact
    print(
        f"two_invalid_control_flow: diagnostic_exact={two_invalid_exact}",
        flush=True,
    )
    report = {
        "schema": "openc.sh27.native_source_chunks.v1",
        "status": "PASS" if passed else "FAIL",
        "compiler_sha256": sha256(compiler),
        "source_chunks": source_chunks,
        "execution": "opt-in native source chunks; scheduling is compiler-revision-specific",
        "results": results,
    }
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 native chunk proof: {report['status']}; report={output}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
