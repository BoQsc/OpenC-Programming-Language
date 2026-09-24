#!/usr/bin/env python3
"""Run checked-in SH-27 projects with exact outputs and Windows RAM guards.

This is a test harness, not part of the OpenC compiler's normal build path.
Cold/warm describe fresh versus already-touched filesystem inputs; this tool
does not clear the Windows file cache or assert incremental compilation.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import sys

from windows_process_measure import run_measured


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SUITE = ROOT / "benchmarks/sh27/representative/SUITE.json"
SCHEMA = "openc.sh27.representative_projects.v1"
REPORT_SCHEMA = "openc.sh27.representative_project_results.v1"
MIB = 1024 * 1024


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(MIB), b""):
            digest.update(block)
    return digest.hexdigest()


def inside(directory: Path, candidate: Path) -> Path:
    resolved = candidate.resolve()
    if not resolved.is_relative_to(directory.resolve()):
        raise ValueError(f"path escapes {directory}: {candidate}")
    return resolved


def source_paths(project: Path) -> tuple[dict[str, object], list[Path]]:
    document = json.loads(project.read_text(encoding="utf-8"))
    modules = document.get("modules")
    if not isinstance(modules, dict) or not modules:
        raise ValueError(f"project has no modules: {project}")
    paths: list[Path] = []
    for names in modules.values():
        if not isinstance(names, list) or not names:
            raise ValueError(f"empty module in {project}")
        for name in names:
            if not isinstance(name, str) or not name.endswith(".p"):
                raise ValueError(f"invalid source path: {name!r}")
            path = inside(project.parent, project.parent / name)
            if not path.is_file():
                raise ValueError(f"missing source: {path}")
            paths.append(path)
    if len(paths) != len(set(paths)):
        raise ValueError(f"duplicate source in {project}")
    return document, paths


def load_suite(path: Path) -> dict[str, object]:
    suite = json.loads(path.read_text(encoding="utf-8"))
    if suite.get("schema") != SCHEMA or suite.get("version") != 1:
        raise ValueError("unsupported representative-project suite version")
    if suite.get("categories") != ["cold", "warm", "edit"]:
        raise ValueError("the suite must define cold, warm, edit in order")
    workloads = suite.get("workloads")
    if not isinstance(workloads, list) or not workloads:
        raise ValueError("suite has no workloads")
    seen: set[str] = set()
    for workload in workloads:
        identifier = workload.get("id")
        if (
            not isinstance(identifier, str)
            or not identifier.replace("_", "").isalnum()
            or identifier in seen
        ):
            raise ValueError(f"invalid or duplicate workload ID: {identifier!r}")
        seen.add(identifier)
        project = inside(ROOT, ROOT / str(workload["project"]))
        if not project.is_file():
            raise ValueError(f"missing project: {project}")
        _, sources = source_paths(project)
        inputs = workload.get("input_files")
        if not isinstance(inputs, list):
            raise ValueError(f"invalid input_files: {identifier}")
        for name in inputs:
            input_path = inside(project.parent, project.parent / str(name))
            if not input_path.is_file():
                raise ValueError(f"missing runtime input: {input_path}")
        edit = workload.get("edit")
        if not isinstance(edit, dict):
            raise ValueError(f"missing edit: {identifier}")
        edited = inside(project.parent, project.parent / str(edit["path"]))
        if edited not in sources:
            raise ValueError(f"edit is not a declared source: {edited}")
        old = edit.get("old")
        new = edit.get("new")
        if not isinstance(old, str) or not old or not isinstance(new, str) or old == new:
            raise ValueError(f"invalid edit replacement: {identifier}")
        if edited.read_text(encoding="utf-8").count(old) != 1:
            raise ValueError(f"edit marker is not unique: {edited}")
        for expected in (
            workload.get("expected_stdout_utf8"),
            workload.get("expected_stderr_utf8"),
            edit.get("expected_stdout_utf8"),
        ):
            if not isinstance(expected, str):
                raise ValueError(f"missing exact expected output: {identifier}")
        if not isinstance(workload.get("run_arguments"), list):
            raise ValueError(f"missing run arguments: {identifier}")
    limits = suite.get("limits")
    if not isinstance(limits, dict) or any(
        not isinstance(value, int) or value <= 0 for value in limits.values()
    ):
        raise ValueError("invalid memory/time/disk limits")
    return suite


def tree_record(directory: Path) -> dict[str, object]:
    records = []
    combined = hashlib.sha256()
    for path in sorted(directory.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(directory).as_posix()
        digest = sha256(path)
        records.append({"path": relative, "bytes": path.stat().st_size,
                        "sha256": digest})
        combined.update(relative.encode("utf-8") + b"\0")
        combined.update(digest.encode("ascii") + b"\n")
    return {"sha256": combined.hexdigest(), "files": len(records),
            "bytes": sum(record["bytes"] for record in records),
            "records": records}


def stage_project(workload: dict[str, object], directory: Path) -> tuple[Path, dict[str, object]]:
    project = inside(ROOT, ROOT / str(workload["project"]))
    document, sources = source_paths(project)
    directory.mkdir(parents=True, exist_ok=False)
    for source in sources:
        target = directory / source.relative_to(project.parent)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    for name in workload["input_files"]:
        source = inside(project.parent, project.parent / str(name))
        target = directory / source.relative_to(project.parent)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    # The staged project is otherwise the checked-in project. Only external
    # library/runtime paths and its output directory need relocation.
    document["standard_library_directory"] = str(ROOT / "standard_library")
    document["runtime_directory"] = str(ROOT / "runtime")
    document["output_directory"] = str(directory / "build")
    staged_project = directory / project.name
    staged_project.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    return staged_project, tree_record(directory)


def apply_edit(workload: dict[str, object], directory: Path) -> dict[str, object]:
    edit = workload["edit"]
    source = inside(directory, directory / str(edit["path"]))
    original = source.read_text(encoding="utf-8")
    old = str(edit["old"])
    if original.count(old) != 1:
        raise ValueError(f"staged edit marker is not unique: {source}")
    source.write_text(original.replace(old, str(edit["new"]), 1), encoding="utf-8")
    return tree_record(directory)


def disk_headroom(directory: Path, minimum_mib: int) -> int:
    available = shutil.disk_usage(directory.resolve().anchor).free
    if available < minimum_mib * MIB:
        raise RuntimeError(
            f"SH27_DISK_HEADROOM: {available} free bytes; "
            f"need {minimum_mib * MIB}"
        )
    return available


def measured(
    command: list[str], cwd: Path, limits: dict[str, int], *, compiler: bool
) -> dict[str, object]:
    prefix = "compiler" if compiler else "program"
    return run_measured(
        command,
        cwd=cwd,
        environment=dict(os.environ),
        sample_interval=0.01,
        max_private_bytes=int(limits[f"{prefix}_private_mib"]) * MIB,
        max_working_set_bytes=int(limits[f"{prefix}_working_set_mib"]) * MIB,
        max_captured_output_bytes=int(limits["captured_output_mib"]) * MIB,
        timeout_seconds=int(limits[f"{prefix}_timeout_seconds"]),
    )


def run_build(
    compiler: Path, project: Path, case_dir: Path, workload: dict[str, object],
    category: str, tree: dict[str, object], limits: dict[str, int]
) -> dict[str, object]:
    case_dir.mkdir(parents=True, exist_ok=False)
    executable = case_dir / "program.exe"
    timings = case_dir / "timings.json"
    command = [str(compiler), "build", f"--project={project}",
               f"--output={executable}", f"--timings={timings}"]
    disk_free = disk_headroom(case_dir, limits["minimum_free_disk_mib"])
    built = measured(command, project.parent, limits, compiler=True)
    build_pass = bool(
        built["exit_code"] == 0 and not built["memory_limit_exceeded"]
        and not built["timed_out"] and not built["stdout_truncated"]
        and not built["stderr_truncated"] and executable.is_file()
    )
    expected_stdout = (
        workload["edit"]["expected_stdout_utf8"]
        if category == "edit" else workload["expected_stdout_utf8"]
    )
    result: dict[str, object] = {
        "category": category,
        "status": "FAIL",
        "source_tree": tree,
        "compiler_sha256": sha256(compiler),
        "build_command": command,
        "disk_free_bytes_before": disk_free,
        "build": built,
        "executable": str(executable),
        "executable_sha256": sha256(executable) if executable.is_file() else None,
        "timings_sha256": sha256(timings) if timings.is_file() else None,
        "expected_exit_code": 0,
        "expected_stdout_utf8": expected_stdout,
        "expected_stderr_utf8": workload["expected_stderr_utf8"],
        "program": None,
    }
    if build_pass:
        program = measured(
            [str(executable), *workload["run_arguments"]],
            project.parent, limits, compiler=False,
        )
        result["program"] = program
        result["status"] = "PASS" if (
            program["exit_code"] == 0
            and not program["memory_limit_exceeded"]
            and not program["timed_out"]
            and not program["stdout_truncated"]
            and not program["stderr_truncated"]
            and program["stdout"] == expected_stdout
            and program["stderr"] == workload["expected_stderr_utf8"]
        ) else "FAIL"
    return result


def run_one(
    compiler: Path, workload: dict[str, object], run_dir: Path,
    limits: dict[str, int], generations: int
) -> dict[str, object]:
    project, tree = stage_project(workload, run_dir / "project")
    result: dict[str, object] = {"status": "INCOMPLETE", "cases": {},
                                 "self_build_chain": []}
    for category in ("cold", "warm"):
        case = run_build(compiler, project, run_dir / category,
                         workload, category, tree, limits)
        result["cases"][category] = case
        if case["status"] != "PASS":
            result["status"] = "FAIL"
            return result
    if workload["class"] == "compiler_self_build" and generations > 1:
        previous = Path(result["cases"]["cold"]["executable"])
        chain_hashes: list[str] = []
        for generation in range(2, generations + 1):
            case = run_build(previous, project, run_dir / f"generation-{generation}",
                             workload, "warm", tree, limits)
            case["generation"] = generation
            result["self_build_chain"].append(case)
            if case["status"] != "PASS":
                result["status"] = "FAIL"
                return result
            previous = Path(case["executable"])
            chain_hashes.append(str(case["executable_sha256"]))
        if generations == 3 and chain_hashes[0] != chain_hashes[1]:
            result["status"] = "FAIL"
            result["fixed_point_error"] = "generation 2 and 3 differ"
            return result
    edited_tree = apply_edit(workload, project.parent)
    edited = run_build(compiler, project, run_dir / "edit",
                       workload, "edit", edited_tree, limits)
    result["cases"]["edit"] = edited
    result["status"] = edited["status"]
    return result


def summarize(samples: list[dict[str, object]]) -> dict[str, object]:
    """Summarize successful serial samples without claiming speed parity."""
    categories: dict[str, object] = {}
    for category in ("cold", "warm", "edit"):
        cases = [sample["cases"][category]
                 for sample in samples if category in sample["cases"]]
        passed = [case for case in cases if case["status"] == "PASS"]
        elapsed = [float(case["build"]["elapsed_seconds"]) for case in passed]
        categories[category] = {
            "attempted": len(cases), "passed": len(passed),
            "median_compile_seconds": (
                round(statistics.median(elapsed), 6) if elapsed else None
            ),
            "raw_compile_seconds": elapsed,
            "peak_private_bytes": max(
                (int(case["build"]["peak_private_bytes"]) for case in cases),
                default=0,
            ),
            "peak_job_private_bytes": max(
                (int(case["build"]["peak_job_private_bytes"]) for case in cases),
                default=0,
            ),
            "peak_working_set_bytes": max(
                (int(case["build"]["peak_working_set_bytes"]) for case in cases),
                default=0,
            ),
        }
    return categories


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", type=Path, default=DEFAULT_SUITE)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--workload", action="append")
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--self-build-generations", type=int, default=1)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not 1 <= args.runs <= 20 or not 1 <= args.self_build_generations <= 3:
        parser.error("--runs must be 1..20 and --self-build-generations 1..3")
    suite_path = args.suite.resolve()
    suite = load_suite(suite_path)
    workloads = suite["workloads"]
    if args.workload:
        selected = set(args.workload)
        known = {workload["id"] for workload in workloads}
        if not selected <= known:
            parser.error(f"unknown workload: {sorted(selected - known)}")
        workloads = [workload for workload in workloads if workload["id"] in selected]
    if args.validate_only:
        print(json.dumps({
            "schema": SCHEMA, "status": "PASS", "workloads": [
                {"id": workload["id"], "class": workload["class"],
                 "project": workload["project"],
                 "source_files": len(source_paths(ROOT / workload["project"])[1])}
                for workload in workloads
            ], "suite_sha256": sha256(suite_path),
        }, indent=2))
        return 0
    if os.name != "nt":
        parser.error("guarded representative runs currently require Windows")
    if args.compiler is None or args.output is None:
        parser.error("--compiler and --output are required for a run")
    compiler = args.compiler.resolve()
    if not compiler.is_file():
        parser.error(f"missing compiler: {compiler}")
    output = args.output.resolve()
    if output.exists():
        parser.error(f"refusing to overwrite report: {output}")
    output.parent.mkdir(parents=True, exist_ok=True)
    run_root = output.parent / (
        output.stem + "-runs-"
        + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    )
    run_root.mkdir(parents=True, exist_ok=False)
    report: dict[str, object] = {
        "schema": REPORT_SCHEMA, "status": "INCOMPLETE",
        "measured_at_utc": datetime.now(timezone.utc).isoformat(),
        "host": {"system": platform.system(), "release": platform.release(),
                 "machine": platform.machine(), "logical_cpus": os.cpu_count()},
        "suite": {"path": str(suite_path), "sha256": sha256(suite_path)},
        "compiler": {"path": str(compiler), "sha256": sha256(compiler)},
        "cache_policy": (
            "Cold means fresh staged project/output; warm repeats unchanged "
            "inputs after a cold build; edit changes one staged source. "
            "OS cache is not flushed; no incremental compiler cache is claimed."
        ),
        "run_root": str(run_root), "runs_per_workload": args.runs,
        "self_build_generations": args.self_build_generations,
        "limits": suite["limits"], "workloads": {},
    }
    limits = suite["limits"]
    try:
        for workload in workloads:
            samples = []
            report["workloads"][workload["id"]] = {
                "class": workload["class"], "samples": samples,
            }
            for index in range(args.runs):
                sample = run_one(
                    compiler, workload,
                    run_root / workload["id"] / f"run-{index + 1:02d}",
                    limits, args.self_build_generations,
                )
                samples.append(sample)
                report["workloads"][workload["id"]]["summary"] = summarize(samples)
                print(f"{workload['id']} {index + 1}/{args.runs}: {sample['status']}",
                      flush=True)
                if sample["status"] != "PASS":
                    report["status"] = "FAIL"
                    return 1
        report["status"] = "PASS"
        return 0
    except Exception as error:
        report["status"] = "FAIL"
        report["error"] = f"{type(error).__name__}: {error}"
        print(report["error"], file=sys.stderr)
        return 1
    finally:
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"SH-27 representative report: {output} ({report['status']})",
              flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
