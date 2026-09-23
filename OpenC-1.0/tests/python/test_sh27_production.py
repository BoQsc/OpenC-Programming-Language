from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "compiler" / "selfhost" / "benchmark_sh27_production.py"
SPEC = importlib.util.spec_from_file_location("benchmark_sh27_production", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
BENCHMARK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BENCHMARK)


class Sh27ProductionTests(unittest.TestCase):
    def test_control_flow_workload_is_bounded_and_equivalent(self) -> None:
        corpus = json.loads((ROOT / "benchmarks/sh27/CORPUS.json").read_text())
        BENCHMARK.validate_corpus(corpus)
        workload = next(
            item for item in corpus["workloads"] if item["id"] == "control_flow"
        )
        self.assertEqual(workload["shape"], "control_flow")
        with tempfile.TemporaryDirectory() as directory:
            records = {
                language: BENCHMARK.generate_language(
                    Path(directory) / language, language, workload
                )
                for language in ("openc", "msvc", "dmd")
            }
            self.assertEqual(
                {record["equivalent_functions"] for record in records.values()},
                {256},
            )
            for record in records.values():
                self.assertEqual(record["tree"]["files"], 4)
                source = record["sources"][0].read_text(encoding="ascii")
                self.assertIn("if ", source)
                self.assertIn("while ", source)
                self.assertIn("cursor_1", source)
        self.assertEqual(
            BENCHMARK.apply_operations(0, 0, 9, "control_flow"), 59
        )

    def test_runtime_fixture_contract_and_oracle(self) -> None:
        corpus = json.loads((ROOT / "benchmarks/sh27/CORPUS.json").read_text())
        BENCHMARK.validate_corpus(corpus)
        inputs = {
            language: BENCHMARK.runtime_input(language, corpus["runtime_workload"])
            for language in ("openc", "msvc", "dmd")
        }
        self.assertEqual(
            {item["expected_output_sha256"] for item in inputs.values()},
            {"6ecc3297b09d6e643c4a2a644c630640b486557458f183a127f74789a5689874"},
        )
        self.assertTrue(all(item["tree"]["files"] == 1 for item in inputs.values()))

    def test_sample_rejects_runtime_parity_failure(self) -> None:
        sample = {
            "exit_code": 0,
            "memory_limit_exceeded": False,
            "stdout_truncated": False,
            "stderr_truncated": False,
            "output_exists": True,
            "program_exit_code": 0,
            "program_timed_out": False,
            "program_memory_limit_exceeded": False,
            "program_stdout_truncated": False,
            "program_stderr_truncated": False,
            "program_output_matches": False,
        }
        self.assertFalse(BENCHMARK.sample_passed(sample))
        sample["program_output_matches"] = True
        self.assertTrue(BENCHMARK.sample_passed(sample))
        sample["program_memory_limit_exceeded"] = True
        self.assertFalse(BENCHMARK.sample_passed(sample))

    def test_disk_headroom_guard_reports_output_volume(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nested" / "output"
            self.assertGreaterEqual(BENCHMARK.require_disk_headroom(path, 0), 0)
            with self.assertRaisesRegex(RuntimeError, "SH27_DISK_HEADROOM"):
                BENCHMARK.require_disk_headroom(path, 10**30)

    def test_ldc_uses_d_sources_and_bounded_release_build(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source_0000.d"
            output = root / "program.exe"
            command = BENCHMARK.build_command(
                "ldc", root / "ldc2.exe", {"sources": [source]},
                output, root / "unused-timings.json",
            )
            self.assertEqual(command[1:4], ["-O2", "-release", "-boundscheck=off"])
            self.assertEqual(command[4:], [str(source), f"-of={output}", f"-od={root}"])

    @unittest.skipUnless(os.name == "nt", "Windows process measurement only")
    def test_execution_timeout_kills_child(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = BENCHMARK.run_measured(
                [sys.executable, "-c", "import time; time.sleep(5)"],
                cwd=directory,
                sample_interval=0.01,
                timeout_seconds=0.1,
            )
        self.assertTrue(result["timed_out"])
        self.assertNotEqual(result["exit_code"], 0)
        self.assertLess(result["elapsed_seconds"], 2)

    @unittest.skipUnless(os.name == "nt", "Windows process measurement only")
    def test_memory_guard_accounts_for_compiler_children(self) -> None:
        child = (
            "import time; payload = bytearray(48 * 1024 * 1024); "
            "time.sleep(0.3)"
        )
        parent = (
            "import subprocess, sys; "
            f"child = subprocess.Popen([sys.executable, '-c', {child!r}]); "
            "sys.exit(child.wait())"
        )
        with tempfile.TemporaryDirectory() as directory:
            result = BENCHMARK.run_measured(
                [sys.executable, "-c", parent],
                cwd=directory,
                sample_interval=0.01,
                timeout_seconds=3,
                max_private_bytes=128 * BENCHMARK.MIB,
            )
        self.assertEqual(result["exit_code"], 0, result["stderr"])
        self.assertGreater(
            result["peak_job_private_bytes"], result["peak_private_bytes"]
        )
        self.assertFalse(result["memory_limit_exceeded"])

    @unittest.skipUnless(os.name == "nt", "Windows process measurement only")
    def test_memory_guard_caps_compiler_child_allocation(self) -> None:
        child = "payload = bytearray(48 * 1024 * 1024)"
        parent = (
            "import subprocess, sys; "
            f"child = subprocess.Popen([sys.executable, '-c', {child!r}]); "
            "sys.exit(child.wait())"
        )
        with tempfile.TemporaryDirectory() as directory:
            result = BENCHMARK.run_measured(
                [sys.executable, "-c", parent],
                cwd=directory,
                sample_interval=0.01,
                timeout_seconds=3,
                max_private_bytes=32 * BENCHMARK.MIB,
            )
        self.assertNotEqual(result["exit_code"], 0)
        self.assertLessEqual(
            result["peak_job_private_bytes"], 32 * BENCHMARK.MIB, result
        )

    @unittest.skipUnless(os.name == "nt", "Windows process measurement only")
    def test_memory_guard_flags_aggregate_parent_and_child(self) -> None:
        child = "payload = bytearray(18 * 1024 * 1024)"
        parent = (
            "import subprocess, sys; "
            "payload = bytearray(18 * 1024 * 1024); "
            f"child = subprocess.Popen([sys.executable, '-c', {child!r}]); "
            "sys.exit(child.wait())"
        )
        with tempfile.TemporaryDirectory() as directory:
            result = BENCHMARK.run_measured(
                [sys.executable, "-c", parent],
                cwd=directory,
                sample_interval=0.01,
                timeout_seconds=3,
                max_private_bytes=48 * BENCHMARK.MIB,
            )
        self.assertNotEqual(result["exit_code"], 0, result)
        self.assertTrue(result["memory_limit_exceeded"], result)
        self.assertEqual(result["memory_limit_name"], "job_private_bytes")
        self.assertGreaterEqual(
            result["peak_job_private_bytes"], 48 * BENCHMARK.MIB
        )


if __name__ == "__main__":
    unittest.main()
