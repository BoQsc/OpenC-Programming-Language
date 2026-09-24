#!/usr/bin/env python3
"""Bounded, byte-exact differential proof for the SH-27 typed handoff."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from windows_process_measure import run_measured


ROOT = Path(__file__).resolve().parents[2]
MIB = 1024 * 1024
LIMIT = 512 * MIB


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def guarded(command: list[str]) -> dict[str, object]:
    result = run_measured(
        command, cwd=ROOT, sample_interval=0.01,
        max_private_bytes=LIMIT, max_working_set_bytes=LIMIT,
        max_captured_output_bytes=2 * MIB, timeout_seconds=90,
    )
    if (result["timed_out"] or result["memory_limit_exceeded"]
            or result["stdout_truncated"] or result["stderr_truncated"]):
        raise RuntimeError(f"guard failed: {command}: {result}")
    return result


def project(directory: Path, source: str) -> Path:
    directory.mkdir(parents=True, exist_ok=False)
    (directory / "main.p").write_text(source, encoding="utf-8", newline="\n")
    manifest = directory / "openc.project.json"
    manifest.write_text(json.dumps({
        "name": directory.name, "version": "0.1.0", "edition": "OpenC 1.0",
        "profile": "standard", "target": "windows-x86_64",
        "modules": {"probe.main": ["main.p"]},
    }, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    baseline = args.baseline.resolve(strict=True)
    candidate = args.candidate.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error(f"refusing to replace {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    fixture_root = output.parent / (output.stem + "-fixtures")
    fixture_root.mkdir(parents=True, exist_ok=False)
    existing = [
        "sh27_integer_literals", "sh27_integer_immediate_signed_overflow",
        "sh27_integer_immediate_unsigned_underflow",
        "sh27_integer_immediate_narrow_overflow", "sh19_native_scalars",
        "sh27_nested_aggregate",
    ]
    projects: list[tuple[str, Path, bool]] = [
        (name, ROOT / "tests" / name / "openc.project.json", True)
        for name in existing
    ]
    generated = {
        "invalid_short_circuit_and": (
            "i32 main() { if false && (1 << 64) == 0 { return 1; } return 0; }\n",
            False,
        ),
        "invalid_short_circuit_or": (
            "i32 main() { if true || (1 << 64) == 0 { return 1; } return 0; }\n",
            False,
        ),
        "semicolon_declaration": (
            "i32 declared();\ni32 main() { return 1 + 2; }\n", True,
        ),
        "unknown_operator": (
            "i32 main() { return 1 @ 2; }\n", False,
        ),
    }
    for name, (source, valid) in generated.items():
        projects.append((name, project(fixture_root / name, source), valid))
    results: list[dict[str, object]] = []
    for name, manifest, valid in projects:
        runs: dict[str, dict[str, object]] = {}
        for label, compiler in (("baseline", baseline), ("candidate", candidate)):
            check = guarded([str(compiler), "check", f"--project={manifest}"])
            exe = fixture_root / f"{name}-{label}.exe"
            build = guarded([
                str(compiler), "build", f"--project={manifest}",
                f"--output={exe}",
            ])
            runtime = guarded([str(exe)]) if build["exit_code"] == 0 and exe.is_file() else None
            runs[label] = {
                "check": check, "build": build,
                "exe_sha256": sha256(exe) if exe.is_file() else None,
                "runtime": runtime,
            }
        left, right = runs["baseline"], runs["candidate"]
        same_check = all(
            left["check"][field] == right["check"][field]
            for field in ("exit_code", "stdout", "stderr")
        )
        same_build_diagnostics = all(
            left["build"][field] == right["build"][field]
            for field in ("exit_code", "stdout", "stderr")
        )
        same_pe = left["exe_sha256"] == right["exe_sha256"]
        same_runtime = (
            left["runtime"] is not None and right["runtime"] is not None
            and all(left["runtime"][field] == right["runtime"][field]
                    for field in ("exit_code", "stdout", "stderr"))
        ) if valid else left["runtime"] is None and right["runtime"] is None
        expected_status = (
            left["check"]["exit_code"] == 0 and left["build"]["exit_code"] == 0
            and left["exe_sha256"] is not None
        ) if valid else (
            left["check"]["exit_code"] != 0 and left["build"]["exit_code"] != 0
            and left["exe_sha256"] is None
        )
        passed = same_check and same_build_diagnostics and same_pe and same_runtime and expected_status
        results.append({
            "name": name, "valid": valid, "pass": passed,
            "same_check_diagnostics": same_check,
            "same_build_diagnostics": same_build_diagnostics,
            "same_pe_sha256": same_pe, "same_runtime": same_runtime,
            "expected_status": expected_status, "runs": runs,
        })
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
    report = {
        "schema": "openc.sh27.typed_handoff_differential.v1",
        "status": "PASS" if all(item["pass"] for item in results) else "FAIL",
        "baseline_sha256": sha256(baseline), "candidate_sha256": sha256(candidate),
        "memory_limit_bytes": LIMIT, "cases": results,
    }
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(report["status"], output, flush=True)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
