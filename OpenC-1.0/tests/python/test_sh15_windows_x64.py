from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "verify_sh15_windows_x64.py"
SPEC = importlib.util.spec_from_file_location("verify_sh15_windows_x64", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
VERIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY)


class Sh15WindowsX64Tests(unittest.TestCase):
    def test_runtime_function_is_pe_x64_twelve_byte_record(self) -> None:
        self.assertEqual(VERIFY.ctypes.sizeof(VERIFY.RuntimeFunction), 12)

    def test_code_bytes_decodes_named_machine_code(self) -> None:
        report = {
            "machine_code": {
                "return": {"bytes": "c3", "length": 1, "relocations": 0}
            }
        }
        self.assertEqual(VERIFY.code_bytes(report, "return"), b"\xc3")


if __name__ == "__main__":
    unittest.main()
