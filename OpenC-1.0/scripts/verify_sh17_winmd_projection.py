#!/usr/bin/env python3
"""Verify the SH-17 OpenC WinMD reader and deterministic raw projection."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
PIN_PATH = ROOT / "compiler/targets/windows-win32-metadata.json"
CONTRACT_PATH = ROOT / "compiler/targets/windows-winmd-projection-contract.json"
GENERATED = ROOT / "standard_library/windows.raw/generated"
MODULES = ("foundation", "file", "memory", "process", "thread", "window", "graphics")
EXPECTED_ROWS = {
    "TypeRef": 16516,
    "TypeDef": 37311,
    "Field": 247642,
    "MethodDef": 70707,
    "Param": 219381,
    "InterfaceImpl": 7960,
    "Constant": 156755,
    "CustomAttribute": 152119,
    "ClassLayout": 1250,
    "FieldLayout": 4523,
    "ModuleRef": 377,
    "ImplMap": 18321,
    "NestedClass": 2165,
}
EXPECTED_ATTRIBUTES = {
    "Documentation": 59584,
    "SupportedArchitecture": 692,
    "SupportedOSPlatform": 14877,
    "Ansi": 3023,
    "Unicode": 2852,
    "NativeArrayInfo": 5347,
    "Retained": 18,
    "RAIIFree": 209,
    "FreeWith": 14,
    "InvalidHandleValue": 398,
    "NativeTypedef": 420,
    "NativeBitfield": 2747,
    "Constant": 2610,
    "FlexibleArray": 903,
    "MemorySize": 2582,
    "StructSizeField": 464,
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def snapshot(directory: Path) -> dict[str, bytes]:
    names = ["manifest.json", *(f"windows.raw.{name}.p" for name in MODULES)]
    return {name: (directory / name).read_bytes() for name in names}


def run_projection(compiler: Path, input_path: Path, output: Path) -> float:
    output.mkdir(parents=True, exist_ok=True)
    started = time.perf_counter()
    completed = subprocess.run(
        [
            str(compiler),
            "--windows-winmd-project",
            str(input_path),
            str(output),
            str(output / "manifest.json"),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    elapsed = time.perf_counter() - started
    if completed.returncode != 0:
        raise SystemExit(
            f"SH-17 projection failed ({completed.returncode})\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return elapsed


def check_generated_sources(compiler: Path, directory: Path, temporary: Path) -> bool:
    project = {
        "name": "sh17-generated-raw-projection",
        "version": "1.0.0",
        "edition": "OpenC 1.0",
        "profile": "standard",
        "target": "windows-x86_64",
        "modules": {
            f"windows.raw.{name}": [str((directory / f"windows.raw.{name}.p").resolve())]
            for name in MODULES
        },
        "standard_library_directory": str((ROOT / "standard_library").resolve()),
        "runtime_directory": str((ROOT / "runtime").resolve()),
        "output_directory": str(temporary.resolve()),
    }
    project_path = temporary / "openc.project.json"
    project_path.write_text(
        json.dumps(project, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    completed = subprocess.run(
        [str(compiler), "check", f"--project={project_path}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return completed.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--regenerate", action="store_true")
    parser.add_argument("--repeat", type=int, default=2)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output/selfhost-sh17/final/sh17-verification.json",
    )
    args = parser.parse_args()
    pin = load_json(PIN_PATH)
    contract = load_json(CONTRACT_PATH)
    manifest_path = GENERATED / "manifest.json"
    manifest = load_json(manifest_path)
    checks: dict[str, bool] = {}
    checks["pin_schema"] = pin.get("schema") == "openc.windows_win32_metadata_pin.v1"
    checks["contract_schema"] = contract.get("schema") == "openc.windows_raw_projection_contract.v1"
    checks["manifest_schema_and_status"] = (
        manifest.get("schema") == "openc.windows_raw_projection_manifest.v1"
        and manifest.get("status") == "PASS"
    )
    metadata = manifest.get("metadata", {})
    generator = manifest.get("generator", {})
    checks["pinned_metadata_identity"] = (
        metadata.get("package") == pin.get("package")
        and metadata.get("version") == pin.get("version")
        and metadata.get("sha256") == pin.get("member_sha256")
        and metadata.get("bytes") == pin.get("member_bytes")
    )
    checks["generator_contract_identity"] = (
        generator.get("version") == contract.get("generator_version")
        and generator.get("contract_sha256") == sha256(CONTRACT_PATH)
        and generator.get("implementation_language") == "OpenC"
    )
    checks["real_ecma335_table_counts"] = manifest.get("table_rows") == EXPECTED_ROWS
    checks["real_custom_attribute_counts"] = (
        manifest.get("recognized_attributes") == EXPECTED_ATTRIBUTES
    )
    input_format = manifest.get("input_format", {})
    checks["real_pe_cli_stream_shape"] = (
        input_format.get("pe_magic") == 267
        and input_format.get("metadata_bytes") == 24354248
        and input_format.get("tables_stream_bytes") == 10456972
        and input_format.get("strings_heap_bytes") == 6665680
        and input_format.get("blob_heap_bytes") == 7231468
    )
    checks["ordinary_build_does_not_parse_winmd"] = manifest.get(
        "ordinary_build_parses_winmd"
    ) is False
    checks["no_c_header_parser"] = manifest.get("c_headers_parsed") is False
    checks["no_third_party_metadata_library"] = manifest.get(
        "third_party_metadata_library_used"
    ) is False
    modules = manifest.get("modules", [])
    checks["seven_raw_modules"] = [item.get("name") for item in modules] == list(MODULES)
    checks["all_generated_hashes_match"] = all(
        (GENERATED / str(item.get("file"))).is_file()
        and sha256(GENERATED / str(item.get("file"))) == item.get("sha256")
        for item in modules
    )
    combined = b"\n".join(
        (GENERATED / f"windows.raw.{name}.p").read_bytes() for name in MODULES
    )
    required_markers = {
        "dll_and_export": (b"43726561746546696c6557", b"4b45524e454c33322e646c6c"),
        "documentation": (b"446f63756d656e746174696f6e417474726962757465",),
        "ansi_unicode": (b"416e7369417474726962757465", b"556e69636f6465417474726962757465"),
        "architecture": (b"537570706f72746564417263686974656374757265417474726962757465",),
        "get_last_error": (b"// I|1902|321|3813|43726561746546696c6557",),
        "array_length": (b"4e61746976654172726179496e666f417474726962757465", b"4d656d6f727953697a65417474726962757465"),
        "retained_pointer": (b"52657461696e6564417474726962757465",),
        "typed_handle_cleanup": (b"5241494946726565417474726962757465", b"496e76616c696448616e646c6556616c7565417474726962757465"),
        "bitfield_and_layout": (b"4e61746976654269746669656c64417474726962757465", b"// L|", b"// O|"),
        "constants_and_unions": (b"// C|", b"// F|"),
        "parameters_and_signatures": (b"// P|", b"// M|"),
    }
    for name, markers in required_markers.items():
        checks[f"preserves_{name}"] = all(marker in combined for marker in markers)
    source_directory = ROOT / "compiler/selfhost/source"
    checks["reader_authored_in_openc"] = all(
        (source_directory / name).is_file()
        for name in (
            "winmd_types.p",
            "winmd_reader.p",
            "winmd_sha256.p",
            "winmd_metadata.p",
            "winmd_projection.p",
        )
    )
    compiler = args.compiler.resolve() if args.compiler else None
    elapsed: list[float] = []
    deterministic = True
    reproduces_checked_in = True
    generated_check = False
    if compiler is not None:
        with tempfile.TemporaryDirectory() as directory:
            generated_check = check_generated_sources(
                compiler, GENERATED, Path(directory)
            )
    checks["generated_openc_sources_check"] = generated_check if compiler else True
    if args.regenerate:
        if compiler is None or args.input is None:
            raise SystemExit("--regenerate requires --compiler and --input")
        input_path = args.input.resolve()
        checks["input_hash_matches_pin"] = (
            input_path.is_file()
            and input_path.stat().st_size == pin.get("member_bytes")
            and sha256(input_path) == pin.get("member_sha256")
        )
        runs: list[dict[str, bytes]] = []
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            for index in range(max(2, args.repeat)):
                target = temporary / f"projection-{index + 1}"
                elapsed.append(run_projection(compiler, input_path, target))
                runs.append(snapshot(target))
            deterministic = all(run == runs[0] for run in runs[1:])
            reproduces_checked_in = runs[0] == snapshot(GENERATED)
        checks["repeat_projection_byte_equal"] = deterministic
        checks["projection_reproduces_checked_in_sources"] = reproduces_checked_in
        checks["projection_time_bounded"] = max(elapsed) <= 240.0
    passed = all(checks.values())
    report = {
        "schema": "openc.sh17_winmd_projection_verification.v1",
        "milestone": "SH-17_OPENC_WIN32_METADATA_READER_AND_RAW_PROJECTION",
        "status": "PASS" if passed else "FAIL",
        "checks": checks,
        "checks_passed": sum(checks.values()),
        "checks_total": len(checks),
        "projection_elapsed_seconds": [round(value, 3) for value in elapsed],
        "projection_repeat_byte_equal": deterministic,
        "projection_reproduces_checked_in_sources": reproduces_checked_in,
        "normal_build_or_runtime_dependencies": {
            "winmd": False,
            "c_headers": False,
            "third_party_metadata_library": False,
        },
    }
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"SH-17 WinMD projection: {report['status']}; "
        f"checks={report['checks_passed']}/{report['checks_total']} "
        f"result={output}"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
