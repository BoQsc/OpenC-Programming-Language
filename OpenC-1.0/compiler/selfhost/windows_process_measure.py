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
JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS = 9
JOB_OBJECT_LIMIT_PROCESS_MEMORY = 0x00000100
JOB_OBJECT_LIMIT_JOB_MEMORY = 0x00000200
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000


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


class JobObjectBasicLimitInformation(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_int64),
        ("PerJobUserTimeLimit", ctypes.c_int64),
        ("LimitFlags", wintypes.DWORD),
        ("MinimumWorkingSetSize", ctypes.c_size_t),
        ("MaximumWorkingSetSize", ctypes.c_size_t),
        ("ActiveProcessLimit", wintypes.DWORD),
        ("Affinity", ctypes.c_size_t),
        ("PriorityClass", wintypes.DWORD),
        ("SchedulingClass", wintypes.DWORD),
    ]


class IoCounters(ctypes.Structure):
    _fields_ = [
        ("ReadOperationCount", ctypes.c_uint64),
        ("WriteOperationCount", ctypes.c_uint64),
        ("OtherOperationCount", ctypes.c_uint64),
        ("ReadTransferCount", ctypes.c_uint64),
        ("WriteTransferCount", ctypes.c_uint64),
        ("OtherTransferCount", ctypes.c_uint64),
    ]


class JobObjectExtendedLimitInformation(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", JobObjectBasicLimitInformation),
        ("IoInfo", IoCounters),
        ("ProcessMemoryLimit", ctypes.c_size_t),
        ("JobMemoryLimit", ctypes.c_size_t),
        ("PeakProcessMemoryUsed", ctypes.c_size_t),
        ("PeakJobMemoryUsed", ctypes.c_size_t),
    ]


def _job_api() -> ctypes.WinDLL:
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    kernel32.CreateJobObjectW.restype = wintypes.HANDLE
    kernel32.SetInformationJobObject.argtypes = [
        wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD,
    ]
    kernel32.SetInformationJobObject.restype = wintypes.BOOL
    kernel32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    kernel32.AssignProcessToJobObject.restype = wintypes.BOOL
    kernel32.QueryInformationJobObject.argtypes = [
        wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD,
        ctypes.POINTER(wintypes.DWORD),
    ]
    kernel32.QueryInformationJobObject.restype = wintypes.BOOL
    kernel32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel32.TerminateJobObject.restype = wintypes.BOOL
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    return kernel32


def _create_job(kernel32: ctypes.WinDLL, max_private_bytes: int | None) -> int:
    job = kernel32.CreateJobObjectW(None, None)
    if not job:
        raise ctypes.WinError(ctypes.get_last_error())
    limits = JobObjectExtendedLimitInformation()
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if max_private_bytes is not None:
        limits.BasicLimitInformation.LimitFlags |= (
            JOB_OBJECT_LIMIT_PROCESS_MEMORY | JOB_OBJECT_LIMIT_JOB_MEMORY
        )
        limits.ProcessMemoryLimit = max_private_bytes
        limits.JobMemoryLimit = max_private_bytes
    if not kernel32.SetInformationJobObject(
        job, JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
        ctypes.byref(limits), ctypes.sizeof(limits),
    ):
        error = ctypes.get_last_error()
        kernel32.CloseHandle(job)
        raise ctypes.WinError(error)
    return job


def _job_peak_private(kernel32: ctypes.WinDLL, job: int) -> int:
    limits = JobObjectExtendedLimitInformation()
    if not kernel32.QueryInformationJobObject(
        job, JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
        ctypes.byref(limits), ctypes.sizeof(limits), None,
    ):
        raise ctypes.WinError(ctypes.get_last_error())
    return int(limits.PeakJobMemoryUsed)


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
    timeout_seconds: float | None = None,
) -> dict[str, object]:
    if os.name != "nt":
        raise RuntimeError("Windows process measurement is Windows-only")
    if sample_interval <= 0:
        raise ValueError("sample interval must be positive")
    if max_captured_output_bytes <= 0:
        raise ValueError("captured output limit must be positive")
    if timeout_seconds is not None and timeout_seconds <= 0:
        raise ValueError("timeout must be positive")
    kernel32 = _job_api()
    job = _create_job(kernel32, max_private_bytes)
    try:
        return _run_measured_in_job(
            command, cwd=cwd, environment=environment,
            sample_interval=sample_interval,
            max_working_set_bytes=max_working_set_bytes,
            max_private_bytes=max_private_bytes,
            max_captured_output_bytes=max_captured_output_bytes,
            timeout_seconds=timeout_seconds,
            kernel32=kernel32, job=job,
        )
    finally:
        kernel32.CloseHandle(job)


