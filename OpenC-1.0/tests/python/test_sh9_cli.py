from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class Sh9CliSourceTests(unittest.TestCase):
    def test_public_commands_are_native(self) -> None:
        source = (
            ROOT / "compiler" / "selfhost" / "source" / "main_driver.p"
        ).read_text(encoding="utf-8")
        for command in ("check", "run", "version", "target", "explain"):
            self.assertIn(f'== "{command}"', source)
        self.assertIn("cli_check_project", source)
        self.assertIn("cli_run_project", source)

    def test_check_preserves_machine_streams(self) -> None:
        source = (
            ROOT / "compiler" / "selfhost" / "source" / "cli.p"
        ).read_text(encoding="utf-8")
        self.assertIn("openc.check.v1", source)
        self.assertIn("openc.native_cli.diagnostic_streams.v1", source)
        self.assertIn('"--semantic-flow-safety"', source)
        self.assertIn('"--semantic-ir"', source)

    def test_rule_explanation_uses_canonical_index(self) -> None:
        source = (
            ROOT / "compiler" / "selfhost" / "source" / "cli.p"
        ).read_text(encoding="utf-8")
        self.assertIn("OpenC_Core_Rule_Index.json", source)
        self.assertIn("historical_compatibility_disclosed", source)

    def test_demo_harness_uses_public_cli(self) -> None:
        source = (ROOT / "demos" / "run_all.py").read_text(
            encoding="utf-8"
        )
        self.assertIn('"check" if args.check_only else "run"', source)
        self.assertNotIn('"build",', source)

    def test_builtin_module_alias_can_be_shadowed_by_a_value(self) -> None:
        source = (
            ROOT
            / "compiler"
            / "selfhost"
            / "source"
            / "acceptance_ranges_part3.p"
        ).read_text(encoding="utf-8")
        self.assertIn("acceptance_value_shadows_builtin_alias", source)
        self.assertIn("resolution_symbol_parameter()", source)
        self.assertIn("resolution_symbol_variable()", source)


if __name__ == "__main__":
    unittest.main()
