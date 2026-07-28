#!/usr/bin/env python3
"""Windows subprocess elapsed-time and peak-memory measurement."""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import os
import subprocess
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
) -> dict[str, object]:
    if os.name != "nt":
        raise RuntimeError("Windows process measurement is Windows-only")
    if sample_interval <= 0:
        raise ValueError("sample interval must be positive")
    started = time.perf_counter()
    process = subprocess.Popen(
        command,
        cwd=cwd,
        env=environment,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        encoding="utf-8",
    )
    handle = _open_process(process.pid)
    peak_working_set = 0
    peak_pagefile = 0
    peak_private = 0
    samples = 0
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    try:
        while process.poll() is None:
            counters = _process_memory(handle)
            peak_working_set = max(peak_working_set, counters.PeakWorkingSetSize)
            peak_pagefile = max(peak_pagefile, counters.PeakPagefileUsage)
            peak_private = max(peak_private, counters.PrivateUsage)
            samples += 1
            time.sleep(sample_interval)
        stdout, stderr = process.communicate()
        try:
            counters = _process_memory(handle)
            peak_working_set = max(peak_working_set, counters.PeakWorkingSetSize)
            peak_pagefile = max(peak_pagefile, counters.PeakPagefileUsage)
            peak_private = max(peak_private, counters.PrivateUsage)
        except OSError:
            pass
    finally:
        kernel32.CloseHandle(handle)
    return {
        "elapsed_seconds": round(time.perf_counter() - started, 3),
        "sample_interval_seconds": sample_interval,
        "samples": samples,
        "peak_working_set_bytes": peak_working_set,
        "peak_pagefile_bytes": peak_pagefile,
        "peak_private_bytes": peak_private,
        "exit_code": process.returncode,
        "stdout": stdout,
        "stderr": stderr,
    }
