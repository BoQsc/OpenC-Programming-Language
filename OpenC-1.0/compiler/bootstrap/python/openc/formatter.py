"""Deterministic OpenC formatter operating on the compiler token stream."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .diagnostics import DiagnosticEngine
from .lexer import Lexer
from .model import Token, TokenKind
from .source import SourceFile


@dataclass(slots=True)
class FormatterConfig:
    indent_width: int = 4
    max_width: int = 100
    line_ending: str = "\n"
    final_newline: bool = True


class Formatter:
    def __init__(self, config: FormatterConfig | None = None):
        self.config = config or FormatterConfig()

    def format_text(self, source_id: str, text: str) -> str:
        diagnostics = DiagnosticEngine()
        source = SourceFile.from_bytes(source_id, text.encode("utf-8"))
        tokens = Lexer(source, diagnostics).lex()
        if diagnostics.has_errors:
            return text
        return self.format_tokens(tokens)

    def format_tokens(self, tokens: list[Token]) -> str:
        lines: list[str] = []
        current = ""
        indent = 0
        paren_depth = 0
        bracket_depth = 0
        previous: Token | None = None

        def flush() -> None:
            nonlocal current
            if current.strip():
                lines.append(" " * (indent * self.config.indent_width) + current.rstrip())
            current = ""

        def append(text: str, force_space: bool = False) -> None:
            nonlocal current
            if force_space and current and not current.endswith(" "):
                current += " "
            current += text

        for token_index, token in enumerate(tokens):
            if token.kind == TokenKind.EOF:
                break
            text = token.text
            if text == "{":
                if current and not current.endswith(" "):
                    current += " "
                current += "{"
                flush()
                indent += 1
            elif text == "}":
                flush()
                indent = max(0, indent - 1)
                current = "}"
                if not self._next_is_semicolon(tokens, token_index):
                    flush()
            elif text == ";":
                current = current.rstrip() + ";"
                if paren_depth == 0:
                    flush()
                else:
                    current += " "
            elif text == ",":
                current = current.rstrip() + ", "
            elif text == "(":
                if previous and previous.kind == TokenKind.IDENTIFIER and previous.text in {"if", "while", "for", "switch", "when"}:
                    append("(")
                else:
                    append("(")
                paren_depth += 1
            elif text == ")":
                current = current.rstrip() + ")"
                paren_depth = max(0, paren_depth - 1)
            elif text == "[":
                append("[")
                bracket_depth += 1
            elif text == "]":
                current = current.rstrip() + "]"
                bracket_depth = max(0, bracket_depth - 1)
            elif text == ".":
                current = current.rstrip() + "."
            elif text == "..":
                current = current.rstrip() + ".."
            elif text in {"=", "+", "-", "*", "/", "%", "==", "!=", "<", "<=", ">", ">=", "&&", "||", "&", "|", "^", "<<", ">>", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>="}:
                current = current.rstrip() + f" {text} "
            elif text == ":":
                current = current.rstrip() + ": "
            else:
                needs_space = bool(current) and not current.endswith((" ", "(", "[", "."))
                if previous and previous.text in {".", "("}:
                    needs_space = False
                if needs_space:
                    current += " "
                current += text
            previous = token
        flush()
        result = self.config.line_ending.join(line.rstrip() for line in lines)
        if self.config.final_newline:
            result += self.config.line_ending
        return result

    @staticmethod
    def _next_is_semicolon(tokens: list[Token], token_index: int) -> bool:
        next_index = token_index + 1
        while next_index < len(tokens) and tokens[next_index].kind == TokenKind.EOF:
            next_index += 1
        return next_index < len(tokens) and tokens[next_index].text == ";"
