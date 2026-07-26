"""Authored tests for the informative Python bootstrap compiler.

These tests are part of the source handoff and are not claimed as executed.
"""
from __future__ import annotations
import json
from pathlib import Path
import tempfile
import unittest

from openc.diagnostics import DiagnosticEngine
from openc.lexer import Lexer
from openc.parser import Parser, ParserOptions
from openc.source import SourceManager


class LexerParserTests(unittest.TestCase):
    def parse(self, source: str):
        sources = SourceManager()
        item = sources.add_virtual("test", source)
        diagnostics = DiagnosticEngine(sources)
        tokens = Lexer(item, diagnostics).lex()
        unit = Parser(tokens, diagnostics, ParserOptions()).parse_source_unit("test.main")
        return unit, diagnostics

    def test_direct_function(self):
        unit, diagnostics = self.parse("i32 main() { return 0; }\n")
        self.assertFalse(diagnostics.has_errors)
        self.assertEqual(len(unit.declarations), 1)
        bom_unit, bom_diagnostics = self.parse("\ufeffi32 main() { return 0; }\n")
        self.assertFalse(bom_diagnostics.has_errors)
        self.assertEqual(len(bom_unit.declarations), 1)

    def test_struct_and_named_initializer(self):
        source = "struct Point { i32 x; i32 y; } i32 main() { Point p = Point{ x = 1, y = 2 }; return p.x; }"
        unit, diagnostics = self.parse(source)
        self.assertFalse(diagnostics.has_errors)
        self.assertEqual(len(unit.declarations), 2)

    def test_symbolic_pointer_is_rejected(self):
        _, diagnostics = self.parse("i32* pointer;\n")
        self.assertTrue(diagnostics.has_errors)


class ProjectRecordTests(unittest.TestCase):
    def test_minimal_project_shape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "main.p").write_text("i32 main() { return 0; }\n", encoding="utf-8")
            record = {
                "name": "test",
                "version": "0.0.0",
                "edition": "OpenC 1.0",
                "profile": "standard",
                "target": "linux-x86_64",
                "modules": {"app.main": ["main.p"]},
            }
            path = root / "openc.project.json"
            path.write_text(json.dumps(record), encoding="utf-8")
            self.assertTrue(path.is_file())


if __name__ == "__main__":
    unittest.main()
