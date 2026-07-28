import importlib.util
import json
from pathlib import Path
import sys
import unittest

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "verify_sh12_semantic_lsp.py"
SPEC = importlib.util.spec_from_file_location(
    "verify_sh12_semantic_lsp", SCRIPT
)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class SemanticLspContractTests(unittest.TestCase):
    def test_fixture_describes_project_and_outside_document(self):
        fixture = json.loads(
            (
                ROOT / "tests" / "tooling" / "sh12" / "session.json"
            ).read_text(encoding="utf-8")
        )
        self.assertEqual(
            fixture["schema"], "openc.semantic_lsp_session.v1"
        )
        self.assertTrue(
            fixture["documents"]["main"]["uri"].startswith(
                fixture["root_uri"]
            )
        )
        self.assertFalse(
            fixture["documents"]["outside"]["uri"].startswith(
                fixture["root_uri"]
            )
        )

    def test_semantic_record_validates(self):
        fixture = json.loads(
            (
                ROOT / "tests" / "tooling" / "sh12" / "session.json"
            ).read_text(encoding="utf-8")
        )
        messages = []
        for request_id, method in enumerate(
            MODULE.SEMANTIC_METHODS, 1
        ):
            messages.extend(
                [
                    {
                        "direction": "client-to-server",
                        "message": {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "method": method,
                        },
                    },
                    {
                        "direction": "server-to-client",
                        "message": {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "result": None,
                        },
                    },
                ]
            )
        record = MODULE.semantic_record(fixture, messages)
        schema = json.loads(
            (
                ROOT
                / "schemas"
                / "SEMANTIC_LSP_TRANSCRIPT.schema.json"
            ).read_text(encoding="utf-8")
        )
        Draft202012Validator(schema).validate(record)
        self.assertEqual(
            record["semanticMethods"], MODULE.SEMANTIC_METHODS
        )
        self.assertEqual(record["documents"], sorted(record["documents"]))

    def test_symbol_lookup_is_total(self):
        response = {"result": [{"name": "Point", "kind": 23}]}
        self.assertEqual(
            MODULE.symbol_by_name(response, "Point")["kind"], 23
        )
        self.assertEqual(MODULE.symbol_by_name(response, "Missing"), {})


if __name__ == "__main__":
    unittest.main()
