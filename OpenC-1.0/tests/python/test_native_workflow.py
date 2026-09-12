"""Unit tests for native toolchain, performance, and release contracts."""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "compiler" / "selfhost"))
sys.path.insert(0, str(ROOT / "release"))

from native_toolchain import digest_paths, validate_native_compiler
from performance_budget import load_budget, measurement_checks
from windows_native_release import verifier_summary_checks


class NativeToolchainTests(unittest.TestCase):
    def test_digest_is_order_independent_and_content_sensitive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "first"
            second = root / "second"
            first.write_text("one", encoding="utf-8")
            second.write_text("two", encoding="utf-8")
            forward = digest_paths(root, [first, second])
            reverse = digest_paths(root, [second, first])
            self.assertEqual(forward, reverse)
            second.write_text("changed", encoding="utf-8")
            self.assertNotEqual(forward, digest_paths(root, [first, second]))

    def test_native_record_and_distribution_are_required(self):
        with tempfile.TemporaryDirectory() as directory:
            distribution = Path(directory)
            compiler = distribution / "openc.exe"
            compiler.write_bytes(b"MZnative")
            record = {
                "schema": "openc-sh5-windows-build-v1",
                "status": "PASS",
                "backend": "openc-x64-pe32",
                "dmd_invoked": False,
                "dub_invoked": False,
                "python_invoked": False,
                "tinycc_invoked": False,
                "external_assembler_invoked": False,
                "external_linker_invoked": False,
            }
            Path(str(compiler) + ".build.json").write_text(
                json.dumps(record), encoding="utf-8"
            )
            result = validate_native_compiler(compiler)
            self.assertEqual(result["dmd_invoked"], False)
            record["dmd_invoked"] = True
            Path(str(compiler) + ".build.json").write_text(
                json.dumps(record), encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "not a verified"):
                validate_native_compiler(compiler)


class PerformanceBudgetTests(unittest.TestCase):
    def test_authored_baselines_fit_budgets(self):
        document, validation = load_budget(
            ROOT / "compiler/selfhost/WINDOWS_NATIVE_BUDGETS.json",
            "validation",
        )
        checks = measurement_checks(
            {
                "exit_code": 0,
                **document["baselines"]["validation"],
            },
            validation,
        )
        self.assertTrue(all(checks.values()))
        _, rebuild = load_budget(
            ROOT / "compiler/selfhost/WINDOWS_NATIVE_BUDGETS.json",
            "self_rebuild",
        )
        checks = measurement_checks(
            {
                "exit_code": 0,
                **document["baselines"]["self_rebuild"],
            },
            rebuild,
        )
        self.assertTrue(all(checks.values()))

    def test_budget_rejects_elapsed_regression(self):
        _, validation = load_budget(
            ROOT / "compiler/selfhost/WINDOWS_NATIVE_BUDGETS.json",
            "validation",
        )
        checks = measurement_checks(
            {
                "exit_code": 0,
                "elapsed_seconds": validation["max_elapsed_seconds"] + 0.001,
                "peak_private_bytes": 1,
                "peak_working_set_bytes": 1,
            },
            validation,
        )
        self.assertFalse(checks["elapsed_within_budget"])


class Sh21NativeBenchmarkSourceTests(unittest.TestCase):
    def test_native_benchmark_owns_required_gates(self):
        source = (
            ROOT / "compiler/selfhost/source/cli_benchmark.p"
        ).read_text(encoding="utf-8")
        for contract in (
            "openc.native_benchmark.v1",
            "twenty_chained_outputs_close_exactly",
            "public_build_median_at_most_25s",
            "validation_median_below_15s",
            "all_runs_within_memory_limits",
            "tinycc_invoked",
            "external_linker_invoked",
        ):
            self.assertIn(contract, source)

    def test_native_hashing_frees_raw_file_buffers(self):
        source = (
            ROOT / "compiler/selfhost/source/cli_workflow.p"
        ).read_text(encoding="utf-8")
        sha_start = source.index("unsafe bool cli_workflow_sha256")
        hash_start = source.index("unsafe i32 cli_workflow_hash_command")
        helper = source[sha_start:hash_start]
        self.assertIn("file.read_bytes_raw", helper)
        self.assertIn("memory.free(data)", helper)
        self.assertNotIn("file.read_text", helper)


class ReleaseSummaryTests(unittest.TestCase):
    def test_passed_verifier_shape_is_accepted(self):
        result = {
            "status": "PASS",
            "conformance": {"passed": 278, "failed": 0},
            "maintained_programs": [{"passed": True} for _ in range(4)],
            "native_cli": {
                "passed": 12,
                "failed": 0,
                "retained_d_seed_executed": False,
            },
            "native_project_workflow": {
                "passed": 21,
                "failed": 0,
                "retained_d_seed_executed": False,
            },
            "native_language_service": {
                "passed": 19,
                "failed": 0,
                "deterministic_transcript_bytes": True,
                "retained_d_seed_executed": False,
            },
            "native_semantic_language_service": {
                "passed": 23,
                "failed": 0,
                "open_order_independent": True,
                "retained_d_seed_executed": False,
            },
            "environment": {"retained_d_seed_executed": False},
        }
        self.assertTrue(all(verifier_summary_checks(result).values()))

    def test_seed_execution_is_rejected(self):
        result = {
            "status": "PASS",
            "conformance": {"passed": 278, "failed": 0},
            "maintained_programs": [{"passed": True} for _ in range(4)],
            "native_cli": {
                "passed": 12,
                "failed": 0,
                "retained_d_seed_executed": False,
            },
            "native_project_workflow": {
                "passed": 21,
                "failed": 0,
                "retained_d_seed_executed": False,
            },
            "native_language_service": {
                "passed": 19,
                "failed": 0,
                "deterministic_transcript_bytes": True,
                "retained_d_seed_executed": False,
            },
            "native_semantic_language_service": {
                "passed": 23,
                "failed": 0,
                "open_order_independent": True,
                "retained_d_seed_executed": False,
            },
            "environment": {"retained_d_seed_executed": True},
        }
        self.assertFalse(
            verifier_summary_checks(result)["retained_d_seed_not_executed"]
        )


if __name__ == "__main__":
    unittest.main()
