#!/usr/bin/env python3
"""Prove byte-exact Stage 0/Stage 1 D-backend parity."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument("--stage1", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    args = parser.parse_args()
    stage0 = args.stage0.resolve()
    stage1 = args.stage1.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    projects = [
        ROOT / "compiler" / "selfhost" / "openc.project.json",
        ROOT / "programs" / "A_COMPUTATION" / "openc.project.json",
        ROOT / "programs" / "B_FLOW_OWNERSHIP" / "openc.project.json",
        ROOT / "programs" / "C_UNSAFE_BOUNDARY" / "openc.project.json",
    ]
    comparisons: list[dict[str, object]] = []
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="bootstrap-d-parity-", dir=output) as temporary:
        temporary_root = Path(temporary)
        for index, project in enumerate(projects):
            reference = temporary_root / f"reference-{index}"
            candidate = temporary_root / f"candidate-{index}"
            reference.mkdir()
            candidate.mkdir()
            run([
                str(stage0), "build", f"--project={project}", "--emit-only",
                f"--generated-output={reference}",
            ])
            mode = "--bootstrap-emit-d" if index == 0 else "--emit-d"
            run([str(stage1), mode, str(project), str(candidate)])
            reference_files = sorted(path.name for path in reference.glob("*.d"))
            candidate_files = sorted(path.name for path in candidate.glob("*.d"))
            if reference_files != candidate_files:
                failures.append(
                    f"{project}: file set {reference_files!r} != {candidate_files!r}"
                )
            files: list[dict[str, object]] = []
            for name in sorted(set(reference_files) & set(candidate_files)):
                reference_path = reference / name
                candidate_path = candidate / name
                reference_hash = digest(reference_path)
                candidate_hash = digest(candidate_path)
                exact = reference_path.read_bytes() == candidate_path.read_bytes()
                if not exact:
                    failures.append(f"{project}: {name} differs")
                files.append({
                    "name": name,
                    "bytes": reference_path.stat().st_size,
                    "sha256": reference_hash,
                    "candidate_sha256": candidate_hash,
                    "exact": exact,
                })
            comparisons.append({
                "project": str(project.relative_to(ROOT)).replace("\\", "/"),
                "files": files,
                "exact": reference_files == candidate_files and all(
                    entry["exact"] for entry in files
                ),
            })

    result = {
        "schema": "openc.self_host_bootstrap_d_parity.v1",
        "stage": "SH-4A_OPENC_D_BACKEND",
        "status": "PASS" if not failures else "FAIL",
        "stage0": str(stage0),
        "stage1": str(stage1),
        "projects": comparisons,
        "project_comparisons": len(comparisons),
        "file_comparisons": sum(len(item["files"]) for item in comparisons),
        "comparison": "byte-exact generated D source",
        "failures": failures,
    }
    result_path = output / "bootstrap-d-parity-result.json"
    result_path.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if failures:
        raise SystemExit(f"bootstrap D parity failed: {failures[0]}")
    print(
        "self-host D backend parity: PASS; "
        f"projects={len(comparisons)} files={result['file_comparisons']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
