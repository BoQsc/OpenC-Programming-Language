"""Guarded 24-file cache proof: paired full/no-op/body-edit build wall time."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics
import struct
import shutil
import subprocess
import tempfile

from windows_process_measure import run_measured


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=5)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    samples = {"full": [], "no_op": [], "body_edit": [], "normal": []}
    with tempfile.TemporaryDirectory(prefix="oc-cache24-") as temporary:
        root = Path(temporary)
        (root / "cache").mkdir()
        modules = {}
        names = ["alpha", "beta", "gamma", "zapp"]
        for module, name in enumerate(names):
            modules[name] = []
            for file in range(6):
                filename = f"m{module}_{file}.p"
                source = ""
                if module == 3 and file == 0:
                    source = ("import alpha;\nimport beta;\nimport gamma;\n"
                              "i32 main() { return alpha.f0_0_0(1) + beta.f1_0_0(1) + gamma.f2_0_0(1) + f3_0_0(1); }\n")
                for function in range(48):
                    source += f"export i32 f{module}_{file}_{function}(i32 x) {{ i32 a = x + 1; return a + 2; }}\n"
                (root / filename).write_text(source)
                modules[name].append(filename)
        project = root / "openc.project.json"
        project.write_text(json.dumps({"name": "cache24", "version": "0.1.0", "edition": "OpenC 1.0",
                                       "profile": "standard", "target": "windows-x86_64", "modules": modules}))

        def build(lane, number):
            prefix = root / f"{lane}-{number}"
            command = [str(compiler), "artifact", f"--project={project}", "--kind=module-coff-set",
                       f"--output={prefix}", f"--linked-exe={prefix}.exe", f"--timings={prefix}.timings.json"]
            if lane == "normal":
                command = [str(compiler), "build", f"--project={project}",
                           f"--output={prefix}.exe", f"--timings={prefix}.timings.json"]
            elif lane != "full":
                command.append(f"--cache-prefix={root / 'cache' / 'objects'}")
            measured = run_measured(command, cwd=root, max_private_bytes=256 * 1024 * 1024,
                                    max_working_set_bytes=64 * 1024 * 1024, sample_interval=0.01,
                                    max_captured_output_bytes=1024 * 1024)
            if measured["exit_code"] != 0:
                failure_dir = args.report.with_suffix(".failure")
                failure_dir.mkdir(parents=True, exist_ok=True)
                objects = {}
                for item in root.glob(f"{lane}-{number}.*.obj"):
                    shutil.copyfile(item, failure_dir / item.name)
                    data = item.read_bytes()
                    objects[item.name] = {"bytes": len(data), "header": struct.unpack_from("<HHIIIHH", data),
                                          "sections": [struct.unpack_from("<8sIIIIIIHHI", data, 20 + i * 40)[:-1]
                                                       for i in range(5)]}
                shutil.copyfile(project, failure_dir / "openc.project.json")
                (failure_dir / "measurement.json").write_text(json.dumps(measured, indent=2))
                print({"objects": objects})
            assert measured["exit_code"] == 0 and not measured["memory_limit_exceeded"], measured
            measured["timings"] = json.loads(Path(str(prefix) + ".timings.json").read_text())
            image = Path(str(prefix) + ".exe")
            measured["sha256"] = hashlib.sha256(image.read_bytes()).hexdigest()
            measured["runtime_exit"] = subprocess.run([str(image)], timeout=10).returncode
            return measured

        cold = build("cold", 0)
        assert cold["timings"]["object_cache"]["misses"] == 4, cold
        assert cold["runtime_exit"] == 16, cold
        for index in range(args.runs):
            order = ("full", "no_op") if index % 2 == 0 else ("no_op", "full")
            pair = {lane: build(lane, index) for lane in order}
            assert pair["full"]["sha256"] == pair["no_op"]["sha256"] == cold["sha256"]
            assert pair["no_op"]["timings"]["object_cache"]["hits"] == 4
            assert pair["no_op"]["timings"]["work"]["functions"] == 0
            for lane in order:
                samples[lane].append(pair[lane])
            normal = build("normal", index)
            assert normal["runtime_exit"] == 16
            samples["normal"].append(normal)
        edited_source = root / "m0_0.p"
        original = edited_source.read_text()
        for index in range(args.runs):
            # Each run is a new implementation key, not an old-key cache hit.
            edited_source.write_text(original.replace("return a + 2", f"return a + {index + 3}", 1))
            edit = build("body_edit", index)
            clean = build("full", "edit" + str(index))
            assert edit["sha256"] == clean["sha256"]
            assert edit["runtime_exit"] == clean["runtime_exit"] == 17 + index
            assert edit["timings"]["object_cache"]["hits"] == 3
            assert edit["timings"]["object_cache"]["misses"] == 1
            assert edit["timings"]["work"]["functions"] == 288
            edit["paired_clean_seconds"] = clean["elapsed_seconds"]
            samples["body_edit"].append(edit)
    report = {"schema": "openc.module_cache_24file.v1", "status": "PASS", "files": 24,
              "functions": 1153, "runs": args.runs, "compiler_sha256": hashlib.sha256(compiler.read_bytes()).hexdigest(),
              "cold": cold, "samples": samples,
              "medians_seconds": {lane: statistics.median(s["elapsed_seconds"] for s in values)
                                  for lane, values in samples.items()},
              "paired_no_op_gain_seconds": statistics.median(
                  a["elapsed_seconds"] - b["elapsed_seconds"] for a, b in zip(samples["full"], samples["no_op"])),
              "paired_edit_gain_seconds": statistics.median(
                  s["paired_clean_seconds"] - s["elapsed_seconds"] for s in samples["body_edit"]),
              "paired_normal_no_op_gain_seconds": statistics.median(
                  a["elapsed_seconds"] - b["elapsed_seconds"] for a, b in zip(samples["normal"], samples["no_op"]))}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ("status", "medians_seconds", "paired_no_op_gain_seconds", "paired_edit_gain_seconds", "paired_normal_no_op_gain_seconds")}, indent=2))


if __name__ == "__main__":
    main()
