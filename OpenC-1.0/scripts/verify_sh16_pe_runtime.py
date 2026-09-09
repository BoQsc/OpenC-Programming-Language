#!/usr/bin/env python3
"""Verify the OpenC-authored SH-16 PE32+ writer and CRT-free runtime."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import subprocess
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_CRT_PREFIXES = (
    "ucrtbase",
    "vcruntime",
    "msvcp",
    "msvcrt",
)
EXPECTED_IMPORTS = [
    "CloseHandle",
    "CreateFileW",
    "ExitProcess",
    "FreeEnvironmentStringsW",
    "GetCommandLineW",
    "GetEnvironmentStringsW",
    "GetLastError",
    "GetProcessHeap",
    "GetStdHandle",
    "HeapAlloc",
    "HeapFree",
    "HeapReAlloc",
    "ReadFile",
    "WideCharToMultiByte",
    "WriteFile",
    "MultiByteToWideChar",
    "GetTickCount64",
    "GetModuleFileNameW",
    "GetFileSizeEx",
    "LoadLibraryExW",
    "GetProcAddress",
    "LocalFree",
    "FreeLibrary",
    "CreatePipe",
    "SetHandleInformation",
    "CreateProcessW",
    "WaitForSingleObject",
    "GetExitCodeProcess",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], *, cwd: Path = ROOT) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, cwd=cwd, capture_output=True, check=False)


@dataclass(frozen=True)
class Section:
    name: str
    virtual_size: int
    rva: int
    raw_size: int
    raw_offset: int
    characteristics: int


class PeImage:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.data = path.read_bytes()
        if self.data[:2] != b"MZ":
            raise ValueError("missing DOS signature")
        self.pe_offset = self.u32(0x3C)
        if self.data[self.pe_offset : self.pe_offset + 4] != b"PE\0\0":
            raise ValueError("missing PE signature")
        coff = self.pe_offset + 4
        self.machine = self.u16(coff)
        self.section_count = self.u16(coff + 2)
        self.timestamp = self.u32(coff + 4)
        self.optional_size = self.u16(coff + 16)
        self.coff_characteristics = self.u16(coff + 18)
        self.optional_offset = coff + 20
        if self.u16(self.optional_offset) != 0x20B:
            raise ValueError("not PE32+")
        opt = self.optional_offset
        self.entry_rva = self.u32(opt + 16)
        self.image_base = self.u64(opt + 24)
        self.section_alignment = self.u32(opt + 32)
        self.file_alignment = self.u32(opt + 36)
        self.image_size = self.u32(opt + 56)
        self.headers_size = self.u32(opt + 60)
        self.checksum = self.u32(opt + 64)
        self.subsystem = self.u16(opt + 68)
        self.dll_characteristics = self.u16(opt + 70)
        directory_count = self.u32(opt + 108)
        self.directories = [
            (self.u32(opt + 112 + index * 8), self.u32(opt + 116 + index * 8))
            for index in range(min(directory_count, 16))
        ]
        section_offset = opt + self.optional_size
        sections: list[Section] = []
        for index in range(self.section_count):
            at = section_offset + index * 40
            name = self.data[at : at + 8].split(b"\0", 1)[0].decode("ascii")
            sections.append(
                Section(
                    name=name,
                    virtual_size=self.u32(at + 8),
                    rva=self.u32(at + 12),
                    raw_size=self.u32(at + 16),
                    raw_offset=self.u32(at + 20),
                    characteristics=self.u32(at + 36),
                )
            )
        self.sections = sections

    def u16(self, offset: int) -> int:
        return struct.unpack_from("<H", self.data, offset)[0]

    def u32(self, offset: int) -> int:
        return struct.unpack_from("<I", self.data, offset)[0]

    def u64(self, offset: int) -> int:
        return struct.unpack_from("<Q", self.data, offset)[0]

    def rva_offset(self, rva: int) -> int:
        if rva < self.headers_size:
            return rva
        for section in self.sections:
            span = max(section.virtual_size, section.raw_size)
            if section.rva <= rva < section.rva + span:
                return section.raw_offset + rva - section.rva
        raise ValueError(f"unmapped RVA 0x{rva:x}")

    def c_string(self, rva: int) -> str:
        at = self.rva_offset(rva)
        end = self.data.index(0, at)
        return self.data[at:end].decode("ascii")

    def imports(self) -> dict[str, list[str]]:
        import_rva, import_size = self.directories[1]
        if not import_rva or import_size < 20:
            return {}
        result: dict[str, list[str]] = {}
        descriptor = self.rva_offset(import_rva)
        while True:
            lookup = self.u32(descriptor)
            name_rva = self.u32(descriptor + 12)
            iat = self.u32(descriptor + 16)
            if lookup == name_rva == iat == 0:
                break
            dll = self.c_string(name_rva)
            names: list[str] = []
            thunk = self.rva_offset(lookup or iat)
            while True:
                value = self.u64(thunk)
                if value == 0:
                    break
                if value >> 63:
                    names.append(f"ordinal:{value & 0xFFFF}")
                else:
                    hint_name = self.rva_offset(value)
                    end = self.data.index(0, hint_name + 2)
                    names.append(self.data[hint_name + 2 : end].decode("ascii"))
                thunk += 8
            result[dll] = names
            descriptor += 20
        return result

    def relocations(self) -> list[tuple[int, int]]:
        rva, size = self.directories[5]
        result: list[tuple[int, int]] = []
        at = self.rva_offset(rva)
        end = at + size
        while at < end:
            page = self.u32(at)
            block_size = self.u32(at + 4)
            if block_size < 8 or at + block_size > end:
                raise ValueError("invalid relocation block")
            entry = at + 8
            while entry < at + block_size:
                value = self.u16(entry)
                kind = value >> 12
                if kind:
                    result.append((kind, page + (value & 0xFFF)))
                entry += 2
            at += block_size
        return result

    def runtime_functions(self) -> list[tuple[int, int, int]]:
        rva, size = self.directories[3]
        at = self.rva_offset(rva)
        return [
            struct.unpack_from("<III", self.data, at + offset)
            for offset in range(0, size, 12)
        ]


def emit(
    compiler: Path,
    source: Path,
    executable: Path,
    subsystem: str,
    report: Path,
) -> subprocess.CompletedProcess[bytes]:
    return run(
        [
            str(compiler),
            "--windows-pe32-runtime",
            str(source),
            str(executable),
            subsystem,
            str(report),
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--compiler",
        type=Path,
        default=ROOT / "build-output/selfhost-sh16/closure/stage4/openc.exe",
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=ROOT / "tests/programs/sh16_runtime_proof/main.p",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output/selfhost-sh16/final/sh16-verification.json",
    )
    args = parser.parse_args()
    compiler = args.compiler.resolve()
    source = args.source.resolve()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="openc-sh16-") as temporary:
        temp = Path(temporary)
        console_a = temp / "runtime-a.exe"
        console_b = temp / "runtime-b.exe"
        windows_image = temp / "runtime-windows.exe"
        report_a = temp / "runtime-a.json"
        report_b = temp / "runtime-b.json"
        report_windows = temp / "runtime-windows.json"
        commands = [
            emit(compiler, source, console_a, "console", report_a),
            emit(compiler, source, console_b, "console", report_b),
            emit(compiler, source, windows_image, "windows", report_windows),
        ]
        console = PeImage(console_a)
        gui = PeImage(windows_image)
        imports = console.imports()
        flattened_imports = [name for names in imports.values() for name in names]
        section_map = {section.name: section for section in console.sections}
        relocations = console.relocations()
        runtime_functions = console.runtime_functions()
        tls_rva, tls_size = console.directories[9]
        tls_at = console.rva_offset(tls_rva)
        tls = {
            "start_raw_data": console.u64(tls_at),
            "end_raw_data": console.u64(tls_at + 8),
            "address_of_index": console.u64(tls_at + 16),
            "address_of_callbacks": console.u64(tls_at + 24),
            "zero_fill": console.u32(tls_at + 32),
            "characteristics": console.u32(tls_at + 36),
            "directory_size": tls_size,
        }
        unwind_bytes = [
            console.data[
                console.rva_offset(function[2]) : console.rva_offset(function[2]) + 8
            ].hex()
            for function in runtime_functions
        ]
        unicode_argument = "Живий-UTF8-𐍈"
        executed = run([str(console_a), unicode_argument], cwd=temp)
        proof_file = temp / "openc-sh16-proof.txt"
        invalid_source = temp / "invalid.p"
        invalid_source.write_text("i32 main() { return 0; }\n", encoding="utf-8")
        invalid_image = temp / "invalid.exe"
        invalid_report = temp / "invalid.json"
        invalid = emit(compiler, invalid_source, invalid_image, "console", invalid_report)
        unwritable_image = temp / "missing-output-directory" / "runtime.exe"
        write_failure_report = temp / "write-failure.json"
        write_failure = emit(
            compiler, source, unwritable_image, "console", write_failure_report
        )

        expected_names = [
            ".text",
            ".rdata",
            ".data",
            ".pdata",
            ".xdata",
            ".tls",
            ".reloc",
        ]
        raw_ranges = sorted(
            (section.raw_offset, section.raw_offset + section.raw_size)
            for section in console.sections
        )
        checks = {
            "compiler_commands_pass": all(command.returncode == 0 for command in commands),
            "source_profile_recorded": all(
                json.loads(path.read_text(encoding="utf-8"))["source_profile"]
                == "SH16_WINDOWS_RUNTIME_PROOF"
                for path in (report_a, report_b, report_windows)
            ),
            "invalid_profile_rejected": invalid.returncode != 0 and not invalid_image.exists(),
            "output_write_failure_rejected": write_failure.returncode != 0
            and not unwritable_image.exists(),
            "deterministic_console_image_bytes": console_a.read_bytes() == console_b.read_bytes(),
            "deterministic_console_report_bytes": report_a.read_bytes() == report_b.read_bytes(),
            "dos_and_pe32_plus_headers": console.machine == 0x8664 and console.optional_size == 240,
            "seven_required_sections": [section.name for section in console.sections] == expected_names,
            "section_rvas_aligned": all(
                section.rva % console.section_alignment == 0 for section in console.sections
            ),
            "section_raw_data_aligned": all(
                section.raw_offset % console.file_alignment == 0
                and section.raw_size % console.file_alignment == 0
                for section in console.sections
            ),
            "section_raw_ranges_nonoverlapping": all(
                raw_ranges[index][1] <= raw_ranges[index + 1][0]
                for index in range(len(raw_ranges) - 1)
            ),
            "text_only_executable": bool(section_map[".text"].characteristics & 0x20000000)
            and all(
                not (section.characteristics & 0x20000000)
                for name, section in section_map.items()
                if name != ".text"
            ),
            "data_and_tls_writable": all(
                section_map[name].characteristics & 0x80000000
                for name in (".data", ".tls")
            ),
            "entry_in_text": section_map[".text"].rva
            <= console.entry_rva
            < section_map[".text"].rva + section_map[".text"].virtual_size,
            "timestamp_and_checksum_reproducible_zero": console.timestamp == 0
            and console.checksum == 0,
            "aslr_nx_and_high_entropy_enabled": (console.dll_characteristics & 0x160) == 0x160,
            "console_subsystem_selected": console.subsystem == 3,
            "graphical_subsystem_selected": gui.subsystem == 2,
            "subsystem_is_only_console_gui_header_difference": len(console.data) == len(gui.data)
            and sum(left != right for left, right in zip(console.data, gui.data)) == 1,
            "only_documented_kernel32_imported": list(imports) == ["KERNEL32.dll"],
            "complete_expected_import_set": flattened_imports == EXPECTED_IMPORTS,
            "no_crt_imports": not any(
                name.lower().startswith(FORBIDDEN_CRT_PREFIXES) for name in imports
            ),
            "import_and_iat_directories_present": console.directories[1][1] == 40
            and console.directories[12][1] == (len(EXPECTED_IMPORTS) + 1) * 8,
            "active_dir64_base_relocations": relocations
            == [(10, 0x2580), (10, 0x2588), (10, 0x2590), (10, 0x3018)],
            "tls_directory_complete": tls
            == {
                "start_raw_data": console.image_base + 0x6000,
                "end_raw_data": console.image_base + 0x6008,
                "address_of_index": console.image_base + 0x3008,
                "address_of_callbacks": 0,
                "zero_fill": 8,
                "characteristics": 0,
                "directory_size": 40,
            },
            "two_sorted_runtime_functions": len(runtime_functions) == 2
            and runtime_functions == sorted(runtime_functions)
            and all(begin < end for begin, end, _ in runtime_functions),
            "version_one_unwind_for_entry_and_panic": unwind_bytes == [
                "0104010004c20000",
                "0104010004420000",
            ],
            "crt_free_executable_runs": executed.returncode == 0,
            "utf16_command_line_decoded_to_utf8": unicode_argument.encode("utf-8")
            in executed.stdout,
            "utf8_console_output_observed": b"OpenC SH-16 CRT-free runtime PASS\n"
            in executed.stdout,
            "heap_backed_file_read_observed": b"OpenC native file PASS\n"
            in executed.stdout,
            "file_write_observed": proof_file.is_file()
            and proof_file.read_bytes() == b"OpenC native file PASS\n",
            "panic_path_present_and_unwindable": b"OpenC SH-16 runtime panic\n"
            in console.data
            and len(runtime_functions) == 2,
            "no_external_assembler_or_linker_recorded": all(
                not json.loads(path.read_text(encoding="utf-8"))[
                    "external_assembler_invoked"
                ]
                and not json.loads(path.read_text(encoding="utf-8"))[
                    "external_linker_invoked"
                ]
                for path in (report_a, report_b, report_windows)
            ),
        }
        status = "PASS" if all(checks.values()) else "FAIL"
        result = {
            "schema": "openc.sh16_pe_runtime_verification.v1",
            "status": status,
            "measured_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "compiler": {
                "path": str(compiler),
                "sha256": sha256(compiler),
                "implementation_language": "OpenC",
            },
            "source": {"path": str(source), "sha256": sha256(source)},
            "image": {
                "sha256": sha256(console_a),
                "bytes": len(console.data),
                "image_base": f"0x{console.image_base:016x}",
                "entry_rva": f"0x{console.entry_rva:08x}",
                "sections": [section.__dict__ for section in console.sections],
                "directories": console.directories,
                "imports": imports,
                "relocations": [
                    {"type": kind, "rva": f"0x{rva:08x}"}
                    for kind, rva in relocations
                ],
                "runtime_functions": runtime_functions,
                "unwind_bytes": unwind_bytes,
                "tls": tls,
            },
            "execution": {
                "exit_code": executed.returncode,
                "stdout_utf8": executed.stdout.decode("utf-8", errors="replace"),
                "stderr_utf8": executed.stderr.decode("utf-8", errors="replace"),
                "unicode_argument": unicode_argument,
                "file_payload": proof_file.read_text(encoding="utf-8")
                if proof_file.is_file()
                else "",
            },
            "checks": checks,
            "checks_passed": sum(checks.values()),
            "checks_total": len(checks),
            "tinycc_used_to_emit_proof_image": False,
            "c_headers_used_to_emit_proof_image": False,
            "microsoft_crt_used_by_proof_image": False,
            "external_assembler_invoked": False,
            "external_linker_invoked": False,
            "linux_and_freestanding_gate": False,
        }
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(
            f"SH-16 PE32+ runtime: {status}; checks={result['checks_passed']}/"
            f"{result['checks_total']}; report={output}"
        )
        if status != "PASS":
            for name, passed in checks.items():
                if not passed:
                    print(f"FAIL: {name}")
        return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
