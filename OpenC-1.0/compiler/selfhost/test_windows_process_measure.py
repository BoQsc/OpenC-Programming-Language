"""Reject a working-set high-water breach even after live memory falls."""
from __future__ import annotations

from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import windows_process_measure as measure

MIB = 1024 * 1024


class WorkingSetPeakTests(unittest.TestCase):
    def run_child(self, *, exited: bool, peak: int):
        child = SimpleNamespace(pid=7, _handle=11, returncode=0,
            poll=Mock(side_effect=[0] if exited else [None, 0]), wait=Mock(return_value=0))
        kernel = Mock()
        kernel.AssignProcessToJobObject.return_value = 1
        kernel.WaitForSingleObject.return_value = measure.WAIT_OBJECT_0
        counters = SimpleNamespace(PeakWorkingSetSize=peak, WorkingSetSize=8 * MIB,
            PeakPagefileUsage=16 * MIB, PrivateUsage=8 * MIB)
        with patch.object(measure.subprocess, "Popen", return_value=child), \
             patch.object(measure, "_open_process", return_value=13), \
             patch.object(measure, "_process_memory", return_value=counters), \
             patch.object(measure, "_job_peak_private", return_value=16 * MIB):
            result = measure._run_measured_in_job(["owned-test.exe"], cwd=".",
                environment=None, sample_interval=.01, max_working_set_bytes=64 * MIB,
                max_private_bytes=256 * MIB, max_captured_output_bytes=1024,
                timeout_seconds=None, kernel32=kernel, job=17)
        return result, kernel

    def test_rejects_peak_when_current_usage_has_already_fallen(self):
        result, kernel = self.run_child(exited=False, peak=80 * MIB)
        self.assertTrue(result["memory_limit_exceeded"])
        self.assertEqual(result["memory_limit_name"], "working_set_bytes")
        self.assertEqual(result["memory_observed_bytes"], 80 * MIB)
        kernel.TerminateJobObject.assert_called_once_with(17, 1)

    def test_rejects_peak_first_observed_after_exit(self):
        result, kernel = self.run_child(exited=True, peak=80 * MIB)
        self.assertTrue(result["memory_limit_exceeded"])
        self.assertEqual(result["peak_working_set_bytes"], 80 * MIB)
        self.assertEqual(result["memory_observed_bytes"], 80 * MIB)
        kernel.TerminateJobObject.assert_not_called()

    def test_exact_cap_is_allowed(self):
        result, _ = self.run_child(exited=False, peak=64 * MIB)
        self.assertFalse(result["memory_limit_exceeded"])


if __name__ == "__main__":
    unittest.main()
