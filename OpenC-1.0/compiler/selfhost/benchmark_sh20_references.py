#!/usr/bin/env python3
"""Pin SH-20 same-host OpenC, optimized ISO C, and D compiler references."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tarfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from windows_process_measure import run_measured


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "openc.sh20_compiler_references.v1"
MIB = 1024 * 1024


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summary_values(values: list[float]) -> dict[str, object]:
    return {
        "runs": len(values),
        "minimum_seconds": round(min(values), 3),
        "median_seconds": round(statistics.median(values), 3),
        "maximum_seconds": round(max(values), 3),
        "raw_seconds": values,
    }


def summary(samples: list[dict[str, object]]) -> dict[str, object]:
    return summary_values([float(sample["elapsed_seconds"]) for sample in samples])


def tool_record(path: Path, version_arguments: list[str]) -> dict[str, object]:
    completed = subprocess.run(
        [str(path), *version_arguments],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return {
        "path": str(path),
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "version_command": [str(path), *version_arguments],
        "version_exit_code": completed.returncode,
        "version_output": (completed.stdout + completed.stderr).strip(),
    }


def tree_fingerprint(paths: list[Path]) -> dict[str, object]:
    records: list[dict[str, object]] = []
    digest = hashlib.sha256()
    for path in sorted({item.resolve() for item in paths}, key=lambda item: str(item).lower()):
        try:
            label = path.relative_to(ROOT).as_posix()
        except ValueError:
            label = str(path)
        value = sha256(path)
        records.append({"path": label, "bytes": path.stat().st_size, "sha256": value})
        digest.update(label.encode("utf-8"))
        digest.update(b"\0")
        digest.update(value.encode("ascii"))
        digest.update(b"\n")
    return {
        "sha256": digest.hexdigest(),
        "files": len(records),
        "bytes": sum(int(record["bytes"]) for record in records),
        "records": records,
    }


def measured(command: list[str], cwd: Path, sample_interval: float) -> dict[str, object]:
    return run_measured(
        command,
        cwd=cwd,
        sample_interval=sample_interval,
        max_private_bytes=256 * MIB,
        max_working_set_bytes=256 * MIB,
        max_captured_output_bytes=4 * MIB,
    )


def sample_passed(sample: dict[str, object]) -> bool:
    return (
        int(sample["exit_code"]) == 0
        and not bool(sample["memory_limit_exceeded"])
        and not bool(sample["stdout_truncated"])
        and not bool(sample["stderr_truncated"])
    )


def main() -> int:
    if os.name != "nt":
        raise SystemExit("the SH-20 comparator currently requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--openc-stability", type=Path, required=True)
    parser.add_argument(
        "--clang", type=Path, default=Path(r"C:\SysGCC\mingw64\bin\clang.exe")
    )
    parser.add_argument(
        "--tinycc-source",
        type=Path,
        default=ROOT / "third_party" / "tinycc-win64" / "source" / "tcc-0.9.27.tar.bz2",
    )
    parser.add_argument(
        "--dub", type=Path, default=Path(r"C:\D\dmd2\windows\bin64\dub.exe")
    )
    parser.add_argument(
        "--dmd", type=Path, default=Path(r"C:\D\dmd2\windows\bin64\dmd.exe")
    )
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--sample-interval", type=float, default=0.05)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh20" / "compiler-references.json",
    )
    parser.add_argument("--enforce", action="store_true")
    args = parser.parse_args()
    if args.runs < 5 or args.sample_interval <= 0:
        raise SystemExit("--runs must be at least five and the sample interval positive")

    stability_path = args.openc_stability.resolve()
    clang = args.clang.resolve()
    tinycc_source = args.tinycc_source.resolve()
    dub = args.dub.resolve()
    dmd = args.dmd.resolve()
    output = args.output.resolve()
    for required in (stability_path, clang, tinycc_source, dub, dmd):
        if not required.is_file():
            raise SystemExit(f"missing required input: {required}")

    stability = json.loads(stability_path.read_text(encoding="utf-8"))
    if stability.get("schema") != "openc.sh20_native_stability.v1":
        raise SystemExit(f"incompatible OpenC stability report: {stability_path}")
    open_samples = list(stability["lanes"]["native_chain"]["samples"][: args.runs])
    if len(open_samples) != args.runs:
        raise SystemExit("OpenC stability report has too few public-chain samples")

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_root = output.parent / f"{output.stem}-runs-{stamp}"
    run_root.mkdir(parents=True, exist_ok=False)
    c_samples: list[dict[str, object]] = []
    d_samples: list[dict[str, object]] = []

    for run in range(args.runs):
        c_root = run_root / f"c-{run + 1:02d}"
        c_root.mkdir(parents=True, exist_ok=False)
        with tarfile.open(tinycc_source, "r:bz2") as archive:
            archive.extractall(c_root, filter="data")
        source_root = c_root / "tcc-0.9.27"
        (source_root / "config.h").write_text(
            '#define TCC_VERSION "0.9.27"\n'
            '#ifdef TCC_TARGET_X86_64\n'
            '#define TCC_LIBTCC1 "libtcc1-64.a"\n'
            '#else\n'
            '#define TCC_LIBTCC1 "libtcc1-32.a"\n'
            '#endif\n',
            encoding="ascii",
            newline="\n",
        )
        c_output = c_root / "tcc.exe"
        c_command = [
            str(clang),
            "-O2",
            "-o",
            str(c_output),
            r"..\tcc.c",
            "-DTCC_TARGET_PE",
            "-DTCC_TARGET_X86_64",
            "-DONE_SOURCE=1",
        ]
        c_sample = measured(c_command, source_root / "win32", args.sample_interval)
        c_sample |= {
            "run": run + 1,
            "command": c_command,
            "output_sha256": sha256(c_output) if c_output.is_file() else None,
        }
        c_samples.append(c_sample)
        print(f"optimized ISO C reference: {run + 1}/{args.runs}", flush=True)
        if not sample_passed(c_sample):
            break

        d_command = [
            str(dub),
            "build",
            f"--root={ROOT / 'compiler'}",
            "--config=compiler",
            "--build=release",
            "--temp-build",
            "--force",
            "--non-interactive",
        ]
        d_sample = measured(d_command, ROOT, args.sample_interval)
        d_sample |= {"run": run + 1, "command": d_command}
        d_samples.append(d_sample)
        print(f"D reference: {run + 1}/{args.runs}", flush=True)
        if not sample_passed(d_sample):
            break

    open_summary = summary(open_samples)
    validation_summary = summary_values(
        [float(sample["timings"]["phases_ms"]["validation"]) / 1000.0 for sample in open_samples]
    )
    c_summary = summary(c_samples)
    d_summary = summary(d_samples)
    open_median = float(open_summary["median_seconds"])
    c_median = float(c_summary["median_seconds"])
    d_median = float(d_summary["median_seconds"])
    slower_reference = max(c_median, d_median)
    open_hashes = {sample.get("output_sha256") for sample in open_samples}
    expected_open_hash = stability["inputs"]["compiler_sha256"]
    checks = {
        "all_reference_commands_passed": (
            len(c_samples) == args.runs
            and len(d_samples) == args.runs
            and all(sample_passed(sample) for sample in [*c_samples, *d_samples])
        ),
        "openc_five_public_builds_passed": all(
            sample_passed(sample) for sample in open_samples
        ),
        "openc_outputs_byte_identical": open_hashes == {expected_open_hash},
        "openc_public_build_records_pass": all(
            sample.get("build_record", {}).get("status") == "PASS"
            and sample.get("build_record", {}).get("backend") == "openc-x64-pe32"
            for sample in open_samples
        ),
        "openc_median_at_most_25s": open_median <= 25.0,
        "every_openc_run_at_most_35s": float(open_summary["maximum_seconds"]) <= 35.0,
        "openc_validation_median_below_15s": (
            float(validation_summary["median_seconds"]) < 15.0
        ),
        "openc_at_most_1_25x_slower_reference": (
            slower_reference > 0 and open_median / slower_reference <= 1.25
        ),
        "openc_at_most_2x_c_reference": c_median > 0 and open_median / c_median <= 2.0,
        "openc_at_most_2x_d_reference": d_median > 0 and open_median / d_median <= 2.0,
    }
    status = "PASS" if all(checks.values()) else "BLOCKED"
    d_inputs = [
        *sorted((ROOT / "compiler" / "source").rglob("*.d")),
        *sorted((ROOT / "runtime").rglob("*.d")),
        *sorted((ROOT / "standard_library" / "source").rglob("*.d")),
        *sorted((ROOT / "tools" / "source").rglob("*.d")),
    ]
    result = {
        "schema": SCHEMA,
        "status": status,
        "measured_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "logical_cpus": os.cpu_count(),
        },
        "tools": {
            "clang": tool_record(clang, ["--version"]),
            "dub": tool_record(dub, ["--version"]),
            "dmd": tool_record(dmd, ["--version"]),
        },
        "inputs": {
            "openc_stability_report": str(stability_path),
            "openc_compiler_sha256": expected_open_hash,
            "openc_source_files": open_samples[0]["timings"]["source_files"],
            "openc_source_bytes": open_samples[0]["timings"]["source_bytes"],
            "tinycc_source_archive": {
                "path": str(tinycc_source),
                "bytes": tinycc_source.stat().st_size,
                "sha256": sha256(tinycc_source),
                "version": "0.9.27",
                "mode": "single-source Windows x64 compiler, Clang -O2",
            },
            "d_reference": tree_fingerprint(d_inputs),
        },
        "gates": {
            "openc_clean_median_max_seconds": 25.0,
            "openc_clean_each_max_seconds": 35.0,
            "openc_validation_median_strictly_below_seconds": 15.0,
            "relative_to_slower_reference_max": 1.25,
            "relative_to_each_reference_max": 2.0,
        },
        "lanes": {
            "openc_public_self_build": {"summary": open_summary, "samples": open_samples},
            "openc_public_validation": {"summary": validation_summary},
            "c_clang_o2_tinycc_x64": {"summary": c_summary, "samples": c_samples},
            "d_forced_release": {"summary": d_summary, "samples": d_samples},
        },
        "ratios": {
            "openc_to_c": round(open_median / c_median, 3),
            "openc_to_d": round(open_median / d_median, 3),
            "openc_to_slower_reference": round(open_median / slower_reference, 3),
        },
        "checks": checks,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"SH-20 compiler references: {status}; OpenC={open_median:.3f}s; "
        f"C={c_median:.3f}s; D={d_median:.3f}s; report={output}",
        flush=True,
    )
    if args.enforce and status != "PASS":
        return 1
    return 0 if checks["all_reference_commands_passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
