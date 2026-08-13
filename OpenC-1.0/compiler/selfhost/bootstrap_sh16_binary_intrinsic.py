#!/usr/bin/env python3
"""One-generation bridge for the SH-16 binary-file compiler intrinsic.

The SH-15 compiler emits the new call correctly but has no return-type entry
for it, so its generated C declares one SSA temporary as void. This bridge
changes only that generated temporary to ``oc_status`` and invokes the existing
TinyCC compiler-build backend. The resulting OpenC compiler understands the
intrinsic and must close Stage 3/Stage 4 without this bridge.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def patch_binary_intrinsic_temporary(source: str) -> tuple[str, str]:
    calls = re.findall(r"^    (v\d+) = oc_file_write_bytes\(", source, re.MULTILINE)
    if len(calls) != 1:
        raise ValueError(f"expected one binary intrinsic call, observed {len(calls)}")
    temporary = calls[0]
    declaration = f"    void {temporary};"
    if source.count(declaration) != 1:
        raise ValueError("binary intrinsic temporary is not uniquely void-typed")
    return source.replace(declaration, f"    oc_status {temporary};", 1), temporary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output/selfhost-sh16/bootstrap-bridge",
    )
    parser.add_argument(
        "--tcc",
        type=Path,
        default=ROOT / "third_party/tinycc-win64/tcc.exe",
    )
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    output = args.output.resolve()
    tcc = args.tcc.resolve()
    output.mkdir(parents=True, exist_ok=True)
    executable = output / "openc.exe"
    generated = output / "openc.exe.openc.c"
    build_record = output / "initial-build.json"
    response = output / "openc-tcc.rsp"
    command = [
        str(compiler),
        "--windows-build",
        str(ROOT / "compiler/selfhost/openc.project.json"),
        str(executable),
        str(generated),
        str(ROOT / "runtime"),
        str(ROOT / "compiler/selfhost/native_runtime"),
        str(build_record),
        str(tcc),
    ]
    initial = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if not generated.is_file() or not response.is_file():
        raise SystemExit(
            "SH-15 compiler did not emit the expected generated C and response file"
        )
    patched, temporary = patch_binary_intrinsic_temporary(
        generated.read_text(encoding="utf-8")
    )
    generated.write_text(patched, encoding="utf-8", newline="\n")
    linked = subprocess.run(
        [str(tcc), f"@{response}"], cwd=ROOT, capture_output=True, text=True
    )
    version = subprocess.run(
        [str(executable), "version"], cwd=ROOT, capture_output=True, text=True
    ) if executable.is_file() else None
    passed = (
        initial.returncode != 0
        and linked.returncode == 0
        and version is not None
        and version.returncode == 0
        and "compiler: OpenC self-hosted native" in version.stdout
    )
    record = {
        "schema": "openc.sh16_binary_intrinsic_bootstrap_bridge.v1",
        "status": "PASS" if passed else "FAIL",
        "role": "one_generation_compiler_bootstrap_only",
        "input_compiler": str(compiler),
        "input_compiler_sha256": sha256(compiler),
        "output_compiler": str(executable),
        "output_compiler_sha256": sha256(executable) if executable.is_file() else None,
        "patched_generated_c_sha256": sha256(generated),
        "patched_temporary": temporary,
        "initial_expected_type_failure_observed": initial.returncode != 0,
        "tinycc_exit_code": linked.returncode,
        "d_invoked": False,
        "external_assembler_invoked": False,
        "normal_build_or_runtime_dependency": False,
    }
    (output / "bootstrap-bridge-result.json").write_text(
        json.dumps(record, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    print(
        f"SH-16 binary intrinsic bootstrap bridge: {record['status']}; "
        f"output={executable}"
    )
    if not passed:
        if initial.stderr:
            print(initial.stderr)
        if linked.stderr:
            print(linked.stderr)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
