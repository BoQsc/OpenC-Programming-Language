"""Direct-link native-object reuse, ID changes and authenticated corruption."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--ordinary-build", action="store_true")
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.native_object_cache.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "builds": {}}
    report["ordinary_build"] = args.ordinary_build
    try:
        run_parent = ROOT / "build-output"
        run_parent.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="nc-", dir=run_parent) as temporary:
            root = Path(temporary)
            canonical = ROOT / "compiler/selfhost"
            project_dir = root / "project"
            shutil.copytree(canonical / "source", project_dir / "source")
            project_data = json.loads((canonical / "openc.project.json").read_text())
            for name in ("standard_library_directory", "runtime_directory"):
                project_data[name] = str((canonical / project_data[name]).resolve())
            project_data["output_directory"] = "build"
            project = project_dir / "openc.project.json"
            project.write_text(json.dumps(project_data, indent=2) + "\n", encoding="utf-8")
            prefix = root / "cache/objects"
            prefix.parent.mkdir()
            if args.ordinary_build:
                prefix = root / "cached.exe.openc-cache/objects"

            def build(name: str, cached: bool, selected_prefix: Path = prefix) -> dict:
                image = root / (name + ".exe")
                timing = root / (name + ".json")
                command = [str(compiler), "artifact", f"--project={project}",
                           "--kind=" + ("cached-exe" if cached else "exe"),
                           f"--output={image}", f"--timings={timing}", "--source-chunks=4"]
                if cached:
                    command += ["--source-partitions=32", f"--cache-prefix={selected_prefix}"]
                # Cache publication uses distinct output executables. Two
                # builds overwriting one executable have a separate Windows
                # file-sharing race, unrelated to shared cache storage.
                shared_writer = name.startswith("writer-") or name == "after-concurrent-writers"
                if args.ordinary_build and not shared_writer:
                    if cached:
                        image = selected_prefix.parent.with_name(selected_prefix.parent.name.removesuffix(".openc-cache"))
                    command = [str(compiler), "build", f"--project={project}",
                               f"--output={image}", f"--timings={timing}"]
                    if not cached: command.append("--no-cache")
                measured = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                data = json.loads(timing.read_text()) if timing.is_file() else {}
                result = {"measurement": measured, "cache": data.get("object_cache", {}),
                          "frontend": data.get("frontend_cache", {}),
                          "phases_ms": data.get("phases_ms"),
                          "sha256": sha256(image) if image.is_file() else None}
                report["builds"][name] = result
                assert measured["exit_code"] == 0 and not measured["memory_limit_exceeded"] and not measured["timed_out"], result
                assert not measured["stdout_truncated"] and not measured["stderr_truncated"]
                return result

            direct = build("direct", False)
            cold = build("cold", True)
            assert cold["cache"]["hits"] == 0 and cold["cache"]["misses"] == 32
            assert cold["cache"]["publish_failures"] == 0
            warm = build("warm", True)
            assert warm["cache"]["hits"] == 32 and warm["cache"]["misses"] == 0
            assert warm["cache"]["flow_sources_skipped"] == sum(map(len, project_data["modules"].values()))
            assert warm["cache"]["acceptance_sources_skipped"] == warm["cache"]["flow_sources_skipped"]
            assert warm["frontend"]["predeclare_hits"] == warm["cache"]["flow_sources_skipped"], warm
            assert warm["frontend"]["resolution_hits"] == warm["cache"]["flow_sources_skipped"], warm
            assert direct["sha256"] == cold["sha256"] == warm["sha256"] == sha256(compiler)
            bundle_path = Path(str(prefix) + ".bundle")
            original_bundle = bundle_path.read_bytes()
            assert struct.unpack_from("<IIII", original_bundle) == (1112425295, 1, 32,
                sum(map(len, project_data["modules"].values())))
            # Select a group containing both native code and relocations.
            selected = None
            for partition in range(32):
                slot = 16 + partition * 136
                offset, length = struct.unpack_from("<II", original_bundle, slot + 128)
                payload = original_bundle[offset:offset + length]
                assert hashlib.sha256(payload).hexdigest().encode() == original_bundle[slot + 64:slot + 128]
                if len(payload) > 40:
                    code, unwind, relocations = struct.unpack_from("<III", payload, 24)
                    if relocations:
                        selected = partition, payload, code, unwind
                        break
            assert selected
            selected_partition, payload, code, unwind = selected

            def forge(name: str, damaged: bytes) -> None:
                header = bytearray(original_bundle[:16 + 32 * 136])
                objects = bytearray()
                for partition in range(32):
                    slot = 16 + partition * 136
                    offset, length = struct.unpack_from("<II", original_bundle, slot + 128)
                    unit = damaged if partition == selected_partition else original_bundle[offset:offset + length]
                    header[slot + 64:slot + 128] = hashlib.sha256(unit).hexdigest().encode()
                    struct.pack_into("<II", header, slot + 128, len(header) + len(objects), len(unit))
                    objects.extend(unit)
                bundle_path.write_bytes(header + objects)
                recovered = build(name, True)
                assert recovered["cache"]["hits"] == 31 and recovered["cache"]["misses"] == 1
                assert recovered["sha256"] == direct["sha256"]

            bad_magic = bytearray(payload)
            bad_magic[0] ^= 1
            forge("bad-magic", bad_magic)
            wrong_group = bytearray(payload)
            struct.pack_into("<I", wrong_group, 8, 0xFFFFFFFF)
            forge("wrong-source-group", wrong_group)
            invalid_symbol = bytearray(payload)
            struct.pack_into("<I", invalid_symbol, 16, 0xFFFFFFFF)
            forge("invalid-function-symbol", invalid_symbol)
            invalid_relocation = bytearray(payload)
            struct.pack_into("<I", invalid_relocation, 16 + 24 + code + unwind, code - 3)
            forge("invalid-relocation", invalid_relocation)
            forge("truncated", payload[:-1])
            bad_version = bytearray(original_bundle)
            struct.pack_into("<I", bad_version, 4, 0xFFFFFFFF)
            bundle_path.write_bytes(bad_version)
            version = build("cache-version-change", True)
            assert version["cache"]["hits"] == 0 and version["cache"]["misses"] == 32
            assert version["sha256"] == direct["sha256"]

            frontend_path = Path(str(prefix) + ".frontend")
            frontend_bytes = frontend_path.read_bytes()
            assert hashlib.sha256(frontend_bytes[:-64]).hexdigest().encode() == frontend_bytes[-64:]

            def damage_frontend(name: str, offset: int, value: int, rehash: bool = True) -> None:
                damaged = bytearray(frontend_bytes)
                struct.pack_into("<I", damaged, offset, value)
                if rehash:
                    damaged[-64:] = hashlib.sha256(damaged[:-64]).hexdigest().encode()
                frontend_path.write_bytes(damaged)
                rebuilt = build(name, True)
                assert rebuilt["frontend"]["predeclare_hits"] == 0, rebuilt
                assert rebuilt["frontend"]["resolution_hits"] == 0, rebuilt
                assert rebuilt["cache"]["hits"] == 32
                assert rebuilt["sha256"] == direct["sha256"]

            damage_frontend("frontend-checksum", 0, 0, False)
            damage_frontend("frontend-version", 4, 0xFFFFFFFF)
            damage_frontend("frontend-extent", 24, 0)
            symbol_offset = struct.unpack_from("<I", frontend_bytes, 28)[0]
            detail_offset = struct.unpack_from("<I", frontend_bytes, 32)[0]
            damage_frontend("frontend-symbol-kind", symbol_offset, 0xFFFFFFFF)
            damage_frontend("frontend-symbol-span", symbol_offset + 16, 0xFFFFFFFF)
            damage_frontend("frontend-symbol-owner", detail_offset + 16, 0xFFFFFFFF)
            type_offset = struct.unpack_from("<I", frontend_bytes, 24)[0]
            # The builtin byte pointer is type 18 and must reference an
            # earlier type. A SHA-valid self-cycle cannot enter the resolver.
            damage_frontend("frontend-type-cycle", type_offset + 18 * 40 + 8, 18)
            with frontend_path.open("wb") as oversized:
                oversized.truncate(8 * MIB + 1)
            oversize = build("frontend-oversize", True)
            assert oversize["frontend"]["predeclare_hits"] == 0
            assert oversize["cache"]["hits"] == 32 and oversize["sha256"] == direct["sha256"]

            main = project_dir / "source/main.p"
            original = main.read_bytes()
            old_digit = b"return value >= 48 && value <= 57;"
            new_digit = b"return value > 47 && value < 58;  "
            assert len(old_digit) == len(new_digit) and original.count(old_digit) == 1
            initial_stat = main.stat()
            main.write_bytes(original.replace(old_digit, new_digit, 1))
            os.utime(main, ns=(initial_stat.st_atime_ns, initial_stat.st_mtime_ns))
            body = build("body-edit", True)
            fresh_body = build("body-fresh", False)
            assert body["cache"]["hits"] == 31 and body["cache"]["misses"] == 1
            assert body["cache"]["flow_sources_skipped"] > 0
            assert body["frontend"]["predeclare_hits"] == sum(map(len, project_data["modules"].values())) - 1
            assert body["frontend"]["resolution_hits"] == body["frontend"]["predeclare_hits"]
            assert body["sha256"] == fresh_body["sha256"] != cold["sha256"]
            # A longer body with no new symbols keeps old function numbering.
            main.write_bytes(original.replace(old_digit, old_digit + b" /* body length */", 1))
            length_edit = build("body-length-edit", True)
            fresh_length = build("body-length-fresh", False)
            assert length_edit["cache"]["hits"] == 31 and length_edit["cache"]["misses"] == 1
            assert length_edit["sha256"] == fresh_length["sha256"]
            # Local declarations can move later global symbol IDs even though
            # the old declaration-only projection is unchanged.
            main.write_bytes(original.replace(old_digit,
                b"usize sh27_new_local = 0; " + old_digit, 1))
            numbering = build("local-id-change", True)
            numbering_fresh = build("local-id-fresh", False)
            assert numbering["cache"]["hits"] == 0 and numbering["cache"]["misses"] == 32
            assert numbering["sha256"] == numbering_fresh["sha256"]
            main.write_bytes(original + b"\ni32 sh27_new_api() { return 0; }\n")
            interface = build("interface-edit", True)
            fresh_interface = build("interface-fresh", False)
            assert interface["cache"]["hits"] == 0 and interface["sha256"] == fresh_interface["sha256"]

            main.write_bytes(original)
            block = root / "blocked"
            block.write_text("not a directory\n")
            blocked_prefix = block / "objects"
            if args.ordinary_build:
                blocked_image = root / "blocked-image.exe"
                blocked_prefix = root / "blocked-image.exe.openc-cache/objects"
                blocked_prefix.parent.write_text("not a directory\n")
            unavailable = build("unavailable-storage", True, blocked_prefix)
            assert unavailable["cache"]["publish_failures"] == 32
            assert unavailable["sha256"] == direct["sha256"]
            # A changed invalid body must be diagnosed before publication.
            main.write_bytes(original.replace(old_digit, b"return sh27_missing_name;", 1))
            diagnostics = []
            before = {p.name: sha256(p) for p in prefix.parent.iterdir() if p.is_file()}
            for cached in (False, True):
                output = root / ("invalid-cache.exe" if cached else "invalid-direct.exe")
                command = [str(compiler), "artifact", f"--project={project}",
                           "--kind=" + ("cached-exe" if cached else "exe"),
                           f"--output={output}", "--source-chunks=4"]
                if cached: command += ["--source-partitions=32", f"--cache-prefix={prefix}"]
                if args.ordinary_build:
                    if cached: output = root / "cached.exe"
                    if output.exists(): output.unlink()
                    command = [str(compiler), "build", f"--project={project}", f"--output={output}"]
                    if not cached: command.append("--no-cache")
                measured = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                assert measured["exit_code"] != 0 and not measured["memory_limit_exceeded"] and not output.exists()
                normalized = "\n".join(line for line in measured["stdout"].splitlines()
                                       if not line.startswith("OpenC Windows artifact:"))
                diagnostics.append((measured["exit_code"], normalized, measured["stderr"]))
            assert diagnostics[0] == diagnostics[1]
            assert before == {p.name: sha256(p) for p in prefix.parent.iterdir() if p.is_file()}
            main.write_bytes(original)
            race_prefix = root / "race/objects"
            if args.ordinary_build: race_prefix = root / "race.exe.openc-cache/objects"
            race_prefix.parent.mkdir()
            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(build, f"writer-{i}", True, race_prefix) for i in range(2)]
                results = [f.result() for f in futures]
            assert all(r["sha256"] == direct["sha256"] for r in results)
            recovered = build("after-concurrent-writers", True, race_prefix)
            assert recovered["cache"]["hits"] == 32 and recovered["sha256"] == direct["sha256"]
            report["status"] = "PASS"
    except Exception as error:
        report["error"] = str(error)
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "error": report.get("error"),
                      "completed_builds": len(report["builds"])}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
