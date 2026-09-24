#!/usr/bin/env python3
"""Bootstrap and compare up to three frozen SH-27 branch revisions serially.

The workflow checks out a trusted repository snapshot with full history. This
driver accepts only same-repository codex/sh27-* remote branch refs descended
from one full-SHA baseline. It never interpolates input into a shell command.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from analyze_sh27_candidate_matrix import analyze as analyze_matrix_phases
from benchmark_sh27_candidate_matrix import SCHEMA as MATRIX_SCHEMA
from benchmark_sh27_paired_revision import bootstrap
from benchmark_sh27_production import ROOT, MIB, require_disk_headroom, run_measured, sha256


REPOSITORY = ROOT.parent
SCHEMA = "openc.sh27.branch_batch.v1"
DEFAULT_BASELINE = "6794d56f65f361fad21d7964337c06ba3f168906"
BRANCH_PATTERN = re.compile(r"codex/sh27-[a-zA-Z0-9][a-zA-Z0-9._/-]*\Z")
SHA_PATTERN = re.compile(r"[0-9a-f]{40}\Z")


def git(*arguments: str) -> str:
    completed = subprocess.run(
        ["git", *arguments], cwd=REPOSITORY,
        check=True, capture_output=True, text=True,
    )
    return completed.stdout.strip()


def resolve_requests(baseline: str, refs: list[str]) -> tuple[str, list[dict[str, str]]]:
    if not SHA_PATTERN.fullmatch(baseline):
        raise ValueError("baseline must be a full lowercase 40-hex commit SHA")
    if not 1 <= len(refs) <= 3:
        raise ValueError("provide one to three candidate branch refs")
    if len(refs) != len(set(refs)):
        raise ValueError("duplicate candidate branch ref")
    actual = git("rev-parse", "--verify", "--end-of-options", f"{baseline}^{{commit}}")
    if actual != baseline:
        raise ValueError("baseline is not the exact requested commit")
    resolved: list[dict[str, str]] = []
    seen_commits: set[str] = {baseline}
    for index, ref in enumerate(refs, 1):
        if not BRANCH_PATTERN.fullmatch(ref):
            raise ValueError(f"untrusted candidate ref: {ref!r}")
        git("check-ref-format", "--branch", ref)
        remote_ref = f"refs/remotes/origin/{ref}"
        commit = git("rev-parse", "--verify", "--end-of-options",
                     f"{remote_ref}^{{commit}}")
        if not SHA_PATTERN.fullmatch(commit) or commit in seen_commits:
            raise ValueError(f"duplicate or invalid candidate commit: {ref}")
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", baseline, commit],
            cwd=REPOSITORY, check=False, capture_output=True,
        )
        if ancestor.returncode != 0:
            raise ValueError(f"candidate is not descended from baseline: {ref}")
        seen_commits.add(commit)
        resolved.append({"name": f"candidate{index}", "branch": ref,
                         "remote_ref": remote_ref, "commit": commit})
    return baseline, resolved


def source_manifest(project_root: Path) -> dict[str, object]:
    paths = sorted((project_root / "compiler/selfhost/source").rglob("*.p"))
    if not paths:
        raise RuntimeError(f"missing compiler source in {project_root}")
    paths.append(project_root / "compiler/selfhost/openc.project.json")
    if any(not path.is_file() for path in paths):
        raise RuntimeError(f"missing compiler source in {project_root}")
    combined = hashlib.sha256()
    records = []
    for path in paths:
        relative = path.relative_to(project_root).as_posix()
        digest = sha256(path)
        combined.update(relative.encode("utf-8") + b"\0")
        combined.update(digest.encode("ascii") + b"\n")
        records.append({"path": relative, "bytes": path.stat().st_size,
                        "sha256": digest})
    return {"sha256": combined.hexdigest(), "files": len(records),
            "records": records}


def strict_fixed_point(
    name: str, project_root: Path, compiler: Path, run_root: Path,
) -> dict[str, object]:
    stage = run_root / "bootstrap" / name / "strict-stage4"
    require_disk_headroom(stage)
    stage.mkdir(parents=True, exist_ok=False)
    output = stage / "openc.exe"
    command = [
        str(compiler), "build",
        f"--project={project_root / 'compiler/selfhost/openc.project.json'}",
        f"--output={output}", f"--timings={stage / 'timings.json'}",
    ]
    sample = run_measured(
        command, cwd=project_root, environment=dict(os.environ),
        sample_interval=0.01, max_private_bytes=256 * MIB,
        max_working_set_bytes=64 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=180,
    )
    sample["command"] = command
    sample["output_exists"] = output.is_file()
    sample["output_sha256"] = sha256(output) if output.is_file() else None
    sample["stage3_stage4_byte_exact"] = sample["output_sha256"] == sha256(compiler)
    sample["passed"] = bool(
        sample["exit_code"] == 0 and not sample["timed_out"]
        and not sample["memory_limit_exceeded"]
        and not sample["stdout_truncated"] and not sample["stderr_truncated"]
        and sample["output_exists"] and sample["stage3_stage4_byte_exact"]
    )
    (stage / "measurement.json").write_text(
        json.dumps(sample, indent=2) + "\n", encoding="utf-8"
    )
    if not sample["passed"]:
        raise RuntimeError(f"{name} strict fixed point failed: {stage / 'measurement.json'}")
    return sample


def checked_worktree(commit: str, target: Path, temporary_root: Path) -> None:
    if not target.resolve().is_relative_to(temporary_root.resolve()):
        raise RuntimeError("refusing worktree outside owned temporary directory")
    git("worktree", "add", "--detach", str(target), commit)


def remove_worktree(target: Path, temporary_root: Path) -> None:
    if not target.resolve().is_relative_to(temporary_root.resolve()):
        raise RuntimeError("refusing to remove unexpected worktree path")
    git("worktree", "remove", "--force", str(target))


def bootstrap_revision(
    name: str, commit: str, seed: Path, run_root: Path,
    temporary_root: Path, *, verify_seed_from_revision: bool = False,
) -> tuple[Path, dict[str, object]]:
    target = temporary_root / name
    checked_worktree(commit, target, temporary_root)
    try:
        project_root = target / "OpenC-1.0"
        if verify_seed_from_revision:
            frozen_seed = target / ".github/bootstrap/openc-stage0.exe"
            if not frozen_seed.is_file() or sha256(frozen_seed) != sha256(seed):
                raise RuntimeError("seed differs from frozen baseline commit")
            frozen_corpus = project_root / "benchmarks/sh27/CORPUS.json"
            active_corpus = ROOT / "benchmarks/sh27/CORPUS.json"
            if (not frozen_corpus.is_file() or not active_corpus.is_file()
                    or sha256(frozen_corpus) != sha256(active_corpus)):
                raise RuntimeError("SH-27 corpus differs from frozen baseline commit")
        manifest = source_manifest(project_root)
        compiler, stages = bootstrap(name, project_root, seed, run_root)
        strict = strict_fixed_point(name, project_root, compiler, run_root)
        return compiler, {"commit": commit, "source": manifest,
                          "bootstrap": stages, "strict_fixed_point": strict,
                          "compiler_sha256": sha256(compiler)}
    finally:
        remove_worktree(target, temporary_root)


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-27 branch batch requires Windows")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default=os.environ.get(
        "SH27_BASELINE_SHA", DEFAULT_BASELINE))
    parser.add_argument("--candidate-ref", action="append", default=[])
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=int(os.environ.get("SH27_PAIRS", "11")))
    parser.add_argument("--allow-binary-difference", action="store_true")
    parser.add_argument("--require-gain", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    refs = args.candidate_ref or [value for value in (
        os.environ.get("SH27_CANDIDATE_REF_1", ""),
        os.environ.get("SH27_CANDIDATE_REF_2", ""),
        os.environ.get("SH27_CANDIDATE_REF_3", ""),
    ) if value]
    if not refs and os.environ.get("GITHUB_EVENT_NAME") == "push":
        refs = [os.environ.get("GITHUB_REF_NAME", "")]
    if not 3 <= args.pairs <= 31:
        parser.error("pairs must be 3..31")
    try:
        baseline, candidates = resolve_requests(args.baseline, refs)
    except (ValueError, subprocess.CalledProcessError) as error:
        parser.error(str(error))
    seed = args.seed.resolve()
    if not seed.is_file():
        parser.error(f"missing seed: {seed}")
    output = args.output.resolve()
    if output.exists():
        parser.error(f"refusing to replace existing report: {output}")
    require_disk_headroom(output.parent)
    output.parent.mkdir(parents=True, exist_ok=True)
    run_root = output.parent / (output.stem + "-runs-" +
        datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    run_root.mkdir(parents=True, exist_ok=False)
    result: dict[str, object] = {
        "schema": SCHEMA, "status": "INCOMPLETE",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "baseline_commit": baseline, "candidate_refs": candidates,
        "seed": {"path": str(seed), "sha256": sha256(seed)},
        "corpus_sha256": sha256(ROOT / "benchmarks/sh27/CORPUS.json"),
        "pairs": args.pairs, "revisions": {}, "matrix": None,
        "errors": [],
    }
    try:
        with tempfile.TemporaryDirectory(prefix="openc-sh27-branch-batch-") as temporary:
            temporary_root = Path(temporary).resolve()
            baseline_compiler, record = bootstrap_revision(
                "baseline", baseline, seed, run_root, temporary_root,
                verify_seed_from_revision=True,
            )
            result["revisions"]["baseline"] = record
            eligible: list[tuple[str, Path]] = []
            for candidate in candidates:
                name = candidate["name"]
                try:
                    compiler, record = bootstrap_revision(
                        name, candidate["commit"], seed, run_root, temporary_root
                    )
                    result["revisions"][name] = record
                    eligible.append((name, compiler))
                except Exception as error:
                    result["revisions"][name] = {
                        "commit": candidate["commit"], "status": "BOOTSTRAP_FAIL",
                        "error": str(error),
                    }
                    result["errors"].append(f"{name}: {error}")
            if eligible:
                matrix_output = run_root / "candidate-matrix.json"
                command = [
                    sys.executable,
                    str(ROOT / "compiler/selfhost/benchmark_sh27_candidate_matrix.py"),
                    "--baseline", str(baseline_compiler),
                    "--pairs", str(args.pairs), "--output", str(matrix_output),
                ]
                for name, compiler in eligible:
                    command += ["--candidate", f"{name}={compiler}"]
                if args.allow_binary_difference:
                    command.append("--allow-binary-difference")
                if args.require_gain:
                    command.append("--require-gain")
                completed = subprocess.run(command, cwd=REPOSITORY, check=False)
                result["matrix"] = {
                    "path": str(matrix_output), "exit_code": completed.returncode,
                    "report_sha256": sha256(matrix_output) if matrix_output.is_file() else None,
                }
                if matrix_output.is_file():
                    matrix = json.loads(matrix_output.read_text(encoding="utf-8"))
                    if matrix.get("schema") != MATRIX_SCHEMA:
                        raise RuntimeError("candidate matrix schema mismatch")
                    phase_output = run_root / "candidate-matrix-phase-summary.json"
                    phase_output.write_text(
                        json.dumps(analyze_matrix_phases(matrix_output), indent=2)
                        + "\n", encoding="utf-8"
                    )
                    result["matrix"]["status"] = matrix["status"]
                    result["matrix"]["phase_summary"] = {
                        "path": str(phase_output), "sha256": sha256(phase_output),
                    }
                    result["matrix"]["corpus"] = matrix["corpus"]
                    result["matrix"]["workloads"] = {
                        key: {"source_tree": lane["source_tree"],
                              "comparisons": {name: comparison["status"]
                                              for name, comparison in lane["comparisons"].items()},
                              "null_control": lane["noise_control"]["status"]}
                        for key, lane in matrix["workloads"].items()
                    }
            result["status"] = "PASS" if (
                not result["errors"] and result["matrix"] is not None
                and result["matrix"].get("status") == "PASS"
            ) else "FAIL"
    except Exception as error:
        result["status"] = "FAIL"
        result["errors"].append(str(error))
    finally:
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 branch batch: {result['status']}; report={output}", flush=True)
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
