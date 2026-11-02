"""Reject a working-set high-water breach even after live memory falls."""
from __future__ import annotations

from types import SimpleNamespace
from concurrent.futures import ThreadPoolExecutor
import ctypes
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

import windows_process_measure as measure

MIB = 1024 * 1024


class WorkingSetPeakTests(unittest.TestCase):
    def run_child(self, *, exited: bool, peak: int):
        child = SimpleNamespace(pid=7, _handle=11, returncode=0,
            poll=Mock(side_effect=[0] if exited else [None, 0]), wait=Mock(return_value=0), close=Mock())
        kernel = Mock()
        kernel.AssignProcessToJobObject.return_value = 1
        kernel.WaitForSingleObject.return_value = measure.WAIT_OBJECT_0
        counters = SimpleNamespace(PeakWorkingSetSize=peak, WorkingSetSize=8 * MIB,
            PeakPagefileUsage=16 * MIB, PrivateUsage=8 * MIB)
        with patch.object(measure, "_JobProcess", return_value=child), \
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


@unittest.skipUnless(os.name == "nt", "Windows suspended Job startup")
class JobStartupTests(unittest.TestCase):
    def test_child_cannot_execute_before_delayed_job_assignment(self):
        real = measure._job_api()
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "executed.txt"
            proxy = Mock(wraps=real)
            def assign(job, process):
                time.sleep(.15)
                self.assertFalse(marker.exists(), "child ran before Job assignment")
                return real.AssignProcessToJobObject(job, process)
            proxy.AssignProcessToJobObject.side_effect = assign
            with patch.object(measure, "_job_api", return_value=proxy):
                result = measure.run_measured([sys.executable, "-c",
                    f"from pathlib import Path; Path({str(marker)!r}).write_text('ok')"],
                    cwd=directory, max_private_bytes=128 * MIB, timeout_seconds=10)
            self.assertEqual(result["exit_code"], 0)
            self.assertTrue(result["job_assigned_before_child_execution"])
            self.assertEqual(marker.read_text(), "ok")

    def test_assignment_and_resume_failures_terminate_the_suspended_child(self):
        import _winapi
        for failure in ("assignment", "resume"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                marker = Path(directory) / "executed.txt"
                real = measure._job_api()
                proxy = Mock(wraps=real)
                retained = []
                def assign(job, handle):
                    current = _winapi.GetCurrentProcess()
                    retained.append(_winapi.DuplicateHandle(current, handle, current,
                        0, False, _winapi.DUPLICATE_SAME_ACCESS))
                    if failure == "assignment":
                        ctypes.set_last_error(5)
                        return 0
                    return real.AssignProcessToJobObject(job, handle)
                proxy.AssignProcessToJobObject.side_effect = assign
                if failure == "resume":
                    def resume(thread):
                        ctypes.set_last_error(31)
                        return 0xFFFFFFFF
                    proxy.ResumeThread.side_effect = resume
                try:
                    with patch.object(measure, "_job_api", return_value=proxy), self.assertRaises(OSError):
                        measure.run_measured([sys.executable, "-c",
                            f"from pathlib import Path; Path({str(marker)!r}).write_text('bad')"],
                            cwd=directory, timeout_seconds=10)
                    self.assertEqual(len(retained), 1)
                    self.assertEqual(_winapi.WaitForSingleObject(retained[0], 0), measure.WAIT_OBJECT_0)
                    self.assertFalse(marker.exists())
                finally:
                    for handle in retained:
                        _winapi.CloseHandle(handle)

    def test_concurrent_fast_children_keep_separate_output_handles(self):
        def run(index):
            return measure.run_measured([sys.executable, "-c", f"print({index})"],
                cwd=Path.cwd(), max_private_bytes=128 * MIB, timeout_seconds=10)
        with ThreadPoolExecutor(max_workers=4) as executor:
            results = list(executor.map(run, range(32)))
        for index, result in enumerate(results):
            self.assertEqual(result["exit_code"], 0)
            self.assertEqual(result["stdout"], f"{index}{os.linesep}")
            self.assertEqual(result["stderr"], "")

    def test_unrelated_inheritable_file_handle_is_not_exposed_to_child(self):
        import msvcrt
        with tempfile.TemporaryDirectory() as directory:
            sentinel = Path(directory) / "unrelated-inheritable-sentinel.txt"
            sentinel.write_text("private parent data")
            with sentinel.open("rb") as stream:
                handle = msvcrt.get_osfhandle(stream.fileno())
                os.set_handle_inheritable(handle, True)
                child = (
                    "import ctypes,sys; from ctypes import wintypes; "
                    "k=ctypes.WinDLL('kernel32',use_last_error=True); "
                    "k.GetFinalPathNameByHandleW.argtypes=[wintypes.HANDLE,wintypes.LPWSTR,wintypes.DWORD,wintypes.DWORD]; "
                    "b=ctypes.create_unicode_buffer(4096); "
                    f"n=k.GetFinalPathNameByHandleW({handle},b,4096,0); "
                    "sys.exit(2 if n and 'unrelated-inheritable-sentinel.txt' in b.value else 0)"
                )
                result = measure.run_measured([sys.executable, "-c", child],
                    cwd=directory, max_private_bytes=128 * MIB, timeout_seconds=10)
            self.assertEqual(result["exit_code"], 0, result)


if __name__ == "__main__":
    unittest.main()
