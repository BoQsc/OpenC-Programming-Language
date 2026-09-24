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
        with patch.object(pins_module, "tool_record", fake_tool):
            record = pins_module.discover(pins_module.PINS)
        self.assertEqual(record["status"], "PENDING")
        self.assertFalse(record["pins_ready"])
        self.assertFalse(record["checks"]["pin_status_reviewed"])

    def test_reviewed_literal_digests_enable_proof(self) -> None:
        document = pins_module.load_pins(pins_module.PINS)
        document.update({"status": "PINNED", "cl_sha256": "a" * 64,
                         "link_sha256": "b" * 64, "dmd_sha256": "c" * 64})
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "pins.json"
            path.write_text(json.dumps(document), encoding="utf-8")
            with patch.object(pins_module, "tool_record", fake_tool):
                record = pins_module.discover(path)
            self.assertEqual(record["status"], "PASS")
            self.assertTrue(record["pins_ready"])
            document["dmd_sha256"] = "d" * 64
            path.write_text(json.dumps(document), encoding="utf-8")
            with patch.object(pins_module, "tool_record", fake_tool):
                mismatch = pins_module.discover(path)
            self.assertEqual(mismatch["status"], "FAIL")
            self.assertFalse(mismatch["pins_ready"])


if __name__ == "__main__":
    unittest.main()
