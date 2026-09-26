"""Exercise >65,535 COFF relocations and cached compiler self-host relinking.

Usage: python test_large_coff_selfhost.py COMPILER --report REPORT.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

from windows_process_measure import run_measured

MIB = 1024 * 1024
VERSION = "OpenC 1.0.0\ncompiler: OpenC self-hosted native\n"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def checked_run(command: list[str], cwd: Path, private_mib: int = 256) -> dict:
    result = run_measured(
        command, cwd=cwd, sample_interval=0.01,
        max_private_bytes=private_mib * MIB,
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
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    project = Path(__file__).with_name("openc.project.json").resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="openc-large-coff-") as temporary:
        root = Path(temporary)
        cache = root / "cache"

        def build(name: str) -> tuple[dict, dict, Path]:
            prefix = root / name
            exe = root / f"{name}.exe"
            timings = root / f"{name}.json"
            command = [
                str(compiler), "artifact", f"--project={project}",
                "--kind=module-coff-set", f"--output={prefix}",
                f"--linked-exe={exe}", f"--cache-prefix={cache}",
                "--source-chunks=1", f"--timings={timings}",
            ]
            measurement = checked_run(command, root)
            assert exe.is_file() and timings.is_file()
            return json.loads(timings.read_text()), measurement, exe

        cold, cold_memory, cold_exe = build("cold")
        assert cold["object_cache"]["hits"] == 0
        assert cold["object_cache"]["misses"] == 1
        assert cold["object_cache"]["publish_failures"] == 0
        manifest = json.loads((root / "cold.modules.json").read_text())
        assert manifest["status"] == "COMPLETE" and len(manifest["modules"]) == 1
        obj = Path(manifest["modules"][0]["object"])
        raw = obj.read_bytes()
        assert len(raw) > 8 * MIB and digest(obj) == manifest["modules"][0]["sha256"]

        section = struct.unpack_from("<8sIIIIIIHHI", raw, 20)
        pdata = struct.unpack_from("<8sIIIIIIHHI", raw, 20 + 3 * 40)
        assert section[0].rstrip(b"\0") == b".text"
        assert section[7] == 65535 and section[9] & 0x01000000
        relocation_at = section[5]
        physical, marker_symbol, marker_type = struct.unpack_from(
            "<IIH", raw, relocation_at)
        assert physical > 65536 and marker_symbol == marker_type == 0
        symbol_table_at = struct.unpack_from("<I", raw, 8)[0]
        assert symbol_table_at == relocation_at + physical * 10 + pdata[7] * 10

        warm, warm_memory, warm_exe = build("warm")
        assert warm["object_cache"]["hits"] == 1
        assert warm["object_cache"]["misses"] == 0
        assert warm["object_cache"]["validation_skipped"]
        assert warm["work"]["syntax_nodes"] == warm["work"]["functions"] == 0
        assert cold_exe.read_bytes() == warm_exe.read_bytes()
        fresh_prefix = root / "fresh"
        fresh_exe = root / "fresh.exe"
        fresh_memory = checked_run(
            [str(compiler), "artifact", f"--project={project}",
             "--kind=module-coff-set", f"--output={fresh_prefix}",
             f"--linked-exe={fresh_exe}", "--source-chunks=1"], root)
        fresh_manifest = json.loads((root / "fresh.modules.json").read_text())
        assert fresh_manifest["status"] == "COMPLETE"
        assert fresh_manifest["modules"][0]["sha256"] == digest(obj)
        assert fresh_exe.read_bytes() == warm_exe.read_bytes()
        version = subprocess.run([str(warm_exe), "--version"], cwd=root,
                                 capture_output=True, text=True, timeout=10)
        assert (version.returncode, version.stdout, version.stderr) == (0, VERSION, "")

        # Authentication is not permission to trust malformed COFF metadata.
        forged = bytearray(raw)
        struct.pack_into("<I", forged, relocation_at, physical - 1)
        bad_object = root / "bad.obj"
        bad_object.write_bytes(forged)
        records = list(root.glob("cache.p.*.record"))
        assert len(records) == 1
        entry = records[0].read_bytes()[73:144].decode("ascii")
        bad_exe = root / "bad.exe"
        rejected = subprocess.run(
            [str(compiler), "module-coff-link", f"--entry={entry}",
             f"--output={bad_exe}", f"--object={bad_object}",
             f"--sha256={digest(bad_object)}"], cwd=root,
            capture_output=True, text=True, timeout=30,
        )
        assert rejected.returncode != 0 and "OPENC-COFF-LINK-PARSE" in rejected.stderr
        assert not bad_exe.exists()

        # A compiler linked from its own saved object must still reproduce the
        # ordinary compiler's byte-exact Stage 2/3 fixed point.
        bootstrap = Path(__file__).with_name("bootstrap_sh27_native_parallel.py")
        proved = subprocess.run(
            [sys.executable, str(bootstrap), "--seed", str(warm_exe),
             "--output-dir", str(root / "boot")], cwd=root,
            capture_output=True, text=True, timeout=180,
        )
        assert proved.returncode == 0, proved.stdout + proved.stderr
        stage2 = root / "boot" / "bootstrap-current" / "stage2" / "openc.exe"
        stage3 = root / "boot" / "bootstrap-current" / "stage3" / "openc.exe"
        assert digest(stage2) == digest(stage3) == digest(compiler)
        report = {
            "schema": "openc.sh27.large_coff_selfhost.v1",
            "status": "PASS", "compiler_sha256": digest(compiler),
            "object_sha256": digest(obj), "object_bytes": len(raw),
            "text_relocations": physical - 1,
            "linked_exe_sha256": digest(warm_exe),
            "cold_cache": cold["object_cache"],
            "warm_cache": warm["object_cache"],
            "cold_memory": cold_memory,
            "warm_memory": warm_memory,
            "fresh_memory": fresh_memory,
            "warm_total_ms": warm["total_ms"],
            "fixed_point_sha256": digest(stage3),
        }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("large COFF compiler cache: PASS; overflow, no-op, malformed marker, seeded fixed point")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
