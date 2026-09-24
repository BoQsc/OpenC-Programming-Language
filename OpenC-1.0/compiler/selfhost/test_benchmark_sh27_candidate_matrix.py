#!/usr/bin/env python3
"""Pure decision tests for the SH-27 multi-candidate comparison gate."""
from __future__ import annotations

import unittest

from benchmark_sh27_candidate_matrix import candidate_spec, compare_pairs, matrix_status
from analyze_sh27_candidate_matrix import numeric_phase


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
