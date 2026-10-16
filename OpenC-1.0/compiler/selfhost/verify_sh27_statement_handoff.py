#!/usr/bin/env python3
"""Execute internal adjacency/body contracts on the current implementation."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from benchmark_sh27_production import ROOT, MIB, require_disk_headroom, sha256
from verify_sh27_array_initializers import guarded
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error("refusing to replace an existing report")
    require_disk_headroom(output.parent)
    runs = output.parent / (output.stem + "-runs")
    runs.mkdir(parents=True, exist_ok=False)
    canonical = ROOT / "compiler/selfhost"
    manifest = json.loads((canonical / "openc.project.json").read_text(encoding="utf-8"))
    driver = (canonical / "source/main_driver.p").read_text(encoding="utf-8")
    needle = "unsafe i32 main() {"
    if driver.count(needle) != 1:
        raise RuntimeError("canonical entry signature changed")
    test_driver = runs / "driver.p"
    test_driver.write_text(driver.replace(needle, "unsafe i32 regression_legacy_main() {"), encoding="utf-8")
    files = []
    for name in manifest["modules"]["openc.selfhost.main"]:
        selected = test_driver if name == "source/main_driver.p" else canonical / name
        files.append(os.path.relpath(selected, runs).replace(os.sep, "/"))
    probe = ROOT / "tests/sh27_statement_handoff/probe.p"
    files.append(os.path.relpath(probe, runs).replace(os.sep, "/"))
    manifest["modules"]["openc.selfhost.main"] = files
    for name in ("standard_library_directory", "runtime_directory"):
        manifest[name] = os.path.relpath((canonical / manifest[name]).resolve(), runs).replace(os.sep, "/")
    manifest["output_directory"] = "build"
    project = runs / "openc.project.json"
    project.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    results = {}
    hashes = set()
    for mode in ("1", "auto"):
        binary = runs / (mode + ".exe")
        build = run_measured([str(compiler), "artifact", f"--project={project}",
            "--kind=exe", f"--source-chunks={mode}", f"--output={binary}"],
            cwd=ROOT, sample_interval=.01, max_private_bytes=512 * MIB,
            max_working_set_bytes=256 * MIB, max_captured_output_bytes=2 * MIB,
            timeout_seconds=180)
        execution = None
        if build["exit_code"] == 0 and binary.is_file():
            execution = run_measured([str(binary)], cwd=runs,
                max_private_bytes=64 * MIB, max_working_set_bytes=32 * MIB,
                max_captured_output_bytes=4096, timeout_seconds=10, sample_interval=.01)
        digest = sha256(binary) if binary.is_file() else None
        hashes.add(digest)
        results[mode] = {"build": build, "execution": execution, "sha256": digest,
            "passed": guarded(build) and build["exit_code"] == 0 and execution is not None and
                guarded(execution) and execution["exit_code"] == 0 and
                execution["stdout"] == "statement-handoff-ok\n" and execution["stderr"] == ""}
    checks = {"all_builds_and_internal_oracles_pass": all(r["passed"] for r in results.values()),
        "serial_adaptive_bytes_exact": None not in hashes and len(hashes) == 1}
    report = {"schema": "openc.sh27.statement_handoff.v1", "status": "PASS" if all(checks.values()) else "FAIL",
        "compiler_sha256": sha256(compiler), "probe_sha256": sha256(probe),
        "implementation_files": {name: sha256(canonical / "source" / name) for name in
            ("ir_adjacency.p", "ir_index_initialize.p", "ir_part1c.p",
             "ir_lower_binary.p", "ir_project.p", "ir.p")},
        "checks": checks, "results": results}
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 statement handoff: {report['status']}; report={output}")
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
