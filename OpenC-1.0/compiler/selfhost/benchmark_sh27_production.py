#!/usr/bin/env python3
"""Run the bounded SH-27 OpenC/MSVC/Clang/DMD production corpus on Windows."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from windows_process_measure import run_measured


ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = ROOT.parent
SCHEMA = "openc.sh27.production_comparators.v1"
MIB = 1024 * 1024


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(MIB), b""):
            digest.update(block)
    return digest.hexdigest()


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = max(0, math.ceil(len(ordered) * fraction) - 1)
    return ordered[index]


def summarize(samples: list[dict[str, object]]) -> dict[str, object]:
    values = [float(item["elapsed_seconds"]) for item in samples]
    if not values:
        return {"runs": 0}
    return {
        "runs": len(values),
        "minimum_seconds": round(min(values), 6),
        "median_seconds": round(statistics.median(values), 6),
        "p95_seconds": round(percentile(values, 0.95), 6),
        "maximum_seconds": round(max(values), 6),
        "raw_seconds": values,
        "peak_private_bytes": max(int(item["peak_private_bytes"]) for item in samples),
        "peak_working_set_bytes": max(
            int(item["peak_working_set_bytes"]) for item in samples
        ),
    }


def validate_corpus(corpus: dict[str, object]) -> None:
    if corpus.get("schema") != "openc.sh27.production_corpus.v1":
        raise SystemExit("unsupported SH-27 corpus schema")
    limits = corpus["limits"]
    seen: set[str] = set()
    for workload in corpus["workloads"]:
        identifier = str(workload["id"])
        files = int(workload["source_files"])
        functions = int(workload["functions_per_file"])
        operations = int(workload["operations_per_function"])
        if not identifier or identifier in seen:
            raise SystemExit(f"duplicate or empty workload id: {identifier!r}")
        seen.add(identifier)
        if files < 1 or files > int(limits["maximum_source_files_per_workload"]):
            raise SystemExit(f"source file limit rejected workload: {identifier}")
        if functions < 1 or files * functions > int(
            limits["maximum_total_functions_per_workload"]
        ):
            raise SystemExit(f"function limit rejected workload: {identifier}")
        if operations < 1 or operations > int(limits["maximum_operations_per_function"]):
            raise SystemExit(f"operation limit rejected workload: {identifier}")


def source_tree_record(directory: Path, suffix: str) -> dict[str, object]:
    records: list[dict[str, object]] = []
    combined = hashlib.sha256()
    for path in sorted(directory.glob(f"*{suffix}")):
        relative = path.relative_to(directory).as_posix()
        value = sha256(path)
        record = {"path": relative, "bytes": path.stat().st_size, "sha256": value}
        records.append(record)
        combined.update(relative.encode("utf-8"))
        combined.update(b"\0")
        combined.update(value.encode("ascii"))
        combined.update(b"\n")
    return {
        "files": len(records),
        "bytes": sum(int(item["bytes"]) for item in records),
        "sha256": combined.hexdigest(),
        "records": records,
    }


def function_text(language: str, index: int, operations: int) -> str:
    type_name = "i64" if language == "openc" else ("long long" if language == "msvc" else "long")
    lines = [f"{type_name} sh27_work_{index:06d}({type_name} value) {{"]
    for operation in range(operations):
        amount = ((index + 1) * (operation + 3)) % 97 + 1
        if operation % 3 == 0:
            lines.append(f"    value = value + {amount};")
        elif operation % 3 == 1:
            lines.append(f"    value = value * 1 + {amount};")
        else:
            lines.append(f"    value = value - {amount // 2};")
    lines.append("    return value;")
    lines.append("}")
    return "\n".join(lines) + "\n"


def apply_operations(value: int, index: int, operations: int) -> int:
    for operation in range(operations):
        amount = ((index + 1) * (operation + 3)) % 97 + 1
        if operation % 3 == 0:
            value += amount
        elif operation % 3 == 1:
            value = value * 1 + amount
        else:
            value -= amount // 2
    return value


def generate_language(
    root: Path, language: str, workload: dict[str, object]
) -> dict[str, object]:
    suffix = {"openc": ".p", "msvc": ".c", "dmd": ".d"}[language]
    source_files = int(workload["source_files"])
    functions_per_file = int(workload["functions_per_file"])
    operations = int(workload["operations_per_function"])
    root.mkdir(parents=True, exist_ok=False)
    names: list[str] = []
    expected = 0
    function_index = 0
    for file_index in range(source_files):
        name = f"source_{file_index:04d}{suffix}"
        names.append(name)
        pieces: list[str] = []
        if language == "dmd":
            pieces.append(f"module sh27_source_{file_index:04d};\n\n")
        first_index = function_index
        for _ in range(functions_per_file):
            pieces.append(function_text(language, function_index, operations))
            pieces.append("\n")
            function_index += 1
        if file_index == 0:
            type_name = "i64" if language == "openc" else ("long long" if language == "msvc" else "long")
            main_type = "i32" if language == "openc" else "int"
            pieces.append(f"{main_type} main() {{\n")
            pieces.append(f"    {type_name} value = 0;\n")
            for index in range(first_index, function_index):
                pieces.append(f"    value = sh27_work_{index:06d}(value);\n")
                expected = apply_operations(expected, index, operations)
            if language == "openc":
                pieces.append(f"    if value != {expected} {{ return 1; }}\n")
            else:
                pieces.append(f"    if (value != {expected}) {{ return 1; }}\n")
            pieces.append("    return 0;\n}\n")
        (root / name).write_text(
            "".join(pieces), encoding="ascii", newline="\n"
        )
    project_path: Path | None = None
    if language == "openc":
        modules = {
            f"sh27.source_{index:04d}": [name]
            for index, name in enumerate(names)
        }
        project_path = root / "openc.project.json"
        project_path.write_text(
            json.dumps(
                {
                    "name": f"sh27-{workload['id']}",
                    "version": "1.0.0",
                    "edition": "OpenC 1.0",
                    "profile": "standard",
                    "target": "windows-x86_64",
                    "modules": modules,
                    "output_directory": "build",
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
    return {
        "directory": root,
        "sources": [root / name for name in names],
        "project": project_path,
        "tree": source_tree_record(root, suffix),
        "equivalent_functions": source_files * functions_per_file,
        "operations_per_function": operations,
        "executed_functions": functions_per_file,
        "expected_exit_code": 0,
    }


def capture_msvc_environment(
    toolset_version: str | None,
) -> tuple[dict[str, str] | None, str | None]:
    inherited = dict(os.environ)
    if shutil.which("cl.exe") and toolset_version is None:
        return inherited, None
    vswhere = Path(
        os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")
    ) / "Microsoft Visual Studio" / "Installer" / "vswhere.exe"
    if not vswhere.is_file():
        return None, None
    found = subprocess.run(
        [
            str(vswhere), "-latest", "-products", "*", "-requires",
            "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
            "-property", "installationPath",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    installation = found.stdout.strip()
    if found.returncode != 0 or not installation:
        return None, None
    vcvars = Path(installation) / "VC" / "Auxiliary" / "Build" / "vcvars64.bat"
    if not vcvars.is_file():
        return None, None
    toolset_argument = (
        f" -vcvars_ver={toolset_version}" if toolset_version is not None else ""
    )
    captured = subprocess.run(
        [
            "cmd.exe", "/d", "/c",
            f'call "{vcvars}"{toolset_argument} >nul && set',
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if captured.returncode != 0:
        return None, str(vcvars)
    environment: dict[str, str] = {}
    for line in captured.stdout.splitlines():
        if "=" in line and not line.startswith("="):
            name, value = line.split("=", 1)
            environment[name] = value
    return environment, str(vcvars)


def resolve_tool(
    explicit: Path | None, candidates: list[str], environment: dict[str, str]
) -> Path | None:
    if explicit is not None:
        resolved = explicit.resolve()
        if resolved.is_file():
            return resolved
        if resolved.suffix == "":
            windows_executable = Path(str(resolved) + ".exe")
            if windows_executable.is_file():
                return windows_executable.resolve()
        found = shutil.which(str(explicit), path=environment.get("PATH"))
        return Path(found).resolve() if found else None
    for candidate in candidates:
        candidate_path = Path(candidate)
        if candidate_path.is_absolute() and candidate_path.is_file():
            return candidate_path.resolve()
        found = shutil.which(candidate, path=environment.get("PATH"))
        if found:
            return Path(found).resolve()
    return None


def version_record(path: Path, arguments: list[str], environment: dict[str, str]) -> dict[str, object]:
    completed = subprocess.run(
        [str(path), *arguments],
        cwd=ROOT,
        env=environment,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    return {
        "path": str(path),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "command": [str(path), *arguments],
        "exit_code": completed.returncode,
        "output": (completed.stdout + completed.stderr).strip()[:16384],
    }


def build_command(
    tool: str,
    executable: Path,
    input_record: dict[str, object],
    output: Path,
    timing: Path,
) -> list[str]:
    sources = [str(path) for path in input_record["sources"]]
    if tool == "openc":
        return [
            str(executable), "build", f"--project={input_record['project']}",
            f"--output={output}", f"--timings={timing}",
        ]
    if tool == "msvc":
        return [
            str(executable), "/nologo", "/O2", "/std:c17", "/Brepro",
            *sources, f"/Fe:{output}",
        ]
    if tool == "clang":
        return [
            str(executable), "/nologo", "/O2", "/std:c17", "/Brepro",
            *sources, f"/Fe:{output}",
        ]
    if tool == "dmd":
        return [
            str(executable), "-O", "-release", "-boundscheck=off",
            *sources, f"-of={output}", f"-od={output.parent}",
        ]
    raise AssertionError(tool)


def sample_passed(sample: dict[str, object]) -> bool:
    return bool(
        int(sample["exit_code"]) == 0
        and not sample["memory_limit_exceeded"]
        and not sample["stdout_truncated"]
        and not sample["stderr_truncated"]
        and sample.get("output_exists")
        and int(sample.get("program_exit_code", -1)) == 0
        and not sample.get("program_timed_out")
    )


def run_sample(
    *,
    tool: str,
    executable: Path,
    environment: dict[str, str],
    input_record: dict[str, object],
    sample_root: Path,
    sample_interval: float,
    max_private_bytes: int,
    max_working_set_bytes: int,
    max_output_bytes: int,
    execution_timeout: int,
) -> dict[str, object]:
    sample_root.mkdir(parents=True, exist_ok=True)
    output = sample_root / "program.exe"
    timing = sample_root / "openc-timings.json"
    command = build_command(tool, executable, input_record, output, timing)
    measured = run_measured(
        command,
        cwd=sample_root,
        environment=environment,
        sample_interval=sample_interval,
        max_private_bytes=max_private_bytes,
        max_working_set_bytes=max_working_set_bytes,
        max_captured_output_bytes=max_output_bytes,
    )
    measured["command"] = command
    measured["output_exists"] = output.is_file()
    measured["output_bytes"] = output.stat().st_size if output.is_file() else None
    measured["output_sha256"] = sha256(output) if output.is_file() else None
    measured["program_exit_code"] = None
    measured["program_elapsed_seconds"] = None
    measured["program_timed_out"] = False
    if int(measured["exit_code"]) == 0 and output.is_file():
        started = time.perf_counter()
        try:
            executed = subprocess.run(
                [str(output)], cwd=sample_root, capture_output=True,
                timeout=execution_timeout,
            )
            measured["program_exit_code"] = executed.returncode
            measured["program_stdout_bytes"] = len(executed.stdout)
            measured["program_stderr_bytes"] = len(executed.stderr)
        except subprocess.TimeoutExpired:
            measured["program_timed_out"] = True
        measured["program_elapsed_seconds"] = round(time.perf_counter() - started, 6)
    measured["passed"] = sample_passed(measured)
    return measured


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-27 production comparison currently requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--corpus", type=Path, default=ROOT / "benchmarks" / "sh27" / "CORPUS.json"
    )
    parser.add_argument(
        "--openc", type=Path, default=REPOSITORY / ".github" / "bootstrap" / "openc-stage0.exe"
    )
    parser.add_argument("--msvc", type=Path)
    parser.add_argument("--clang", type=Path)
    parser.add_argument("--dmd", type=Path)
    parser.add_argument("--msvc-toolset")
    parser.add_argument("--expected-msvc-version")
    parser.add_argument("--expected-clang-version")
    parser.add_argument("--expected-dmd-version")
    parser.add_argument(
        "--antivirus-state",
        default="not controlled or queried by the benchmark harness",
    )
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--self-build-runs", type=int, default=1)
    parser.add_argument("--parallel-projects", type=int, default=4)
    parser.add_argument(
        "--output", type=Path,
        default=ROOT / "build-output" / "selfhost-sh27" / "production-comparators.json",
    )
    parser.add_argument("--require-all", action="store_true")
    parser.add_argument("--enforce-parity", action="store_true")
    args = parser.parse_args()

    corpus_path = args.corpus.resolve()
    corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
    validate_corpus(corpus)
    measurement = corpus["measurement"]
    if args.runs < int(measurement["minimum_runs"]):
        raise SystemExit(
            f"--runs must be at least {measurement['minimum_runs']} for percentile evidence"
        )
    if args.self_build_runs < 1 or not 1 <= args.parallel_projects <= 16:
        raise SystemExit("self-build runs must be positive and parallel projects must be 1..16")

    output = args.output.resolve()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_root = output.parent / f"{output.stem}-runs-{stamp}"
    run_root.mkdir(parents=True, exist_ok=False)

    base_environment = dict(os.environ)
    msvc_environment, vcvars = capture_msvc_environment(args.msvc_toolset)
    open_path = resolve_tool(args.openc, ["openc.exe"], base_environment)
    clang_path = resolve_tool(
        args.clang,
        ["clang-cl.exe", r"C:\Program Files\LLVM\bin\clang-cl.exe"],
        base_environment,
    )
    dmd_explicit = args.dmd
    if dmd_explicit is None and os.environ.get("DC"):
        configured_dmd = Path(os.environ["DC"])
        configured_name = configured_dmd.name
        if configured_dmd.suffix == "":
            configured_name += ".exe"
        bin64_dmd = configured_dmd.parent.parent / "bin64" / configured_name
        dmd_explicit = bin64_dmd if bin64_dmd.is_file() else configured_dmd
    dmd_path = resolve_tool(dmd_explicit, ["dmd.exe", "dmd"], base_environment)
    msvc_path = (
        resolve_tool(args.msvc, ["cl.exe"], msvc_environment)
        if msvc_environment is not None else None
    )
    resolved = {
        "openc": (open_path, base_environment),
        "msvc": (msvc_path, msvc_environment or base_environment),
        "clang": (clang_path, msvc_environment or base_environment),
        "dmd": (dmd_path, base_environment),
    }
    missing = [name for name, (path, _) in resolved.items() if path is None]
    if open_path is None:
        raise SystemExit(f"missing OpenC compiler: {args.openc.resolve()}")
    if args.require_all and missing:
        raise SystemExit("missing required production comparators: " + ", ".join(missing))
    available = [name for name in ("openc", "msvc", "clang", "dmd") if name not in missing]
    version_arguments = {
        "openc": ["version"], "msvc": [], "clang": ["--version"],
        "dmd": ["--version"],
    }
    tools: dict[str, object] = {}
    for name in available:
        path, environment = resolved[name]
        tools[name] = version_record(path, version_arguments[name], environment)
    expected_versions = {
        "msvc": args.expected_msvc_version,
        "clang": args.expected_clang_version,
        "dmd": args.expected_dmd_version,
    }
    version_pin_checks = {
        name: expected is None or expected in str(tools.get(name, {}).get("output", ""))
        for name, expected in expected_versions.items()
        if name in available
    }

    language_for_tool = {"openc": "openc", "msvc": "msvc", "clang": "msvc", "dmd": "dmd"}
    generated: dict[str, dict[str, dict[str, object]]] = {}
    for workload in corpus["workloads"]:
        workload_id = str(workload["id"])
        generated[workload_id] = {}
        for language in ("openc", "msvc", "dmd"):
            generated[workload_id][language] = generate_language(
                run_root / "corpus" / workload_id / language, language, workload
            )

    sample_interval = float(measurement["sample_interval_seconds"])
    max_private = int(measurement["max_private_mib_per_compiler"]) * MIB
    max_working = int(measurement["max_working_set_mib_per_compiler"]) * MIB
    max_output = int(measurement["max_captured_output_mib"]) * MIB
    execution_timeout = int(measurement["execution_timeout_seconds"])
    lanes: dict[str, dict[str, object]] = {}
    integrity = True

    for workload_index, workload in enumerate(corpus["workloads"]):
        workload_id = str(workload["id"])
        tool_samples: dict[str, list[dict[str, object]]] = {name: [] for name in available}
        for run in range(args.runs):
            rotated = available[(run + workload_index) % len(available):] + available[:(run + workload_index) % len(available)]
            for tool in rotated:
                path, environment = resolved[tool]
                sample = run_sample(
                    tool=tool, executable=path, environment=environment,
                    input_record=generated[workload_id][language_for_tool[tool]],
                    sample_root=run_root / "clean" / workload_id / tool / f"run-{run + 1:02d}",
                    sample_interval=sample_interval,
                    max_private_bytes=max_private,
                    max_working_set_bytes=max_working,
                    max_output_bytes=max_output,
                    execution_timeout=execution_timeout,
                )
                sample["run"] = run + 1
                sample["cache_state"] = "first_observation" if run == 0 else "warm_os_cache"
                tool_samples[tool].append(sample)
                integrity = integrity and bool(sample["passed"])
                print(f"{workload_id}: {tool} {run + 1}/{args.runs}", flush=True)
        lanes[workload_id] = {
            "workload": workload,
            "inputs": {
                language: record["tree"] for language, record in generated[workload_id].items()
            },
            "compilers": {
                tool: {"summary": summarize(samples), "samples": samples}
                for tool, samples in tool_samples.items()
            },
        }

    edit_workload_id = "many_files"
    edit_lanes: dict[str, object] = {}
    for tool in available:
        path, environment = resolved[tool]
        record = generated[edit_workload_id][language_for_tool[tool]]
        edit_file = record["sources"][-1]
        original = edit_file.read_text(encoding="ascii")
        samples: list[dict[str, object]] = []
        for run in range(args.runs):
            edit_file.write_text(
                original + f"// sh27-one-source-edit-{run % 2}\n",
                encoding="ascii", newline="\n",
            )
            sample = run_sample(
                tool=tool, executable=path, environment=environment,
                input_record=record,
                sample_root=run_root / "one-source-edit" / tool,
                sample_interval=sample_interval,
                max_private_bytes=max_private,
                max_working_set_bytes=max_working,
                max_output_bytes=max_output,
                execution_timeout=execution_timeout,
            )
            sample["run"] = run + 1
            sample["changed_source"] = edit_file.name
            sample["edit_variant"] = run % 2
            samples.append(sample)
            integrity = integrity and bool(sample["passed"])
            print(f"one-source-edit: {tool} {run + 1}/{args.runs}", flush=True)
        edit_file.write_text(original, encoding="ascii", newline="\n")
        edit_lanes[tool] = {"summary": summarize(samples), "samples": samples}
    lanes["one_source_edit"] = {
        "base_workload": edit_workload_id,
        "policy": "same source tree and output directory; exactly one source text changes before each full compiler invocation",
        "compilers": edit_lanes,
    }

    parallel_lanes: dict[str, object] = {}
    parallel_input_id = "small_single_file"
    for tool in available:
        path, environment = resolved[tool]
        started = time.perf_counter()
        with ThreadPoolExecutor(max_workers=args.parallel_projects) as executor:
            futures = [
                executor.submit(
                    run_sample,
                    tool=tool, executable=path, environment=environment,
                    input_record=generated[parallel_input_id][language_for_tool[tool]],
                    sample_root=run_root / "parallel" / tool / f"project-{index + 1:02d}",
                    sample_interval=sample_interval,
                    max_private_bytes=max_private,
                    max_working_set_bytes=max_working,
                    max_output_bytes=max_output,
                    execution_timeout=execution_timeout,
                )
                for index in range(args.parallel_projects)
            ]
            samples = [future.result() for future in futures]
        wall = round(time.perf_counter() - started, 6)
        passed = all(bool(sample["passed"]) for sample in samples)
        integrity = integrity and passed
        parallel_lanes[tool] = {
            "projects": args.parallel_projects,
            "wall_seconds": wall,
            "throughput_projects_per_second": round(args.parallel_projects / wall, 3),
            "passed": passed,
            "samples": samples,
        }
        print(f"parallel: {tool} {args.parallel_projects} projects", flush=True)
    lanes["parallel_projects"] = {
        "base_workload": parallel_input_id,
        "compilers": parallel_lanes,
    }

    self_build_samples: list[dict[str, object]] = []
    self_project = ROOT / "compiler" / "selfhost" / "openc.project.json"
    self_input = {"project": self_project, "sources": []}
    for run in range(args.self_build_runs):
        sample = run_sample(
            tool="openc", executable=open_path, environment=base_environment,
            input_record=self_input,
            sample_root=run_root / "openc-self-build" / f"run-{run + 1:02d}",
            sample_interval=sample_interval,
            max_private_bytes=max_private,
            max_working_set_bytes=max_working,
            max_output_bytes=max_output,
            execution_timeout=execution_timeout,
        )
        sample["run"] = run + 1
        self_build_samples.append(sample)
        integrity = integrity and bool(sample["passed"])
        print(f"OpenC complete self-build: {run + 1}/{args.self_build_runs}", flush=True)
    lanes["openc_complete_self_build"] = {
        "project": str(self_project),
        "summary": summarize(self_build_samples),
        "samples": self_build_samples,
    }

    ratios: dict[str, dict[str, float]] = {}
    ratio_limit = float(corpus["parity"]["maximum_openc_to_comparator_median_ratio"])
    ratio_checks: dict[str, bool] = {}
    for workload in corpus["workloads"]:
        workload_id = str(workload["id"])
        compilers = lanes[workload_id]["compilers"]
        open_median = float(compilers["openc"]["summary"]["median_seconds"])
        ratios[workload_id] = {}
        for comparator in ("msvc", "clang", "dmd"):
            if comparator not in compilers:
                continue
            comparator_median = float(compilers[comparator]["summary"]["median_seconds"])
            ratio = open_median / comparator_median if comparator_median else float("inf")
            ratios[workload_id][f"openc_to_{comparator}"] = round(ratio, 3)
            ratio_checks[f"{workload_id}_openc_at_most_{ratio_limit}x_{comparator}"] = ratio <= ratio_limit

    all_comparators_present = not missing
    parity = all_comparators_present and bool(ratio_checks) and all(ratio_checks.values())
    version_pins_match = all(version_pin_checks.values())
    if (
        not integrity
        or (args.require_all and not all_comparators_present)
        or (args.require_all and not version_pins_match)
    ):
        status = "FAIL"
    elif args.enforce_parity and not parity:
        status = "FAIL_PARITY"
    elif not all_comparators_present:
        status = "PARTIAL_COMPARATOR_SET"
    elif parity:
        status = "PASS_PARITY"
    else:
        status = "EVIDENCE_COMPLETE_DEFICIT"

    result = {
        "schema": SCHEMA,
        "status": status,
        "measured_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "host": {
            "system": platform.system(), "release": platform.release(),
            "version": platform.version(), "machine": platform.machine(),
            "processor": platform.processor(), "logical_cpus": os.cpu_count(),
            "github_actions": os.environ.get("GITHUB_ACTIONS") == "true",
            "runner_name": os.environ.get("RUNNER_NAME"),
            "runner_image_os": os.environ.get("ImageOS"),
            "runner_image_version": os.environ.get("ImageVersion"),
        },
        "corpus": {
            "path": str(corpus_path), "sha256": sha256(corpus_path),
            "schema": corpus["schema"], "version": corpus["version"],
        },
        "environment": {
            "cache_policy": "OS cache is not flushed; first observation and subsequent warm observations are labeled",
            "run_order": "deterministically rotated by workload and run",
            "msvc_vcvars64": vcvars,
            "msvc_toolset_request": args.msvc_toolset,
            "antivirus_state": args.antivirus_state,
            "python": sys.version,
            "python_role": "optional evidence orchestration only; absent from normal OpenC compilation",
        },
        "tools": tools,
        "missing_tools": missing,
        "required_all": args.require_all,
        "gates": {
            "max_private_bytes_per_compiler": max_private,
            "max_working_set_bytes_per_compiler": max_working,
            "maximum_openc_to_comparator_median_ratio": ratio_limit,
        },
        "lanes": lanes,
        "ratios": ratios,
        "checks": {
            "all_requested_compilers_present": all_comparators_present,
            "requested_comparator_versions_match": version_pins_match,
            "version_pin_checks": version_pin_checks,
            "all_compile_memory_and_execution_checks_passed": integrity,
            **ratio_checks,
        },
        "claims": {
            "broad_production_parity": parity,
            "normal_toolchain_independence_changed": False,
            "remaining_corpus_expansion": [
                "file I/O and allocation runtime workloads",
                "incremental object reuse/build-system integration",
                "LDC comparator",
                "broader real-project corpus",
            ],
        },
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"SH-27 production comparison: {status}; report={output}", flush=True)
    if status in ("FAIL", "FAIL_PARITY"):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
