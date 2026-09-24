#!/usr/bin/env python3
"""One guarded exact-byte proof for the opt-in function type freeze."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

from benchmark_sh27_production import (
    generate_language,
    require_disk_headroom,
    sha256,
    validate_corpus,
)
from windows_process_measure import run_measured


MIB = 1024 * 1024
ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "benchmarks" / "sh27" / "CORPUS.json"
INVALID = ROOT / "tests" / "sh27_prepared_source_invalid" / "openc.project.json"


def checked_run(command: list[str], *, cwd: Path, seconds: float) -> dict[str, object]:
    return run_measured(
        command,
        cwd=cwd,
        sample_interval=0.01,
        max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=2 * MIB,
        timeout_seconds=seconds,
    )


def complete(sample: dict[str, object], expected_exit: int) -> bool:
    return (
        sample["exit_code"] == expected_exit
        and not sample["timed_out"]
        and not sample["memory_limit_exceeded"]
        and not sample["stdout_truncated"]
        and not sample["stderr_truncated"]
    )


def main() -> int:
    if os.name != "nt":
        raise SystemExit("function type freeze verification requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output_dir = args.output_dir.resolve()
    if output_dir.exists():
        raise SystemExit(f"refusing existing output directory: {output_dir}")
    require_disk_headroom(output_dir.parent)
    output_dir.mkdir(parents=True, exist_ok=False)

    corpus = json.loads(CORPUS.read_text(encoding="utf-8"))
    validate_corpus(corpus)
    report: dict[str, object] = {
        "schema": "openc.sh27.function_type_freeze.v1",
        "status": "FAIL",
        "compiler": {"path": str(compiler), "sha256": sha256(compiler)},
        "corpus": {"path": str(CORPUS), "sha256": sha256(CORPUS)},
        "limits": {"private_bytes": 512 * MIB, "working_set_bytes": 512 * MIB},
        "workloads": [],
    }
    passed = True
    for workload in corpus["workloads"]:
        if workload["id"] not in {"large_functions", "control_flow"}:
            continue
        name = str(workload["id"])
        generated = generate_language(output_dir / name / "source", "openc", workload)
        project = Path(generated["project"])
        item: dict[str, object] = {
            "id": name,
            "source_tree": generated["tree"],
            "compilers": {},
        }
        outputs: dict[str, Path] = {}
        for mode in ("default", "freeze"):
            output = output_dir / name / f"{mode}.exe"
            timings = output_dir / name / f"{mode}.timings.json"
            command = [
                str(compiler), "artifact", f"--project={project}",
                "--kind=exe", f"--output={output}",
                f"--timings={timings}", "--source-chunks=4",
            ]
            if mode == "freeze":
                command.append("--freeze-function-types")
            measurement = checked_run(command, cwd=ROOT, seconds=120)
            good = complete(measurement, 0) and output.is_file() and timings.is_file()
            compiler_record: dict[str, object] = {
                "command": command,
                "measurement": measurement,
                "passed": good,
            }
            if good:
                compiler_record["output_sha256"] = sha256(output)
                compiler_record["timings"] = json.loads(
                    timings.read_text(encoding="utf-8")
                )
                outputs[mode] = output
            item["compilers"][mode] = compiler_record
            passed = passed and good
            if not good:
                break
        if len(outputs) == 2:
            item["byte_exact"] = sha256(outputs["default"]) == sha256(outputs["freeze"])
            freeze_timings = item["compilers"]["freeze"]["timings"]
            item["late_type_misses"] = freeze_timings.get("late_function_type_misses")
            item["prematerialized_types"] = freeze_timings.get(
                "prematerialized_function_types"
            )
            item["prematerialization_ms"] = freeze_timings.get(
                "function_type_prematerialization_ms"
            )
            runs = {}
            for mode, output in outputs.items():
                runs[mode] = checked_run([str(output)], cwd=output_dir / name, seconds=30)
            item["programs"] = runs
            item["program_exact"] = all(complete(run, 0) for run in runs.values()) and all(
                runs["default"][key] == runs["freeze"][key]
                for key in ("exit_code", "stdout", "stderr")
            )
            passed = passed and bool(item["byte_exact"]) and bool(item["program_exact"])
            passed = passed and item["late_type_misses"] == 0
        report["workloads"].append(item)

    invalid_runs = {}
    for mode in ("default", "freeze"):
        command = [
            str(compiler), "artifact", f"--project={INVALID}",
            "--kind=exe", f"--output={output_dir / ('invalid-' + mode + '.exe')}",
            "--source-chunks=1",
        ]
        if mode == "freeze":
            command.append("--freeze-function-types")
        invalid_runs[mode] = checked_run(command, cwd=ROOT, seconds=30)
    report["invalid"] = invalid_runs
    report["invalid_exact"] = (
        all(complete(run, 1) for run in invalid_runs.values())
        and all(
            invalid_runs["default"][key] == invalid_runs["freeze"][key]
            for key in ("exit_code", "stdout", "stderr")
        )
    )
    passed = passed and bool(report["invalid_exact"])
    report["status"] = "PASS" if passed else "FAIL"
    (output_dir / "function-type-freeze.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(f"SH-27 function type freeze: {report['status']}; report={output_dir / 'function-type-freeze.json'}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
