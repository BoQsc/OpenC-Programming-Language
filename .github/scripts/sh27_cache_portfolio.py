"""Compare early owned identity hashing with its serial control and frozen baseline."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "OpenC-1.0"
SCRIPTS = ROOT / "compiler/selfhost"
sys.path.insert(0, str(SCRIPTS))
from windows_process_measure import run_measured
from benchmark_sh27_production import MIB, sha256

BASE = "bf6c9114fef0c2396125ea76ec789f2e9bda7d43"
BASE_HASH = "f97d4610573391cb4d8f5d4acd71b38a5a2337462e5992c2568413cb8a06a44d"
OBJECT = "source/backend_native_object_cache.p"
PARALLEL = "source/backend_c_parallel_state.p"
FRONTEND = "source/backend_native_frontend_cache.p"
EMIT = "source/backend_emit.p"
BACKEND = "source/backend.p"
TIMINGS = "source/backend_c_build.p"
INTRINSICS = "source/backend_native_scalar_intrinsic.p"
ANCHOR = "    if !prepared {\n        module_cache_destroy(cache);"
EARLY = """    if prepared && options.cache_type_count != 0 && options.cache_type_count <= base.types.length {
        PackedBuffer semantic_types = base.types;
        semantic_types.length = options.cache_type_count;
        frontend.prepare_parallel = true;
        native_frontend_prepare_publish(frontend, options.cache_prefix,
            base.type_data, semantic_types, base.symbol_data, base.detail_data, base.symbols);
    }
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((SCRIPTS / "openc.project.json").read_text())
    changed = subprocess.check_output(["git", "diff", "--name-only", BASE, "--",
        "OpenC-1.0/compiler/selfhost/source"], cwd=REPO, text=True).splitlines()
    fields = (OBJECT, PARALLEL, FRONTEND, EMIT, BACKEND, TIMINGS, INTRINSICS)
    if set(changed) - {"OpenC-1.0/compiler/selfhost/" + name for name in fields}:
        raise RuntimeError("portfolio inputs differ outside the isolated object-cache cut")
    original = {name: subprocess.check_output(["git", "show",
        BASE + ":OpenC-1.0/compiler/selfhost/" + name], cwd=REPO) for name in fields}
    compilers = {}
    records = {}
    variants = ("async-identity", "serial-control")
    for name in ("baseline", *variants):
        folder = output / name
        shutil.copytree(SCRIPTS / "source", folder / "source")
        if name == "baseline":
            for field in fields:
                (folder / field).write_bytes(original[field])
        if name == "serial-control":
            path = folder / EMIT
            text = path.read_text()
            marker = "native_frontend_begin_identity(frontend);"
            if text.count(marker) != 1:
                raise RuntimeError("identity scheduling marker changed")
            path.write_text(text.replace(marker, "// serial identity control"), newline="\n")
        data = {**manifest, "output_directory": "build"}
        for key in ("runtime_directory", "standard_library_directory"):
            data[key] = str((SCRIPTS / data[key]).resolve())
        project = folder / "openc.project.json"
        project.write_text(json.dumps(data, indent=2) + "\n")
        current = (REPO / ".github/bootstrap/openc-stage0.exe" if name == "baseline" else compilers["baseline"])
        hashes = []
        for generation in range(1, 4):
            binary = folder / f"c{generation}.exe"
            transition = name == "baseline" and generation == 1
            command = [str(current), "build", f"--project={project}", f"--output={binary}",
                       f"--timings={folder / f'c{generation}-timings.json'}"]
            if not transition:
                command.append("--no-cache")
            result = run_measured(command, cwd=ROOT, sample_interval=.01, timeout_seconds=180,
                max_private_bytes=(512 if transition else 256)*MIB,
                max_working_set_bytes=(256 if transition else 64)*MIB,
                max_captured_output_bytes=2*MIB)
            (folder / f"c{generation}.json").write_text(json.dumps(result, indent=2) + "\n")
            if result["exit_code"] or result["memory_limit_exceeded"] or result["timed_out"] or result["stdout_truncated"] or result["stderr_truncated"]:
                print(result["stdout"][-4096:], result["stderr"][-4096:], flush=True)
                raise RuntimeError(f"{name} bootstrap failed: c{generation}.json")
            hashes.append(sha256(binary))
            current = binary
        if hashes[1] != hashes[2] or (name == "baseline" and hashes[2] != BASE_HASH):
            raise RuntimeError(f"{name} does not reproduce its fixed point")
        compilers[name] = current
        records[name] = {"sha256": hashes[2], "generations": hashes}
        print(name, hashes[2], flush=True)
    (output / "compilers.json").write_text(json.dumps(records, indent=2) + "\n")
    results = {}
    for repeat in (1, 2):
        order = variants if repeat == 1 else tuple(reversed(variants))
        for name in order:
            report = output / f"{name}-31-{repeat}.json"
            command = [sys.executable, str(SCRIPTS / "benchmark_native_object_cache.py"), str(compilers[name]),
                "--ordinary-build", "--fixture", "medium", "--pairs", "31", "--enforce", "--compare-cold",
                "--baseline-compiler", str(compilers["baseline"]), "--observations-per-side", "5",
                "--report", str(report)]
            subprocess.run(command, cwd=ROOT, check=False)
            result = json.loads(report.read_text())
            results[f"{name}-{repeat}"] = {key: result.get(key) for key in
                ("status", "checks", "summary", "null_floor_seconds", "error")}
    qualified = [name for name in variants
                 if all(results[f"{name}-{repeat}"]["status"] == "PASS" for repeat in (1, 2))]
    summary = {"schema": "openc.sh27.cold_cache_portfolio.v1", "status": "EVIDENCE_COMPLETE",
        "baseline_source_commit": BASE, "pairs_per_variant_per_repeat": 31,
        "observations_per_side": 5, "null_control": "same baseline and cold cache operation",
        "independent_repeats": 2, "results": results, "qualified": qualified,
        "production_promotion_authorized": False}
    (output / "portfolio.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
