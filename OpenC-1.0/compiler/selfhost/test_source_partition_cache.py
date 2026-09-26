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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--flow4", action="store_true")
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    compiler_dir = Path(__file__).resolve().parent
    original = compiler_dir / "openc.project.json"
    report: dict = {
        "schema": "openc.sh27.source_partition_cache.v1",
        "status": "FAIL", "compiler_sha256": sha256(compiler),
        "parallel_flow": args.flow4, "builds": {},
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
                f"--linked-exe={exe}", "--source-partitions=32",
                f"--source-chunks={4 if cached and args.flow4 else 1}",
                f"--timings={timings}",
            ]
            if cached:
                command.append(f"--cache-prefix={cache_prefix}")
            measurement = guarded(command, root)
            data = json.loads(timings.read_text())
            manifest = json.loads((root / f"{name}.modules.json").read_text())
            assert manifest["status"] == "COMPLETE"
            assert len(manifest["partitions"]) == 32
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
        assert cold["object_cache"]["misses"] == 32
        assert cold["object_cache"]["publish_failures"] == 0
        warm, _, warm_exe, warm_manifest = build("warm", True)
        assert warm["object_cache"]["hits"] == 32
        assert warm["object_cache"]["misses"] == 0
        assert sha256(warm_exe) == sha256(cold_exe)
        assert all(p["cache_hit"] for p in warm_manifest["partitions"])
        records = sorted(cache_dir.glob("part.k.*.record"))
        assert len(records) == 32
        records[0].write_bytes(b"truncated\n")
        corrupt, _, corrupt_exe, _ = build("corrupt-record", True)
        assert corrupt["object_cache"]["hits"] == 31
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
        assert edit["object_cache"]["hits"] == 31
        assert edit["object_cache"]["misses"] == 1
        assert sum(not p["cache_hit"] for p in edit_manifest["partitions"]) == 1
        assert not edit_manifest["partitions"][0]["cache_hit"]
        assert sha256(edit_exe) != sha256(cold_exe)
        _, _, fresh_exe, fresh_manifest = build("body-fresh", False)
        assert sha256(edit_exe) == sha256(fresh_exe)
        assert [p["sha256"] for p in edit_manifest["partitions"]] == [
            p["sha256"] for p in fresh_manifest["partitions"]
        ]

        main_source.write_bytes(main_source.read_bytes() + newline +
            b"// Source-partition declaration projection edit proof." + newline)
        interface, _, interface_exe, interface_manifest = build(
            "interface-edit", True
        )
        assert interface["object_cache"]["hits"] == 0
        assert interface["object_cache"]["misses"] == 32
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
                "--source-partitions=32",
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
