#!/usr/bin/env python3
"""Verify array expression roots, isolated operands, conversions, and diagnostics."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from benchmark_sh27_production import MIB, ROOT, require_disk_headroom, sha256
from windows_process_measure import run_measured


PROJECT = ROOT / "tests/sh27_array_initializer_operands/openc.project.json"
INVALID = {
    "too_few": "i32 main() { i32[3] a = {1, 2}; return 0; }",
    "too_many": "i32 main() { i32[1] a = {1, 2}; return 0; }",
    "empty": "i32 main() { i32[1] a = {}; return 0; }",
    "wrong_type": "i32 main() { i32[1] a = {true}; return 0; }",
    "literal_range": "i32 main() { u8[1] a = {256}; return 0; }",
    "copy_extent": "i32 main() { i32[2] a = {1, 2}; i32[3] b = a; return 0; }",
}


def measured(command: list[str], cwd: Path = ROOT) -> dict[str, object]:
    sample = run_measured(command, cwd=cwd, sample_interval=0.01,
                          max_private_bytes=256 * MIB, max_working_set_bytes=128 * MIB,
                          max_captured_output_bytes=2 * MIB, timeout_seconds=60)
    sample["command"] = command
    return sample


def guarded(sample: dict[str, object]) -> bool:
    return bool(not sample["timed_out"] and not sample["memory_limit_exceeded"] and
                not sample["stdout_truncated"] and not sample["stderr_truncated"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error(f"refusing to replace existing report: {output}")
    require_disk_headroom(output.parent)
    runs = output.parent / (output.stem + "-runs")
    runs.mkdir(parents=True, exist_ok=False)
    valid = {}
    hashes = set()
    for mode in ("1", "auto"):
        binary = runs / ("valid-" + mode + ".exe")
        checked = measured([str(compiler), "check", f"--project={PROJECT}"])
        build = measured([str(compiler), "artifact", f"--project={PROJECT}",
                          "--kind=exe", f"--source-chunks={mode}", f"--output={binary}"])
        execution = measured([str(binary)], runs) if build["exit_code"] == 0 and binary.is_file() else None
        digest = sha256(binary) if binary.is_file() else None
        hashes.add(digest)
        passed = bool(guarded(checked) and checked["exit_code"] == 0 and
                      guarded(build) and build["exit_code"] == 0 and execution is not None and
                      guarded(execution) and execution["exit_code"] == 0 and
                      execution["stdout"] == "112123\n" and execution["stderr"] == "")
        valid[mode] = {"passed": passed, "check": checked, "build": build,
                       "execution": execution, "binary_sha256": digest}
    invalid = {}
    for name, source in INVALID.items():
        directory = runs / name
        directory.mkdir()
        main_source = directory / "main.p"
        main_source.write_text(source + "\n", encoding="utf-8")
        project = directory / "openc.project.json"
        project.write_text(json.dumps({
            "name": "array-diagnostic-" + name, "version": "1.0.0",
            "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
            "modules": {"array.diagnostic": ["main.p"]}, "output_directory": "build",
        }), encoding="utf-8")
        samples = {}
        diagnostics = []
        for mode in ("1", "auto"):
            check = measured([str(compiler), "check", f"--project={project}"])
            binary = directory / (mode + ".exe")
            build = measured([str(compiler), "artifact", f"--project={project}",
                              "--kind=exe", f"--source-chunks={mode}", f"--output={binary}"])
            diagnostics.append((check["exit_code"], check["stdout"], check["stderr"],
                                build["exit_code"], build["stdout"], build["stderr"]))
            samples[mode] = {"check": check, "build": build,
                             "binary_exists": binary.is_file()}
        passed = bool(diagnostics[0] == diagnostics[1] and all(
            guarded(s["check"]) and guarded(s["build"]) and
            s["check"]["exit_code"] != 0 and s["build"]["exit_code"] != 0 and
            "SEMANTIC_ERROR" in (s["build"]["stdout"] + s["build"]["stderr"]) and
            not s["binary_exists"] for s in samples.values()))
        invalid[name] = {"passed": passed, "samples": samples,
                         "source_sha256": sha256(main_source)}
    checks = {
        "valid_checks_builds_and_runtime_oracles_passed": all(v["passed"] for v in valid.values()),
        "serial_adaptive_binary_exact": None not in hashes and len(hashes) == 1,
        "invalid_cases_rejected_with_exact_mode_diagnostics": all(v["passed"] for v in invalid.values()),
    }
    report = {"schema": "openc.sh27.array_initializer.v1",
              "status": "PASS" if all(checks.values()) else "FAIL",
              "compiler": {"path": str(compiler), "sha256": sha256(compiler)},
              "project": str(PROJECT), "source_sha256": sha256(PROJECT.parent / "source/main.p"),
              "checks": checks, "valid": valid, "invalid": invalid}
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 array initializers: {report['status']}; report={output}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
