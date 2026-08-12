#!/usr/bin/env python3
"""Verify the OpenC-authored SH-15 Windows x64 ABI/encoder substrate."""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SCHEMA = "openc.sh15_windows_x64_verification.v1"
SUBSTRATE_SCHEMA = "openc.windows_x64_substrate.v1"
MEM_COMMIT_RESERVE = 0x3000
PAGE_EXECUTE_READWRITE = 0x40
MEM_RELEASE = 0x8000


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(command: list[str], *, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


class ExecutableBlock:
    def __init__(self, payload: bytes, suffix: bytes = b"") -> None:
        self.kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        self.kernel32.VirtualAlloc.argtypes = [
            ctypes.c_void_p,
            ctypes.c_size_t,
            wintypes.DWORD,
            wintypes.DWORD,
        ]
        self.kernel32.VirtualAlloc.restype = ctypes.c_void_p
        self.kernel32.VirtualFree.argtypes = [
            ctypes.c_void_p,
            ctypes.c_size_t,
            wintypes.DWORD,
        ]
        self.kernel32.VirtualFree.restype = wintypes.BOOL
        self.size = max(1, len(payload) + len(suffix))
        self.address = int(
            self.kernel32.VirtualAlloc(
                None, self.size, MEM_COMMIT_RESERVE, PAGE_EXECUTE_READWRITE
            )
            or 0
        )
        if not self.address:
            raise OSError(ctypes.get_last_error(), "VirtualAlloc failed")
        ctypes.memmove(self.address, payload + suffix, self.size)

    def close(self) -> None:
        if self.address:
            if not self.kernel32.VirtualFree(self.address, 0, MEM_RELEASE):
                raise OSError(ctypes.get_last_error(), "VirtualFree failed")
            self.address = 0

    def __enter__(self) -> "ExecutableBlock":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()


class RuntimeFunction(ctypes.Structure):
    _fields_ = [
        ("BeginAddress", wintypes.DWORD),
        ("EndAddress", wintypes.DWORD),
        ("UnwindData", wintypes.DWORD),
    ]


def code_bytes(report: dict[str, object], name: str) -> bytes:
    machine_code = report["machine_code"]
    assert isinstance(machine_code, dict)
    record = machine_code[name]
    assert isinstance(record, dict)
    return bytes.fromhex(str(record["bytes"]))


def execute_machine_probes(report: dict[str, object]) -> dict[str, object]:
    checks: dict[str, bool] = {}
    observations: dict[str, object] = {}
    winfunctype = ctypes.WINFUNCTYPE

    blocks: list[ExecutableBlock] = []
    try:
        integer = ExecutableBlock(code_bytes(report, "integer_six"))
        blocks.append(integer)
        integer_fn = winfunctype(
            ctypes.c_uint64,
            ctypes.c_uint64,
            ctypes.c_uint64,
            ctypes.c_uint64,
            ctypes.c_uint64,
            ctypes.c_uint64,
            ctypes.c_uint64,
        )(integer.address)
        integer_result = integer_fn(1, 2, 3, 4, 5, 6)
        observations["integer_six_result"] = integer_result
        checks["integer_register_and_stack_arguments_execute"] = integer_result == 21

        floating = ExecutableBlock(code_bytes(report, "float_four"))
        blocks.append(floating)
        float_fn = winfunctype(
            ctypes.c_double,
            ctypes.c_double,
            ctypes.c_double,
            ctypes.c_double,
            ctypes.c_double,
        )(floating.address)
        float_result = float_fn(1.25, 2.5, 3.75, 4.0)
        observations["float_four_result"] = float_result
        checks["positional_xmm_arguments_execute"] = math.isclose(
            float_result, 11.5, rel_tol=0.0, abs_tol=1e-12
        )

        aggregate = ExecutableBlock(code_bytes(report, "aggregate_pair"))
        blocks.append(aggregate)
        aggregate_fn = winfunctype(
            ctypes.c_uint64, ctypes.c_uint64, ctypes.c_uint64
        )(aggregate.address)
        aggregate_result = aggregate_fn(0x1122334455667788, 0x0102030405060708)
        observations["aggregate_pair_result"] = f"0x{aggregate_result:016x}"
        checks["direct_eight_byte_aggregates_execute"] = aggregate_result == (
            0x1122334455667788 ^ 0x0102030405060708
        )

        indirect = ExecutableBlock(code_bytes(report, "indirect_aggregate"))
        blocks.append(indirect)
        indirect_fn = winfunctype(
            ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint64)
        )(indirect.address)
        aggregate_storage = (ctypes.c_uint64 * 2)(
            0xA1B2C3D4E5F60718, 0x1020304050607080
        )
        indirect_result = indirect_fn(aggregate_storage)
        observations["indirect_aggregate_first_word"] = (
            f"0x{indirect_result:016x}"
        )
        checks["indirect_aggregate_pointer_executes"] = (
            indirect_result == 0xA1B2C3D4E5F60718
        )

        hidden = ExecutableBlock(
            code_bytes(report, "hidden_aggregate_return")
        )
        blocks.append(hidden)
        hidden_fn = winfunctype(
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_uint64),
            ctypes.c_uint64,
        )(hidden.address)
        hidden_storage = ctypes.c_uint64(0)
        hidden_address = ctypes.addressof(hidden_storage)
        hidden_result = int(
            hidden_fn(ctypes.byref(hidden_storage), 0x8877665544332211) or 0
        )
        observations["hidden_return_pointer_matches"] = (
            hidden_result == hidden_address
        )
        observations["hidden_return_storage"] = (
            f"0x{hidden_storage.value:016x}"
        )
        checks["hidden_aggregate_return_pointer_executes"] = (
            hidden_result == hidden_address
            and hidden_storage.value == 0x8877665544332211
        )

        callback_code = code_bytes(report, "callback_call")
        callback = ExecutableBlock(callback_code)
        blocks.append(callback)
        callback_type = winfunctype(ctypes.c_uint64, ctypes.c_uint64)

        @callback_type
        def plus_one(value: int) -> int:
            return value + 1

        callback_fn = winfunctype(
            ctypes.c_uint64, ctypes.c_void_p, ctypes.c_uint64
        )(callback.address)
        callback_result = callback_fn(
            ctypes.cast(plus_one, ctypes.c_void_p).value, 41
        )
        observations["callback_result"] = callback_result
        checks["callback_and_function_pointer_execute"] = callback_result == 42

        alignment = ExecutableBlock(code_bytes(report, "stack_alignment"))
        blocks.append(alignment)
        alignment_result = callback_fn(alignment.address, 0)
        observations["callback_entry_rsp_mod_16"] = alignment_result
        checks["callback_stack_alignment_executes"] = alignment_result == 8

        inner = ExecutableBlock(code_bytes(report, "nonvolatile_inner"))
        outer = ExecutableBlock(code_bytes(report, "nonvolatile_outer"))
        blocks.extend((inner, outer))
        outer_fn = winfunctype(
            ctypes.c_uint64, ctypes.c_void_p, ctypes.c_uint64
        )(outer.address)
        nonvolatile_result = outer_fn(inner.address, 99)
        observations["rbx_after_nested_call"] = f"0x{nonvolatile_result:016x}"
        checks["nonvolatile_rbx_preserved_across_nested_call"] = (
            nonvolatile_result == 0x1122334455667788
        )

        vector_inner = ExecutableBlock(
            code_bytes(report, "nonvolatile_vector_inner")
        )
        vector_outer = ExecutableBlock(
            code_bytes(report, "nonvolatile_vector_outer")
        )
        blocks.extend((vector_inner, vector_outer))
        vector_outer_fn = winfunctype(
            ctypes.c_uint64, ctypes.c_void_p, ctypes.c_uint64
        )(vector_outer.address)
        vector_nonvolatile_result = vector_outer_fn(vector_inner.address, 77)
        observations["xmm6_after_nested_call"] = (
            f"0x{vector_nonvolatile_result:016x}"
        )
        checks["nonvolatile_xmm6_preserved_across_nested_call"] = (
            vector_nonvolatile_result == 0x0F1E2D3C4B5A6978
        )

        unwind = report["unwind"]
        assert isinstance(unwind, dict)
        xdata = bytes.fromhex(str(unwind["callback_xdata"]))
        xdata_offset = (len(callback_code) + 3) & ~3
        registered = ExecutableBlock(
            callback_code, b"\x00" * (xdata_offset - len(callback_code)) + xdata
        )
        blocks.append(registered)
        function = RuntimeFunction(0, len(callback_code), xdata_offset)
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.RtlAddFunctionTable.argtypes = [
            ctypes.POINTER(RuntimeFunction),
            wintypes.DWORD,
            ctypes.c_uint64,
        ]
        kernel32.RtlAddFunctionTable.restype = wintypes.BOOL
        kernel32.RtlDeleteFunctionTable.argtypes = [ctypes.POINTER(RuntimeFunction)]
        kernel32.RtlDeleteFunctionTable.restype = wintypes.BOOL
        added = bool(kernel32.RtlAddFunctionTable(ctypes.byref(function), 1, registered.address))
        lookup_matches = False
        deleted = False
        if added:
            ntdll = ctypes.WinDLL("ntdll")
            ntdll.RtlLookupFunctionEntry.argtypes = [
                ctypes.c_uint64,
                ctypes.POINTER(ctypes.c_uint64),
                ctypes.c_void_p,
            ]
            ntdll.RtlLookupFunctionEntry.restype = ctypes.POINTER(RuntimeFunction)
            image_base = ctypes.c_uint64()
            found = ntdll.RtlLookupFunctionEntry(
                registered.address + 8, ctypes.byref(image_base), None
            )
            lookup_matches = bool(found) and (
                found.contents.BeginAddress == 0
                and found.contents.EndAddress == len(callback_code)
                and found.contents.UnwindData == xdata_offset
                and image_base.value == registered.address
            )
            deleted = bool(kernel32.RtlDeleteFunctionTable(ctypes.byref(function)))
        observations["unwind_function_table_added"] = added
        observations["unwind_lookup_matches"] = lookup_matches
        observations["unwind_function_table_deleted"] = deleted
        checks["nonleaf_unwind_record_registers_and_resolves"] = (
            added and lookup_matches and deleted
        )
    finally:
        for block in reversed(blocks):
            block.close()
    return {"checks": checks, "observations": observations}


