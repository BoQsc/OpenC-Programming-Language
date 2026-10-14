#!/usr/bin/env python3
"""Exercise native argument snapshots through EXE and concurrent DLL calls."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import ctypes
import json
from pathlib import Path
import sys
import threading

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured


SOURCE = """import system.process;
import system.text;
import system.io;

export usize snapshot_count() { return process.argument_count(); }
export unsafe usize snapshot_hash(usize index) {
    text value = process.argument(index);
    usize size = text.byte_length(value);
    usize result = size * 100000;
    usize at = 0;
    while at < size {
        result = result + cast(usize, text.byte_at_unchecked(value, at)) * (at + 1);
        at = at + 1;
    }
    return result;
}
i32 main() {
    usize count = process.argument_count();
    usize repeat = 0;
    while repeat < 3 {
        usize index = 0;
        while index < count {
            io.print(index); io.print(":"); io.println(process.argument(index));
            index = index + 1;
        }
        repeat = repeat + 1;
    }
    return 0;
}
"""


def windows_arguments() -> list[str]:
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    shell = ctypes.WinDLL("shell32", use_last_error=True)
    kernel.GetCommandLineW.restype = ctypes.c_wchar_p
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    kernel.LocalFree.restype = ctypes.c_void_p
    shell.CommandLineToArgvW.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_int)]
    shell.CommandLineToArgvW.restype = ctypes.POINTER(ctypes.c_wchar_p)
    count = ctypes.c_int()
    argv = shell.CommandLineToArgvW(kernel.GetCommandLineW(), ctypes.byref(count))
    if not argv:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return [argv[index] for index in range(1, count.value)]
    finally:
        kernel.LocalFree(ctypes.cast(argv, ctypes.c_void_p))


def fingerprint(value: str) -> int:
    data = value.encode("utf-8")
    return len(data) * 100000 + sum(octet * (at + 1) for at, octet in enumerate(data))


def worker(dll: Path) -> int:
    expected = windows_arguments()
    library = ctypes.WinDLL(str(dll.resolve()))
    library.snapshot_count.argtypes = []
    library.snapshot_count.restype = ctypes.c_size_t
    library.snapshot_hash.argtypes = [ctypes.c_size_t]
    library.snapshot_hash.restype = ctypes.c_size_t
    barrier = threading.Barrier(16)

    def query(ordinal: int) -> bool:
        barrier.wait(timeout=15)
        # Even threads initialize via argc; odd threads initialize via argv.
        # No OpenC API is called on this DLL before the barrier releases.
        if ordinal % 2 == 0 and library.snapshot_count() != len(expected):
            return False
        for repeat in range(32):
            for index, value in enumerate(expected):
                if library.snapshot_hash(index) != fingerprint(value):
                    return False
            if library.snapshot_count() != len(expected):
                return False
        return True

    with ThreadPoolExecutor(max_workers=16) as pool:
        passed = all(pool.map(query, range(16)))
    print(json.dumps({"passed": passed, "threads": 16, "repeats": 32, "arguments": len(expected)}))
    return 0 if passed else 1


def measured(command: list[str], cwd: Path) -> dict[str, object]:
    return run_measured(
        command, cwd=cwd, sample_interval=0.01,
        max_private_bytes=256 * MIB, max_working_set_bytes=128 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=60,
    )


def passed(sample: dict[str, object]) -> bool:
    return (
        sample["exit_code"] == 0 and not sample["memory_limit_exceeded"]
        and not sample["timed_out"] and not sample["stdout_truncated"]
        and not sample["stderr_truncated"]
    )


def main() -> int:
    if len(sys.argv) > 2 and sys.argv[1] == "--worker":
        return worker(Path(sys.argv[2]))
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    directory = output.parent / (output.stem + "-runs")
    directory.mkdir(parents=True, exist_ok=False)
    (directory / "main.p").write_text(SOURCE, encoding="utf-8", newline="\n")
    project = directory / "openc.project.json"
    project.write_text(json.dumps({
        "name": "sh27-argument-snapshot", "version": "1.0.0",
        "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
        "modules": {"snapshot": ["main.p"]}, "output_directory": "build",
    }), encoding="utf-8")
    builds = []
    for kind in ("exe", "dll"):
        artifact = directory / ("snapshot." + kind)
        builds.append(measured([
            str(compiler), "artifact", f"--project={project}", f"--kind={kind}",
            f"--output={artifact}", "--dll-name=snapshot.dll",
        ], ROOT))
    cases = []
    if all(passed(sample) for sample in builds):
        payloads = [[], ["alpha", "two words", 'a"b', "backslash\\"],
                    ["", "", "Привіт", "世界", "emoji 🐦"], ["x" * 4096]]
        for payload in payloads:
            executable = measured([str(directory / "snapshot.exe"), *payload], directory)
            expected = "".join(f"{index}:{value}\n" for index, value in enumerate(payload)) * 3
            exact = executable["stdout"] == expected and executable["stderr"] == ""
            concurrent = measured([
                sys.executable, str(Path(__file__).resolve()), "--worker",
                str(directory / "snapshot.dll"), *payload,
            ], directory)
            cases.append({
                "payload": payload, "exe": executable, "dll_concurrent": concurrent,
                "passed": passed(executable) and exact and passed(concurrent),
            })
    success = all(passed(sample) for sample in builds) and len(cases) == 4 and all(c["passed"] for c in cases)
    report = {"schema": "openc.sh27.argument_snapshot.v1", "status": "PASS" if success else "FAIL",
              "compiler_sha256": sha256(compiler), "builds": builds, "cases": cases}
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"SH-27 argument snapshot: {report['status']}; cases={sum(c['passed'] for c in cases)}/4; report={output}")
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
