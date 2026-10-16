import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import verify_sh27_worker_pool as verifier


class PatchLocationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        source = self.root / "compiler/selfhost/source"
        source.mkdir(parents=True)
        self.names = ["source_without_initial_bom", "record_stride", *(
            value[0] for value in verifier.PHASES.values())]
        self.source = "\n".join(f"unsafe usize {name}() {{ return 0; }}" for name in self.names)
        (source / "main.p").write_text(self.source, encoding="utf-8")
        (source.parent / "openc.project.json").write_text(json.dumps({
            "modules": {"openc.selfhost.main": ["source/main.p"]}}), encoding="utf-8")
        self.image = bytearray(1792)
        self.image[:2] = b"MZ"
        struct.pack_into("<I", self.image, 60, 64)
        self.image[64:68] = b"PE\0\0"
        struct.pack_into("<HH", self.image, 68, 0x8664, 3)
        struct.pack_into("<H", self.image, 84, 240)
        struct.pack_into("<H", self.image, 88, 0x20B)
        for index, (name, size, rva, raw_size, raw) in enumerate([
            (b".text", 1024, 4096, 1024, 512),
            (b".pdata", 96, 8192, 128, 1536),
            (b".rdata", 128, 12288, 128, 1664),
        ]):
            at = 328 + index * 40
            self.image[at:at + len(name)] = name
            struct.pack_into("<IIII", self.image, at + 8, size, rva, raw_size, raw)
        for index in range(8):
            struct.pack_into("<III", self.image, 1536 + index * 12,
                4096 + index * 128, 4096 + (index + 1) * 128, 16384)
        for index, (_, count) in enumerate(verifier.PHASES.values()):
            offset = 512 + (index + 5) * 128
            for number in range(count):
                at = offset + number * 16
                self.image[at:at + len(verifier.CREATE_CALL)] = verifier.CREATE_CALL

    def locate(self):
        with patch.object(verifier, "ROOT", self.root):
            return verifier.patch_locations(bytes(self.image))

    def test_exact_function_and_call_site_joins(self):
        sections, locations, hashes = self.locate()
        self.assertEqual(set(sections), {".text", ".pdata", ".rdata"})
        self.assertEqual({name: len(value) for name, value in locations.items()},
            {"parse": 3, "flow": 4, "native": 4})
        self.assertEqual(locations["flow"], [1280, 1296, 1312, 1328])
        self.assertEqual(hashes["source/main.p"], hashlib.sha256(
            (self.root / "compiler/selfhost/source/main.p").read_bytes()).hexdigest())

    def test_rejects_non_pe(self):
        self.image[:2] = b"XX"
        with self.assertRaises(ValueError):
            self.locate()

    def test_rejects_wrong_architecture(self):
        struct.pack_into("<H", self.image, 68, 0x14C)
        with self.assertRaises(ValueError):
            self.locate()

    def test_rejects_section_outside_file(self):
        struct.pack_into("<I", self.image, 328 + 80 + 20, len(self.image))
        with self.assertRaises(ValueError):
            self.locate()

    def test_rejects_unwind_range_overlap(self):
        struct.pack_into("<I", self.image, 1536 + 12, 4096)
        with self.assertRaises(ValueError):
            self.locate()

    def test_rejects_changed_creation_encoding(self):
        self.image[1280] = 0x90
        with self.assertRaises(ValueError):
            self.locate()

    def test_rejects_source_order_anchor_change(self):
        (self.root / "compiler/selfhost/source/main.p").write_text(
            self.source.replace("record_stride", "renamed_stride"), encoding="utf-8")
        with self.assertRaises(ValueError):
            self.locate()

    def test_rejects_source_function_count_change(self):
        (self.root / "compiler/selfhost/source/main.p").write_text(
            self.source + "\nunsafe usize extra() { return 0; }", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.locate()


if __name__ == "__main__":
    unittest.main()