def build_oracle(tcc: Path, directory: Path) -> Path:
    source = directory / "sh15_oracle.c"
    library = directory / "sh15_oracle.dll"
    source.write_text(
        """
#include <stddef.h>
#include <stdint.h>

typedef unsigned long long u64;
typedef u64 (*variadic_target)(int, ...);

struct LayoutProbe { unsigned char tag; void* next; long flags; };
union UnionProbe { uint32_t small; uint64_t large; };
struct ExplicitProbe { unsigned char tag; unsigned char pad[3]; uint32_t value; };
struct BitProbe { unsigned int a:3; unsigned int b:5; unsigned int c:10; };

__declspec(dllexport) u64 sh15_call_variadic(void* target) {
    return ((variadic_target)target)(7, 3.5);
}
__declspec(dllexport) u64 sh15_layout_value(unsigned int selector) {
    if (selector == 0) return sizeof(void*);
    if (selector == 1) return sizeof(long);
    if (selector == 2) return sizeof(struct LayoutProbe);
    if (selector == 3) return offsetof(struct LayoutProbe, next);
    if (selector == 4) return offsetof(struct LayoutProbe, flags);
    if (selector == 5) return sizeof(union UnionProbe);
    if (selector == 6) return sizeof(struct ExplicitProbe);
    if (selector == 7) return offsetof(struct ExplicitProbe, value);
    if (selector == 8) return sizeof(struct BitProbe);
    return ~0ULL;
}
__declspec(dllexport) u64 sh15_bitfield_value(void) {
    union { struct BitProbe bits; uint32_t raw; } value = {0};
    value.bits.a = 5;
    value.bits.b = 17;
    value.bits.c = 341;
    return value.raw;
}
""".lstrip(),
        encoding="utf-8",
        newline="\n",
    )
    completed = run([str(tcc), "-shared", "-o", str(library), str(source)])
    if completed.returncode != 0 or not library.is_file():
        raise RuntimeError(
            "TinyCC ABI oracle build failed\n"
            + completed.stdout
            + completed.stderr
        )
    return library


