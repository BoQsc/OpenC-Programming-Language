#!/usr/bin/env python3
"""Scope, parameter-owner, and serial/adaptive regression for index consumers."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from benchmark_sh27_production import ROOT, require_disk_headroom, sha256
from verify_sh27_array_initializers import measured, guarded


PROJECT = ROOT / "tests/sh27_indexed_bindings/openc.project.json"
INVALID = {
    "outside_block": "i32 main() { if true { i32 hidden = 7; } return hidden; }",
    "before_declaration": "i32 main() { i32 result = later; i32 later = 7; return result; }",
    "sibling_block": "i32 main() { if true { i32 hidden = 7; } if true { return hidden; } return 0; }",
    "other_function_parameter": "i32 first(i32 hidden) { return hidden; } i32 main() { return hidden; }",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("refusing to replace an existing report")
    require_disk_headroom(output.parent)
    runs = output.parent / (output.stem + "-runs")
    runs.mkdir(parents=True, exist_ok=False)
    compilers = {"candidate": args.compiler.resolve(strict=True)}
    if args.baseline:
        compilers["baseline"] = args.baseline.resolve(strict=True)
    results = {}
    hashes = set()
    for label, compiler in compilers.items():
        for mode in ("1", "auto"):
            binary = runs / (label + "-" + mode + ".exe")
            check = measured([str(compiler), "check", f"--project={PROJECT}"])
            build = measured([str(compiler), "artifact", f"--project={PROJECT}",
                "--kind=exe", f"--source-chunks={mode}", f"--output={binary}"])
            execution = measured([str(binary)], runs) if build["exit_code"] == 0 and binary.is_file() else None
            digest = sha256(binary) if binary.is_file() else None
            hashes.add(digest)
            results[label + "-" + mode] = {"check": check, "build": build,
                "execution": execution, "sha256": digest,
                "passed": guarded(check) and check["exit_code"] == 0 and
                    guarded(build) and build["exit_code"] == 0 and execution is not None and
                    guarded(execution) and execution["exit_code"] == 0 and
                    execution["stdout"] == "indexed-bindings-ok\n" and execution["stderr"] == ""}
    invalid = {}
    for name, source in INVALID.items():
        directory = runs / name
        directory.mkdir()
        (directory / "main.p").write_text(source + "\n", encoding="utf-8")
        project = directory / "openc.project.json"
        project.write_text(json.dumps({"name": "scope-" + name, "version": "1.0.0",
            "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
            "modules": {"scope.diagnostic": ["main.p"]}, "output_directory": "build"}), encoding="utf-8")
        samples = {}
        diagnostics = []
        for label, compiler in compilers.items():
            for mode in ("1", "auto"):
                binary = directory / (label + "-" + mode + ".exe")
                check = measured([str(compiler), "check", f"--project={project}"])
                build = measured([str(compiler), "artifact", f"--project={project}",
                    "--kind=exe", f"--source-chunks={mode}", f"--output={binary}"])
                samples[label + "-" + mode] = {"check": check, "build": build,
                    "binary_exists": binary.is_file(), "passed":
                    guarded(check) and guarded(build) and check["exit_code"] != 0 and
                    build["exit_code"] != 0 and not binary.is_file() and
                    "SEMANTIC_ERROR" in build["stdout"] + build["stderr"]}
                diagnostics.append((check["exit_code"], check["stdout"], check["stderr"],
                                    build["exit_code"], build["stdout"], build["stderr"]))
        invalid[name] = {"samples": samples, "passed":
            all(s["passed"] for s in samples.values()) and len(set(diagnostics)) == 1}
    checks = {"valid_oracles_pass": all(r["passed"] for r in results.values()),
        "all_binary_bytes_exact": None not in hashes and len(hashes) == 1,
        "invalid_rejection_and_exact_diagnostics": all(r["passed"] for r in invalid.values())}
    report = {"schema": "openc.sh27.indexed_bindings.v1", "status": "PASS" if all(checks.values()) else "FAIL",
        "compilers": {k: {"path": str(v), "sha256": sha256(v)} for k, v in compilers.items()},
        "checks": checks, "valid": results, "invalid": invalid}
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 indexed bindings: {report['status']}; report={output}")
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
