"""Unit tests for the SH-8 native toolchain and performance contracts."""
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
                "backend": "c11-tinycc-win64",
                "dmd_invoked": False,
                "dub_invoked": False,
                "python_invoked": False,
            }
            Path(str(compiler) + ".build.json").write_text(
                json.dumps(record), encoding="utf-8"
            )
            required = [
                distribution / "runtime/common/source/openc_runtime.c",
                distribution
                / "runtime/windows/source/openc_platform_windows.c",
                distribution
                / "compiler/selfhost/native_runtime/openc_sh5_runtime.c",
                distribution / "third_party/tinycc-win64/tcc.exe",
            ]
            for path in required:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"present")
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


class ReleaseSummaryTests(unittest.TestCase):
    def test_passed_verifier_shape_is_accepted(self):
        result = {
            "status": "PASS",
            "conformance": {"passed": 278, "failed": 0},
            "maintained_programs": [{"passed": True} for _ in range(4)],
            "environment": {"retained_d_seed_executed": False},
        }
        self.assertTrue(all(verifier_summary_checks(result).values()))

    def test_seed_execution_is_rejected(self):
        result = {
            "status": "PASS",
            "conformance": {"passed": 278, "failed": 0},
            "maintained_programs": [{"passed": True} for _ in range(4)],
            "environment": {"retained_d_seed_executed": True},
        }
        self.assertFalse(
            verifier_summary_checks(result)["retained_d_seed_not_executed"]
        )


if __name__ == "__main__":
    unittest.main()
