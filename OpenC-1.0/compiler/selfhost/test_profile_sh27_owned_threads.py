import ctypes
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

from profile_sh27_owned_threads import function_at, OwnedSampler


class FunctionLookupTests(unittest.TestCase):
    def test_half_open_ranges_and_gaps(self):
        ranges = [(100, 110, 'one'), (120, 150, 'two')]
        starts = [100, 120]
        for address, expected in ((-1, '<outside compiler>'),
                (99, '<outside compiler>'), (100, 'one'), (109, 'one'),
                (110, '<outside compiler>'), (119, '<outside compiler>'),
                (120, 'two'), (149, 'two'), (150, '<outside compiler>')):
            self.assertEqual(function_at(ranges, starts, address), expected)

    def test_empty_map(self):
        self.assertEqual(function_at([], [], 10), '<outside compiler>')


class OwnedThreadSafetyTests(unittest.TestCase):
    def setUp(self):
        self.compiler = Path('test-owned-compiler.exe').resolve()
        self.sampler = OwnedSampler(self.compiler, [(100, 110, 'test-function')])
        self.process = Mock(pid=12345)
        self.process.poll.side_effect = [None, 0]
        self.sampler.process = self.process
        self.kernel = Mock()
        self.kernel.CreateToolhelp32Snapshot.side_effect = [111, 222]
        self.kernel.OpenThread.return_value = 333
        self.kernel.SuspendThread.return_value = 0
        self.kernel.ResumeThread.return_value = 1
        self.kernel.Thread32Next.return_value = False
        self.owner = self.process.pid
        def module(snapshot, destination):
            destination._obj.path = str(self.compiler)
            destination._obj.base = 0x140000000
            return True
        def thread(snapshot, destination):
            destination._obj.process = self.owner
            destination._obj.thread = 67890
            return True
        def cycles(handle, destination):
            destination._obj.value = 100000
            return True
        def context(handle, address):
            ctypes.c_uint64.from_address(address + 248).value = 0x140000000 + 103
            return True
        self.kernel.Module32FirstW.side_effect = module
        self.kernel.Thread32First.side_effect = thread
        self.kernel.QueryThreadCycleTime.side_effect = cycles
        self.kernel.GetThreadContext.side_effect = context

    def run_sample(self):
        with patch('ctypes.WinDLL', return_value=self.kernel, create=True):
            self.sampler.sample()

    def test_success_resumes_and_closes_every_owned_handle(self):
        self.run_sample()
        self.assertEqual(self.sampler.samples[0]['function'], 'test-function')
        self.kernel.ResumeThread.assert_called_once_with(333)
        self.assertEqual(self.kernel.CloseHandle.call_count, 3)
        self.assertEqual(self.sampler.errors, [])

    def test_context_failure_still_resumes(self):
        self.kernel.GetThreadContext.side_effect = None
        self.kernel.GetThreadContext.return_value = False
        self.run_sample()
        self.kernel.ResumeThread.assert_called_once_with(333)
        self.assertEqual(self.sampler.samples, [])

    def test_context_exception_still_resumes(self):
        self.kernel.GetThreadContext.side_effect = RuntimeError('test-context-error')
        self.run_sample()
        self.kernel.ResumeThread.assert_called_once_with(333)
        self.process.kill.assert_not_called()
        self.assertEqual(self.sampler.errors, ['test-context-error'])

    def test_resume_failure_terminates_only_the_owned_child(self):
        self.kernel.ResumeThread.return_value = 0xFFFFFFFF
        self.run_sample()
        self.process.kill.assert_called_once_with()
        self.assertIn('could not resume owned child', self.sampler.errors[0])

    def test_other_process_threads_are_never_opened(self):
        self.owner = 54321
        self.run_sample()
        self.kernel.OpenThread.assert_not_called()
        self.kernel.SuspendThread.assert_not_called()

    def test_failed_suspend_is_never_resumed(self):
        self.kernel.SuspendThread.return_value = 0xFFFFFFFF
        self.run_sample()
        self.kernel.GetThreadContext.assert_not_called()
        self.kernel.ResumeThread.assert_not_called()


if __name__ == '__main__':
    unittest.main()
