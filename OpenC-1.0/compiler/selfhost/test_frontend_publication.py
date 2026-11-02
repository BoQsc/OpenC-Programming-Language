"""Prove joined frontend preparation, failed commit cleanup, and PE failure cleanup."""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
from pathlib import Path
import shutil
import struct
import tempfile
import traceback

from benchmark_sh27_production import ROOT, MIB, sha256
from benchmark_sh27_representative import DEFAULT_SUITE, load_suite, stage_project
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.frontend_publication.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "builds": {}}
    try:
        parent = ROOT / "build-output"
        parent.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="fp-", dir=parent) as temporary:
            root = Path(temporary)
            workload = next(w for w in load_suite(DEFAULT_SUITE)["workloads"]
                            if w["id"] == "medium_audit")
            project, _ = stage_project(workload, root / "app")
            # Named declarations make the incoming type-prefix order differ
            # as well as symbol/projection order in this unsorted manifest.
            for filename, declaration in (
                ("report.p", b"\nstruct PublicationLayout { i32 value; usize stamp; }\n"),
                ("score.p", b"\nstruct PublicationCode { i16 value; i64 wide; }\n"),
            ):
                target = project.parent / "source" / filename
                target.write_bytes(target.read_bytes() + declaration)
            prefix = root / "cache/objects"
            prefix.parent.mkdir()

            def build(name: str, tool: Path = compiler, selected: Path = project,
                      cached: bool = True, expected: int = 0, bootstrap: bool = False,
                      selected_prefix: Path = prefix) -> dict:
                output = root / (name + ".exe")
                timing = output.with_suffix(".json")
                command = [str(tool), "artifact", f"--project={selected}",
                           "--kind=" + ("cached-exe" if cached else "exe"),
                           "--source-chunks=4", f"--output={output}", f"--timings={timing}"]
                if cached:
                    command += [f"--cache-prefix={selected_prefix}", "--source-partitions=2"]
                if bootstrap:
                    command = [str(tool), "build", f"--project={selected}",
                               f"--output={output}", "--no-cache", f"--timings={timing}"]
                measured = run_measured(command, cwd=project.parent, sample_interval=.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                result = {"command": command, "measurement": measured,
                          "timings": json.loads(timing.read_text()) if timing.is_file() else None,
                          "sha256": sha256(output) if output.is_file() else None}
                report["builds"][name] = result
                assert measured["exit_code"] == expected and not measured["memory_limit_exceeded"] and not measured["timed_out"], result
                assert not measured["stdout_truncated"] and not measured["stderr_truncated"]
                if expected != 0:
                    assert not output.exists(), "failed link left an executable"
                elif not bootstrap:
                    executed = run_measured([str(output)], cwd=project.parent,
                        sample_interval=.01, max_private_bytes=128 * MIB,
                        max_working_set_bytes=64 * MIB,
                        max_captured_output_bytes=MIB, timeout_seconds=30)
                    result["program"] = executed
                    assert executed["exit_code"] == 0 and not executed["memory_limit_exceeded"] and not executed["timed_out"], executed
                    assert not executed["stdout_truncated"] and not executed["stderr_truncated"]
                    assert executed["stdout"] == expected_stdout and executed["stderr"] == "", executed
                return result

            expected_stdout = workload["expected_stdout_utf8"]
            # Keep the complete old projection walk as a same-source oracle.
            # Only the declaration-collection policy differs; code generation,
            # schema, worker layout and every source unit remain identical.
            canonical = ROOT / "compiler/selfhost"
            oracle_root = root / "projection-oracle"
            shutil.copytree(canonical / "source", oracle_root / "source")
            oracle_manifest = json.loads((canonical / "openc.project.json").read_text())
            for key in ("standard_library_directory", "runtime_directory"):
                oracle_manifest[key] = str((canonical / oracle_manifest[key]).resolve())
            oracle_manifest["output_directory"] = "build"
            oracle_project = oracle_root / "openc.project.json"
            oracle_project.write_text(json.dumps(oracle_manifest, indent=2) + "\n")
            target = oracle_root / "source/backend_emit.p"
            code = target.read_text()
            fused = ("native_frontend_predeclare_source(frontend,\n"
                "                            project_source, project_root, module_data, modules,\n"
                "                            source_data, module_index, source_record, type_data,\n"
                "                            types, source, parsed);")
            ordinary = ("semantic_predeclare_parsed_source(project_source, project_root,\n"
                "                            module_data, modules, source_data, module_index, source_record,\n"
                "                            type_data, types, source, parsed.token_data, parsed.tokens,\n"
                "                            parsed.syntax_data, parsed.syntax);\n"
                "                        native_frontend_finish_predeclare(frontend, source_record, source, types, parsed);")
            assert code.count(fused) == 1, "projection oracle policy marker changed"
            target.write_text(code.replace(fused, ordinary), newline="\n")
            oracle = compiler
            oracle_hashes = []
            for generation in (1, 2):
                name = f"projection-oracle{generation}"
                result = build(name, tool=oracle, selected=oracle_project, cached=False, bootstrap=True)
                oracle_hashes.append(result["sha256"])
                oracle = root / (name + ".exe")
            assert oracle_hashes[0] == oracle_hashes[1]
            direct = build("direct", cached=False)
            cold = build("cold")
            assert cold["sha256"] == direct["sha256"]
            assert cold["timings"]["frontend_cache"]["prepare_parallel"] is True
            frontend = Path(str(prefix) + ".frontend")
            oracle_prefix = root / "oracle-cache/objects"
            oracle_prefix.parent.mkdir()
            oracle_result = build("old-projection", tool=oracle, selected_prefix=oracle_prefix)
            old_frontend = Path(str(oracle_prefix) + ".frontend").read_bytes()
            fused_frontend = frontend.read_bytes()
            # The 64-byte compiler identity and enclosing digest legitimately
            # differ. Header, all contribution rows/tables and projection bytes
            # must remain exact, including unsorted source order and named types.
            assert old_frontend[:48] == fused_frontend[:48]
            assert old_frontend[112:-64] == fused_frontend[112:-64]
            assert oracle_result["sha256"] == cold["sha256"] == direct["sha256"]
            report["projection_oracle"] = {"status": "PASS", "compiler_sha256": oracle_hashes[1],
                "contribution_rows_tables_projection_exact": True, "program_bytes_exact": True}
            original = sha256(frontend)
            foreign = prefix.parent / "objects.frontend.tmp.foreign"
            foreign.write_bytes(b"not owned by this compilation\n")

            def clean() -> None:
                assert sorted(p.name for p in prefix.parent.glob("*.tmp.*")) == [foreign.name]
                assert foreign.read_bytes() == b"not owned by this compilation\n"

            clean()
            edited_source = project.parent / workload["edit"]["path"]
            data = edited_source.read_bytes()
            old = workload["edit"]["old"].encode("utf-8")
            assert data.count(old) == 1
            edited_source.write_bytes(data.replace(old, workload["edit"]["new"].encode("utf-8"), 1))
            expected_stdout = workload["edit"]["expected_stdout_utf8"]
            fresh = build("edited-direct", cached=False)
            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
            kernel.CreateFileW.restype = wintypes.HANDLE
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            kernel.CloseHandle.restype = wintypes.BOOL
            handle = kernel.CreateFileW(str(frontend), 0x80000000, 1, None, 3, 128, None)
            assert handle not in (None, ctypes.c_void_p(-1).value), ctypes.get_last_error()
            try:
                locked = build("locked-frontend")
            finally:
                assert kernel.CloseHandle(handle)
            assert locked["sha256"] == fresh["sha256"]
            assert locked["timings"]["object_cache"]["hits"] == 1
            assert locked["timings"]["object_cache"]["misses"] == 1
            assert locked["timings"]["frontend_cache"]["prepare_parallel"] is True
            assert locked["timings"]["frontend_cache"]["publish_failures"] == 1
            assert sha256(frontend) == original
            clean()
            recovered = build("unlocked")
            warm = build("warm")
            assert recovered["sha256"] == warm["sha256"] == fresh["sha256"]
            assert warm["timings"]["object_cache"]["hits"] == 2
            assert warm["timings"]["frontend_cache"]["resolution_hits"] == 4
            assert warm["timings"]["frontend_cache"]["prepare_parallel"] is False
            clean()

            # Source IDs, rather than global symbol IDs, order native groups.
            # This group's two sources are in reverse module/symbol order.
            bundle_path = Path(str(prefix) + ".bundle")
            bundle = bytearray(bundle_path.read_bytes())
            slot = 16 + 136
            offset, length = struct.unpack_from("<II", bundle, slot + 128)
            payload = bundle[offset:offset + length]
            records = []
            cursor = 16
            while cursor < len(payload):
                code, unwind, relocations, constants = struct.unpack_from("<IIII", payload, cursor + 8)
                end = cursor + 24 + code + unwind + relocations * 8 + constants
                assert end <= len(payload)
                records.append(payload[cursor:end])
                cursor = end
            assert cursor == len(payload) and len(records) == 2
            assert struct.unpack_from("<I", records[0])[0] > struct.unpack_from("<I", records[1])[0]
            damaged = payload[:16] + records[1] + records[0]
            bundle[offset:offset + length] = damaged
            bundle[slot + 64:slot + 128] = hashlib.sha256(damaged).hexdigest().encode("ascii")
            bundle_path.write_bytes(bundle)
            reordered = build("authenticated-wrong-source-order")
            assert reordered["sha256"] == fresh["sha256"]
            assert reordered["timings"]["object_cache"]["hits"] == 1
            assert reordered["timings"]["object_cache"]["misses"] == 1
            clean()

            # An owned compiler variant forces PE failure while a real frontend
            # temporary is prepared. Source fallback builds use --no-cache.
            canonical = ROOT / "compiler/selfhost"
            owned = root / "owned"
            shutil.copytree(canonical / "source", owned / "source")
            data = json.loads((canonical / "openc.project.json").read_text())
            for name in ("standard_library_directory", "runtime_directory"):
                data[name] = str((canonical / data[name]).resolve())
            data["output_directory"] = "build"
            owned_project = owned / "openc.project.json"
            owned_project.write_text(json.dumps(data, indent=2) + "\n")
            target = owned / "source/backend_native_object_cache.p"
            code = target.read_text()
            link = ("publication.written = native_write_image_options(\n"
                    "        context, objects, publication.output_path, options);")
            prepare = ("context.type_data, semantic_types, context.symbol_data, context.detail_data, context.symbols);")
            assert code.count(link) == code.count(prepare) == 1
            code = code.replace(link, "publication.written = status{code = 1};")
            code = code.replace(prepare, prepare + '\n    if frontend.pending.claimed { io.println("OPENC-TEST-FRONTEND-PREPARED"); }')
            target.write_text("import system.io;\n" + code)
            current = compiler
            hashes = []
            for generation in range(1, 4):
                name = f"fault{generation}"
                result = build(name, tool=current, selected=owned_project, cached=False, bootstrap=True)
                hashes.append(result["sha256"])
                current = root / (name + ".exe")
            assert hashes[1] == hashes[2]
            report["fault_compiler_fixed_point"] = hashes[2]
            before = sha256(frontend)
            failed = build("failed-link", tool=current, expected=1)
            assert "OPENC-TEST-FRONTEND-PREPARED\n" in failed["measurement"]["stdout"]
            assert failed["timings"]["frontend_cache"]["prepare_parallel"] is True
            assert sha256(frontend) == before, "failed PE link committed frontend state"
            clean()
            final = build("after-failed-link")
            assert final["sha256"] == fresh["sha256"]
            clean()
            report["status"] = "PASS"
    except Exception as error:
        report["error"] = repr(error)
        report["traceback"] = traceback.format_exc()
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report.get(key) for key in ("status", "error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
