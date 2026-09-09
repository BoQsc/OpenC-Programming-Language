#!/usr/bin/env python3
"""Windows subprocess elapsed-time and peak-memory measurement."""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import os
import subprocess
import tempfile
import time


PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
PROCESS_VM_READ = 0x0010


class ProcessMemoryCountersEx(ctypes.Structure):
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


def _open_process(pid: int) -> int:
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


def _process_memory(handle: int) -> ProcessMemoryCountersEx:
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


def run_measured(
    command: list[str],
    *,
    cwd: str | os.PathLike[str],
    environment: dict[str, str] | None = None,
    sample_interval: float = 0.1,
    max_working_set_bytes: int | None = None,
    max_private_bytes: int | None = None,
    max_captured_output_bytes: int = 8 * 1024 * 1024,
) -> dict[str, object]:
    if os.name != "nt":
        raise RuntimeError("Windows process measurement is Windows-only")
    if sample_interval <= 0:
        raise ValueError("sample interval must be positive")
    if max_captured_output_bytes <= 0:
        raise ValueError("captured output limit must be positive")
    started = time.perf_counter()
    with tempfile.TemporaryFile() as stdout_file, tempfile.TemporaryFile() as stderr_file:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=environment,
            stdout=stdout_file,
            stderr=stderr_file,
        )
        handle = _open_process(process.pid)
        peak_working_set = 0
        peak_pagefile = 0
        peak_private = 0
        samples = 0
        memory_limit_exceeded = False
        memory_limit_name = ""
        memory_limit_bytes = 0
        memory_observed_bytes = 0
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel32.CloseHandle.restype = wintypes.BOOL
        try:
            while process.poll() is None:
                try:
                    counters = _process_memory(handle)
                except OSError:
                    if process.poll() is not None:
                        break
                    raise
                peak_working_set = max(
                    peak_working_set, counters.PeakWorkingSetSize
                )
                peak_pagefile = max(
                    peak_pagefile, counters.PeakPagefileUsage
                )
                peak_private = max(peak_private, counters.PrivateUsage)
                samples += 1
                if (
                    max_private_bytes is not None
                    and counters.PrivateUsage > max_private_bytes
                ):
                    memory_limit_exceeded = True
                    memory_limit_name = "private_bytes"
                    memory_limit_bytes = max_private_bytes
                    memory_observed_bytes = counters.PrivateUsage
                    process.kill()
                    break
                if (
                    max_working_set_bytes is not None
                    and counters.WorkingSetSize > max_working_set_bytes
                ):
                    memory_limit_exceeded = True
                    memory_limit_name = "working_set_bytes"
                    memory_limit_bytes = max_working_set_bytes
                    memory_observed_bytes = counters.WorkingSetSize
                    process.kill()
                    break
                time.sleep(sample_interval)
            process.wait()
            try:
                counters = _process_memory(handle)
                peak_working_set = max(
                    peak_working_set, counters.PeakWorkingSetSize
                )
                peak_pagefile = max(
                    peak_pagefile, counters.PeakPagefileUsage
                )
                peak_private = max(peak_private, counters.PrivateUsage)
            except OSError:
                pass
        finally:
            kernel32.CloseHandle(handle)

        def captured(file: object) -> tuple[str, bool]:
            file.flush()
            file.seek(0)
            data = file.read(max_captured_output_bytes + 1)
            truncated = len(data) > max_captured_output_bytes
            return (
                data[:max_captured_output_bytes].decode("utf-8", errors="replace"),
                truncated,
            )

        stdout, stdout_truncated = captured(stdout_file)
        stderr, stderr_truncated = captured(stderr_file)
    return {
        "elapsed_seconds": round(time.perf_counter() - started, 3),
        "sample_interval_seconds": sample_interval,
        "samples": samples,
        "peak_working_set_bytes": peak_working_set,
        "peak_pagefile_bytes": peak_pagefile,
        "peak_private_bytes": peak_private,
        "memory_limit_exceeded": memory_limit_exceeded,
        "memory_limit_name": memory_limit_name,
        "memory_limit_bytes": memory_limit_bytes,
        "memory_observed_bytes": memory_observed_bytes,
        "exit_code": process.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "stdout_truncated": stdout_truncated,
        "stderr_truncated": stderr_truncated,
    }
