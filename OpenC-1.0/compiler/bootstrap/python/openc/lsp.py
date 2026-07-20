"""Minimal first-party OpenC Language Server Protocol implementation.

The server shares the compiler lexer/parser/semantic pipeline.  It supports
initialization, text synchronization, diagnostics, symbols, hover, definition,
references, rename validation, formatting, completion, and shutdown using only
the Python standard library.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import io
import json
from pathlib import Path
import sys
import tempfile
from typing import Any, BinaryIO, TextIO
from urllib.parse import unquote, urlparse

from .compiler import Compiler
from .formatter import Formatter
from .lexer import Lexer
from .model import (
    Decl, FunctionDecl, LocalDecl, NameExpr, Node, SourceUnit, StructDecl,
    EnumDecl, walk,
)
from .parser import Parser
from .source import SourceFile


@dataclass(slots=True)
class Document:
    uri: str
    version: int
    text: str


class JsonRpcStream:
    def __init__(self, input_stream: BinaryIO, output_stream: BinaryIO):
        self.input = input_stream
        self.output = output_stream

    def read(self) -> dict[str, Any] | None:
        headers: dict[str, str] = {}
        while True:
            line = self.input.readline()
            if not line:
                return None
            decoded = line.decode("ascii", errors="strict").strip()
            if not decoded:
                break
            key, value = decoded.split(":", 1)
            headers[key.lower()] = value.strip()
        length = int(headers.get("content-length", "0"))
        if length <= 0:
            return None
        return json.loads(self.input.read(length).decode("utf-8"))

    def write(self, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        self.output.write(f"Content-Length: {len(data)}\r\n\r\n".encode("ascii"))
        self.output.write(data)
        self.output.flush()


class LanguageServer:
    def __init__(self, repository_root: Path, stream: JsonRpcStream):
        self.repository_root = repository_root
        self.stream = stream
        self.documents: dict[str, Document] = {}
        self.shutdown_requested = False
        self.root_uri: str | None = None
        self.formatter = Formatter()

    def run(self) -> int:
        while True:
            request = self.stream.read()
            if request is None:
                return 0
            method = request.get("method")
            request_id = request.get("id")
            params = request.get("params") or {}
            if method == "initialize":
                self.root_uri = params.get("rootUri")
                self.respond(request_id, self.capabilities())
            elif method == "initialized":
                continue
            elif method == "shutdown":
                self.shutdown_requested = True
                self.respond(request_id, None)
            elif method == "exit":
                return 0 if self.shutdown_requested else 1
            elif method == "textDocument/didOpen":
                item = params["textDocument"]
                self.documents[item["uri"]] = Document(item["uri"], item.get("version", 0), item["text"])
                self.publish_diagnostics(item["uri"])
            elif method == "textDocument/didChange":
                item = params["textDocument"]
                changes = params.get("contentChanges", [])
                if changes:
                    document = self.documents.get(item["uri"], Document(item["uri"], 0, ""))
                    document.text = changes[-1]["text"]
                    document.version = item.get("version", document.version)
                    self.documents[item["uri"]] = document
                    self.publish_diagnostics(item["uri"])
            elif method == "textDocument/didClose":
                uri = params["textDocument"]["uri"]
                self.documents.pop(uri, None)
                self.notify("textDocument/publishDiagnostics", {"uri": uri, "diagnostics": []})
            elif method == "textDocument/formatting":
                self.respond(request_id, self.format_document(params["textDocument"]["uri"]))
            elif method == "textDocument/documentSymbol":
                self.respond(request_id, self.document_symbols(params["textDocument"]["uri"]))
            elif method == "textDocument/hover":
                self.respond(request_id, self.hover(params))
            elif method == "textDocument/definition":
                self.respond(request_id, self.definition(params))
            elif method == "textDocument/references":
                self.respond(request_id, self.references(params))
            elif method == "textDocument/completion":
                self.respond(request_id, self.completion(params))
            elif method == "textDocument/rename":
                self.respond(request_id, self.rename(params))
            elif request_id is not None:
                self.error(request_id, -32601, f"method not implemented: {method}")

    def capabilities(self) -> dict[str, Any]:
        return {
            "capabilities": {
                "textDocumentSync": 1,
                "documentFormattingProvider": True,
                "documentSymbolProvider": True,
                "hoverProvider": True,
                "definitionProvider": True,
                "referencesProvider": True,
                "renameProvider": {"prepareProvider": False},
                "completionProvider": {"resolveProvider": False, "triggerCharacters": ["."]},
            },
            "serverInfo": {"name": "openc-lsp", "version": "1.0.0-rc.3"},
        }

    def parse_document(self, uri: str) -> tuple[SourceUnit | None, list[dict]]:
        document = self.documents.get(uri)
        if document is None:
            return None, []
        compiler = Compiler()
        source = compiler.sources.add_text(uri, document.text)
        try:
            tokens = Lexer(source, compiler.diagnostics).lex()
            unit = Parser(tokens, compiler.diagnostics).parse_source_unit("document")
        except Exception:
            unit = None
        return unit, [self.lsp_diagnostic(item) for item in compiler.diagnostics.items]

    def publish_diagnostics(self, uri: str) -> None:
        _, diagnostics = self.parse_document(uri)
        self.notify("textDocument/publishDiagnostics", {"uri": uri, "diagnostics": diagnostics})

    def lsp_diagnostic(self, diagnostic) -> dict[str, Any]:
        severity = {"error": 1, "warning": 2, "note": 3, "help": 4}[diagnostic.severity.value]
        if diagnostic.span is None:
            range_value = {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 1}}
        else:
            range_value = {
                "start": {"line": diagnostic.span.start.line - 1, "character": diagnostic.span.start.column - 1},
                "end": {"line": diagnostic.span.end.line - 1, "character": max(diagnostic.span.start.column, diagnostic.span.end.column - 1)},
            }
        return {
            "range": range_value,
            "severity": severity,
            "code": diagnostic.rule_id,
            "source": "openc",
            "message": diagnostic.message,
            "data": diagnostic.to_json(),
        }

    def format_document(self, uri: str) -> list[dict[str, Any]]:
        document = self.documents.get(uri)
        if document is None:
            return []
        formatted = self.formatter.format_text(uri, document.text)
        if formatted == document.text:
            return []
        lines = document.text.splitlines()
        return [{
            "range": {
                "start": {"line": 0, "character": 0},
                "end": {"line": len(lines) + 1, "character": 0},
            },
            "newText": formatted,
        }]

    def document_symbols(self, uri: str) -> list[dict[str, Any]]:
        unit, _ = self.parse_document(uri)
        if unit is None:
            return []
        result: list[dict[str, Any]] = []
        for decl in unit.declarations:
            kind = 12 if isinstance(decl, FunctionDecl) else 23 if isinstance(decl, StructDecl) else 10 if isinstance(decl, EnumDecl) else 13
            result.append({
                "name": decl.name,
                "kind": kind,
                "range": self.lsp_range(decl.span),
                "selectionRange": self.lsp_range(decl.span),
            })
        return result

    def hover(self, params: dict[str, Any]) -> dict[str, Any] | None:
        uri = params["textDocument"]["uri"]
        unit, _ = self.parse_document(uri)
        if unit is None:
            return None
        node = self.node_at(unit, params["position"])
        if node is None:
            return None
        content = node.__class__.__name__
        if isinstance(node, Decl):
            content = f"{node.__class__.__name__} `{node.name}`"
        elif isinstance(node, NameExpr):
            content = f"name `{node.qualified}`"
        return {"contents": {"kind": "markdown", "value": content}, "range": self.lsp_range(node.span)}

    def definition(self, params: dict[str, Any]) -> dict[str, Any] | None:
        uri = params["textDocument"]["uri"]
        unit, _ = self.parse_document(uri)
        if unit is None:
            return None
        node = self.node_at(unit, params["position"])
        if not isinstance(node, NameExpr):
            return None
        name = node.parts[-1]
        for candidate in walk(unit):
            if isinstance(candidate, Decl) and candidate.name == name:
                return {"uri": uri, "range": self.lsp_range(candidate.span)}
            if isinstance(candidate, LocalDecl) and candidate.name == name:
                return {"uri": uri, "range": self.lsp_range(candidate.span)}
        return None

    def references(self, params: dict[str, Any]) -> list[dict[str, Any]]:
        uri = params["textDocument"]["uri"]
        unit, _ = self.parse_document(uri)
        if unit is None:
            return []
        node = self.node_at(unit, params["position"])
        name = node.parts[-1] if isinstance(node, NameExpr) else node.name if isinstance(node, (Decl, LocalDecl)) else None
        if not name:
            return []
        result = []
        for candidate in walk(unit):
            if isinstance(candidate, NameExpr) and candidate.parts[-1] == name:
                result.append({"uri": uri, "range": self.lsp_range(candidate.span)})
            elif isinstance(candidate, (Decl, LocalDecl)) and candidate.name == name:
                result.append({"uri": uri, "range": self.lsp_range(candidate.span)})
        return result

    def completion(self, params: dict[str, Any]) -> dict[str, Any]:
        uri = params["textDocument"]["uri"]
        unit, _ = self.parse_document(uri)
        names = {
            "import", "export", "struct", "resource", "enum", "const", "unsafe",
            "void", "own", "out", "when", "ref", "ptr", "optional", "storage",
            "if", "else", "while", "for", "switch", "case", "default", "break",
            "continue", "return", "scope", "true", "false", "none", "null",
        }
        if unit:
            for node in walk(unit):
                if isinstance(node, (Decl, LocalDecl)):
                    names.add(node.name)
        return {"isIncomplete": False, "items": [{"label": name, "kind": 6} for name in sorted(names)]}

    def rename(self, params: dict[str, Any]) -> dict[str, Any] | None:
        new_name = params.get("newName", "")
        if not new_name or not (new_name[0].isalpha() or new_name[0] == "_") or not all(char.isalnum() or char == "_" for char in new_name):
            return None
        references = self.references(params)
        if not references:
            return None
        changes = {params["textDocument"]["uri"]: [{"range": item["range"], "newText": new_name} for item in references]}
        return {"changes": changes}

    @staticmethod
    def node_at(root: Node, position: dict[str, int]) -> Node | None:
        line = position["line"] + 1
        column = position["character"] + 1
        candidates = [
            node for node in walk(root)
            if (node.span.start.line, node.span.start.column) <= (line, column) <= (node.span.end.line, node.span.end.column)
        ]
        return min(candidates, key=lambda node: node.span.end.offset - node.span.start.offset) if candidates else None

    @staticmethod
    def lsp_range(span) -> dict[str, Any]:
        return {
            "start": {"line": span.start.line - 1, "character": span.start.column - 1},
            "end": {"line": span.end.line - 1, "character": max(span.start.column, span.end.column - 1)},
        }

    def respond(self, request_id: Any, result: Any) -> None:
        self.stream.write({"jsonrpc": "2.0", "id": request_id, "result": result})

    def error(self, request_id: Any, code: int, message: str) -> None:
        self.stream.write({"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}})

    def notify(self, method: str, params: Any) -> None:
        self.stream.write({"jsonrpc": "2.0", "method": method, "params": params})


def run_stdio(repository_root: Path) -> int:
    stream = JsonRpcStream(sys.stdin.buffer, sys.stdout.buffer)
    return LanguageServer(repository_root, stream).run()
