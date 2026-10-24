"""Verify native peak accounting, including children that exit between polls."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from benchmark_sh27_production import MIB, ROOT, sha256
from windows_process_measure import run_measured

SOURCE = """import system.process;
unsafe status cli_process_run_measured(text command, usize timeout,
    out i32 exit_code, out text output, out usize peak_private, out usize peak_working) {
    return status{code = 1};
}
unsafe i32 main() {
    i32 code; text output; usize private_bytes; usize working_bytes;
    status ran = cli_process_run_measured(process.argument(0), 5000,
        out code, out output, out private_bytes, out working_bytes);
    if process.argument(1) == "reject" {
        if ran.ok { return 1; }
        return 0;
    }
    if !ran.ok { return 2; }
    if code != 0 { return 2; }
    if private_bytes == 0 || working_bytes == 0 || working_bytes > 67108864 { return 3; }
    return 0;
}
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("compiler", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.compiler.resolve(strict=True)
    report = {"schema": "openc.sh27.native_process_peaks.v1", "status": "FAIL",
              "compiler_sha256": sha256(compiler), "builds": [], "cases": {}}
    try:
        with tempfile.TemporaryDirectory(prefix="npk-", dir=ROOT / "build-output") as temporary:
            root = Path(temporary)
            (root / "main.p").write_text(SOURCE, encoding="utf-8")
            project = root / "openc.project.json"
            project.write_text(json.dumps({"name": "native-process-peaks", "version": "1.0.0",
                "edition": "OpenC 1.0", "profile": "standard", "target": "windows-x86_64",
                "modules": {"peaks": ["main.p"]}}), encoding="utf-8")
            small, large = root / "small.py", root / "large.py"
            small.write_text("pass\n")
            large.write_text("payload = bytearray(96 * 1024 * 1024)\n")

            def guarded(command: list[str], working: int = 64, expected_exit: int = 0) -> dict:
                sample = run_measured(command, cwd=root, sample_interval=.01,
                    max_private_bytes=256 * MIB, max_working_set_bytes=working * MIB,
                    max_captured_output_bytes=MIB, timeout_seconds=60)
                assert sample["exit_code"] == expected_exit and not sample["timed_out"] and not sample["memory_limit_exceeded"], sample
                assert not sample["stdout_truncated"] and not sample["stderr_truncated"], sample
                return sample

            def probe(tool: Path, label: str, missing_final: bool = False) -> None:
                output = root / f"{label}.exe"
                report["builds"].append(guarded([str(tool), "artifact", f"--project={project}",
                    "--kind=exe", f"--output={output}"]))
                for child, expected in ((small, "accept"), (large, "reject")):
                    command = subprocess.list2cmdline([sys.executable, str(child)])
                    expected_exit = (3 if expected == "accept" else 1) if missing_final else 0
                    sample = guarded([str(output), command, expected], working=128,
                                     expected_exit=expected_exit)
                    assert not sample["stdout"], sample
                    if expected == "reject" and not missing_final:
                        assert "OPENC-NATIVE-PROCESS-WORKING-SET-BUDGET" in sample["stderr"], sample
                    else:
                        assert not sample["stderr"], sample
                    report["cases"][label + "-" + expected] = sample

            probe(compiler, "live")
            # This owned compiler variant emits a wait before its first memory
            # poll. Both child probes therefore finish before live supervision;
            # success requires the retained post-exit counters, deterministically.
            canonical = ROOT / "compiler/selfhost"
            relative = "source/backend_native_runtime_process_supervise.p"
            source = (canonical / relative).read_text(encoding="utf-8")
            marker = "    usize read_loop = function.code.bytes.length;"
            assert source.count(marker) == 1
            waiting = root / "wait-before-poll.p"
            waiting.write_text(source.replace(marker, """    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 4294967295));
    native_import(function, 26);
""" + marker), encoding="utf-8")
            data = json.loads((canonical / "openc.project.json").read_text())
            for module, files in data["modules"].items():
                data["modules"][module] = [os.path.relpath(
                    waiting if name == relative else canonical / name, root
                    ).replace(os.sep, "/") for name in files]
            for name in ("standard_library_directory", "runtime_directory"):
                data[name] = str((canonical / data[name]).resolve(strict=True))
            data["output_directory"] = "build"
            fault_project = root / "wait.json"
            fault_project.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            fault_compiler = root / "wait-compiler.exe"
            report["builds"].append(guarded([str(compiler), "build", f"--project={fault_project}",
                f"--output={fault_compiler}"]))
            report["wait_compiler_sha256"] = sha256(fault_compiler)
            probe(fault_compiler, "after-exit")
            # Negative control: removing only final accounting must make both
            # post-exit oracles fail. This rules out accidental live sampling.
            control_source = waiting.read_text(encoding="utf-8")
            start = control_source.index("    // A child may cross the limit and exit between polls.")
            marker = "    native_skip_end(function.code, unavailable_final_counters);\n"
            end = control_source.index(marker, start) + len(marker)
            waiting.write_text(control_source[:start] + control_source[end:], encoding="utf-8")
            control = root / "missing-final-compiler.exe"
            report["builds"].append(guarded([str(compiler), "build", f"--project={fault_project}",
                f"--output={control}"]))
            probe(control, "missing-final-control", missing_final=True)
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
