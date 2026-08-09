from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "compiler" / "selfhost" / "benchmark_throughput_suite.py"
SPEC = importlib.util.spec_from_file_location("benchmark_throughput_suite", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
SUITE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SUITE)


class ThroughputSuiteTests(unittest.TestCase):
    def test_summarize_preserves_raw_samples_and_median(self) -> None:
        summary = SUITE.summarize([
            {"elapsed_seconds": 12.0},
            {"elapsed_seconds": 10.0},
            {"elapsed_seconds": 11.0},
        ])
        self.assertEqual(summary["runs"], 3)
        self.assertEqual(summary["minimum_seconds"], 10.0)
        self.assertEqual(summary["median_seconds"], 11.0)
        self.assertEqual(summary["maximum_seconds"], 12.0)
        self.assertEqual(summary["raw_seconds"], [12.0, 10.0, 11.0])

    def test_evaluate_requires_absolute_and_relative_gates(self) -> None:
        passing = SUITE.evaluate(
            {"median_seconds": 25.0, "maximum_seconds": 40.0},
            {"median_seconds": 22.0, "maximum_seconds": 25.0},
            median_limit=30.0,
            every_limit=45.0,
            ratio_limit=1.25,
        )
        self.assertTrue(all(passing.values()))
        failing = SUITE.evaluate(
            {"median_seconds": 30.0, "maximum_seconds": 46.0},
            {"median_seconds": 20.0, "maximum_seconds": 21.0},
            median_limit=30.0,
            every_limit=45.0,
            ratio_limit=1.25,
        )
        self.assertTrue(failing["openc_clean_median_within_absolute_gate"])
        self.assertFalse(failing["every_openc_clean_run_within_absolute_gate"])
        self.assertFalse(failing["openc_median_within_d_ratio_gate"])


if __name__ == "__main__":
    unittest.main()
