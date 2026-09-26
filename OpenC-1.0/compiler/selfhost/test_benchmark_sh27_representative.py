#!/usr/bin/env python3
"""Lightweight manifest/staging checks; never invokes a compiler."""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchmark_sh27_representative import (
    DEFAULT_SUITE, apply_edit, edit_comparator, load_suite, source_paths,
    stage_comparator, stage_project, summarize,
)


class RepresentativeSuiteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.suite = load_suite(DEFAULT_SUITE)
        self.workloads = {item["id"]: item for item in self.suite["workloads"]}

    def test_three_distinct_project_sizes(self) -> None:
        counts = [
            len(source_paths(Path(__file__).resolve().parents[2] /
                             item["project"])[1])
            for item in self.suite["workloads"]
        ]
        self.assertEqual(counts, [1, 4, 228])

    def test_source_edit_changes_only_staged_tree(self) -> None:
        workload = self.workloads["medium_audit"]
        with tempfile.TemporaryDirectory() as temporary:
            stage = Path(temporary) / "project"
            project, original = stage_project(workload, stage)
            self.assertTrue(project.is_file())
            self.assertTrue((stage / "sample.log").is_file())
            edited = apply_edit(workload, stage)
            self.assertNotEqual(original["sha256"], edited["sha256"])
            self.assertIn("hash * 33", (stage / "source/score.p").read_text())
            checked_in = Path(__file__).resolve().parents[2] / (
                "benchmarks/sh27/representative/medium_audit/source/score.p"
            )
            self.assertIn("hash * 31", checked_in.read_text())

    def test_manifest_rejects_ambiguous_edit(self) -> None:
        suite = json.loads(DEFAULT_SUITE.read_text(encoding="utf-8"))
        suite["workloads"][0]["edit"]["old"] = "io.print"
        with tempfile.TemporaryDirectory() as temporary:
            manifest = Path(temporary) / "invalid-suite.json"
            manifest.write_text(json.dumps(suite), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "not unique"):
                load_suite(manifest)

    def test_summary_keeps_raw_and_memory_peaks(self) -> None:
        sample = {
            "cases": {
                "cold": {
                    "status": "PASS",
                    "build": {
                        "elapsed_seconds": 0.25,
                        "peak_private_bytes": 10,
                        "peak_job_private_bytes": 11,
                        "peak_working_set_bytes": 9,
                    },
                },
            },
        }
        result = summarize([sample])
        self.assertEqual(result["cold"]["raw_compile_seconds"], [0.25])
        self.assertEqual(result["cold"]["peak_job_private_bytes"], 11)
        self.assertEqual(result["warm"]["attempted"], 0)

    def test_comparator_fixtures_stage_and_edit_independently(self) -> None:
        workload = self.workloads["medium_audit"]
        with tempfile.TemporaryDirectory() as temporary:
            for language in ("c", "d"):
                source, original = stage_comparator(
                    workload, language, Path(temporary) / language
                )
                self.assertTrue((source.parent / "sample.log").is_file())
                edited = edit_comparator(workload, language, source)
                self.assertNotEqual(original["sha256"], edited["sha256"])
                self.assertIn("hash * 33", source.read_text())

    def test_log_input_matches_literal_expected_outputs(self) -> None:
        workload = self.workloads["medium_audit"]
        source = Path(__file__).resolve().parents[2] / (
            "benchmarks/sh27/representative/medium_audit/sample.log"
        )
        data = source.read_bytes()
        lines = data.count(b"\n") + int(bool(data) and data[-1] != 10)
        digits = sum(48 <= value <= 57 for value in data)
        warnings = sum(data[index:index + 4] == b"WARN"
                       for index in range(len(data)))
        for multiplier, expected in (
            (31, workload["expected_stdout_utf8"]),
            (33, workload["edit"]["expected_stdout_utf8"]),
        ):
            fingerprint = 0
            for value in data:
                fingerprint = (fingerprint * multiplier + value) % 65521
            self.assertEqual(
                expected,
                f"lines={lines}\ndigits={digits}\nwarnings={warnings}\n"
                f"fingerprint={fingerprint}\n",
            )


if __name__ == "__main__":
    unittest.main()