def oracle_probes(
    report: dict[str, object], tcc: Path, directory: Path
) -> dict[str, object]:
    library_path = build_oracle(tcc, directory)
    library = ctypes.WinDLL(str(library_path))
    library_handle = library._handle
    try:
        library.sh15_layout_value.argtypes = [ctypes.c_uint]
        library.sh15_layout_value.restype = ctypes.c_uint64
        layout_values = [
            int(library.sh15_layout_value(index)) for index in range(9)
        ]
        expected_layout_values = [8, 4, 24, 8, 16, 8, 8, 4, 4]
        library.sh15_bitfield_value.argtypes = []
        library.sh15_bitfield_value.restype = ctypes.c_uint64
        bitfield_value = int(library.sh15_bitfield_value())

        variadic = ExecutableBlock(
            code_bytes(report, "variadic_float_duplicate")
        )
        try:
            library.sh15_call_variadic.argtypes = [ctypes.c_void_p]
            library.sh15_call_variadic.restype = ctypes.c_uint64
            variadic_result = int(
                library.sh15_call_variadic(variadic.address)
            )
        finally:
            variadic.close()
    finally:
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.FreeLibrary.argtypes = [wintypes.HMODULE]
        kernel32.FreeLibrary.restype = wintypes.BOOL
        if not kernel32.FreeLibrary(library_handle):
            raise OSError(ctypes.get_last_error(), "FreeLibrary failed")
        library._handle = 0
    return {
        "checks": {
            "tinycc_layout_oracle_matches": layout_values == expected_layout_values,
            "tinycc_bitfield_oracle_matches": bitfield_value == (
                5 | (17 << 3) | (341 << 8)
            ),
            "variadic_float_is_duplicated_to_integer_register": variadic_result == 1,
        },
        "observations": {
            "layout_values": layout_values,
            "expected_layout_values": expected_layout_values,
            "bitfield_value": bitfield_value,
            "expected_bitfield_value": 5 | (17 << 3) | (341 << 8),
            "variadic_duplicate_result": variadic_result,
            "oracle_dll_sha256": sha256(library_path),
        },
    }


