#!/usr/bin/env python3
"""Pure decision tests for the SH-27 multi-candidate comparison gate."""
from __future__ import annotations

import argparse
import json
import unittest
from pathlib import Path

from benchmark_sh27_candidate_matrix import (
    ROOT, candidate_spec, chunk_policy_spec, compare_pairs, matrix_status, sample_paths_within_budget,
    sample_root_path, validate_matrix_corpus, paired_order,
)
from analyze_sh27_candidate_matrix import numeric_phase
from benchmark_sh27_production import validate_corpus


def sample(
    seconds: float, digest: str, passed: bool = True,
    program_stdout: str = "empty",
) -> dict[str, object]:
    return {
        "elapsed_seconds": seconds,
        "output_sha256": digest,
        "passed": passed,
        "program_exit_code": 0,
        "program_stdout_sha256": program_stdout,
        "program_stderr_sha256": "empty",
        "peak_private_bytes": 10,
        "peak_job_private_bytes": 20,
        "peak_working_set_bytes": 5,
    }


class CandidateMatrixTests(unittest.TestCase):
    def test_each_candidate_alternates_independently_of_rotation(self):
        for count in range(1, 7):
            names = [f"candidate{i}" for i in range(count)] + ["__null__"]
            orders = {name: [] for name in names}
            for pair in range(11):
                rotated = names[pair % len(names):] + names[:pair % len(names)]
                for name in rotated:
                    orders[name].append(paired_order(pair, name, names))
            for name, observed in orders.items():
                with self.subTest(count=count, name=name):
                    self.assertTrue(all(a != b for a, b in zip(observed, observed[1:])))
                    self.assertEqual(abs(sum(o[0] == "baseline" for o in observed)
                                         - sum(o[0] == name for o in observed)), 1)

    def test_function_scale_is_distinct_from_frozen_production_corpus(self):
        production = json.loads((ROOT / "benchmarks/sh27/CORPUS.json").read_text(encoding="utf-8"))
        scale = json.loads((ROOT / "benchmarks/sh27/FUNCTION_SCALE.json").read_text(encoding="utf-8"))
        validate_corpus(production)
        validate_corpus(scale)
        self.assertEqual(production["limits"]["maximum_operations_per_function"], 64)
        self.assertEqual([w["operations_per_function"] for w in scale["workloads"]], [64, 256, 1024])
        self.assertFalse({w["id"] for w in production["workloads"]} & {w["id"] for w in scale["workloads"]})
        self.assertTrue(all(w["source_files"] == w["functions_per_file"] == 1 for w in scale["workloads"]))
        validate_matrix_corpus(production)
        validate_matrix_corpus(scale)

    def test_custom_metadata_cannot_expand_generator_work_without_bound(self):
        for files, functions, operations in ((129, 1, 1), (1, 10000, 1024), (1, 1, 1025)):
            corpus = json.loads((ROOT / "benchmarks/sh27/FUNCTION_SCALE.json").read_text(encoding="utf-8"))
            corpus["workloads"] = [{"id": "test", "source_files": files,
                "functions_per_file": functions, "operations_per_function": operations}]
            corpus["limits"] = {"maximum_source_files_per_workload": 1000000,
                "maximum_total_functions_per_workload": 1000000, "maximum_operations_per_function": 1000000}
            with self.assertRaises(SystemExit):
                validate_matrix_corpus(corpus)

    def test_custom_metadata_rejects_path_escape_and_excess_workload_count(self):
        corpus = json.loads((ROOT / "benchmarks/sh27/FUNCTION_SCALE.json").read_text(encoding="utf-8"))
        corpus["workloads"][0]["id"] = "../escape"
        with self.assertRaises(SystemExit):
            validate_matrix_corpus(corpus)
        corpus["workloads"] = [{"id": f"test_{i}", "source_files": 1,
            "functions_per_file": 1, "operations_per_function": 1} for i in range(17)]
        with self.assertRaises(SystemExit):
            validate_matrix_corpus(corpus)

    def test_explicit_worker_policy_is_declared_per_candidate(self):
        for policy in ("default", "auto", "1", "2", "4"):
            self.assertEqual(chunk_policy_spec("trial=" + policy), ("trial", policy))

    def test_worker_policy_rejects_unsupported_modes(self):
        for value in ("trial=0", "trial=3", "trial=8", "trial=", "trial", "=2", "../trial=2"):
            with self.assertRaises(argparse.ArgumentTypeError):
                chunk_policy_spec(value)

    def test_native_sample_path_budget_covers_null_sidecar(self) -> None:
        root = Path("C:/short/m-abcdefgh")
        sample_root = sample_root_path(
            root, "large_functions", 10, "__null__", "__null__"
        )
        self.assertEqual(sample_root.name, "__null__")
        self.assertTrue(sample_paths_within_budget(
            root, ["large_functions"], ["latest"], 11
        ))
        self.assertFalse(sample_paths_within_budget(
            Path("C:/" + "deep/" * 48), ["large_functions"],
            ["latest"], 11
        ))

    def test_top_level_requires_passing_null_control(self) -> None:
        lanes = {
            "large_functions": {
                "noise_control": {"status": "FAIL"},
                "comparisons": {"candidate1": {"status": "PASS"}},
            }
        }
        self.assertEqual(matrix_status(lanes), "FAIL")
        lanes["large_functions"]["noise_control"]["status"] = "PASS"
        self.assertEqual(matrix_status(lanes), "PASS")

    def test_paired_gain_and_exact_binary(self) -> None:
        pairs = [
            {"baseline": sample(1.0, "same"), "candidate": sample(0.8, "same")},
            {"baseline": sample(1.1, "same"), "candidate": sample(0.9, "same")},
            {"baseline": sample(1.0, "same"), "candidate": sample(0.7, "same")},
        ]
        result = compare_pairs(
            pairs, allow_binary_difference=False, require_gain=True
        )
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["candidate_wins"], 3)
        self.assertTrue(result["checks"]["generated_binaries_byte_exact"])

    def test_different_binary_needs_explicit_policy(self) -> None:
        pairs = [
            {"baseline": sample(1.0, "old"), "candidate": sample(0.8, "new")}
            for _ in range(3)
        ]
        strict = compare_pairs(
            pairs, allow_binary_difference=False, require_gain=True
        )
        relaxed = compare_pairs(
            pairs, allow_binary_difference=True, require_gain=True
        )
        self.assertEqual(strict["status"], "FAIL")
        self.assertEqual(relaxed["status"], "PASS")

    def test_gain_below_null_noise_is_not_accepted(self) -> None:
        pairs = [
            {"baseline": sample(1.0, "same"), "candidate": sample(0.96, "same")}
            for _ in range(3)
        ]
        result = compare_pairs(
            pairs, allow_binary_difference=False, require_gain=True,
            noise_floor_seconds=0.05,
        )
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(result["checks"]["paired_speed_gain_observed"])
        self.assertFalse(result["checks"]["paired_gain_above_null_noise"])

    def test_failure_and_nondeterminism_are_not_speed_wins(self) -> None:
        pairs = [
            {"baseline": sample(1.0, "same"), "candidate": sample(0.8, "same")},
            {"baseline": sample(1.0, "same"), "candidate": sample(0.8, "other")},
            {"baseline": sample(1.0, "same"), "candidate": sample(0.8, "same", False)},
        ]
        result = compare_pairs(
            pairs, allow_binary_difference=True, require_gain=True
        )
        self.assertEqual(result["status"], "FAIL")
        self.assertFalse(result["checks"]["candidate_binary_deterministic"])
        self.assertFalse(
            result["checks"]["all_compiles_executions_and_memory_guards_passed"]
        )

    def test_codegen_difference_does_not_allow_runtime_output_difference(self) -> None:
        pairs = [
            {
                "baseline": sample(1.0, "old"),
                "candidate": sample(0.8, "new", program_stdout="surprise"),
            }
            for _ in range(3)
        ]
        result = compare_pairs(
            pairs, allow_binary_difference=True, require_gain=False
        )
        self.assertEqual(result["status"], "FAIL")
        self.assertFalse(result["checks"]["all_program_outputs_byte_exact"])

    def test_candidate_name_is_path_safe(self) -> None:
        name, path = candidate_spec("typed_ops=C:\\artifact\\openc.exe")
        self.assertEqual(name, "typed_ops")
        self.assertEqual(path.name, "openc.exe")
        with self.assertRaises(Exception):
            candidate_spec("../outside=compiler.exe")

    def test_nested_phase_extraction_is_explicit(self) -> None:
        sample_record = {
            "compiler_timings": {
                "total_ms": 100,
                "phases_ms": {"declarations": 20},
                "native_parallel_profile": {
                    "critical_chunk": {"acceptance_ms": 30}
                },
            }
        }
        self.assertEqual(numeric_phase(sample_record, "total_ms"), 100)
        self.assertEqual(
            numeric_phase(sample_record, "phases_ms.declarations"), 20
        )
        self.assertEqual(numeric_phase(sample_record, "acceptance_ms"), 30)
        self.assertIsNone(numeric_phase(sample_record, "native_emit_ms"))


if __name__ == "__main__":
    unittest.main()
