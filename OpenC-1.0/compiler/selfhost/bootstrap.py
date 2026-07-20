#!/usr/bin/env python3
"""Build and execute the first compiler-in-OpenC seed stage."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str], cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return completed


def run_rejection(command: list[str], expected_exit: int, cwd: Path = ROOT) -> None:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if completed.returncode != expected_exit:
        raise SystemExit(
            f"rejection probe returned {completed.returncode}, expected {expected_exit}: "
            f"{' '.join(command)}\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    args = parser.parse_args()

    stage0 = args.stage0.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = ROOT / "compiler" / "selfhost" / "openc.project.json"
    source = ROOT / "compiler" / "selfhost" / "source" / "main.p"
    stage1 = output / "openc-selfhost-seed.exe"

    run([
        str(stage0), "build", f"--project={project}", f"--output={stage1}",
        f"--build_record={output / 'stage1-build-record.json'}",
    ])
    executed = run([str(stage1), str(source)])
    if "OpenC self-host seed: source accepted" not in executed.stdout:
        raise SystemExit("stage-1 seed did not report successful self-scan")
    run_rejection([
        str(stage1), str(ROOT / "compiler" / "selfhost" / "tests" / "unbalanced.p")
    ], 31)
    run_rejection([
        str(stage1), str(ROOT / "compiler" / "selfhost" / "tests" / "unterminated_string.p")
    ], 20)

    record = {
        "schema": "openc.self_host_stage_result.v1",
        "stage": "SH-1_FRONTEND_SEED",
        "status": "PASS",
        "stage0": str(stage0),
        "source": "compiler/selfhost/source/main.p",
        "artifact": str(stage1),
        "self_scan_stdout": executed.stdout.replace("\r\n", "\n"),
        "claims": {
            "compiler_source_written_in_openc": True,
            "stage0_builds_stage1": True,
            "stage1_scans_own_source": True,
            "stage1_rejection_probes": 2,
            "stage1_compiles_openc": False,
            "self_hosted": False,
            "dmd_independent": False,
        },
    }
    (output / "stage1-result.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(executed.stdout, end="")
    print(f"self-host seed: PASS; artifact={stage1}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
