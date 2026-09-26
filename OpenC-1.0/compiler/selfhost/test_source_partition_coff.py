"""Prove source-group COFF objects for the actual self-host compiler.

Usage: python test_source_partition_coff.py COMPILER --report REPORT.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import tempfile

from windows_process_measure import run_measured

MIB = 1024 * 1024
VERSION = "OpenC 1.0.0\ncompiler: OpenC self-hosted native\n"


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
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    project = Path(__file__).with_name("openc.project.json").resolve(strict=True)
    report: dict = {
        "schema": "openc.sh27.source_partition_coff.v1",
        "status": "FAIL", "compiler_sha256": sha256(compiler), "variants": {},
    }
    with tempfile.TemporaryDirectory(prefix="openc-source-coff-") as temporary:
        root = Path(temporary)
        for count in (2, 8, 32):
            prefix = root / f"part{count}"
            exe = root / f"part{count}.exe"
            command = [
                str(compiler), "artifact", f"--project={project}",
                "--kind=module-coff-set", f"--output={prefix}",
                f"--linked-exe={exe}", f"--source-partitions={count}",
                "--source-chunks=1",
            ]
            measurement = guarded(command, root)
            manifest = json.loads((root / f"part{count}.modules.json").read_text())
            assert manifest["status"] == "COMPLETE"
            assert manifest["schema"] == "openc.source_partition_coff_set.v1"
            pieces = manifest["partitions"]
            assert len(pieces) == count, (count, len(pieces))
            assert pieces[0]["source_first"] == 0
            assert pieces[-1]["source_end"] == 228
            assert all(
                left["source_end"] == right["source_first"]
                for left, right in zip(pieces, pieces[1:])
            )
            assert all(
                Path(piece["object"]).is_file() and
                sha256(Path(piece["object"])) == piece["sha256"] and
                piece["functions"] > 0
                for piece in pieces
            )
            assert exe.is_file()
            version = guarded([str(exe), "--version"], root)
            assert version["stdout"] == VERSION and version["stderr"] == "", version
            report["variants"][str(count)] = {
                "linked_exe_sha256": sha256(exe),
                "object_count": len(pieces),
                "total_object_bytes": sum(Path(p["object"]).stat().st_size for p in pieces),
                "total_functions": sum(p["functions"] for p in pieces),
                "compile_peak_private_bytes": measurement["peak_private_bytes"],
                "compile_peak_working_set_bytes": measurement["peak_working_set_bytes"],
            }
        # Every object boundary adds COFF/PE padding. Different partition
        # counts need not produce identical image bytes; each count must be
        # deterministic and self-host correctly instead.
        repeated = root / "part32-repeat.exe"
        guarded([
            str(compiler), "artifact", f"--project={project}",
            "--kind=module-coff-set", f"--output={root / 'part32-repeat'}",
            f"--linked-exe={repeated}", "--source-partitions=32",
            "--source-chunks=1",
        ], root)
        assert sha256(repeated) == report["variants"]["32"]["linked_exe_sha256"]
        linked = root / "part32.exe"
        rebuilt = root / "rebuilt.exe"
        rebuilt_memory = guarded([
            str(linked), "build", f"--project={project}", f"--output={rebuilt}"
        ], root)
        assert sha256(rebuilt) == sha256(compiler)
        report["seeded_fixed_point_sha256"] = sha256(rebuilt)
        report["seeded_peak_private_bytes"] = rebuilt_memory["peak_private_bytes"]
        report["seeded_peak_working_set_bytes"] = rebuilt_memory["peak_working_set_bytes"]
    report["status"] = "PASS"
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
