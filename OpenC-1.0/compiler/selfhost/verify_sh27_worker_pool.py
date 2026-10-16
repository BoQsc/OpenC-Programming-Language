#!/usr/bin/env python3
"""Owned-binary fault injection for bounded compiler threadpool setup.

Copies only the explicitly selected compiler, never modifies it. Missing API
names and skipped creation calls force pre-submission fallback. Code patches
replace a register load/indirect call with XOR EAX,EAX and NOPs: no allocator
is called for the injected failure. Existing unsubmitted work must be closed
by the normal cleanup path. No DLL hooking or system changes are used.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

from benchmark_sh27_production import ROOT, MIB, require_disk_headroom, sha256
from verify_sh27_array_initializers import guarded
from windows_process_measure import run_measured


APIS = ("CreateThreadpoolWork", "SubmitThreadpoolWork",
        "WaitForThreadpoolWorkCallbacks", "CloseThreadpoolWork")
PHASES = {"parse": ("resolution_parse_sources_parallel", 3),
          "flow": ("flow_validate_project_parallel", 4),
          "native": ("c_emit_native_sources_chunked", 4)}
CREATE_CALL = bytes.fromhex("4c8b9c24c005000041ffd3")


def patch_locations(data: bytes) -> tuple[dict[str, tuple[int, int, int, int]], dict[str, list[int]], dict[str, str]]:
    if data[:2] != b"MZ":
        raise ValueError("not a PE image")
    pe = struct.unpack_from("<I", data, 60)[0]
    if data[pe:pe + 4] != b"PE\0\0" or struct.unpack_from("<H", data, pe + 4)[0] != 0x8664:
        raise ValueError("requires a native Windows x64 PE image")
    optional = pe + 24
    if struct.unpack_from("<H", data, optional)[0] != 0x20B:
        raise ValueError("requires PE32+")
    table = optional + struct.unpack_from("<H", data, pe + 20)[0]
    sections = {}
    for n in range(struct.unpack_from("<H", data, pe + 6)[0]):
        at = table + n * 40
        name = data[at:at + 8].rstrip(b"\0").decode("ascii")
        section = struct.unpack_from("<IIII", data, at + 8)
        if section[3] + section[2] > len(data):
            raise ValueError("section outside file")
        sections[name] = section
    size, _, _, raw = sections[".pdata"]
    if size % 12:
        raise ValueError("invalid unwind table")
    ranges = [struct.unpack_from("<III", data, raw + at)[:2] for at in range(0, size, 12)]
    if any(a >= b for a, b in ranges) or any(a[1] > b[0] for a, b in zip(ranges, ranges[1:])):
        raise ValueError("unordered native function table")
    root = ROOT / "compiler/selfhost"
    manifest = json.loads((root / "openc.project.json").read_text(encoding="utf-8"))
    names = []
    hashes = {}
    for filename in manifest["modules"]["openc.selfhost.main"]:
        source = (root / filename).read_bytes()
        hashes[filename] = hashlib.sha256(source).hexdigest()
        names.extend(m.group(1) for m in re.finditer(
            r"(?m)^(?:unsafe\s+)?(?:[A-Za-z_]\w*(?:\s+\w+)?)\s+([A-Za-z_]\w*)\s*\(",
            source.decode("utf-8")))
    if len(names) + 3 != len(ranges) or names[:2] != ["source_without_initial_bom", "record_stride"]:
        raise ValueError("compiler/current source map mismatch")
    _, text_rva, text_size, text_raw = sections[".text"]
    matches = {}
    for phase, (name, expected) in PHASES.items():
        if names.count(name) != 1:
            raise ValueError("ambiguous phase function")
        start, end = ranges[names.index(name) + 3]
        if start < text_rva or end > text_rva + text_size:
            raise ValueError("phase outside .text")
        offset = text_raw + start - text_rva
        code = data[offset:offset + end - start]
        locations = [offset + m.start() for m in re.finditer(re.escape(CREATE_CALL), code)]
        if len(locations) != expected:
            raise ValueError(f"unexpected work-creation sites for {phase}")
        # Flow/native have an earlier one-work-item two-worker branch. Tests
        # explicitly request four chunks and target the following three sites.
        matches[phase] = locations
    return sections, matches, hashes


def measured(command: list[str]) -> dict[str, object]:
    sample = run_measured(command, cwd=ROOT, sample_interval=.01,
        max_private_bytes=256 * MIB, max_working_set_bytes=128 * MIB,
        max_captured_output_bytes=2 * MIB, timeout_seconds=60)
    sample["command"] = command
    return sample


def build(compiler: Path, project: Path, directory: Path, chunks: str) -> dict[str, object]:
    directory.mkdir()
    binary = directory / "program.exe"
    timing = directory / "timings.json"
    sample = measured([str(compiler), "artifact", f"--project={project}",
        "--kind=exe", f"--source-chunks={chunks}", f"--output={binary}", f"--timings={timing}"])
    return {"measurement": sample, "binary": str(binary),
        "binary_sha256": sha256(binary) if binary.is_file() else None,
        "timings": json.loads(timing.read_text(encoding="utf-8")) if timing.is_file() else None}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error("refusing to replace an existing report")
    require_disk_headroom(output.parent)
    if compiler.stat().st_size > 16 * MIB:
        parser.error("compiler image exceeds fault-test budget")
    data = compiler.read_bytes()
    sections, sites, source_hashes = patch_locations(data)
    runs = output.parent / (output.stem + "-runs")
    runs.mkdir(parents=True, exist_ok=False)
    projects = {}
    for profile, count, padding in (("parse-flow2", 4, 50000), ("flow4", 32, 33000)):
        projects[profile] = {}
        for invalid in (False, True):
            directory = runs / (profile + ("-invalid" if invalid else "-valid"))
            directory.mkdir()
            for index in range(count):
                source = 'import system.io;\n' if index == 0 else ""
                if index == 0:
                    source += "struct Pair { i32 value; i32 spare; }\n"
                    source += ('unsafe i32 main() { Pair value = Pair{ value = 10, spare = 0 }; '
                        'if read0(value) + read1(value) + read2(value) + read3(value) != 46 { return 1; } '
                        'io.println("pool-ok"); return 0; }\n')
                expression = "true" if invalid and index == count - 1 else str(index)
                source += f"unsafe i32 read{index}(ref Pair value) {{ return value.value + {expression}; }}\n"
                source += "//" + "x" * padding + "\n"
                (directory / f"source{index}.p").write_text(source, encoding="utf-8")
            project = directory / "openc.project.json"
            project.write_text(json.dumps({"name": "pool-fault-oracle", "version": "1.0.0",
                "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
                "modules": {"pool.oracle": [f"source{i}.p" for i in range(count)]}, "output_directory": "build"}), encoding="utf-8")
            projects[profile][invalid] = project
    controls = {}
    for profile, pair in projects.items():
        controls[profile] = {
            "serial": build(compiler, pair[False], runs / (profile + "-serial"), "1"),
            "parallel": build(compiler, pair[False], runs / (profile + "-parallel"), "4"),
            "invalid": build(compiler, pair[True], runs / (profile + "-invalid-control"), "4")}
    variants = {}
    _, _, raw_size, raw = sections[".rdata"]
    for name in APIS:
        encoded = name.encode("ascii") + b"\0"
        positions = [raw + m.start() for m in re.finditer(re.escape(encoded), data[raw:raw + raw_size])]
        if not positions:
            raise ValueError("expected dynamic API name absent")
        patched = bytearray(data)
        for at in positions:
            patched[at] = ord("Z")
        variants["missing-" + name] = (patched, {"rdata_name_offsets": positions},
            ("parse-flow2", "flow4"), "4")
    tests = [("parse", sites["parse"], "parse-flow2", "4"),
             ("flow-two", sites["flow"][:1], "parse-flow2", "4"),
             ("flow-four", sites["flow"][1:], "flow4", "4"),
             ("native-four", sites["native"][1:], "parse-flow2", "4"),
             ("native-two", sites["native"][:1], "parse-flow2", "2")]
    for phase, locations, profile, chunks in tests:
        for index, at in enumerate(locations):
            patched = bytearray(data)
            replacement = b"\x31\xc0" + b"\x90" * (len(CREATE_CALL) - 2)
            patched[at:at + len(CREATE_CALL)] = replacement
            variants[f"{phase}-create-{index + 1}"] = (patched,
                {"phase": phase, "creation_ordinal": index + 1, "file_offset": at,
                 "original_hex": CREATE_CALL.hex(), "replacement_hex": replacement.hex()}, (profile,), chunks)
    results = {}
    for name, (patched, mutation, profiles, chunks) in variants.items():
        test_compiler = runs / (name + ".exe")
        with test_compiler.open("xb") as binary_copy:
            binary_copy.write(patched)
        profile_results = {}
        for profile in profiles:
            control = controls[profile]
            expected_hash = control["serial"]["binary_sha256"]
            invalid_measure = control["invalid"]["measurement"]
            invalid_diagnostic = (invalid_measure["exit_code"], invalid_measure["stdout"], invalid_measure["stderr"])
            valid = build(test_compiler, projects[profile][False], runs / (name + "-" + profile + "-valid"), chunks)
            invalid = build(test_compiler, projects[profile][True], runs / (name + "-" + profile + "-invalid"), chunks)
            execution = measured([valid["binary"]]) if valid["binary_sha256"] else None
            vm, im = valid["measurement"], invalid["measurement"]
            timing = valid["timings"] or {}
            expected_fallback = True
            if name.startswith("missing-") or name.startswith("flow-"):
              expected_fallback = timing.get("flow_threads_launched") is False
            if name.startswith("missing-") or name.startswith("native-"):
              expected_fallback = expected_fallback and timing.get("native_parallel_profile", {}).get("launch_completed") is False
            passed = bool(guarded(vm) and vm["exit_code"] == 0 and valid["binary_sha256"] == expected_hash and
                guarded(im) and im["exit_code"] != 0 and invalid["binary_sha256"] is None and
                (im["exit_code"], im["stdout"], im["stderr"]) == invalid_diagnostic and expected_fallback and
                execution is not None and guarded(execution) and execution["exit_code"] == 0 and
                execution["stdout"] == "pool-ok\n" and execution["stderr"] == "")
            profile_results[profile] = {"valid": valid, "invalid": invalid, "execution": execution,
                "expected_fallback_observed": expected_fallback, "passed": passed}
        results[name] = {"mutation": mutation, "compiler_sha256": sha256(test_compiler),
            "profiles": profile_results, "passed": all(r["passed"] for r in profile_results.values())}
        print(f"worker setup {name}: {results[name]['passed']}", flush=True)
    checks = {"controls_build_with_exact_bytes": all(c["serial"]["binary_sha256"] is not None and
            c["parallel"]["binary_sha256"] == c["serial"]["binary_sha256"] and all(
                guarded(c[key]["measurement"]) and c[key]["measurement"]["exit_code"] == 0
                for key in ("serial", "parallel")) for c in controls.values()),
        "normal_four_chunk_and_two_four_flow_launches_completed": all(
            c["parallel"]["timings"]["parallel_source_chunks"] == 4 and
            c["parallel"]["timings"]["parallel_flow_workers"] == (2 if profile == "parse-flow2" else 4) and
            c["parallel"]["timings"]["native_parallel_profile"]["launch_completed"] is True and
            c["parallel"]["timings"]["flow_threads_launched"] is True for profile, c in controls.items()),
        "invalid_controls_reject": all(guarded(c["invalid"]["measurement"]) and
            c["invalid"]["measurement"]["exit_code"] != 0 and c["invalid"]["binary_sha256"] is None and
            "SEMANTIC_ERROR" in c["invalid"]["measurement"]["stdout"] for c in controls.values()),
        "all_fifteen_fault_variants_pass": len(results) == 15 and all(r["passed"] for r in results.values())}
    report = {"schema": "openc.sh27.worker_pool_faults.v1", "status": "PASS" if all(checks.values()) else "FAIL",
        "compiler": {"path": str(compiler), "sha256": sha256(compiler)},
        "script_sha256": sha256(Path(__file__)), "source_map_sha256": source_hashes,
        "checks": checks, "controls": controls, "faults": results}
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SH-27 worker pool faults: {report['status']}; report={output}")
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
