import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "verify_sh11_lsp.py"
SPEC = importlib.util.spec_from_file_location("verify_sh11_lsp", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class LspFramingTests(unittest.TestCase):
    def test_frame_round_trip_uses_utf8_byte_length(self):
        message = {
            "jsonrpc": "2.0",
            "method": "example",
            "params": {"text": "OpenC \u03bc"},
        }
        framed = MODULE.frame_bytes(message)
        self.assertEqual(MODULE.read_frame(io.BytesIO(framed)), message)
        header, body = framed.split(b"\r\n\r\n", 1)
        self.assertEqual(int(header.split(b":", 1)[1]), len(body))

    def test_missing_content_length_is_rejected(self):
        with self.assertRaises(ValueError):
            MODULE.read_frame(io.BytesIO(b"Other: value\r\n\r\n{}"))

    def test_truncated_body_is_rejected(self):
        with self.assertRaises(EOFError):
            MODULE.read_frame(io.BytesIO(b"Content-Length: 4\r\n\r\n{}"))


class LspContractTests(unittest.TestCase):
    def test_fixture_is_complete(self):
        fixture = json.loads(
            (
                ROOT
                / "tests"
                / "tooling"
                / "sh11"
                / "session.json"
            ).read_text(encoding="utf-8")
        )
        self.assertEqual(fixture["schema"], "openc.lsp_session.v1")
        self.assertTrue(fixture["uri"].startswith("file:///"))
        self.assertNotEqual(fixture["valid_source"], fixture["formatted_source"])

    def test_transcript_record_has_stable_shape(self):
        record = MODULE.transcript_record(
            [
                {
                    "direction": "client-to-server",
                    "message": {"jsonrpc": "2.0", "method": "exit"},
                }
            ]
        )
        self.assertEqual(record["schema"], "openc.lsp_transcript.v1")
        self.assertEqual(record["transport"], "stdio-content-length")
        self.assertEqual(
            MODULE.canonical_json(record),
            MODULE.canonical_json(record),
        )


if __name__ == "__main__":
    unittest.main()
