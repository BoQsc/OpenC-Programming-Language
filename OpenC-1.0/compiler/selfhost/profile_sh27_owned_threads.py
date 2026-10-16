"""Diagnostic instruction-pointer samples from compiler children we launch.

Not a benchmark: sampling briefly suspends one owned child thread at a time.
Every successful suspension has a finally-resume; failure to resume kills only
that owned child. No existing process can be selected. A passing worker-pool
proof pins the compiler hash and the complete source map before sampling.

Contracts: learn.microsoft.com/windows/win32/api/processthreadsapi/
nf-processthreadsapi-getthreadcontext and nf-processthreadsapi-suspendthread;
learn.microsoft.com/windows/win32/api/winnt/ns-winnt-context;
learn.microsoft.com/windows/win32/api/realtimeapiset/nf-realtimeapiset-querythreadcycletime.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
from collections import Counter
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import threading
import time

from benchmark_sh27_production import ROOT, MIB, require_disk_headroom, sha256
import verify_sh27_worker_pool as mapping
import windows_process_measure as measure


class ThreadEntry(ctypes.Structure):
    _fields_ = [(name, wintypes.DWORD) for name in
        ('size', 'usage', 'thread', 'process')] + [
        ('base_priority', wintypes.LONG), ('delta_priority', wintypes.LONG),
        ('flags', wintypes.DWORD)]


class ModuleEntry(ctypes.Structure):
    _fields_ = [(name, wintypes.DWORD) for name in
        ('size', 'module', 'process', 'global_usage', 'process_usage')] + [
        ('base', ctypes.c_void_p), ('base_size', wintypes.DWORD),
        ('handle', wintypes.HANDLE), ('name', wintypes.WCHAR * 256),
        ('path', wintypes.WCHAR * 260)]


def native_map(data: bytes) -> list[tuple[int, int, str]]:
    sections, _, _ = mapping.patch_locations(data)
    size, _, _, raw = sections['.pdata']
    root = mapping.ROOT / 'compiler/selfhost'
    manifest = json.loads((root / 'openc.project.json').read_text(encoding='utf-8'))
    names = ['<entry>', '<panic>', '<target-fault>']
    for filename in manifest['modules']['openc.selfhost.main']:
        names.extend(re.findall(
            r'(?m)^(?:unsafe\s+)?(?:[A-Za-z_]\w*(?:\s+\w+)?)\s+([A-Za-z_]\w*)\s*\(',
            (root / filename).read_text(encoding='utf-8')))
    ranges = [struct.unpack_from('<III', data, raw + at)[:2] for at in range(0, size, 12)]
    if len(names) != len(ranges):
        raise ValueError('source/image function count mismatch')
    return [(start, end, name) for (start, end), name in zip(ranges, names)]


def function_at(ranges: list[tuple[int, int, str]], starts: list[int], rva: int) -> str:
    index = bisect_right(starts, rva) - 1
    if index >= 0 and ranges[index][0] <= rva < ranges[index][1]:
        return ranges[index][2]
    return '<outside compiler>'


class OwnedSampler:
    def __init__(self, compiler: Path, ranges: list[tuple[int, int, str]], max_samples: int = 20000):
        self.compiler = compiler
        self.ranges = ranges
        self.starts = [row[0] for row in ranges]
        self.max_samples = max_samples
        self.stop = threading.Event()
        self.samples = []
        self.errors = []
        self.process = None
        self.thread = None

    def attach(self, process):
        if self.process is not None:
            raise RuntimeError('only one directly launched child per sampler')
        self.process = process
        self.thread = threading.Thread(target=self.sample, daemon=True)
        self.thread.start()

    def finish(self):
        self.stop.set()
        if self.thread is not None:
            self.thread.join(timeout=5)
            if self.thread.is_alive():
                self.errors.append('sampler did not stop')

    def sample(self):
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        signatures = {
            'CreateToolhelp32Snapshot': ([wintypes.DWORD, wintypes.DWORD], wintypes.HANDLE),
            'CloseHandle': ([wintypes.HANDLE], wintypes.BOOL),
            'OpenThread': ([wintypes.DWORD, wintypes.BOOL, wintypes.DWORD], wintypes.HANDLE),
            'SuspendThread': ([wintypes.HANDLE], wintypes.DWORD),
            'ResumeThread': ([wintypes.HANDLE], wintypes.DWORD),
            'GetThreadContext': ([wintypes.HANDLE, ctypes.c_void_p], wintypes.BOOL),
            'QueryThreadCycleTime': ([wintypes.HANDLE, ctypes.POINTER(ctypes.c_uint64)], wintypes.BOOL),
        }
        for name, (arguments, result) in signatures.items():
            getattr(kernel, name).argtypes = arguments
            getattr(kernel, name).restype = result
        for name in ('Thread32First', 'Thread32Next'):
            getattr(kernel, name).argtypes = [wintypes.HANDLE, ctypes.POINTER(ThreadEntry)]
            getattr(kernel, name).restype = wintypes.BOOL
        kernel.Module32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(ModuleEntry)]
        kernel.Module32FirstW.restype = wintypes.BOOL
        invalid = ctypes.c_void_p(-1).value
        handles = {}
        cycles = {}
        base = None
        refresh = 0.0
        # Windows AMD64 CONTEXT is 1232 bytes, aligned to 16. CONTROL requests
        # RIP/RSP and control state only; RIP is at offset 248, Flags at 48.
        storage = ctypes.create_string_buffer(1232 + 15)
        address = (ctypes.addressof(storage) + 15) & ~15
        ctypes.c_uint32.from_address(address + 48).value = 0x100001
        try:
            while not self.stop.is_set() and self.process.poll() is None:
                if base is None:
                    snapshot = kernel.CreateToolhelp32Snapshot(8, self.process.pid)
                    if snapshot and snapshot != invalid:
                        try:
                            entry = ModuleEntry()
                            entry.size = ctypes.sizeof(entry)
                            if kernel.Module32FirstW(snapshot, ctypes.byref(entry)):
                                if Path(entry.path).resolve() != self.compiler:
                                    raise RuntimeError('owned child image identity mismatch')
                                base = entry.base
                        finally:
                            kernel.CloseHandle(snapshot)
                    if base is None:
                        self.stop.wait(.002)
                        continue
                if time.perf_counter() >= refresh:
                    snapshot = kernel.CreateToolhelp32Snapshot(4, 0)
                    if snapshot and snapshot != invalid:
                        try:
                            entry = ThreadEntry()
                            entry.size = ctypes.sizeof(entry)
                            okay = kernel.Thread32First(snapshot, ctypes.byref(entry))
                            visits = 0
                            while okay and visits < 50000:
                                # System snapshots enumerate broadly; open and
                                # inspect ONLY threads of our direct child PID.
                                if entry.process == self.process.pid and entry.thread not in handles:
                                    if len(handles) >= 64:
                                        raise RuntimeError('owned thread budget exceeded')
                                    handle = kernel.OpenThread(0x0002 | 0x0008 | 0x0040, False, entry.thread)
                                    if handle:
                                        handles[entry.thread] = handle
                                visits += 1
                                entry.size = ctypes.sizeof(entry)
                                okay = kernel.Thread32Next(snapshot, ctypes.byref(entry))
                        finally:
                            kernel.CloseHandle(snapshot)
                    refresh = time.perf_counter() + .02
                for thread_id, handle in handles.items():
                    count = ctypes.c_uint64()
                    if not kernel.QueryThreadCycleTime(handle, ctypes.byref(count)):
                        continue
                    previous = cycles.get(thread_id, 0)
                    cycles[thread_id] = count.value
                    delta = count.value - previous
                    # Avoid repeatedly sampling an idle thread solely because
                    # the previous observation itself consumed kernel cycles.
                    # This declared filter is not a CPU-time estimator.
                    if delta < 50000:
                        continue
                    suspended = kernel.SuspendThread(handle)
                    if suspended == 0xFFFFFFFF:
                        continue
                    try:
                        if kernel.GetThreadContext(handle, address):
                            rip = ctypes.c_uint64.from_address(address + 248).value
                            rva = rip - base
                            self.samples.append({'thread': thread_id,
                                'rva': rva if 0 <= rva < 0x100000000 else None,
                                'cycle_delta': delta,
                                'function': function_at(self.ranges, self.starts, rva)})
                    finally:
                        if kernel.ResumeThread(handle) == 0xFFFFFFFF:
                            self.process.kill()
                            raise RuntimeError('could not resume owned child; child terminated')
                    if len(self.samples) >= self.max_samples:
                        raise RuntimeError('sample budget exceeded')
                self.stop.wait(.002)
        except Exception as error:
            self.errors.append(str(error))
        finally:
            for handle in handles.values():
                kernel.CloseHandle(handle)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--mapping-proof', type=Path, required=True)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--runs', type=int, default=15)
    args = parser.parse_args()
    if os.name != 'nt' or struct.calcsize('P') != 8:
        parser.error('requires 64-bit Windows Python')
    if not 1 <= args.runs <= 50:
        parser.error('runs must be between 1 and 50')
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error('refusing to replace retained evidence')
    if args.mapping_proof.stat().st_size > 32 * MIB:
        parser.error('mapping metadata exceeds the 32 MiB input budget')
    proof = json.loads(args.mapping_proof.read_text(encoding='utf-8'))
    if proof.get('status') != 'PASS' or proof['compiler']['sha256'] != sha256(compiler):
        parser.error('compiler lacks a matching passing mapping proof')
    manifest = json.loads((ROOT / 'compiler/selfhost/openc.project.json').read_text(encoding='utf-8'))
    if set(proof['source_map_sha256']) != set(manifest['modules']['openc.selfhost.main']):
        parser.error('mapping proof does not cover the complete compiler source')
    for name, digest in proof['source_map_sha256'].items():
        if sha256(ROOT / 'compiler/selfhost' / name) != digest:
            parser.error('current source differs from the pinned map')
    if compiler.stat().st_size > 16 * MIB:
        parser.error('compiler image exceeds map budget')
    ranges = native_map(compiler.read_bytes())
    require_disk_headroom(output.parent)
    runs = output.parent / (output.stem + '-runs')
    runs.mkdir(parents=True, exist_ok=False)
    records = []
    total_samples = 0
    original_popen = measure.subprocess.Popen
    for index in range(args.runs):
        binary = runs / f'program-{index}.exe'
        remaining = 100000 - total_samples
        if remaining <= 0:
            raise RuntimeError('aggregate sample budget exceeded')
        sampler = OwnedSampler(compiler, ranges, min(20000, remaining))
        def launch(*arguments, **keywords):
            process = original_popen(*arguments, **keywords)
            sampler.attach(process)
            return process
        try:
            measure.subprocess.Popen = launch
            result = measure.run_measured([str(compiler), 'artifact',
                f'--project={args.project.resolve(strict=True)}', '--kind=exe',
                f'--output={binary}'], cwd=ROOT, sample_interval=.01,
                max_private_bytes=256*MIB, max_working_set_bytes=128*MIB,
                max_captured_output_bytes=2*MIB, timeout_seconds=60)
        finally:
            measure.subprocess.Popen = original_popen
            sampler.finish()
        if result['exit_code'] != 0 or result['timed_out'] or result['memory_limit_exceeded'] or sampler.errors:
            raise RuntimeError({'measurement': result, 'sampler_errors': sampler.errors})
        if not sampler.samples:
            raise RuntimeError('no context samples; profile is not usable')
        total_samples += len(sampler.samples)
        records.append({'profiled_measurement_not_benchmark': result,
            'binary_sha256': sha256(binary), 'samples': sampler.samples})
        print(f'owned compiler profile {index+1}/{args.runs}: {len(sampler.samples)} samples', flush=True)
    totals = Counter(sample['function'] for record in records for sample in record['samples'])
    if len({record['binary_sha256'] for record in records}) != 1:
        raise RuntimeError('profiled compiler outputs are not deterministic')
    report = {'schema': 'openc.sh27.owned_thread_samples.v1', 'status': 'PROFILE_ONLY',
        'throughput_claim_permitted': False, 'critical_path_claim_permitted': False,
        'weighting': 'one endpoint sample after at least 50000 thread cycles advanced; no cycle-to-time conversion',
        'minimum_cycle_advance': 50000, 'all_profiled_outputs_byte_exact': True,
        'compiler_sha256': sha256(compiler), 'source_map_sha256': proof['source_map_sha256'],
        'script_sha256': sha256(Path(__file__)), 'mapping_proof_sha256': sha256(args.mapping_proof),
        'histogram': dict(totals.most_common()), 'records': records}
    with output.open('x', encoding='utf-8') as retained:
        json.dump(report, retained, indent=2)
        retained.write('\n')
    print(json.dumps({'samples': sum(totals.values()), 'top': totals.most_common(20)}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
