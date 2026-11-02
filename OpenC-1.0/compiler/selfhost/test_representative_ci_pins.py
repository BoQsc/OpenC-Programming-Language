#!/usr/bin/env python3
"""Pin-state tests that do not need hosted C/D toolchains."""
from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import representative_ci_pins as pins_module


def fake_tool(name: str, arguments: list[str]) -> dict[str, object]:
    identity = {"cl.exe": "a", "link.exe": "b", "dmd.exe": "c"}[name]
    version = "Compiler Version 19.44" if name == "cl.exe" else (
        "DMD64 D Compiler v2.112.0" if name == "dmd.exe" else "link"
    )
    return {"path": name, "sha256": identity * 64,
            "version_command": [name, *arguments],
            "version_exit_code": 0, "version_output": version}


class RepresentativePinTests(unittest.TestCase):
    def test_discovery_never_counts_as_pin(self) -> None:
        document = pins_module.load_pins(pins_module.PINS)
        document.update({"status": "PENDING_DISCOVERY", "msvc_variants": [],
                         "dmd_sha256": None})
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "pins.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            with patch.object(pins_module, "tool_record", fake_tool), patch.dict(
                pins_module.os.environ, {"ImageVersion": "test-image"}
            ):
                record = pins_module.discover(path)
        self.assertEqual(record["status"], "PENDING")
        self.assertFalse(record["pins_ready"])
        self.assertFalse(record["checks"]["pin_status_reviewed"])

    def test_reviewed_literal_digests_enable_proof(self) -> None:
        document = pins_module.load_pins(pins_module.PINS)
        document.update({
            "status": "PINNED", "dmd_sha256": "c" * 64,
            "msvc_variants": [
                {"runner_image_version": "image-a", "cl_sha256": "a" * 64,
                 "link_sha256": "b" * 64},
                {"runner_image_version": "image-b", "cl_sha256": "d" * 64,
                 "link_sha256": "e" * 64},
            ],
        })
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "pins.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            with patch.object(pins_module, "tool_record", fake_tool), patch.dict(
                pins_module.os.environ, {"ImageVersion": "image-a"}
            ):
                record = pins_module.discover(path)
            self.assertEqual(record["status"], "PASS")
            self.assertTrue(record["pins_ready"])
            self.assertEqual(record["selected_msvc_variant"]["runner_image_version"],
                             "image-a")
            with patch.object(pins_module, "tool_record", fake_tool), patch.dict(
                pins_module.os.environ, {"ImageVersion": "image-b"}
            ):
                other_image = pins_module.discover(path)
            self.assertEqual(other_image["status"], "FAIL")
            self.assertTrue(other_image["checks"]["runner_image_reviewed"])
            self.assertFalse(other_image["checks"]["cl_sha256_matches"])
            def crossed_pair(name: str, arguments: list[str]) -> dict[str, object]:
                record = fake_tool(name, arguments)
                if name == "link.exe":
                    record["sha256"] = "e" * 64
                return record
            with patch.object(pins_module, "tool_record", crossed_pair), patch.dict(
                pins_module.os.environ, {"ImageVersion": "image-a"}
            ):
                mixed = pins_module.discover(path)
            self.assertEqual(mixed["status"], "FAIL")
            self.assertTrue(mixed["checks"]["cl_sha256_matches"])
            self.assertFalse(mixed["checks"]["link_sha256_matches"])
            with patch.object(pins_module, "tool_record", fake_tool), patch.dict(
                pins_module.os.environ, {"ImageVersion": "unreviewed"}
            ):
                unreviewed = pins_module.discover(path)
            self.assertFalse(unreviewed["checks"]["runner_image_reviewed"])
            document["dmd_sha256"] = "d" * 64
            path.write_text(json.dumps(document), encoding="utf-8")
            with patch.object(pins_module, "tool_record", fake_tool), patch.dict(
                pins_module.os.environ, {"ImageVersion": "image-a"}
            ):
                mismatch = pins_module.discover(path)
            self.assertEqual(mismatch["status"], "FAIL")
            self.assertFalse(mismatch["pins_ready"])


if __name__ == "__main__":
    unittest.main()