def _run_measured_in_job(
    command: list[str],
    *,
    cwd: str | os.PathLike[str],
    environment: dict[str, str] | None,
    sample_interval: float,
    max_working_set_bytes: int | None,
    max_private_bytes: int | None,
    max_captured_output_bytes: int,
    timeout_seconds: float | None,
    kernel32: ctypes.WinDLL,
    job: int,
) -> dict[str, object]:
    started = time.perf_counter()
    with tempfile.TemporaryFile() as stdout_file, tempfile.TemporaryFile() as stderr_file:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=environment,
            stdout=stdout_file,
            stderr=stderr_file,
        )
        # Assignment follows process creation, so commits made before this
        # call are not retroactively limited. Sample the whole-job peak too.
        if not kernel32.AssignProcessToJobObject(job, process._handle):
            error = ctypes.get_last_error()
            process.kill()
            process.wait()
            raise ctypes.WinError(error)
        handle = _open_process(process.pid)
        peak_working_set = 0
        peak_pagefile = 0
        peak_private = 0
        peak_job_private = 0
        samples = 0
        memory_limit_exceeded = False
        memory_limit_name = ""
        memory_limit_bytes = 0
        memory_observed_bytes = 0
        timed_out = False
        try:
            while process.poll() is None:
                if (
                    timeout_seconds is not None
                    and time.perf_counter() - started >= timeout_seconds
                ):
                    timed_out = True
                    kernel32.TerminateJobObject(job, 1)
                    break
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
                peak_job_private = max(
                    peak_job_private, _job_peak_private(kernel32, job)
                )
                samples += 1
                if (
                    max_private_bytes is not None
                    and peak_job_private >= max_private_bytes
                ):
                    memory_limit_exceeded = True
                    memory_limit_name = "job_private_bytes"
                    memory_limit_bytes = max_private_bytes
                    memory_observed_bytes = peak_job_private
                    kernel32.TerminateJobObject(job, 1)
                    break
                if (
                    max_private_bytes is not None
                    and counters.PrivateUsage > max_private_bytes
                ):
                    memory_limit_exceeded = True
                    memory_limit_name = "private_bytes"
                    memory_limit_bytes = max_private_bytes
                    memory_observed_bytes = counters.PrivateUsage
                    kernel32.TerminateJobObject(job, 1)
                    break
                if (
                    max_working_set_bytes is not None
                    and counters.WorkingSetSize > max_working_set_bytes
                ):
                    memory_limit_exceeded = True
                    memory_limit_name = "working_set_bytes"
                    memory_limit_bytes = max_working_set_bytes
                    memory_observed_bytes = counters.WorkingSetSize
                    kernel32.TerminateJobObject(job, 1)
                    break
                time.sleep(sample_interval)
            process.wait()
            peak_job_private = max(
                peak_job_private, _job_peak_private(kernel32, job)
            )
            if (
                max_private_bytes is not None
                and peak_job_private >= max_private_bytes
                and not memory_limit_exceeded
            ):
                memory_limit_exceeded = True
                memory_limit_name = "job_private_bytes"
                memory_limit_bytes = max_private_bytes
                memory_observed_bytes = peak_job_private
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
        "peak_job_private_bytes": peak_job_private,
        "memory_limit_exceeded": memory_limit_exceeded,
        "memory_limit_name": memory_limit_name,
        "memory_limit_bytes": memory_limit_bytes,
        "memory_observed_bytes": memory_observed_bytes,
        "timed_out": timed_out,
        "exit_code": process.returncode,
        "stdout": stdout,
        "stderr": stderr,
        "stdout_truncated": stdout_truncated,
        "stderr_truncated": stderr_truncated,
    }
