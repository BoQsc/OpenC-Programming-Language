#!/usr/bin/env python3
"""Verify the extracted OpenC standalone Windows distribution."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import zipfile


PROGRAMS = (
    ("A_COMPUTATION", 32, (), ""),
    ("B_FLOW_OWNERSHIP", 0, (), ""),
    ("C_UNSAFE_BOUNDARY", 30, (), ""),
    (
        "D_HOSTED_CLI",
        0,
        ("alpha", "two words"),
        "arguments: 2\n0: alpha\n1: two words\n",
    ),
)
REQUIRED_CONFORMANCE_FIXTURES = 278
REQUIRED_DIAGNOSTIC_CONTRACTS = 153
REQUIRED_RUNTIME_FIXTURES = 35


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalized_pe(path: Path) -> bytes:
    data = bytearray(path.read_bytes())
    if len(data) < 0x40 or data[:2] != b"MZ":
        return bytes(data)
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if pe + 92 > len(data) or data[pe : pe + 4] != b"PE\0\0":
        return bytes(data)
    data[pe + 8 : pe + 12] = b"\0" * 4
    optional = pe + 24
    data[optional + 64 : optional + 68] = b"\0" * 4
    return bytes(data)


def safe_extract(archive: Path, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        names = [Path(info.filename) for info in bundle.infolist()]
        if not names:
            raise SystemExit("standalone archive is empty")
        roots = {name.parts[0] for name in names if name.parts}
        if len(roots) != 1:
            raise SystemExit("standalone archive must contain exactly one root")
        for name in names:
            if name.is_absolute() or ".." in name.parts:
                raise SystemExit(f"unsafe archive member: {name}")
        bundle.extractall(destination)
    return destination / roots.pop()


def verify_manifest(root: Path) -> tuple[int, list[str]]:
    manifest = root / "STANDALONE-MANIFEST.sha256"
    failures = []
    lines = manifest.read_text(encoding="utf-8").splitlines()
    for line in lines:
        expected, relative = line.split("  ", 1)
        path = root / Path(relative)
        if not path.is_file():
            failures.append(f"missing:{relative}")
        elif sha256(path) != expected:
            failures.append(f"hash:{relative}")
    return len(lines), failures


def clean_native_environment(tcc: Path) -> tuple[dict[str, str], list[str]]:
    environment = os.environ.copy()
    system_root = Path(environment.get("SystemRoot", r"C:\Windows"))
    path_entries = [str(system_root / "System32"), str(tcc.parent)]
    environment["PATH"] = os.pathsep.join(path_entries)
    for name in (
        "DC",
        "DMD",
        "DUB",
        "DFLAGS",
        "PYTHONHOME",
        "PYTHONPATH",
        "VIRTUAL_ENV",
    ):
        environment.pop(name, None)
    return environment, path_entries


def run(
    command: list[str],
    cwd: Path,
    environment: dict[str, str],
    label: str,
) -> subprocess.CompletedProcess[str]:
    print(f"[SH-7] {label}", flush=True)
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=environment,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    if completed.returncode != 0:
        raise SystemExit(
            f"{label} failed ({completed.returncode})\n"
            f"command: {' '.join(command)}\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return completed


def native_build(
    compiler: Path,
    project: Path,
    output: Path,
    cwd: Path,
    environment: dict[str, str],
    label: str,
) -> None:
    run(
        [
            str(compiler),
            "build",
            f"--project={project}",
            f"--output={output}",
        ],
        cwd,
        environment,
        label,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--comparison-archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument(
        "--audit-seed",
        action="store_true",
        help="run the optional retained-D semantic/IR comparison oracle",
    )
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    archive = args.archive.resolve()
    comparison_archive = args.comparison_archive.resolve()
    output = args.output.resolve()
    if archive.read_bytes() != comparison_archive.read_bytes():
        raise SystemExit(
            "independent standalone archive builds are not byte-identical"
        )
    if output.exists():
        if not args.force:
            raise SystemExit(f"verification output already exists: {output}")
        if output == Path(output.anchor) or len(output.parts) < 3:
            raise SystemExit(f"refusing to replace broad output path: {output}")
        shutil.rmtree(output)
    output.mkdir(parents=True)
    distribution = safe_extract(archive, output / "extracted")
    foreign_cwd = output / "foreign working directory"
    foreign_cwd.mkdir()

    manifest_count, manifest_failures = verify_manifest(distribution)
    if manifest_failures:
        raise SystemExit(
            "standalone manifest failed: " + ", ".join(manifest_failures[:10])
        )
    compiler = distribution / "openc.exe"
    seed = distribution / "bootstrap" / "openc-stage0.exe"
    tcc = distribution / "third_party" / "tinycc-win64" / "tcc.exe"
    project = distribution / "compiler" / "selfhost" / "openc.project.json"
    environment, clean_path = clean_native_environment(tcc)

    stage2_root = output / "stage2-distribution"
    stage3_root = output / "stage3-distribution"
    shutil.copytree(distribution, stage2_root)
    shutil.copytree(distribution, stage3_root)
    stage2 = stage2_root / "openc.exe"
    stage3 = stage3_root / "openc.exe"
    stage2.unlink()
    stage3.unlink()
    native_build(
        compiler,
        project,
        stage2,
        foreign_cwd,
        environment,
        "packaged OpenC compiler builds Stage 2 from a foreign cwd",
    )
    native_build(
        stage2,
        project,
        stage3,
        foreign_cwd,
        environment,
        "packaged Stage 2 builds Stage 3",
    )

    generated2 = Path(str(stage2) + ".openc.c")
    generated3 = Path(str(stage3) + ".openc.c")
    record2 = json.loads(
        Path(str(stage2) + ".build.json").read_text(encoding="utf-8")
    )
    record3 = json.loads(
        Path(str(stage3) + ".build.json").read_text(encoding="utf-8")
    )
    normalized2 = normalized_pe(stage2)
    normalized3 = normalized_pe(stage3)

    maintained_results = []
    program_output = output / "maintained"
    program_output.mkdir()
    for name, expected_exit, arguments, expected_stdout in PROGRAMS:
        executable = program_output / f"{name}.exe"
        native_build(
            stage3,
            distribution / "programs" / name / "openc.project.json",
            executable,
            foreign_cwd,
            environment,
            f"native build of maintained program {name}",
        )
        completed = subprocess.run(
            [str(executable), *arguments],
            cwd=foreign_cwd,
            env=environment,
            text=True,
            capture_output=True,
            encoding="utf-8",
        )
        maintained_results.append(
            {
                "program": name,
                "expected_exit_code": expected_exit,
                "actual_exit_code": completed.returncode,
                "expected_stdout": expected_stdout,
                "stdout": completed.stdout,
                "stderr": completed.stderr,
                "passed": (
                    completed.returncode == expected_exit
                    and completed.stdout == expected_stdout
                ),
                "executable_sha256": sha256(executable),
            }
        )
    maintained_passed = sum(item["passed"] for item in maintained_results)
    if maintained_passed != len(maintained_results):
        raise SystemExit(
            f"native maintained-program gate failed: "
            f"{maintained_passed}/{len(maintained_results)}"
        )

    parity_output = output / "semantic-parity"
    parity_stdout = ""
    parity_report: dict[str, object] = {
        "status": "NOT_RUN_OPTIONAL",
        "reason": "retained D seed is not part of the required SH-7 gate",
    }
    if args.audit_seed:
        parity = run(
            [
                sys.executable,
                str(
                    distribution
                    / "compiler"
                    / "selfhost"
                    / "semantic_ir_parity.py"
                ),
                "--stage0",
                str(seed),
                "--stage1",
                str(stage3),
                "--output",
                str(parity_output),
                "--jobs",
                str(max(1, args.jobs)),
            ],
            distribution,
            environment,
            "optional retained-D semantic/IR audit",
        )
        parity_stdout = parity.stdout
        parity_report = json.loads(
            (parity_output / "semantic-ir-parity-result.json").read_text(
                encoding="utf-8"
            )
        )

    conformance_report_path = output / "conformance-report.json"
    conformance = run(
        [
            str(stage3),
            "validate",
            f"--manifest={distribution / 'conformance' / 'fixtures' / 'MANIFEST.json'}",
            f"--output={conformance_report_path}",
        ],
        foreign_cwd,
        environment,
        "OpenC-authored native runner executes all packaged conformance fixtures",
    )
    conformance_report = json.loads(
        conformance_report_path.read_text(encoding="utf-8")
    )
    conformance_results = conformance_report.get("results", [])
    diagnostic_results = [
        item for item in conformance_results if item.get("expected_rule")
    ]
    runtime_results = [
        item
        for item in conformance_results
        if item.get("fixture_kind") == "runtime"
    ]

    checks = {
        "independent_archive_builds_byte_equal": True,
        "archive_manifest_valid": not manifest_failures,
        "package_is_relocatable_from_foreign_cwd": stage2.is_file(),
        "packaged_compiler_builds_stage2": stage2.is_file(),
        "stage2_builds_stage3": stage3.is_file(),
        "generated_c_byte_equal": generated2.read_bytes() == generated3.read_bytes(),
        "native_executable_byte_equal": stage2.read_bytes() == stage3.read_bytes(),
        "normalized_pe_equal": normalized2 == normalized3,
        "native_build_records_exclude_dmd_dub_python": all(
            record.get("status") == "PASS"
            and record.get("dmd_invoked") is False
            and record.get("dub_invoked") is False
            and record.get("python_invoked") is False
            for record in (record2, record3)
        ),
        "maintained_programs_4_of_4": maintained_passed == len(PROGRAMS),
        "native_openc_validate_278_of_278": (
            conformance_report.get("schema") == "openc.conformance_result.v2"
            and conformance_report.get("evidence_state") == "EXECUTED_NATIVE"
            and conformance_report.get("implementation", {}).get("language")
            == "OpenC"
            and conformance_report.get("total") == REQUIRED_CONFORMANCE_FIXTURES
            and conformance_report.get("passed") == REQUIRED_CONFORMANCE_FIXTURES
            and conformance_report.get("failed") == 0
            and conformance_report.get("infrastructure_failures") == 0
        ),
        "exact_diagnostic_contracts_153_of_153": (
            len(diagnostic_results) == REQUIRED_DIAGNOSTIC_CONTRACTS
            and all(item.get("rule_matched") for item in diagnostic_results)
            and (
                conformance_report.get("exact_native_diagnostic_observations", 0)
                + conformance_report.get(
                    "native_fixture_contract_diagnostics", 0
                )
                == REQUIRED_DIAGNOSTIC_CONTRACTS
            )
        ),
        "native_runtime_35_of_35": (
            len(runtime_results) == REQUIRED_RUNTIME_FIXTURES
            and all(
                item.get("runtime_execution") == "EXECUTED"
                and item.get("passed")
                for item in runtime_results
            )
        ),
        "required_conformance_command_uses_native_stage3": True,
    }
    result = {
        "schema": "openc.self_host_standalone_release.v1",
        "stage": "SH7_NATIVE_CONFORMANCE",
        "status": "PASS" if all(checks.values()) else "FAIL",
        "checks": checks,
        "roles": {
            "compiler_under_test": "OpenC-native openc.exe",
            "supported_library_mode": (
                "compiler-provided system.file/io/memory/path/process/text "
                "modules backed by the packaged Windows C runtime and native shim"
            ),
            "authored_native_provider_sources": (
                "packaged but outside the Windows Hosted gate"
            ),
            "bootstrap_seed": (
                "optional retained D comparison oracle; packaged for audit "
                "continuity but never executed by the required SH-7 gate"
            ),
            "python": "external evidence harness only",
        },
        "environment": {
            "native_child_path": clean_path,
            "native_build_dmd_available": False,
            "native_build_dub_available": False,
            "native_build_python_available": False,
            "verification_cwd": str(foreign_cwd),
            "distribution_root": str(distribution),
            "linux_and_freestanding_gate": False,
            "native_provider_gate": False,
            "retained_d_seed_executed": args.audit_seed,
        },
        "artifacts": {
            "archive": str(archive),
            "archive_sha256": sha256(archive),
            "comparison_archive": str(comparison_archive),
            "comparison_archive_sha256": sha256(comparison_archive),
            "package_manifest_entries": manifest_count,
            "packaged_compiler_sha256": sha256(compiler),
            "bootstrap_seed_sha256": sha256(seed),
            "stage2_sha256": sha256(stage2),
            "stage3_sha256": sha256(stage3),
            "normalized_stage2_sha256": hashlib.sha256(normalized2).hexdigest(),
            "normalized_stage3_sha256": hashlib.sha256(normalized3).hexdigest(),
            "generated_c_sha256": sha256(generated2),
            "tcc_sha256": sha256(tcc),
            "optional_semantic_parity_report": (
                str(parity_output / "semantic-ir-parity-result.json")
                if args.audit_seed
                else None
            ),
            "conformance_report": str(conformance_report_path),
        },
        "optional_seed_audit": {
            "executed": args.audit_seed,
            "status": parity_report.get("status"),
            "ir_comparisons": parity_report.get("ir_comparisons"),
            "semantic_rejections": parity_report.get("semantic_rejections"),
            "authored_source_fixtures": parity_report.get(
                "authored_source_fixtures"
            ),
        },
        "conformance": {
            "total": conformance_report.get("total"),
            "passed": conformance_report.get("passed"),
            "failed": conformance_report.get("failed"),
            "infrastructure_failures": conformance_report.get(
                "infrastructure_failures"
            ),
            "exact_native_diagnostic_observations": conformance_report.get(
                "exact_native_diagnostic_observations"
            ),
            "native_fixture_contract_diagnostics": conformance_report.get(
                "native_fixture_contract_diagnostics"
            ),
            "runtime_fixtures": len(runtime_results),
        },
        "maintained_programs": maintained_results,
        "optional_seed_audit_stdout": parity_stdout,
        "conformance_harness_stdout": conformance.stdout,
        "normalization": [
            "PE COFF TimeDateStamp",
            "PE optional-header checksum",
        ],
    }
    result_path = output / "standalone-release-result.json"
    result_path.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if result["status"] != "PASS":
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("SH-7 standalone gate failed: " + ", ".join(failed))
    print(
        "SH-7 native conformance and tooling independence: PASS; "
        f"conformance={conformance_report.get('passed')}/"
        f"{conformance_report.get('total')} "
        f"maintained={maintained_passed}/{len(PROGRAMS)} "
        f"result={result_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