def static_checks(report: dict[str, object]) -> dict[str, bool]:
    expected_code = {
        "integer_six": "4889c84801d04c01c04c01c848034424284803442430c3",
        "float_four": "f20f58c1f20f58c2f20f58c3c3",
        "aggregate_pair": "4889c84831d0c3",
        "indirect_aggregate": "488b01c3",
        "hidden_aggregate_return": "4889114889c8c3",
        "callback_call": "4883ec284889c84889d1ffd04883c428c3",
        "stack_alignment": "4889e04883e00fc3",
        "nonvolatile_inner": "534889cb4889d84883c0015bc3",
        "nonvolatile_outer": (
            "534883ec204889c848bb88776655443322114889d1ffd04889d8"
            "4883c4205bc3"
        ),
        "variadic_float_duplicate": "66480f7ec84839d00f94c00fb6c0c3",
        "nonvolatile_vector_inner": (
            "4883ec28f30f7f74241066480f6ef166480f7ef0f30f6f742410"
            "4883c428c3"
        ),
        "nonvolatile_vector_outer": (
            "4883ec28f30f7f7424104889c84889d148ba78695a4b3c2d1e0f"
            "66480f6ef2ffd066480f7ef0f30f6f7424104883c428c3"
        ),
    }
    actual_code = {
        name: code_bytes(report, name).hex() for name in expected_code
    }
    classification = report["classification"]
    layouts = report["layouts"]
    relocations = report["relocations"]
    unwind = report["unwind"]
    dependencies = report["dependencies"]
    assert isinstance(classification, dict)
    assert isinstance(layouts, dict)
    assert isinstance(relocations, dict)
    assert isinstance(unwind, dict)
    assert isinstance(dependencies, dict)
    mixed = classification["mixed_arguments"]
    assert isinstance(mixed, list)
    expected_mixed = [
        ("integer_register", "rcx", 0, False, False),
        ("vector_register", "xmm1", 8, False, False),
        ("integer_register", "r8", 16, True, False),
        ("vector_register", "xmm3", 24, False, True),
        ("stack", "none", 32, False, False),
    ]
    actual_mixed = [
        (
            item["kind"],
            item["register"],
            item["stack_offset"],
            item["indirect"],
            item["duplicate_float_to_integer"],
        )
        for item in mixed
    ]
    relative = relocations["relative32"]
    absolute = relocations["absolute64"]
    assert isinstance(relative, dict) and isinstance(absolute, dict)
    return {
        "substrate_reports_pass": report.get("status") == "PASS",
        "llp64_data_model_complete": report.get("data_model") == {
            "name": "LLP64",
            "pointer_bits": 64,
            "usize_bits": 64,
            "c_int_bits": 32,
            "c_long_bits": 32,
            "c_long_long_bits": 64,
            "wchar_bits": 16,
        },
        "mixed_argument_classification_matches": actual_mixed == expected_mixed,
        "hidden_return_shifts_first_argument": (
            classification["hidden_aggregate_return"] == {
                "kind": "hidden_return",
                "register": "rcx",
                "shifts_arguments": True,
            }
            and classification["first_argument_after_hidden_return"]["register"]
            == "rdx"
        ),
        "typed_instruction_bytes_match": actual_code == expected_code,
        "relative32_relocation_matches": relative == {
            "symbol": 7,
            "offset": 1,
            "width": 4,
            "addend": -4,
            "unresolved_bytes": "e800000000c3",
            "resolved_target_offset": 16,
            "resolved_bytes": "e80b000000c3",
            "backward_resolved_bytes": "e8fbffffffc3",
        },
        "absolute64_relocation_matches": absolute == {
            "symbol": 11,
            "offset": 2,
            "width": 8,
            "addend": 0,
            "unresolved_bytes": "48b80000000000000000c3",
            "resolved_value": "0x1122334455667788",
            "resolved_bytes": "48b88877665544332211c3",
        },
        "version_one_unwind_bytes_match": (
            unwind["callback_xdata"] == "0104010004420000"
            and unwind["inner_xdata"] == "0101010001300000"
            and unwind["outer_xdata"] == "0105020005320130"
            and unwind["vector_xdata"] == "010a03000a68010004420000"
            and unwind["runtime_function_bytes"] == "000000001100000020000000"
            and unwind["runtime_functions_sorted"] is True
        ),
        "structure_union_explicit_and_bitfield_layouts_present": (
            layouts["structure"]["size"] == 24
            and layouts["union"]["size"] == 8
            and layouts["explicit"]["size"] == 8
            and layouts["bitfields"]["size"] == 4
        ),
        "substrate_has_no_c_header_assembler_or_linker_dependency": (
            dependencies["c_headers_required_by_substrate"] is False
            and dependencies["external_assembler_required"] is False
            and dependencies["external_linker_required"] is False
        ),
    }


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-15 verification requires Windows x86-64")
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument(
        "--tcc",
        type=Path,
        default=ROOT / "third_party" / "tinycc-win64" / "tcc.exe",
    )
    parser.add_argument(
        "--target-record",
        type=Path,
        default=ROOT / "compiler" / "targets" / "windows-x86_64.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh15" / "verification.json",
    )
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    tcc = args.tcc.resolve()
    target_record_path = args.target_record.resolve()
    output = args.output.resolve()
    for required in (compiler, tcc, target_record_path):
        if not required.is_file():
            raise SystemExit(f"missing required input: {required}")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="openc-sh15-") as temporary:
        run_root = Path(temporary)
        report_a = run_root / "substrate-a.json"
        report_b = run_root / "substrate-b.json"
        commands = [
            [str(compiler), "--windows-x64-substrate", str(report_a)],
            [str(compiler), "--windows-x64-substrate", str(report_b)],
        ]
        command_results = [run(command) for command in commands]
        if any(result.returncode != 0 for result in command_results):
            details = "\n".join(
                result.stdout + result.stderr for result in command_results
            )
            raise SystemExit("substrate command failed\n" + details)
        report = json.loads(report_a.read_text(encoding="utf-8"))
        if report.get("schema") != SUBSTRATE_SCHEMA:
            raise SystemExit("unexpected substrate schema")
        checks = static_checks(report)
        target_record = json.loads(target_record_path.read_text(encoding="utf-8"))
        target_abi = target_record.get("abi_contract", {})
        checks["target_record_encodes_microsoft_x64_abi"] = (
            target_record.get("name") == "windows-x86_64"
            and target_record.get("abi") == "win64"
            and target_abi.get("schema") == "openc.windows_x64_abi.v1"
            and target_abi.get("data_model", {}).get("name") == "LLP64"
            and target_abi.get("arguments", {}).get("shadow_space_bytes") == 32
            and target_abi.get("stack", {}).get("body_alignment_bytes") == 16
            and target_abi.get("unwind", {}).get("version") == 1
        )
        checks["deterministic_report_bytes"] = (
            report_a.read_bytes() == report_b.read_bytes()
        )
        machine = execute_machine_probes(report)
        oracle = oracle_probes(report, tcc, run_root)
        checks.update(machine["checks"])
        checks.update(oracle["checks"])
        status = "PASS" if all(checks.values()) else "FAILED"
        result = {
            "schema": SCHEMA,
            "status": status,
            "measured_at_utc": datetime.now(timezone.utc)
            .isoformat()
            .replace("+00:00", "Z"),
            "target": "windows-x86_64-hosted",
            "compiler": {
                "path": str(compiler),
                "sha256": sha256(compiler),
                "implementation_language": "OpenC",
            },
            "substrate_report": {
                "schema": report["schema"],
                "sha256": sha256(report_a),
                "bytes": report_a.stat().st_size,
            },
            "target_record": {
                "path": str(target_record_path),
                "sha256": sha256(target_record_path),
                "abi_schema": target_abi.get("schema"),
            },
            "oracle": {
                "role": "verification_only",
                "tinycc": str(tcc),
                **oracle["observations"],
            },
            "machine_observations": machine["observations"],
            "checks": checks,
            "checks_passed": sum(checks.values()),
            "checks_total": len(checks),
            "retained_tinycc_backend_required": True,
            "external_assembler_invoked": False,
            "external_linker_invoked_for_substrate": False,
            "linux_and_freestanding_gate": False,
        }
        output.write_text(
            json.dumps(result, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    print(
        f"SH-15 Windows x64 substrate: {status}; "
        f"checks={result['checks_passed']}/{result['checks_total']}; "
        f"report={output}"
    )
    if args.enforce and status != "PASS":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
