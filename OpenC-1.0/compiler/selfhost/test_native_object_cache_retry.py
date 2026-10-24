"""Force a late cache reread failure and prove a complete validating retry."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.native_cache_retry.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "builds": []}
    try:
        parent = ROOT / "build-output"
        parent.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="nr-", dir=parent) as temporary:
            root = Path(temporary)
            canonical = ROOT / "compiler/selfhost"
            shutil.copytree(canonical / "source", root / "source")
            data = json.loads((canonical / "openc.project.json").read_text())
            for name in ("standard_library_directory", "runtime_directory"):
                data[name] = str((canonical / data[name]).resolve())
            data["output_directory"] = "build"
            project = root / "openc.project.json"
            project.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            source = root / "source/backend_native_object_cache.p"
            code = source.read_text()
            call = ("ok = native_object_cache_read_hit(options.cache_prefix,\n"
                    "                    partition, partitions, context, entry_module, cache);")
            assert code.count(call) == 1, "late cache read fault point changed"
            source.write_text(code.replace(call, "ok = false; // injected late-read failure"), encoding="utf-8")

            def build(tool: Path, output: Path, no_cache: bool = False) -> dict:
                timing = output.with_suffix(".json")
                command = [str(tool), "build", f"--project={project}",
                           f"--output={output}", f"--timings={timing}"]
                if no_cache: command.append("--no-cache")
                measured = run_measured(command, cwd=root, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                result = {"measurement": measured,
                          "command": command,
                          "timings": json.loads(timing.read_text()) if timing.is_file() else None,
                          "sha256": sha256(output) if output.is_file() else None}
                report["builds"].append(result)
                assert measured["exit_code"] == 0 and not measured["memory_limit_exceeded"] and not measured["timed_out"], measured
                assert not measured["stdout_truncated"] and not measured["stderr_truncated"]
                return result

            current = compiler
            hashes = []
            for generation in range(1, 4):
                target = root / f"fault{generation}.exe"
                hashes.append(build(current, target)["sha256"])
                current = target
                print(f"native cache late-read bootstrap: {generation}/3", flush=True)
            assert hashes[1] == hashes[2], "fault compiler did not reach a fixed point"
            direct = build(current, root / "direct.exe", True)
            output = root / "cached.exe"
            cold = build(current, output)
            assert cold["timings"]["object_cache"]["misses"] == 32
            bundle = root / "cached.exe.openc-cache/objects.bundle"
            original_hash = sha256(bundle)
            retried = build(current, output)
            assert retried["timings"]["object_cache_retries"] == 1
            assert "object_cache" not in retried["timings"], "retry still skipped cached sources"
            assert retried["timings"]["work"]["functions"] == direct["timings"]["work"]["functions"]
            assert sha256(bundle) == original_hash, "failed cached attempt republished storage"
            assert direct["sha256"] == cold["sha256"] == retried["sha256"] == hashes[2]
            report["status"] = "PASS"
    except Exception as error:
        report["error"] = repr(error)
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report.get(k) for k in ("status", "error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
