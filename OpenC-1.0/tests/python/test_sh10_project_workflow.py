from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SELFHOST = ROOT / "compiler" / "selfhost"


class Sh10ProjectWorkflowSourceTests(unittest.TestCase):
    def test_public_commands_are_dispatched_natively(self) -> None:
        source = (SELFHOST / "source" / "main_driver.p").read_text(
            encoding="utf-8"
        )
        for command, function in (
            ("fmt", "cli_format_command"),
            ("info", "cli_info_command"),
            ("test", "cli_test_command"),
        ):
            self.assertIn(f'== "{command}"', source)
            self.assertIn(function, source)

    def test_formatter_contract_is_stable(self) -> None:
        source = (SELFHOST / "source" / "cli_format.p").read_text(
            encoding="utf-8"
        )
        workflow = (
            SELFHOST / "source" / "cli_project_workflow.p"
        ).read_text(encoding="utf-8")
        self.assertIn('"--parse"', source)
        self.assertIn("state.indent * 4", source)
        self.assertIn("openc.format.v1", workflow)
        self.assertIn("UTF-8", workflow)
        self.assertIn("source_extension", workflow)
        schema = json.loads(
            (ROOT / "schemas" / "FORMAT_RESULT.schema.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            schema["properties"]["schema"]["const"], "openc.format.v1"
        )

    def test_info_context_has_required_views(self) -> None:
        source = (
            SELFHOST / "source" / "cli_project_workflow.p"
        ).read_text(encoding="utf-8")
        self.assertIn("openc.tool_context.v1", source)
        for view in (
            "sources",
            "modules",
            "limits",
            "dependencies",
            "target",
            "types",
        ):
            self.assertIn(f'"--{view}"', source)
        self.assertIn("environment_inputs_consulted", source)

    def test_test_runner_records_failure_classes(self) -> None:
        source = (
            SELFHOST / "source" / "cli_project_workflow.p"
        ).read_text(encoding="utf-8")
        self.assertIn("openc.test_result.v1", source)
        for status in (
            "LANGUAGE_FAILURE",
            "ASSERTION_FAILURE",
            "INFRASTRUCTURE_FAILURE",
        ):
            self.assertIn(status, source)
        self.assertIn("name-sorted", source)
        self.assertIn("openc-stable32", source)
        schema = json.loads(
            (ROOT / "schemas" / "TEST_RESULT.schema.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            schema["properties"]["schema"]["const"], "openc.test_result.v1"
        )

    def test_checked_in_test_manifest_is_deterministic(self) -> None:
        path = ROOT / "tests" / "tooling" / "sh10" / "openc.tests.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        names = [item["name"] for item in data["tests"]]
        self.assertEqual(names, sorted(names))
        self.assertEqual(data["schema"], "openc.test_manifest.v1")
        self.assertTrue(all(item["project"].endswith(".json") for item in data["tests"]))

    def test_native_verifier_covers_all_three_commands(self) -> None:
        source = (
            ROOT / "scripts" / "verify_sh10_project_workflow.py"
        ).read_text(encoding="utf-8")
        self.assertIn('"fmt"', source)
        self.assertIn('"info"', source)
        self.assertIn('"test"', source)
        self.assertIn("retained_d_seed_executed", source)
        self.assertIn("linux_and_freestanding_gate", source)


if __name__ == "__main__":
    unittest.main()
