from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
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

    def test_native_chunk_comparator_lane_is_explicit_opt_in(self) -> None:
        project = Path("example.project.json")
        output = Path("program.exe")
        report = Path("report.json")
        input_record = {"project": project, "sources": []}
        serial = BENCHMARK.build_command(
            "openc", Path("openc.exe"), input_record, output, report,
        )
        parallel = BENCHMARK.build_command(
            "openc", Path("openc.exe"), input_record, output, report,
            openc_source_chunks=4,
        )
        two_workers = BENCHMARK.build_command(
            "openc", Path("openc.exe"), input_record, output, report,
            openc_source_chunks=2,
        )
        adaptive = BENCHMARK.build_command(
            "openc", Path("openc.exe"), input_record, output, report,
            openc_source_chunks="auto",
        )
        self.assertEqual(serial[1], "build")
        self.assertNotIn("--source-chunks=4", serial)
        self.assertEqual(parallel[1], "artifact")
        self.assertIn("--kind=exe", parallel)
        self.assertIn("--source-chunks=4", parallel)
        self.assertIn(f"--timings={report}", parallel)
        self.assertIn("--report=openc-artifact.json", parallel)
        self.assertEqual(two_workers[1], "artifact")
        self.assertIn("--source-chunks=2", two_workers)
        self.assertEqual(adaptive[1], "artifact")
        self.assertIn("--source-chunks=auto", adaptive)

    def test_native_chunk_timing_basis_tracks_actual_worker_mode(self) -> None:
        script_directory = str(MODULE_PATH.parent)
        sys.path.insert(0, script_directory)
        try:
            import verify_sh27_native_chunks as proof
        finally:
            sys.path.remove(script_directory)
        active_profile = {
            "launch_completed": True, "workers_wall_ms": 400,
            "merge_wall_ms": 0,
            "critical_chunk": {
                "first_source": 0, "end_source_exclusive": 1,
                "wall_ms": 350, "lex_parse_ms": 0, "index_ms": 20,
                "acceptance_ms": 160, "expression_ms": 120,
                "assignment_ms": 90, "calls_ms": 10,
                "ir_lower_ms": 70, "native_emit_ms": 50,
                "type_queries": 300, "type_cache_hits": 100,
                "type_uncached": 200, "type_failures": 0,
                "assignment_type_queries": 100,
                "assignment_type_cache_hits": 40,
                "assignment_type_uncached": 60,
            },
        }
        serial_profile = {
            "launch_completed": False, "workers_wall_ms": 0,
            "merge_wall_ms": 0,
            "critical_chunk": {
                "first_source": 0, "end_source_exclusive": 0,
                "wall_ms": 0, "lex_parse_ms": 0, "index_ms": 0,
                "acceptance_ms": 0, "expression_ms": 0,
                "assignment_ms": 0, "calls_ms": 0,
                "ir_lower_ms": 0, "native_emit_ms": 0,
                "type_queries": 0, "type_cache_hits": 0,
                "type_uncached": 0, "type_failures": 0,
                "assignment_type_queries": 0,
                "assignment_type_cache_hits": 0,
                "assignment_type_uncached": 0,
            },
        }
        timing = {
            "status": "PASS", "source_files": 4, "source_bytes": 206637,
            "parallel_source_chunks": 2,
            "parallel_flow_workers": 2,
            "flow_threads_launched": True,
            "source_chunks_policy": "explicit_or_default",
            "phase_accounting": "wall_elapsed_with_acceptance_in_lowering",
            "validation_profile": {
                "acceptance_time_basis": "summed_worker_elapsed",
                "flow_group_time_basis": "summed_worker_elapsed",
            },
            "native_parallel_profile": active_profile,
            "type_query_profile": {
                "enabled": True, "validation_queries": 500,
                "validation_cache_hits": 100,
                "validation_uncached": 400,
                "validation_failures": 0,
                "assignment_queries": 180,
                "assignment_cache_hits": 70,
                "assignment_uncached": 110,
            },
        }
        self.assertTrue(proof.timing_accounting_valid(timing, True, 2))
        timing["type_query_profile"]["validation_uncached"] = 399
        self.assertFalse(proof.timing_accounting_valid(timing, True, 2))
        timing["type_query_profile"]["validation_uncached"] = 400
        timing["native_parallel_profile"]["critical_chunk"]["assignment_ms"] = 170
        self.assertFalse(proof.timing_accounting_valid(timing, True, 2))
        timing["native_parallel_profile"]["critical_chunk"]["assignment_ms"] = 90
        self.assertFalse(proof.timing_accounting_valid(timing, False, 2))
        timing["source_files"] = 1
        timing["parallel_source_chunks"] = 0
        timing["parallel_flow_workers"] = 0
        timing["flow_threads_launched"] = False
        timing["phase_accounting"] = "wall_elapsed_with_acceptance_in_validation"
        timing["validation_profile"]["acceptance_time_basis"] = "wall_elapsed"
        timing["validation_profile"]["flow_group_time_basis"] = "wall_elapsed"
        timing["native_parallel_profile"] = serial_profile
        self.assertTrue(proof.timing_accounting_valid(timing, True, 2))
        timing["validation_profile"]["acceptance_time_basis"] = "summed_worker_elapsed"
        self.assertFalse(proof.timing_accounting_valid(timing, True, 2))
        timing.update({
            "source_files": 4, "source_bytes": 206637,
            "parallel_source_chunks": 4, "source_chunks_policy": "auto",
            "parallel_flow_workers": 2, "flow_threads_launched": True,
            "phase_accounting": "wall_elapsed_with_acceptance_in_lowering",
        })
        timing["validation_profile"]["flow_group_time_basis"] = "summed_worker_elapsed"
        timing["native_parallel_profile"] = active_profile
        self.assertTrue(proof.timing_accounting_valid(timing, True, "auto"))
        timing["source_bytes"] = 196608
        self.assertTrue(proof.timing_accounting_valid(timing, True, "auto"))
        timing["source_bytes"] = 196607
        timing["parallel_source_chunks"] = 0
        timing["parallel_flow_workers"] = 0
        timing["flow_threads_launched"] = False
        timing["phase_accounting"] = "wall_elapsed_with_acceptance_in_validation"
        timing["validation_profile"]["acceptance_time_basis"] = "wall_elapsed"
        timing["validation_profile"]["flow_group_time_basis"] = "wall_elapsed"
        timing["native_parallel_profile"] = serial_profile
        self.assertTrue(proof.timing_accounting_valid(timing, True, "auto"))
        timing["parallel_source_chunks"] = 2
        self.assertFalse(proof.timing_accounting_valid(timing, True, "auto"))
        timing.update({
            "source_files": 8, "source_bytes": 741660,
            "parallel_source_chunks": 4, "parallel_flow_workers": 2,
            "flow_threads_launched": True,
            "phase_accounting": "wall_elapsed_with_acceptance_in_lowering",
        })
        timing["validation_profile"]["acceptance_time_basis"] = "summed_worker_elapsed"
        timing["validation_profile"]["flow_group_time_basis"] = "summed_worker_elapsed"
        timing["native_parallel_profile"] = active_profile
        self.assertTrue(proof.timing_accounting_valid(timing, True, "auto"))
        timing["source_files"] = 221
        timing["source_bytes"] = 2066330
        timing["parallel_flow_workers"] = 4
        self.assertTrue(proof.timing_accounting_valid(timing, True, "auto"))
        timing["type_query_profile"] = {
            "enabled": False, "validation_queries": 0,
            "validation_cache_hits": 0, "validation_uncached": 0,
            "validation_failures": 0, "assignment_queries": 0,
            "assignment_cache_hits": 0, "assignment_uncached": 0,
        }
        for key in (
            "type_queries", "type_cache_hits", "type_uncached",
            "type_failures", "assignment_type_queries",
            "assignment_type_cache_hits", "assignment_type_uncached",
        ):
            timing["native_parallel_profile"]["critical_chunk"][key] = 0
        self.assertTrue(proof.timing_accounting_valid(timing, True, "auto"))

    def test_worker_tradeoff_requires_same_compiler_and_material_savings(self) -> None:
        script = ROOT / "compiler/selfhost/verify_sh27_worker_tradeoff.py"
        def proof(chunks: int, peak_mib: int) -> dict[str, object]:
            return {
                "status": "PASS", "source_chunks": chunks,
                "compiler_sha256": "same-compiler",
                "results": {
                    name: {
                        "byte_exact": True,
                        "serial": {"output_sha256": "same-program"},
                        "chunked": {"peak_job_private_bytes": peak_mib * BENCHMARK.MIB},
                    }
                    for name in ("control_flow", "large_functions", "selfhost")
                },
            }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            two = root / "two.json"
            four = root / "four.json"
            output = root / "result.json"
            two.write_text(json.dumps(proof(2, 100)), encoding="utf-8")
            four_record = proof(4, 140)
            four.write_text(json.dumps(four_record), encoding="utf-8")
            command = [
                sys.executable, str(script), "--two-proof", str(two),
                "--four-proof", str(four), "--output", str(output),
            ]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            self.assertEqual(json.loads(output.read_text())["status"], "PASS")
            four_record["results"]["large_functions"]["chunked"][
                "peak_job_private_bytes"
            ] = 120 * BENCHMARK.MIB
            four.write_text(json.dumps(four_record), encoding="utf-8")
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
            four_record["compiler_sha256"] = "different-compiler"
            four.write_text(json.dumps(four_record), encoding="utf-8")
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

    @unittest.skipUnless(os.name == "nt", "Windows process measurement only")
    def test_failed_paired_bootstrap_preserves_stage_measurement(self) -> None:
        script_directory = str(MODULE_PATH.parent)
        sys.path.insert(0, script_directory)
        try:
            import benchmark_sh27_paired_revision as paired
        finally:
            sys.path.remove(script_directory)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "project" / "compiler" / "selfhost"
            project.mkdir(parents=True)
            (project / "openc.project.json").write_text("{}", encoding="utf-8")
            run_root = root / "runs"
            with self.assertRaisesRegex(RuntimeError, "measurement="):
                paired.bootstrap("baseline", root / "project", Path(sys.executable), run_root)
            measurement = json.loads(
                (run_root / "bootstrap" / "baseline" / "stage1" / "measurement.json")
                .read_text(encoding="utf-8")
            )
            self.assertFalse(measurement["passed"])
            self.assertEqual(measurement["stage"], 1)
            self.assertFalse(measurement["output_exists"])
            self.assertNotEqual(measurement["exit_code"], 0)

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
