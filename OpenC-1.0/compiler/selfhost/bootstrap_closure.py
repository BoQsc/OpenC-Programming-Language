#!/usr/bin/env python3
"""Build Stage 1 -> Stage 2 -> Stage 3 and prove bootstrap closure."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        command, cwd=ROOT, text=True, capture_output=True, encoding="utf-8"
    )
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return completed


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def generated_snapshot(directory: Path) -> dict[str, dict[str, object]]:
    return {
        path.name: {
            "bytes": path.stat().st_size,
            "sha256": sha256(path.read_bytes()),
        }
        for path in sorted(directory.glob("*.d"))
    }


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument("--d-compiler", default=shutil.which("dmd") or "dmd")
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost-sh4")
    args = parser.parse_args()
    stage0 = args.stage0.resolve()
    d_compiler = str(Path(args.d_compiler).resolve())
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    project = ROOT / "compiler" / "selfhost" / "openc.project.json"
    runtime = ROOT / "runtime" / "source" / "openc" / "runtime"
    library = ROOT / "standard_library" / "source" / "openc" / "std"
    source_probe = ROOT / "compiler" / "selfhost" / "source" / "main.p"
    ir_probe = ROOT / "programs" / "A_COMPUTATION" / "openc.project.json"
    stage1 = output / "openc-stage1.exe"
    stage2 = output / "openc-stage2.exe"
    stage3 = output / "openc-stage3.exe"
    generated1 = output / "stage1-generated"
    generated2 = output / "stage2-generated"
    generated3 = output / "stage3-generated"
    for directory in (generated1, generated2, generated3):
        directory.mkdir(parents=True, exist_ok=True)

    run([
        str(stage0), "build", f"--project={project}", f"--output={stage1}",
        f"--generated-output={generated1}",
        f"--build_record={output / 'stage1-build-record.json'}",
    ])
    run([
        str(stage1), "--bootstrap-build", str(project), str(stage2), str(generated2),
        str(runtime), str(library), str(output / "stage2-build-record.json"), d_compiler,
    ])
    run([
        str(stage2), "--bootstrap-build", str(project), str(stage3), str(generated3),
        str(runtime), str(library), str(output / "stage3-build-record.json"), d_compiler,
    ])

    snapshot1 = generated_snapshot(generated1)
    snapshot2 = generated_snapshot(generated2)
    snapshot3 = generated_snapshot(generated3)
    stage1_stage2_source_equal = snapshot1 == snapshot2
    stage2_stage3_source_equal = snapshot2 == snapshot3

    lexer2 = run([str(stage2), str(source_probe)]).stdout
    lexer3 = run([str(stage3), str(source_probe)]).stdout
    ir2 = run([str(stage2), "--semantic-ir", str(ir_probe)]).stdout
    ir3 = run([str(stage3), "--semantic-ir", str(ir_probe)]).stdout
    normalized2 = normalized_pe(stage2)
    normalized3 = normalized_pe(stage3)

    checks = {
        "stage0_builds_stage1": stage1.is_file(),
        "stage1_builds_stage2": stage2.is_file(),
        "stage2_builds_stage3": stage3.is_file(),
        "stage1_stage2_generated_source_equal": stage1_stage2_source_equal,
        "stage2_stage3_generated_source_equal": stage2_stage3_source_equal,
        "stage2_stage3_lexer_behavior_equal": lexer2 == lexer3,
        "stage2_stage3_canonical_ir_equal": ir2 == ir3,
        "stage2_stage3_normalized_artifact_equal": normalized2 == normalized3,
    }
    result = {
        "schema": "openc.self_host_bootstrap_closure.v1",
        "stage": "SH-4C_BOOTSTRAP_CLOSURE",
        "status": "PASS" if all(checks.values()) else "FAIL",
        "checks": checks,
        "artifacts": {
            "stage1": str(stage1),
            "stage2": str(stage2),
            "stage3": str(stage3),
            "generated_source_files": len(snapshot3),
            "stage2_normalized_sha256": sha256(normalized2),
            "stage3_normalized_sha256": sha256(normalized3),
            "lexer_observation_sha256": sha256(lexer2.encode("utf-8")),
            "canonical_ir_sha256": sha256(ir2.encode("utf-8")),
        },
        "normalization": ["PE COFF TimeDateStamp", "PE optional-header checksum"],
        "generated": {
            "stage1": snapshot1,
            "stage2": snapshot2,
            "stage3": snapshot3,
        },
        "build_records": [
            str(output / "stage1-build-record.json"),
            str(output / "stage2-build-record.json"),
            str(output / "stage3-build-record.json"),
        ],
    }
    result_path = output / "bootstrap-closure-result.json"
    result_path.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if result["status"] != "PASS":
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit(f"bootstrap closure failed: {', '.join(failed)}")
    print(
        "self-host bootstrap closure: PASS; "
        f"generated={len(snapshot3)} normalized={sha256(normalized3)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
