#!/usr/bin/env python3
"""Prove SH-5 closure through the vendored DMD-independent Windows backend."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized_pe(path: Path) -> bytes:
    data = bytearray(path.read_bytes())
    if len(data) < 0x40 or data[:2] != b"MZ":
        return bytes(data)
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if pe + 92 > len(data) or data[pe:pe + 4] != b"PE\0\0":
        return bytes(data)
    data[pe + 8:pe + 12] = b"\0" * 4
    optional = pe + 24
    data[optional + 64:optional + 68] = b"\0" * 4
    return bytes(data)


def clean_child_environment(tcc: Path) -> tuple[dict[str, str], list[str]]:
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
    command: list[str], environment: dict[str, str]
) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        env=environment,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return completed


def build(
    compiler: Path,
    output_executable: Path,
    environment: dict[str, str],
) -> None:
    project = ROOT / "compiler" / "selfhost" / "openc.project.json"
    run(
        [
            str(compiler),
            "build",
            f"--project={project}",
            f"--output={output_executable}",
        ],
        environment,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--stage0",
        type=Path,
        default=ROOT / "compiler" / "openc.exe",
        help="retained bootstrap seed used to prepare Stage 1",
    )
    parser.add_argument(
        "--stage1",
        type=Path,
        default=ROOT
        / "build-output"
        / "selfhost-sh5"
        / "stage1"
        / "openc-selfhost-frontend.exe",
        help="trusted SH-4 compiler used only to enter the SH-5 closure",
    )
    parser.add_argument(
        "--use-existing-stage1",
        action="store_true",
        help="do not rebuild the trusted Stage-1 entry compiler",
    )
    parser.add_argument(
        "--tcc",
        type=Path,
        default=ROOT / "third_party" / "tinycc-win64" / "tcc.exe",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh5" / "closure",
    )
    args = parser.parse_args()

    stage0 = args.stage0.resolve()
    stage1 = args.stage1.resolve()
    tcc = args.tcc.resolve()
    output = args.output.resolve()
    project = ROOT / "compiler" / "selfhost" / "openc.project.json"
    if not args.use_existing_stage1:
        if not stage0.is_file():
            raise SystemExit(f"missing retained stage-0 compiler: {stage0}")
        stage1.parent.mkdir(parents=True, exist_ok=True)
        run(
            [
                str(stage0),
                "build",
                f"--project={project}",
                f"--output={stage1}",
                f"--build_record={stage1.parent / 'stage1-seed-build-record.json'}",
            ],
            os.environ.copy(),
        )
    elif not stage1.is_file():
        raise SystemExit(f"missing trusted stage-1 compiler: {stage1}")
    if not tcc.is_file():
        raise SystemExit(f"missing vendored TinyCC executable: {tcc}")
    output.mkdir(parents=True, exist_ok=True)

    stage2 = output / "openc-stage2.exe"
    stage3 = output / "openc-stage3.exe"
    generated2 = Path(str(stage2) + ".openc.c")
    generated3 = Path(str(stage3) + ".openc.c")
    record2 = Path(str(stage2) + ".build.json")
    record3 = Path(str(stage3) + ".build.json")
    environment, clean_path = clean_child_environment(tcc)

    build(stage1, stage2, environment)
    build(stage2, stage3, environment)

    source_probe = ROOT / "compiler" / "selfhost" / "source" / "main.p"
    ir_probe = ROOT / "programs" / "A_COMPUTATION" / "openc.project.json"
    lexer2 = run([str(stage2), str(source_probe)], environment).stdout
    lexer3 = run([str(stage3), str(source_probe)], environment).stdout
    ir2 = run([str(stage2), "--semantic-ir", str(ir_probe)], environment).stdout
    ir3 = run([str(stage3), "--semantic-ir", str(ir_probe)], environment).stdout
    build2 = json.loads(record2.read_text(encoding="utf-8"))
    build3 = json.loads(record3.read_text(encoding="utf-8"))
    normalized2 = normalized_pe(stage2)
    normalized3 = normalized_pe(stage3)

    records_clean = all(
        record.get("status") == "PASS"
        and record.get("dmd_invoked") is False
        and record.get("dub_invoked") is False
        and record.get("python_invoked") is False
        for record in (build2, build3)
    )
    checks = {
        "vendored_tcc_present": tcc.is_file(),
        "stage1_builds_native_stage2": stage2.is_file(),
        "native_stage2_builds_native_stage3": stage3.is_file(),
        "stage2_stage3_generated_c_byte_equal": (
            generated2.read_bytes() == generated3.read_bytes()
        ),
        "stage2_stage3_lexer_behavior_equal": lexer2 == lexer3,
        "stage2_stage3_canonical_ir_equal": ir2 == ir3,
        "stage2_stage3_normalized_artifact_equal": normalized2 == normalized3,
        "build_records_exclude_dmd_dub_python": records_clean,
    }
    result = {
        "schema": "openc.self_host_windows_closure.v1",
        "stage": "SH-5_DMD_INDEPENDENT_WINDOWS_BACKEND",
        "status": "PASS" if all(checks.values()) else "FAIL",
        "checks": checks,
        "environment": {
            "child_path": clean_path,
            "harness": "Python verifier outside compiler child processes",
            "stage1_prepared_by_retained_stage0": not args.use_existing_stage1,
            "dmd_available_to_native_build": False,
            "dub_available_to_native_build": False,
            "python_available_to_native_build": False,
        },
        "artifacts": {
            "stage2_sha256": sha256(stage2.read_bytes()),
            "stage3_sha256": sha256(stage3.read_bytes()),
            "stage2_normalized_sha256": sha256(normalized2),
            "stage3_normalized_sha256": sha256(normalized3),
            "generated_c_sha256": sha256(generated2.read_bytes()),
            "lexer_observation_sha256": sha256(lexer2.encode("utf-8")),
            "canonical_ir_sha256": sha256(ir2.encode("utf-8")),
            "tcc_sha256": sha256(tcc.read_bytes()),
        },
        "normalization": ["PE COFF TimeDateStamp", "PE optional-header checksum"],
        "build_records": [str(record2), str(record3)],
    }
    result_path = output / "bootstrap-windows-closure-result.json"
    result_path.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if result["status"] != "PASS":
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit(f"SH-5 closure failed: {', '.join(failed)}")
    print(
        "SH-5 Windows bootstrap closure: PASS; "
        f"c={result['artifacts']['generated_c_sha256']} "
        f"pe={result['artifacts']['stage3_normalized_sha256']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
