"""Force the optional SHA API unavailable and verify saved-object fallback."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from test_module_coff_set import build, coff_symbols
from windows_process_measure import run_measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.coff_hash_fallback.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "builds": [], "links": {}}
    try:
        # A hosted checkout can live on D: while TEMP lives on C:. Keep the
        # isolated project on the source volume so relative source references
        # remain valid without changing the user's process environment.
        source_volume_runs = ROOT / "build-output"
        source_volume_runs.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="hash-", dir=source_volume_runs) as temporary:
            directory = Path(temporary)
            canonical = ROOT / "compiler/selfhost"
            project = json.loads((canonical / "openc.project.json").read_text())
            runtime_path = canonical / "source/backend_native_cache.p"
            runtime = runtime_path.read_text(encoding="utf-8")
            original = '"crypt32.dll", "CryptHashCertificate2"'
            assert runtime.count(original) == 1
            changed_runtime = directory / "missing-hash.p"
            changed_runtime.write_text(runtime.replace(original,
                '"crypt32.dll", "OpenC_SH27_MissingHash"'), encoding="utf-8")
            for name, files in project["modules"].items():
                project["modules"][name] = [os.path.relpath(
                    changed_runtime if filename == "source/backend_native_cache.p"
                    else canonical / filename, directory).replace(os.sep, "/") for filename in files]
            for name in ("standard_library_directory", "runtime_directory"):
                project[name] = str((canonical / project[name]).resolve(strict=True))
            project["output_directory"] = str(directory / "build")
            project_path = directory / "openc.project.json"
            project_path.write_text(json.dumps(project, indent=2) + "\n", encoding="utf-8")

            def guarded(command: list[str]) -> dict:
                result = run_measured(command, cwd=directory, sample_interval=0.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=64 * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=120)
                assert result["exit_code"] == 0 and not result["timed_out"] and not result[
                    "memory_limit_exceeded"], result
                assert not result["stdout_truncated"] and not result["stderr_truncated"], result
                return result

            current = compiler
            hashes = []
            for generation in range(1, 4):
                target = directory / f"fault-stage{generation}.exe"
                measurement = guarded([str(current), "build", f"--project={project_path}",
                                       f"--output={target}"])
                digest = sha256(target)
                hashes.append(digest)
                report["builds"].append({"generation": generation,
                    "sha256": digest, "measurement": measurement})
                current = target
                print(f"missing SHA API bootstrap: {generation}/3", flush=True)
            assert hashes[1] == hashes[2], "fault compiler does not close exactly"
            # The old host emits its runtime hooks into generation 1. Only
            # generations 2/3 prove that our missing API reaches the runtime.
            fault_bytes = current.read_bytes()
            assert b"CryptHashCertificate2\0" not in fault_bytes
            assert b"OpenC_SH27_MissingHash\0" in fault_bytes
            beta = "import alpha;\ni32 main() { i32 x = 0;\n" + (
                "x = x + alpha.add(0, 1);\n" * 64) + "return x; }\n"
            objects, manifest = build(compiler, directory / "fixture", beta=beta,
                                      native_link=True)
            assert len(objects["beta"]) >= 4096, "fixture misses the accelerated size range"
            expected = sha256(directory / "fixture/native-linked.exe")
            names = coff_symbols(objects["beta"])
            entry = next(name for name, (section, storage) in names.items()
                         if name.startswith("$openc$") and section == 1 and storage == 2)
            options = []
            for item in manifest["modules"]:
                path = Path(item["object"])
                oracle = hashlib.sha256(path.read_bytes()).hexdigest()
                assert oracle == item["sha256"]
                options += [f"--object={path}", f"--sha256={oracle}"]
            for label, tool in (("accelerated", compiler), ("unavailable_api", current)):
                output = directory / f"{label}.exe"
                measurement = guarded([str(tool), "module-coff-link", f"--entry={entry}",
                                       f"--output={output}", *options])
                digest = sha256(output)
                assert digest == expected
                executed = subprocess.run([str(output)], capture_output=True, timeout=10)
                assert executed.returncode == 64 and not executed.stdout and not executed.stderr
                report["links"][label] = {"exe_sha256": digest, "measurement": measurement,
                                          "exit_code": executed.returncode}
            report["status"] = "PASS"
    except Exception as error:
        report["error"] = str(error)
    finally:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"COFF hash unavailable-API fallback: {report['status']}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
