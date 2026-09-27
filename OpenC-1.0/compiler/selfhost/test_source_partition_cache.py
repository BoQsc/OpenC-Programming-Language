"""Cold/warm/body/interface cache proof on the actual 228-source compiler.

Usage: python test_source_partition_cache.py COMPILER --report REPORT.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

from windows_process_measure import run_measured

MIB = 1024 * 1024


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def guarded(command: list[str], cwd: Path) -> dict:
    result = run_measured(
        command, cwd=cwd, sample_interval=0.01,
        max_private_bytes=256 * MIB,
        max_working_set_bytes=64 * MIB,
        max_captured_output_bytes=MIB, timeout_seconds=120,
    )
    assert result["exit_code"] == 0 and not result["memory_limit_exceeded"] \
        and not result["timed_out"], result
    return result


def prove_body_flow_flag_invalidation(compiler: Path, compiler_dir: Path) -> dict:
    """A body-local pointer must invalidate otherwise unchanged partitions."""
    with tempfile.TemporaryDirectory(prefix="openc-flow-key-") as temporary:
        root = Path(temporary)
        source_dir = root / "source"
        source_dir.mkdir()
        (source_dir / "a.p").write_text(
            "unsafe i32 main() { return helper(); }\n", encoding="utf-8")
        helper = source_dir / "b.p"
        helper.write_text(
            "unsafe i32 helper() { return 7; }\n", encoding="utf-8")
        (source_dir / "c.p").write_text(
            "i32 other_one() { return 1; }\n", encoding="utf-8")
        (source_dir / "d.p").write_text(
            "i32 other_two() { return 2; }\n", encoding="utf-8")
        project = root / "openc.project.json"
        project.write_text(json.dumps({
            "name": "sh27-flow-key-proof", "version": "1.0.0",
            "edition": "OpenC 1.0", "profile": "standard",
            "target": "windows-x86_64",
            "modules": {"probe": [
                "source/a.p", "source/b.p", "source/c.p", "source/d.p"]},
            "standard_library_directory": str(
                (compiler_dir / "../../standard_library").resolve(strict=True)),
            "runtime_directory": str(
                (compiler_dir / "../../runtime").resolve(strict=True)),
            "output_directory": str(root / "build"),
        }, indent=2) + "\n", encoding="utf-8")
        cache_prefix = root / "cache" / "partition"
        cache_prefix.parent.mkdir()

        def build(name: str) -> dict:
            exe = root / f"{name}.exe"
            timing = root / f"{name}.json"
            guarded([
                str(compiler), "artifact", f"--project={project}",
                "--kind=module-coff-set", f"--output={root / name}",
                f"--linked-exe={exe}", "--source-partitions=4",
                "--source-chunks=4", f"--cache-prefix={cache_prefix}",
                f"--timings={timing}",
            ], root)
            assert exe.is_file()
            return json.loads(timing.read_text())["object_cache"]

        cold = build("cold")
        assert cold["hits"] == 0 and cold["misses"] == 4
        helper.write_text(
            "unsafe i32 helper() { return 8; }\n", encoding="utf-8")
        ordinary_edit = build("ordinary-body-edit")
        assert ordinary_edit["hits"] == 3 and ordinary_edit["misses"] == 1
        assert ordinary_edit["flow_sources_skipped"] == 3
        assert ordinary_edit["acceptance_sources_skipped"] == 3
        helper.write_text(
            "unsafe i32 helper() { ptr byte local = null; "
            "if local == null { return 7; } return 9; }\n",
            encoding="utf-8")
        edited = build("pointer-body-edit")
        assert edited["hits"] == 0 and edited["misses"] == 4, edited
        assert edited["flow_sources_skipped"] == 0
        assert edited["acceptance_sources_skipped"] == 0
        return {"cold": cold, "ordinary_body_edit": ordinary_edit,
                "pointer_body_edit": edited}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--flow4", action="store_true")
    parser.add_argument("--partitions", type=int, default=32)
    args = parser.parse_args()
    assert 2 <= args.partitions <= 32
    compiler = args.compiler.resolve(strict=True)
    compiler_dir = Path(__file__).resolve().parent
    original = compiler_dir / "openc.project.json"
    report: dict = {
        "schema": "openc.sh27.source_partition_cache.v1",
        "status": "FAIL", "compiler_sha256": sha256(compiler),
        "parallel_flow": args.flow4, "partitions": args.partitions,
        "builds": {},
    }
    with tempfile.TemporaryDirectory(prefix="openc-partition-cache-") as temporary:
        root = Path(temporary)
        project_dir = root / "project"
        shutil.copytree(compiler_dir / "source", project_dir / "source")
        project_data = json.loads(original.read_text())
        project_data["standard_library_directory"] = str(
            (compiler_dir / "../../standard_library").resolve(strict=True)
        )
        project_data["runtime_directory"] = str(
            (compiler_dir / "../../runtime").resolve(strict=True)
        )
        project_data["output_directory"] = str(root / "build")
        project = project_dir / "openc.project.json"
        project.write_text(json.dumps(project_data, indent=2) + "\n")
        cache_dir = root / "cache"
        cache_dir.mkdir()
        cache_prefix = cache_dir / "part"

        def build(name: str, cached: bool) -> tuple[dict, dict, Path, dict]:
            prefix = root / name
            exe = root / f"{name}.exe"
            timings = root / f"{name}.json"
            command = [
                str(compiler), "artifact", f"--project={project}",
                "--kind=module-coff-set", f"--output={prefix}",
                f"--linked-exe={exe}",
                f"--source-partitions={args.partitions}",
                f"--source-chunks={4 if cached and args.flow4 else 1}",
                f"--timings={timings}",
            ]
            if cached:
                command.append(f"--cache-prefix={cache_prefix}")
            measurement = guarded(command, root)
            data = json.loads(timings.read_text())
            manifest = json.loads((root / f"{name}.modules.json").read_text())
            assert manifest["status"] == "COMPLETE"
            assert len(manifest["partitions"]) == args.partitions
            report["builds"][name] = {
                "exe_sha256": sha256(exe),
                "cache": data.get("object_cache", {}),
                "compiler_total_ms": data.get("total_ms"),
                "phases_ms": data.get("phases_ms", {}),
                "elapsed_seconds": measurement["elapsed_seconds"],
                "peak_private_bytes": measurement["peak_private_bytes"],
                "peak_working_set_bytes": measurement["peak_working_set_bytes"],
                "objects": [p["sha256"] for p in manifest["partitions"]],
            }
            return data, measurement, exe, manifest

        cold, _, cold_exe, cold_manifest = build("cold", True)
        assert cold["object_cache"]["hits"] == 0
        assert cold["object_cache"]["misses"] == args.partitions
        assert cold["object_cache"]["publish_failures"] == 0
        assert cold["object_cache"]["flow_sources_skipped"] == 0
        assert cold["object_cache"]["acceptance_sources_skipped"] == 0
        warm, _, warm_exe, warm_manifest = build("warm", True)
        assert warm["object_cache"]["hits"] == args.partitions
        assert warm["object_cache"]["misses"] == 0
        assert warm["object_cache"]["validation_skipped"]
        assert sha256(warm_exe) == sha256(cold_exe)
        assert all(p["cache_hit"] for p in warm_manifest["partitions"])
        objects = sorted(cache_dir.glob("part.o.*.obj"))
        assert len(objects) == args.partitions
        objects[0].write_bytes(b"truncated\n")
        corrupt, _, corrupt_exe, _ = build("corrupt-record", True)
        assert corrupt["object_cache"]["hits"] == args.partitions - 1
        assert corrupt["object_cache"]["misses"] == 1
        assert sha256(corrupt_exe) == sha256(cold_exe)

        main_source = project_dir / "source" / "main.p"
        old = main_source.read_bytes()
        original_stat = main_source.stat()
        newline = b"\r\n" if b"\r\n" in old else b"\n"
        old_digit = b"return value >= 48 && value <= 57;"
        new_digit = b"return value > 47 && value < 58;  "
        assert len(new_digit) == len(old_digit)
        assert old.count(old_digit) == 1
        main_source.write_bytes(old.replace(
            old_digit, new_digit, 1
        ))
        os.utime(main_source, ns=(original_stat.st_atime_ns,
            original_stat.st_mtime_ns))
        assert main_source.stat().st_size == original_stat.st_size
        assert main_source.stat().st_mtime_ns == original_stat.st_mtime_ns
        edit, _, edit_exe, edit_manifest = build("body-edit", True)
        assert edit["object_cache"]["hits"] == args.partitions - 1
        assert edit["object_cache"]["misses"] == 1
        assert edit["object_cache"]["flow_sources_skipped"] > 0
        assert edit["object_cache"]["flow_sources_skipped"] == edit[
            "object_cache"]["acceptance_sources_skipped"]
        assert sum(not p["cache_hit"] for p in edit_manifest["partitions"]) == 1
        assert not edit_manifest["partitions"][0]["cache_hit"]
        assert sha256(edit_exe) != sha256(cold_exe)
        _, _, fresh_exe, fresh_manifest = build("body-fresh", False)
        assert sha256(edit_exe) == sha256(fresh_exe)
        assert [p["sha256"] for p in edit_manifest["partitions"]] == [
            p["sha256"] for p in fresh_manifest["partitions"]
        ]

        # A malformed body keeps the project declaration projection stable.
        # The unchanged partitions may be authenticated hits, but the edited
        # source must still be validated with byte-identical diagnostics.
        valid_body = main_source.read_bytes()
        main_source.write_bytes(valid_body.replace(
            b"usize record_stride() {" + newline,
            b"usize record_stride() {" + newline +
                b"    source_partition_unknown = 1;" + newline,
            1,
        ))
        body_failures = []
        for cached in (True, False):
            name = "bad-body-cached" if cached else "bad-body-fresh"
            timing = root / f"{name}.json"
            command = [
                str(compiler), "artifact", f"--project={project}",
                "--kind=module-coff-set", f"--output={root / name}",
                f"--linked-exe={root / (name + '.exe')}",
                f"--source-partitions={args.partitions}",
                f"--source-chunks={4 if cached and args.flow4 else 1}",
                f"--timings={timing}",
            ]
            if cached:
                command.append(f"--cache-prefix={cache_prefix}")
            result = run_measured(
                command, cwd=root, sample_interval=0.01,
                max_private_bytes=256 * MIB,
                max_working_set_bytes=64 * MIB,
                max_captured_output_bytes=MIB, timeout_seconds=120,
            )
            assert result["exit_code"] != 0 and not result["memory_limit_exceeded"] \
                and not result["timed_out"], result
            assert not (root / (name + ".exe")).exists()
            details = json.loads(timing.read_text())
            if cached:
                assert details["object_cache"]["hits"] == args.partitions - 1
                assert details["object_cache"]["misses"] == 1
            body_failures.append((result["stdout"], result["stderr"]))
        assert body_failures[0] == body_failures[1]
        assert body_failures[0][0] or body_failures[0][1]
        report["invalid_body_diagnostics_equal_with_cached_hits"] = True
        main_source.write_bytes(valid_body)

        main_source.write_bytes(main_source.read_bytes() + newline +
            b"i32 source_partition_interface_probe() { return 27; }" + newline)
        interface, _, interface_exe, interface_manifest = build(
            "interface-edit", True
        )
        assert interface["object_cache"]["hits"] == 0
        assert interface["object_cache"]["misses"] == args.partitions
        assert interface["object_cache"]["flow_sources_skipped"] == 0
        assert interface["object_cache"]["acceptance_sources_skipped"] == 0
        assert not any(p["cache_hit"] for p in interface_manifest["partitions"])
        guarded([str(interface_exe), "--version"], root)

        invalid_source = main_source.read_bytes().replace(
            b"usize record_stride() {" + newline,
            b"usize record_stride() {" + newline +
                b"    source_partition_unknown = 1;" + newline,
            1
        )
        main_source.write_bytes(invalid_source)
        failed_results = []
        for cached in (True, False):
            name = "bad-cached" if cached else "bad-fresh"
            command = [
                str(compiler), "artifact", f"--project={project}",
                "--kind=module-coff-set", f"--output={root / name}",
                f"--linked-exe={root / (name + '.exe')}",
                f"--source-partitions={args.partitions}",
                f"--source-chunks={4 if cached and args.flow4 else 1}",
            ]
            if cached:
                command.append(f"--cache-prefix={cache_prefix}")
            result = run_measured(
                command, cwd=root, sample_interval=0.01,
                max_private_bytes=256 * MIB,
                max_working_set_bytes=64 * MIB,
                max_captured_output_bytes=MIB, timeout_seconds=120,
            )
            assert result["exit_code"] != 0 and not result["memory_limit_exceeded"] \
                and not result["timed_out"], result
            assert not (root / (name + ".exe")).exists()
            failed_results.append((result["stdout"], result["stderr"]))
        assert failed_results[0] == failed_results[1]
        assert failed_results[0][0] or failed_results[0][1]
        report["invalid_source_diagnostics_equal"] = True

    report["flow_flag_invalidation"] = prove_body_flow_flag_invalidation(
        compiler, compiler_dir)
    report["status"] = "PASS"
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({
        "status": report["status"],
        "compiler_sha256": report["compiler_sha256"],
        "builds": {name: {
            "cache": value["cache"],
            "compiler_total_ms": value["compiler_total_ms"],
            "phases_ms": value["phases_ms"],
            "elapsed_seconds": value["elapsed_seconds"],
            "peak_private_bytes": value["peak_private_bytes"],
            "peak_working_set_bytes": value["peak_working_set_bytes"],
        } for name, value in report["builds"].items()},
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
