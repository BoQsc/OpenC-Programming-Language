#!/usr/bin/env python3
"""Measure a native OpenC compiler rebuilding the self-hosted compiler."""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import time


ROOT = Path(__file__).resolve().parents[2]
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
PROCESS_VM_READ = 0x0010


class ProcessMemoryCountersEx(ctypes.Structure):
    """Windows PROCESS_MEMORY_COUNTERS_EX."""

    _fields_ = [
        ("cb", wintypes.DWORD),
        ("PageFaultCount", wintypes.DWORD),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
        ("PrivateUsage", ctypes.c_size_t),
    ]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


def open_process(pid: int) -> int:
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.argtypes = [
        wintypes.DWORD,
        wintypes.BOOL,
        wintypes.DWORD,
    ]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    handle = kernel32.OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ,
        False,
        pid,
    )
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    return handle


def process_memory(handle: int) -> ProcessMemoryCountersEx:
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    psapi.GetProcessMemoryInfo.argtypes = [
        wintypes.HANDLE,
        ctypes.c_void_p,
        wintypes.DWORD,
    ]
    psapi.GetProcessMemoryInfo.restype = wintypes.BOOL
    counters = ProcessMemoryCountersEx()
    counters.cb = ctypes.sizeof(counters)
    if not psapi.GetProcessMemoryInfo(
        handle,
        ctypes.byref(counters),
        counters.cb,
    ):
        raise ctypes.WinError(ctypes.get_last_error())
    return counters


def main() -> int:
    if os.name != "nt":
        raise SystemExit("native self-rebuild measurement is Windows-only")

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--compiler",
        type=Path,
        default=ROOT
        / "build-output"
        / "selfhost-sh6"
        / "final"
        / "stage3-distribution"
        / "openc.exe",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=ROOT / "compiler" / "selfhost" / "openc.project.json",
    )
    parser.add_argument(
        "--tcc",
        type=Path,
        default=ROOT / "third_party" / "tinycc-win64" / "tcc.exe",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT
        / "build-output"
        / "performance"
        / "native-self-rebuild"
        / "openc.exe",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=ROOT
        / "build-output"
        / "performance"
        / "native-self-rebuild"
        / "measurement.json",
    )
    parser.add_argument("--sample-interval", type=float, default=0.1)
    args = parser.parse_args()

    compiler = args.compiler.resolve()
    project = args.project.resolve()
    tcc = args.tcc.resolve()
    output = args.output.resolve()
    report = args.report.resolve()
    for required in (compiler, project, tcc):
        if not required.is_file():
            raise SystemExit(f"missing required input: {required}")
    if args.sample_interval <= 0:
        raise SystemExit("--sample-interval must be positive")

    output.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    generated = Path(str(output) + ".openc.c")
    record = Path(str(output) + ".build.json")
    environment, child_path = clean_child_environment(tcc)
    command = [
        str(compiler),
        "--windows-build",
        str(project),
        str(output),
        str(generated),
        str(ROOT / "runtime"),
        str(ROOT / "compiler" / "selfhost" / "native_runtime"),
        str(record),
        str(tcc),
    ]

    started_at = datetime.now(timezone.utc)
    started = time.perf_counter()
    process = subprocess.Popen(
        command,
        cwd=ROOT,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        encoding="utf-8",
    )
    handle = open_process(process.pid)
    peak_working_set = 0
    peak_pagefile = 0
    peak_private = 0
    samples = 0
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    try:
        while process.poll() is None:
            counters = process_memory(handle)
            peak_working_set = max(
                peak_working_set, counters.PeakWorkingSetSize
            )
            peak_pagefile = max(peak_pagefile, counters.PeakPagefileUsage)
            peak_private = max(peak_private, counters.PrivateUsage)
            samples += 1
            time.sleep(args.sample_interval)
        stdout, stderr = process.communicate()
        try:
            counters = process_memory(handle)
            peak_working_set = max(
                peak_working_set, counters.PeakWorkingSetSize
            )
            peak_pagefile = max(peak_pagefile, counters.PeakPagefileUsage)
            peak_private = max(peak_private, counters.PrivateUsage)
        except OSError:
            pass
    finally:
        kernel32.CloseHandle(handle)
    elapsed = time.perf_counter() - started

    artifacts: dict[str, object] = {}
    for name, path in (
        ("compiler_input", compiler),
        ("project_input", project),
        ("output_executable", output),
        ("generated_c", generated),
        ("build_record", record),
    ):
        artifacts[name] = {
            "path": str(path),
            "present": path.is_file(),
            "bytes": path.stat().st_size if path.is_file() else 0,
            "sha256": sha256(path) if path.is_file() else None,
        }
    result = {
        "schema": "openc.native_self_rebuild_measurement.v1",
        "status": "PASS" if process.returncode == 0 else "FAIL",
        "measured_at_utc": started_at.isoformat().replace("+00:00", "Z"),
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
        },
        "command": command,
        "environment": {
            "child_path": child_path,
            "dmd_available_to_native_build": False,
            "dub_available_to_native_build": False,
            "python_available_to_native_build": False,
        },
        "measurement": {
            "elapsed_seconds": round(elapsed, 3),
            "sample_interval_seconds": args.sample_interval,
            "samples": samples,
            "peak_working_set_bytes": peak_working_set,
            "peak_pagefile_bytes": peak_pagefile,
            "peak_private_bytes": peak_private,
        },
        "process": {
            "exit_code": process.returncode,
            "stdout": stdout,
            "stderr": stderr,
        },
        "artifacts": artifacts,
    }
    report.write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(json.dumps(result["measurement"], sort_keys=True))
    if process.returncode != 0:
        print(stderr, end="", file=os.sys.stderr)
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
