"""Deterministic OpenC UTF-8 lexer.

The lexer implements the lexical productions of OpenC Core 1.0, preserves
source spans, validates numeric separators and Unicode escapes, and performs no
name or type lookup.
"""
from __future__ import annotations

from dataclasses import dataclass
import math
import unicodedata
from typing import Iterator

from .diagnostics import DiagnosticEngine
from .model import Phase, Span, Token, TokenKind
from .source import SourceFile


KEYWORDS = {
    "import", "export", "struct", "resource", "enum", "const", "unsafe",
    "void", "own", "out", "when", "ref", "ptr", "optional", "storage",
    "if", "else", "while", "for", "switch", "case", "default", "break",
    "continue", "return", "scope", "cast", "cast_unchecked", "reinterpret",
    "construct", "destroy", "size_of", "align_of", "true", "false", "null",
    "none", "external", "layout",
}

MULTI_SYMBOLS = (
    "<<=", ">>=", "==", "!=", "<=", ">=", "&&", "||", "<<", ">>",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "..",
)
SINGLE_SYMBOLS = set("{}()[];,.=+-*/%!~&|^<>:")


@dataclass(slots=True)
class LexerState:
    index: int = 0
    line: int = 1
    column: int = 1


class Lexer:
    def __init__(self, source: SourceFile, diagnostics: DiagnosticEngine):
        self.source = source
        self.text = source.text
        self.diagnostics = diagnostics
        self.state = LexerState()

    def lex(self) -> list[Token]:
        tokens: list[Token] = []
        while not self.at_end():
            self.skip_ignored()
            if self.at_end():
                break
            start = self.state.index
            char = self.current()
            if self.is_identifier_start(char):
                tokens.append(self.lex_identifier(start))
            elif char.isdigit():
                tokens.append(self.lex_number(start))
            elif char == '"':
                tokens.append(self.lex_text(start))
            else:
                tokens.append(self.lex_symbol(start))
        span = self.source.span(len(self.text), len(self.text))
        tokens.append(Token(TokenKind.EOF, "<eof>", span))
        return tokens

    def at_end(self) -> bool:
        return self.state.index >= len(self.text)

    def current(self) -> str:
        return self.text[self.state.index] if not self.at_end() else "\0"

    def peek(self, distance: int = 1) -> str:
        index = self.state.index + distance
        return self.text[index] if index < len(self.text) else "\0"

    def advance(self) -> str:
        if self.at_end():
            return "\0"
        char = self.text[self.state.index]
        self.state.index += 1
        if char == "\n":
            self.state.line += 1
            self.state.column = 1
        elif char == "\r":
            if self.current() == "\n":
                pass
            self.state.line += 1
            self.state.column = 1
        else:
            self.state.column += 1
        return char

    def match(self, text: str) -> bool:
        if self.text.startswith(text, self.state.index):
            for _ in text:
                self.advance()
            return True
        return False

    def span(self, start: int) -> Span:
        return self.source.span(start, self.state.index)

    def skip_ignored(self) -> None:
        while not self.at_end():
            char = self.current()
            if char in {" ", "\t", "\n", "\r"}:
                self.advance()
                if char == "\r" and self.current() == "\n":
                    self.advance()
                continue
            if char == "/" and self.peek() == "/":
                self.advance(); self.advance()
                while not self.at_end() and self.current() not in {"\r", "\n"}:
                    self.advance()
                continue
            if char == "/" and self.peek() == "*":
                start = self.state.index
                self.advance(); self.advance()
                while not self.at_end() and not (self.current() == "*" and self.peek() == "/"):
                    self.advance()
                if self.at_end():
                    self.diagnostics.raise_error(
                        "OPENC-LEX-COMMENT-001", Phase.LEXICAL,
                        "unterminated block comment", self.source.span(start, self.state.index),
                        "lexical.comment",
                    )
                self.advance(); self.advance()
                continue
            break

    @staticmethod
    def is_identifier_start(char: str) -> bool:
        return char == "_" or "A" <= char <= "Z" or "a" <= char <= "z"

    @staticmethod
    def is_identifier_continue(char: str) -> bool:
        return Lexer.is_identifier_start(char) or char.isdigit()

    def lex_identifier(self, start: int) -> Token:
        self.advance()
        while self.is_identifier_continue(self.current()):
            self.advance()
        text = self.text[start:self.state.index]
        return Token(TokenKind.IDENTIFIER, text, self.span(start), text)

    def lex_number(self, start: int) -> Token:
        if self.current() == "0" and self.peek() in {"x", "X"}:
            self.advance(); self.advance()
            digits_start = self.state.index
            self.consume_digit_sequence("hexadecimal", lambda c: c.isdigit() or c.lower() in "abcdef")
            raw = self.text[start:self.state.index]
            if self.state.index == digits_start:
                self.number_error(start, "hexadecimal literal requires at least one hexadecimal digit")
            return Token(TokenKind.INTEGER, raw, self.span(start), int(raw.replace("_", ""), 16))
        if self.current() == "0" and self.peek() in {"b", "B"}:
            self.advance(); self.advance()
            digits_start = self.state.index
            self.consume_digit_sequence("binary", lambda c: c in "01")
            raw = self.text[start:self.state.index]
            if self.state.index == digits_start:
                self.number_error(start, "binary literal requires at least one binary digit")
            return Token(TokenKind.INTEGER, raw, self.span(start), int(raw.replace("_", ""), 2))

        self.consume_digit_sequence("decimal", str.isdigit)
        is_float = False
        if self.current() == "." and self.peek() != "." and self.peek().isdigit():
            is_float = True
            self.advance()
            self.consume_digit_sequence("fraction", str.isdigit)
        if self.current() in {"e", "E"}:
            is_float = True
            self.advance()
            if self.current() in {"+", "-"}:
                self.advance()
            if not self.current().isdigit():
                self.number_error(start, "floating exponent requires decimal digits")
            self.consume_digit_sequence("exponent", str.isdigit)

        if self.is_identifier_start(self.current()):
            suffix_start = self.state.index
            while self.is_identifier_continue(self.current()):
                self.advance()
            self.diagnostics.raise_error(
                "OPENC-LEX-NUMERIC-SUFFIX-001", Phase.LEXICAL,
                f"numeric suffix '{self.text[suffix_start:self.state.index]}' is not part of OpenC Core",
                self.span(start), "lexical.numeric",
            )

        raw = self.text[start:self.state.index]
        normalized = raw.replace("_", "")
        if is_float:
            value = float(normalized)
            if not math.isfinite(value):
                self.number_error(start, "floating literal is outside the finite representable range")
            return Token(TokenKind.FLOAT, raw, self.span(start), value)
        return Token(TokenKind.INTEGER, raw, self.span(start), int(normalized, 10))

    def consume_digit_sequence(self, name: str, predicate) -> None:
        previous_separator = False
        saw_digit = False
        while True:
            char = self.current()
            if predicate(char):
                saw_digit = True
                previous_separator = False
                self.advance()
                continue
            if char == "_":
                if not saw_digit or previous_separator or not predicate(self.peek()):
                    start = self.state.index
                    self.advance()
                    self.diagnostics.raise_error(
                        "OPENC-LEX-NUMERIC-SEPARATOR-001", Phase.LEXICAL,
                        f"invalid digit separator in {name} literal",
                        self.source.span(start, self.state.index), "lexical.numeric",
                    )
                previous_separator = True
                self.advance()
                continue
            break

    def number_error(self, start: int, message: str) -> None:
        self.diagnostics.raise_error(
            "OPENC-LEX-NUMERIC-001", Phase.LEXICAL, message,
            self.span(start), "lexical.numeric",
        )

    def lex_text(self, start: int) -> Token:
        self.advance()
        decoded: list[str] = []
        while not self.at_end() and self.current() != '"':
            char = self.advance()
            if char in {"\r", "\n"}:
                self.diagnostics.raise_error(
                    "OPENC-LEX-TEXT-LINE-001", Phase.LEXICAL,
                    "text literal cannot contain an unescaped line break",
                    self.span(start), "lexical.text",
                )
            if char != "\\":
                decoded.append(char)
                continue
            if self.at_end():
                break
            code = self.advance()
            escapes = {"\\": "\\", '"': '"', "n": "\n", "r": "\r", "t": "\t", "0": "\0"}
            if code in escapes:
                decoded.append(escapes[code])
                continue
            if code == "u" and self.current() == "{":
                self.advance()
                digits_start = self.state.index
                while self.current().lower() in "0123456789abcdef" and self.state.index - digits_start < 6:
                    self.advance()
                digits = self.text[digits_start:self.state.index]
                if not digits or self.current() != "}":
                    self.diagnostics.raise_error(
                        "OPENC-LEX-UNICODE-ESCAPE-001", Phase.LEXICAL,
                        "Unicode escape must contain one to six hexadecimal digits and a closing brace",
                        self.span(start), "lexical.text",
                    )
                self.advance()
                scalar = int(digits, 16)
                if scalar > 0x10FFFF or 0xD800 <= scalar <= 0xDFFF:
                    self.diagnostics.raise_error(
                        "OPENC-LEX-UNICODE-SCALAR-001", Phase.LEXICAL,
                        "Unicode escape does not name a Unicode scalar value",
                        self.span(start), "lexical.text",
                    )
                decoded.append(chr(scalar))
                continue
            self.diagnostics.raise_error(
                "OPENC-LEX-TEXT-ESCAPE-001", Phase.LEXICAL,
                f"unsupported text escape '\\{code}'", self.span(start), "lexical.text",
            )
        if self.at_end():
            self.diagnostics.raise_error(
                "OPENC-LEX-TEXT-001", Phase.LEXICAL,
                "unterminated text literal", self.span(start), "lexical.text",
            )
        self.advance()
        raw = self.text[start:self.state.index]
        return Token(TokenKind.TEXT, raw, self.span(start), "".join(decoded))

    def lex_symbol(self, start: int) -> Token:
        for symbol in MULTI_SYMBOLS:
            if self.text.startswith(symbol, self.state.index):
                for _ in symbol:
                    self.advance()
                return Token(TokenKind.SYMBOL, symbol, self.span(start), symbol)
        char = self.current()
        if char in SINGLE_SYMBOLS:
            self.advance()
            return Token(TokenKind.SYMBOL, char, self.span(start), char)
        self.advance()
        self.diagnostics.raise_error(
            "OPENC-LEX-CHARACTER-001", Phase.LEXICAL,
            f"unexpected source character U+{ord(char):04X}",
            self.span(start), "lexical.character",
        )
        raise AssertionError("unreachable")
