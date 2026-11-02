#!/usr/bin/env python3
"""Bounded Windows HeapAlloc proxy for the SH-27 source-scratch hypothesis.

This is a triage probe, not an OpenC compiler timing.  It deliberately gives
split allocations a Python-call disadvantage, so a tiny measured benefit is
strong evidence against spending a guarded compiler build on an arena.
"""
from __future__ import annotations

import ctypes
import json
from pathlib import Path
import statistics
import time


HEAP_ZERO_MEMORY = 8
ROOT = Path(__file__).resolve().parents[2]


def shape(syntax: int, source: int, aggregate_bytes: int) -> list[int]:
    # 43 profiled source-constructor sites: 4 IR buffers, 34 syntax-sized
    # arrays (including profiling-only type-seen), 3 source-position arrays,
    # and two symbol-sized arrays.  The residual sets the two symbol sizes so
    # cumulative requested bytes match the opt-in probe's published total.
    sizes = [
        (syntax // 2 + 32) * 40,
        (syntax + 64) * 40,
        (syntax + 64) * 40,
        (syntax * 2 + 64) * 40,
        *([(syntax + 1) * 8] * 34),
        *([(source + 1) * 8] * 3),
    ]
    residual = aggregate_bytes - sum(sizes)
    assert residual > 0
    sizes.extend((residual // 2, residual - residual // 2))
    assert len(sizes) == 43 and sum(sizes) == aggregate_bytes
    return sizes


def run_group(heap: int, sizes: list[int], sources: int, arena: bool, touch: bool) -> int:
    began = time.perf_counter_ns()
    for _ in range(sources):
        requested = [sum(sizes)] if arena else sizes
        blocks: list[int] = []
        try:
            for size in requested:
                block = kernel32.HeapAlloc(heap, HEAP_ZERO_MEMORY, size)
                if not block:
                    raise MemoryError(f"HeapAlloc({size})")
                blocks.append(block)
                if touch:
                    ctypes.memset(block, 0, size)
        finally:
            for block in reversed(blocks):
                if not kernel32.HeapFree(heap, 0, block):
                    raise OSError("HeapFree failed")
    return time.perf_counter_ns() - began


kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
kernel32.GetProcessHeap.argtypes = ()
kernel32.GetProcessHeap.restype = ctypes.c_void_p
kernel32.HeapAlloc.argtypes = (ctypes.c_void_p, ctypes.c_ulong, ctypes.c_size_t)
kernel32.HeapAlloc.restype = ctypes.c_void_p
kernel32.HeapFree.argtypes = (ctypes.c_void_p, ctypes.c_ulong, ctypes.c_void_p)
kernel32.HeapFree.restype = ctypes.c_int


def main() -> int:
    heap = kernel32.GetProcessHeap()
    if not heap:
        raise OSError("GetProcessHeap failed")
    cases = {
        "large_functions": {
            "source_count": 8,
            "syntax_per_source": 183833 // 8,
            "source_bytes_per_source": 741660 // 8,
            "profiled_requested_bytes_per_source": 101490936 // 8,
        },
        "control_flow": {
            "source_count": 4,
            "syntax_per_source": 40341 // 4,
            "source_bytes_per_source": 206637 // 4,
            "profiled_requested_bytes_per_source": 23312496 // 4,
        },
    }
    report: dict[str, object] = {
        "schema": "openc.sh27.scratch_heap_proxy.v1",
        "interpretation": (
            "Win32 HeapAlloc/HeapFree proxy with forced page touch; Python "
            "per-call overhead favors the arena and makes gains optimistic. "
            "It does not benchmark OpenC or model concurrent worker cache effects."
        ),
        "cases": {},
    }
    for name, case in cases.items():
        sizes = shape(
            case["syntax_per_source"], case["source_bytes_per_source"],
            case["profiled_requested_bytes_per_source"],
        )
        source_count = case["source_count"]
        group: dict[str, object] = {
            "profiled_requests": len(sizes) * source_count,
            "production_requests": (len(sizes) - 1) * source_count,
            "profiled_requested_bytes": sum(sizes) * source_count,
            "source_count": source_count,
            "max_live_requested_bytes": sum(sizes),
            "variants": {},
        }
        for touch in (False, True):
            split: list[int] = []
            arena: list[int] = []
            for index in range(43):
                first_arena = index % 2 == 0
                one = run_group(heap, sizes, source_count, first_arena, touch)
                two = run_group(heap, sizes, source_count, not first_arena, touch)
                if first_arena:
                    arena.append(one)
                    split.append(two)
                else:
                    split.append(one)
                    arena.append(two)
            group["variants"]["forced_touch" if touch else "heap_zero_only"] = {
                "split_median_ms": statistics.median(split) / 1_000_000,
                "arena_median_ms": statistics.median(arena) / 1_000_000,
                "paired_delta_median_ms": statistics.median(
                    s - a for s, a in zip(split, arena)
                ) / 1_000_000,
                "split_raw_ns": split,
                "arena_raw_ns": arena,
            }
        report["cases"][name] = group
    output = ROOT / "build-output" / "sh27-scratch-ownership" / "heap-proxy-01.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for name, group in report["cases"].items():
        print(name, {
            key: round(value["paired_delta_median_ms"], 3)
            for key, value in group["variants"].items()
        })
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
