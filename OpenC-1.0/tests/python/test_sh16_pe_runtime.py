import importlib.util
import struct
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "verify_sh16_pe_runtime", ROOT / "scripts/verify_sh16_pe_runtime.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)

BRIDGE_SPEC = importlib.util.spec_from_file_location(
    "bootstrap_sh16_binary_intrinsic",
    ROOT / "compiler/selfhost/bootstrap_sh16_binary_intrinsic.py",
)
BRIDGE = importlib.util.module_from_spec(BRIDGE_SPEC)
assert BRIDGE_SPEC.loader is not None
sys.modules[BRIDGE_SPEC.name] = BRIDGE
BRIDGE_SPEC.loader.exec_module(BRIDGE)


class Sh16PeRuntimeTests(unittest.TestCase):
    def test_parser_reads_minimal_pe32_plus_shape(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "minimal.exe"
            data = bytearray(512)
            data[:2] = b"MZ"
            struct.pack_into("<I", data, 0x3C, 0x80)
            data[0x80:0x84] = b"PE\0\0"
            struct.pack_into("<HHIIIHH", data, 0x84, 0x8664, 0, 0, 0, 0, 240, 0x22)
            struct.pack_into("<H", data, 0x98, 0x20B)
            struct.pack_into("<I", data, 0x98 + 108, 0)
            path.write_bytes(data)
            image = MODULE.PeImage(path)
            self.assertEqual(image.machine, 0x8664)
            self.assertEqual(image.section_count, 0)
            self.assertEqual(image.optional_size, 240)

    def test_non_pe_input_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "not-pe.bin"
            path.write_bytes(b"not a PE image")
            with self.assertRaises(ValueError):
                MODULE.PeImage(path)

    def test_bootstrap_bridge_patches_only_intrinsic_result_type(self) -> None:
        source = "    void v42;\n    v42 = oc_file_write_bytes(a, b, c);\n"
        patched, temporary = BRIDGE.patch_binary_intrinsic_temporary(source)
        self.assertEqual(temporary, "v42")
        self.assertEqual(
            patched,
            "    oc_status v42;\n    v42 = oc_file_write_bytes(a, b, c);\n",
        )


if __name__ == "__main__":
    unittest.main()
