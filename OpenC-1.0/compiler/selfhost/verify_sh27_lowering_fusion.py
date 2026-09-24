#!/usr/bin/env python3
"""Guarded exact-output and diagnostic proof for fused scalar lowering."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from benchmark_sh27_native_parallel import build
from benchmark_sh27_production import (
    MIB, ROOT, generate_language, run_measured, sha256, validate_corpus,
)


CASES = {
    "binary_numeric": "i32 main() { i32 x = true + 1; return x; }\n",
    "assignment_lvalue": "i32 main() { i32 x = 1; 1 = x; return x; }\n",
    "short_circuit_invalid": (
        "i32 main() { bool x = false && (1 + true > 0); "
        "if x { return 1; } return 0; }\n"
    ),
    "never_branch_invalid": (
        "i32 main() { if false { i32 x = 1 + true; "
        "return x; } return 0; }\n"
    ),
    "global_invalid": "i32 value = 1 + true; i32 main() { return 0; }\n",
    "semicolon_valid": (
        "i32 external_function(); "
        "i32 main() { i32 x = 1 + 2; return x - 3; }\n"
    ),
}


def project_for(root: Path, name: str, source: str) -> Path:
    root.mkdir(parents=True, exist_ok=False)
    (root / "main.p").write_text(source, encoding="utf-8", newline="\n")
    project = root / "openc.project.json"
    project.write_text(
        json.dumps({
            "name": name, "version": "1.0.0", "edition": "OpenC 1.0",
            "profile": "standard", "target": "windows-x86_64",
            "modules": {f"{name}.main": ["main.p"]},
            "output_directory": "build",
        }, indent=2) + "\n",
        encoding="utf-8", newline="\n",
    )
    return project


def command_sample(
    compiler: Path, verb: str, project: Path, directory: Path
) -> dict[str, object]:
    directory.mkdir(parents=True, exist_ok=False)
    command = [str(compiler), verb, f"--project={project}"]
    output = directory / "program.exe"
    if verb == "artifact":
        command += ["--kind=exe", f"--output={output}",
                    f"--report={directory / 'artifact.json'}"]
    sample = run_measured(
        command, cwd=ROOT, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=60,
    )
    sample["artifact_exists"] = output.exists()
    sample["artifact_sha256"] = sha256(output) if output.exists() else None
    return sample


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    baseline = args.baseline.resolve(strict=True)
    candidate = args.candidate.resolve(strict=True)
    output = args.output.resolve()
    root = output.parent / f"{output.stem}-runs"
    root.mkdir(parents=True, exist_ok=False)
    corpus = json.loads((ROOT / "benchmarks/sh27/CORPUS.json").read_text())
    validate_corpus(corpus)
    valid: dict[str, object] = {}
    for name in ("large_functions", "control_flow"):
        workload = next(x for x in corpus["workloads"] if x["id"] == name)
        generated = generate_language(root / name / "source", "openc", workload)
        project = Path(str(generated["project"]))
        pairs = {}
        for role, compiler in (("baseline", baseline), ("candidate", candidate)):
            result = build(
                compiler, project, root / name / role,
                True, True, "auto",
            )
            execution = None
            if result["passed"]:
                execution = run_measured(
                    [str(root / name / role / "program.exe")],
                    cwd=ROOT, environment=dict(os.environ),
                    sample_interval=0.01, max_private_bytes=512 * MIB,
                    max_working_set_bytes=512 * MIB,
                    max_captured_output_bytes=64 * 1024, timeout_seconds=15,
                )
            pairs[role] = {"build": result, "execution": execution}
        left, right = pairs["baseline"], pairs["candidate"]
        valid[name] = {
            "passed": bool(
                left["build"]["passed"] and right["build"]["passed"]
                and left["build"]["output_sha256"] ==
                    right["build"]["output_sha256"]
                and left["execution"] is not None
                and right["execution"] is not None
                and left["execution"]["exit_code"] == 0
                and right["execution"]["exit_code"] == 0
                and left["execution"]["stdout"] ==
                    right["execution"]["stdout"]
            ),
            "byte_exact": left["build"]["output_sha256"] ==
                right["build"]["output_sha256"],
            "candidate_deferred_scalar":
                right["build"]["compiler_timings"]["validation_profile"].get(
                    "deferred_scalar"
                ) if right["build"]["compiler_timings"] else None,
            "pairs": pairs,
        }
    diagnostics: dict[str, object] = {}
    for name, source in CASES.items():
        project = project_for(root / "diagnostics" / name / "source", name, source)
        modes = {}
        for verb in ("check", "artifact"):
            samples = {
                role: command_sample(
                    compiler, verb, project,
                    root / "diagnostics" / name / verb / role,
                )
                for role, compiler in (
                    ("baseline", baseline), ("candidate", candidate)
                )
            }
            before, after = samples["baseline"], samples["candidate"]
            modes[verb] = {
                "passed": bool(
                    before["exit_code"] == after["exit_code"]
                    and before["stdout"] == after["stdout"]
                    and before["stderr"] == after["stderr"]
                    and before["artifact_exists"] == after["artifact_exists"]
                    and before["artifact_sha256"] == after["artifact_sha256"]
                    and not before["memory_limit_exceeded"]
                    and not after["memory_limit_exceeded"]
                ),
                "samples": samples,
            }
        diagnostics[name] = {
            "passed": all(mode["passed"] for mode in modes.values()),
            "modes": modes,
        }
    passed = all(item["passed"] for item in valid.values()) and all(
        item["passed"] for item in diagnostics.values()
    )
    report = {
        "schema": "openc.sh27.lowering_fusion_proof.v1",
        "status": "PASS" if passed else "FAIL",
        "baseline_sha256": sha256(baseline),
        "candidate_sha256": sha256(candidate),
        "valid": valid,
        "diagnostics": diagnostics,
    }
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 lowering fusion: {report['status']}; report={output}")
    for name, item in valid.items():
        print(f"  {name}: {item['passed']} {item['candidate_deferred_scalar']}")
    for name, item in diagnostics.items():
        print(f"  {name}: {item['passed']}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
