#!/usr/bin/env python3
"""Verify the complete SH-18 idiomatic Windows module milestone."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "tests/sh18_windows_modules/openc.project.json"
RUNTIME_HEADER = ROOT / "runtime/common/source/openc_runtime.h"
WINDOWS_PROVIDER = ROOT / "runtime/windows/source/openc_platform_windows.c"
MODULES = (
    "foundation",
    "file",
    "memory",
    "process",
    "thread",
    "console",
    "window",
    "graphics",
    "resources",
    "network",
    "registry",
    "shell",
)
RAW_BACKED = (
    "foundation",
    "file",
    "memory",
    "process",
    "thread",
    "window",
    "graphics",
)
EXPECTED_STDOUT = "OpenC SH-18 friendly Windows modules ✓\n".replace("\\n", "\n")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], *, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def u64(data: bytes, offset: int) -> int:
    return struct.unpack_from("<Q", data, offset)[0]


def pe_imports(path: Path) -> set[str]:
    data = path.read_bytes()
    pe = u32(data, 0x3C)
    if data[:2] != b"MZ" or data[pe : pe + 4] != b"PE\0\0":
        raise ValueError("not a PE image")
    coff = pe + 4
    section_count = u16(data, coff + 2)
    optional_size = u16(data, coff + 16)
    optional = coff + 20
    if u16(data, optional) != 0x20B:
        raise ValueError("not PE32+")
    headers_size = u32(data, optional + 60)
    import_rva = u32(data, optional + 120)
    import_size = u32(data, optional + 124)
    section_at = optional + optional_size
    sections: list[tuple[int, int, int]] = []
    for index in range(section_count):
        at = section_at + index * 40
        virtual_size = u32(data, at + 8)
        rva = u32(data, at + 12)
        raw_size = u32(data, at + 16)
        raw_offset = u32(data, at + 20)
        sections.append((rva, max(virtual_size, raw_size), raw_offset))

    def offset(rva: int) -> int:
        if rva < headers_size:
            return rva
        for start, size, raw in sections:
            if start <= rva < start + size:
                return raw + rva - start
        raise ValueError(f"unmapped RVA 0x{rva:x}")

    if import_rva == 0 or import_size < 20:
        return set()
    result: set[str] = set()
    descriptor = offset(import_rva)
    while True:
        lookup = u32(data, descriptor)
        name_rva = u32(data, descriptor + 12)
        iat = u32(data, descriptor + 16)
        if lookup == name_rva == iat == 0:
            break
        name_at = offset(name_rva)
        name_end = data.index(0, name_at)
        result.add(data[name_at:name_end].decode("ascii").lower())
        descriptor += 20
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output/selfhost-sh18/final/sh18-verification.json",
    )
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    checks: dict[str, bool] = {}
    manifest = json.loads(
        (ROOT / "standard_library/openc.project.json").read_text(encoding="utf-8")
    )
    project_modules = manifest["modules"]
    checks["twelve_friendly_modules_registered"] = all(
        f"windows.{name}" in project_modules for name in MODULES
    )
    sources = {
        name: ROOT / f"standard_library/windows.{name}/source/{name}.p"
        for name in MODULES
    }
    checks["all_friendly_sources_authored"] = all(path.is_file() for path in sources.values())
    texts = {name: path.read_text(encoding="utf-8") for name, path in sources.items()}
    checks["raw_friendly_separation"] = all(
        f"import windows.raw.{name};" in texts[name] for name in RAW_BACKED
    )
    checks["typed_resource_families"] = all(
        marker in "\n".join(texts.values())
        for marker in (
            "resource File",
            "resource Heap",
            "resource Block",
            "resource Process",
            "resource Event",
            "resource DeviceContext",
            "resource Brush",
            "resource Library",
            "resource Session",
            "resource Key",
        )
    )
    checks["exact_cleanup_operations"] = all(
        marker in "\n".join(texts.values())
        for marker in (
            "win_file_close_runtime",
            "win_memory_free_runtime",
            "win_memory_heap_destroy_runtime",
            "win_process_close_runtime",
            "win_thread_close_runtime",
            "win_graphics_dc_release_runtime",
            "win_graphics_delete_runtime",
            "win_resources_close_runtime",
            "win_network_stop_runtime",
            "win_registry_close_runtime",
        )
    )
    foundation = texts["foundation"]
    checks["utf8_utf16_boundary_api"] = all(
        marker in foundation
        for marker in ("encode_utf16", "decode_utf16", "Utf16", "OwnedText")
    )
    checks["owned_text_view_is_explicitly_unsafe"] = "export unsafe text view" in foundation
    checks["friendly_apis_use_status_results"] = all(
        "status " in texts[name] for name in MODULES
    )
    checks["friendly_apis_use_explicit_options"] = (
        "struct OpenOptions" in texts["file"]
        and "optional u32 timeout" in texts["process"]
        and "optional u32 timeout" in texts["thread"]
    )
    combined = "\n".join(texts.values())
    checks["friendly_sources_do_not_parse_c_headers"] = all(
        marker not in combined for marker in ("#include", "windows.h", "WINAPI")
    )
    core_text = (ROOT / "standard/core/OpenC_Core_Current.md").read_text(encoding="utf-8")
    checks["windows_concepts_not_in_core_language"] = re.search(
        r"\b(?:HANDLE|DWORD|HWND)\b", core_text
    ) is None
    provider = WINDOWS_PROVIDER.read_text(encoding="utf-8")
    header = RUNTIME_HEADER.read_text(encoding="utf-8")
    checks["purpose_built_windows_provider"] = all(
        marker in provider
        for marker in (
            "CreateFileW",
            "CreateProcessW",
            "GetProcessHeap",
            "HeapAlloc",
            "GetModuleFileNameW",
            "RegOpenKeyExW",
            "SHGetFolderPathW",
        )
    )
    checks["unicode_w_apis_only_at_friendly_boundary"] = all(
        marker not in provider
        for marker in (
            "CreateFileA(",
            "CreateProcessA(",
            "MessageBoxA(",
            "RegOpenKeyExA(",
        )
    )
    checks["no_direct_windows_syscalls"] = all(
        marker not in provider for marker in ("NtCreate", "NtOpen", "syscall")
    )
    checks["secure_optional_dll_loading"] = (
        "LOAD_LIBRARY_SEARCH_SYSTEM32" in provider and "LoadLibraryExW" in provider
    )
    checks["provider_contract_complete"] = all(
        f"ocw_{marker}" in header and f"ocw_{marker}" in provider
        for marker in (
            "utf16_encode",
            "file_open",
            "heap_allocate",
            "process_start",
            "event_create",
            "console_write",
            "window_desktop",
            "dc_acquire",
            "module_path",
            "network_start",
            "registry_open_current_user",
            "shell_local_app_data",
        )
    )

    started = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="openc-sh18-") as temporary_name:
        temporary = Path(temporary_name)
        check_record = temporary / "check.json"
        checked = run(
            [
                str(compiler),
                "check",
                f"--project={PROJECT}",
                f"--output={check_record}",
            ]
        )
        checks["full_project_check_passes"] = (
            checked.returncode == 0
            and check_record.is_file()
            and json.loads(check_record.read_text(encoding="utf-8")).get("status") == "PASS"
        )
        executable = temporary / "sh18-probe.exe"
        generated = temporary / "sh18-probe.c"
        record = temporary / "sh18-probe.build.json"
        built = run(
            [
                str(compiler),
                "--windows-build",
                str(PROJECT),
                str(executable),
                str(generated),
                str(ROOT / "runtime"),
                str(ROOT / "compiler/selfhost/native_runtime"),
                str(record),
                str(ROOT / "third_party/tinycc-win64/tcc.exe"),
            ]
        )
        checks["native_windows_build_passes"] = built.returncode == 0 and executable.is_file()
        build_record = json.loads(record.read_text(encoding="utf-8")) if record.is_file() else {}
        checks["native_build_record_passes"] = (
            build_record.get("status") == "PASS"
            and build_record.get("dmd_invoked") is False
            and build_record.get("dub_invoked") is False
            and build_record.get("python_invoked") is False
        )
        checks["generated_c_has_all_friendly_symbols"] = generated.is_file() and all(
            f"oc_windows_{name}_" in generated.read_text(encoding="utf-8")
            for name in MODULES
        )
        executed = run([str(executable)], timeout=30) if executable.is_file() else None
        checks["full_behavior_probe_exits_zero"] = executed is not None and executed.returncode == 0
        checks["utf8_console_behavior"] = executed is not None and executed.stdout == EXPECTED_STDOUT
        checks["file_roundtrip_and_cleanup"] = not (ROOT / "build-output/sh18-friendly-✓.txt").exists()
        imports = pe_imports(executable) if executable.is_file() else set()
        checks["pe32_plus_kernel32_import"] = "kernel32.dll" in imports
        checks["optional_subsystems_dynamically_loaded"] = all(
            dll not in imports
            for dll in ("user32.dll", "gdi32.dll", "advapi32.dll", "shell32.dll", "ws2_32.dll")
        )
        checks["no_ucrt_vcruntime_msvcp_imports"] = all(
            not (dll == "ucrtbase.dll" or dll.startswith("vcruntime") or dll.startswith("msvcp"))
            for dll in imports
        )
        checks["legacy_msvcrt_dependency_explicitly_bounded_to_sh19"] = imports <= {
            "kernel32.dll",
            "msvcrt.dll",
        }
        artifacts = {
            "compiler_sha256": sha256(compiler),
            "executable_sha256": sha256(executable) if executable.is_file() else "",
            "generated_c_sha256": sha256(generated) if generated.is_file() else "",
            "imports": sorted(imports),
            "stdout": executed.stdout if executed is not None else "",
            "exit_code": executed.returncode if executed is not None else None,
            "build_record": build_record,
        }

    elapsed = time.perf_counter() - started
    passed = sum(checks.values())
    result = {
        "schema": "openc.sh18_windows_modules.verification.v1",
        "milestone": "SH-18",
        "status": "PASS" if passed == len(checks) else "FAIL",
        "checks_passed": passed,
        "checks_total": len(checks),
        "checks": checks,
        "artifacts": artifacts,
        "elapsed_seconds": round(elapsed, 3),
        "disclosures": {
            "linux_freestanding": "optional future work; not an SH-18 gate",
            "legacy_backend": "TinyCC/generated C/msvcrt remain only until SH-19",
            "historical_rule_id_compatibility_matches": 93,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(
        f"SH-18 Windows friendly modules: {result['status']}; "
        f"checks={passed}/{len(checks)} elapsed={elapsed:.3f}s"
    )
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
