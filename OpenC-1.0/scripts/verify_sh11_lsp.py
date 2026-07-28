#!/usr/bin/env python3
"""Verify the OpenC-native SH-11 language-service contract."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import io
import json
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import threading
from typing import BinaryIO


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from native_toolchain import resolve_native_compiler, validate_native_compiler


def frame_bytes(message: dict) -> bytes:
    body = json.dumps(
        message,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return f"Content-Length: {len(body)}\r\n\r\n".encode("ascii") + body


def read_frame(stream: BinaryIO) -> dict | None:
    headers: dict[str, str] = {}
    while True:
        line = stream.readline()
        if not line:
            return None
        decoded = line.decode("ascii").strip()
        if not decoded:
            break
        name, value = decoded.split(":", 1)
        headers[name.lower()] = value.strip()
    length = int(headers.get("content-length", "0"))
    if length <= 0:
        raise ValueError("missing positive Content-Length")
    body = stream.read(length)
    if len(body) != length:
        raise EOFError("truncated JSON-RPC body")
    return json.loads(body.decode("utf-8"))


def canonical_json(value: object) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ) + "\n"


@dataclass
class Case:
    name: str
    passed: bool
    detail: str


class LspClient:
    def __init__(self, compiler: Path):
        self.process = subprocess.Popen(
            [str(compiler), "lsp", "--stdio"],
            cwd=ROOT,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        assert self.process.stdin is not None
        assert self.process.stdout is not None
        self._messages: queue.Queue[dict | BaseException | None] = queue.Queue()
        self.transcript: list[dict] = []

        def reader() -> None:
            try:
                while True:
                    message = read_frame(self.process.stdout)
                    self._messages.put(message)
                    if message is None:
                        return
            except BaseException as error:
                self._messages.put(error)

        self._reader = threading.Thread(target=reader, daemon=True)
        self._reader.start()

    def send(self, message: dict) -> None:
        assert self.process.stdin is not None
        self.process.stdin.write(frame_bytes(message))
        self.process.stdin.flush()
        self.transcript.append(
            {"direction": "client-to-server", "message": message}
        )

    def receive(self, timeout: float = 15.0) -> dict:
        item = self._messages.get(timeout=timeout)
        if isinstance(item, BaseException):
            raise item
        if item is None:
            raise EOFError("language server closed its output")
        self.transcript.append(
            {"direction": "server-to-client", "message": item}
        )
        return item

    def finish(self, timeout: float = 15.0) -> tuple[int, str]:
        assert self.process.stdin is not None
        assert self.process.stderr is not None
        self.process.stdin.close()
        code = self.process.wait(timeout=timeout)
        stderr = self.process.stderr.read().decode("utf-8")
        return code, stderr

    def terminate(self) -> None:
        if self.process.poll() is None:
            self.process.kill()
            self.process.wait(timeout=5)


def request(method: str, params: object, request_id: int | None = None) -> dict:
    message: dict[str, object] = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
    }
    if request_id is not None:
        message["id"] = request_id
    return message


def transcript_record(messages: list[dict]) -> dict:
    return {
        "schema": "openc.lsp_transcript.v1",
        "server": "openc-lsp",
        "target": "windows-x86_64-hosted",
        "transport": "stdio-content-length",
        "messages": messages,
    }


def run_primary_session(compiler: Path, fixture: dict) -> tuple[list[Case], dict]:
    cases: list[Case] = []
    client = LspClient(compiler)
    uri = fixture["uri"]
    try:
        client.send(request("initialize", {}, 1))
        initialized = client.receive()
        capabilities = initialized.get("result", {}).get("capabilities", {})
        cases.append(
            Case(
                "initialize_capabilities",
                initialized.get("id") == 1
                and capabilities.get("positionEncoding") == "utf-8"
                and capabilities.get("documentFormattingProvider") is True
                and capabilities.get("textDocumentSync", {}).get("change") == 1,
                "initialize returns UTF-8, full-sync, and formatting capabilities",
            )
        )
        cases.append(
            Case(
                "server_identity",
                initialized.get("result", {}).get("serverInfo", {}).get("name")
                == "openc-lsp",
                "initialize identifies the native OpenC language server",
            )
        )

        client.send(request("initialized", {}))
        client.send(
            request(
                "textDocument/didOpen",
                {
                    "textDocument": {
                        "uri": uri,
                        "languageId": "openc",
                        "version": 1,
                        "text": fixture["invalid_source"],
                    }
                },
            )
        )
        opened = client.receive()
        diagnostics = opened.get("params", {}).get("diagnostics", [])
        cases.append(
            Case(
                "did_open_diagnostics",
                opened.get("method") == "textDocument/publishDiagnostics"
                and opened.get("params", {}).get("uri") == uri
                and opened.get("params", {}).get("version") == 1
                and len(diagnostics) >= 1,
                "opening invalid OpenC publishes native diagnostics",
            )
        )
        cases.append(
            Case(
                "stable_diagnostic_contract",
                all(
                    item.get("source") == "openc"
                    and str(item.get("code", "")).startswith("OPENC-")
                    and item.get("severity") == 1
                    and "range" in item
                    and "data" in item
                    for item in diagnostics
                ),
                "diagnostics carry stable rule IDs, severity, ranges, and byte data",
            )
        )

        client.send(
            request(
                "textDocument/formatting",
                {
                    "textDocument": {"uri": uri},
                    "options": {"tabSize": 4, "insertSpaces": True},
                },
                2,
            )
        )
        invalid_format = client.receive()
        cases.append(
            Case(
                "invalid_document_not_formatted",
                invalid_format.get("id") == 2
                and invalid_format.get("result") == [],
                "invalid source is not rewritten",
            )
        )

        client.send(
            request(
                "textDocument/didChange",
                {
                    "textDocument": {"uri": uri, "version": 2},
                    "contentChanges": [{"text": fixture["valid_source"]}],
                },
            )
        )
        changed = client.receive()
        cases.append(
            Case(
                "did_change_clears_diagnostics",
                changed.get("method") == "textDocument/publishDiagnostics"
                and changed.get("params", {}).get("version") == 2
                and changed.get("params", {}).get("diagnostics") == [],
                "changing to valid source clears diagnostics",
            )
        )

        client.send(
            request(
                "textDocument/formatting",
                {
                    "textDocument": {"uri": uri},
                    "options": {"tabSize": 4, "insertSpaces": True},
                },
                3,
            )
        )
        formatted = client.receive()
        edits = formatted.get("result", [])
        cases.append(
            Case(
                "sh10_formatter_edit",
                formatted.get("id") == 3
                and len(edits) == 1
                and edits[0].get("newText") == fixture["formatted_source"],
                "formatting returns the SH-10 canonical full-document edit",
            )
        )

        client.send(request("textDocument/didClose", {"textDocument": {"uri": uri}}))
        closed = client.receive()
        cases.append(
            Case(
                "did_close_clears_diagnostics",
                closed.get("method") == "textDocument/publishDiagnostics"
                and closed.get("params", {}).get("diagnostics") == [],
                "closing a document publishes an empty diagnostic set",
            )
        )

        client.send(
            request(
                "textDocument/formatting",
                {"textDocument": {"uri": uri}, "options": {}},
                4,
            )
        )
        missing = client.receive()
        cases.append(
            Case(
                "closed_document_error",
                missing.get("id") == 4
                and missing.get("error", {}).get("code") == -32602,
                "formatting a closed document returns invalid params",
            )
        )

        client.send(request("openc/notImplemented", {}, 5))
        unknown = client.receive()
        cases.append(
            Case(
                "unknown_method_error",
                unknown.get("id") == 5
                and unknown.get("error", {}).get("code") == -32601,
                "unknown requests return method-not-found",
            )
        )

        client.send(request("shutdown", None, 6))
        shutdown = client.receive()
        cases.append(
            Case(
                "shutdown_response",
                shutdown == {"jsonrpc": "2.0", "id": 6, "result": None},
                "shutdown responds with null",
            )
        )

        client.send(request("textDocument/formatting", {"textDocument": {"uri": uri}}, 7))
        after_shutdown = client.receive()
        cases.append(
            Case(
                "request_after_shutdown_error",
                after_shutdown.get("id") == 7
                and after_shutdown.get("error", {}).get("code") == -32600,
                "requests after shutdown are rejected",
            )
        )

        client.send(request("exit", None))
        exit_code, stderr = client.finish()
        cases.append(
            Case(
                "shutdown_exit",
                exit_code == 0 and stderr == "",
                "exit after shutdown is clean and silent",
            )
        )
        return cases, transcript_record(client.transcript)
    finally:
        client.terminate()


def run_negative_sessions(compiler: Path) -> list[Case]:
    cases: list[Case] = []

    uninitialized = LspClient(compiler)
    try:
        uninitialized.send(request("textDocument/formatting", {}, 1))
        response = uninitialized.receive()
        uninitialized.send(request("exit", None))
        code, stderr = uninitialized.finish()
        cases.append(
            Case(
                "request_before_initialize_error",
                response.get("error", {}).get("code") == -32002,
                "requests before initialize are rejected",
            )
        )
        cases.append(
            Case(
                "exit_without_shutdown",
                code == 1 and stderr == "",
                "exit without shutdown returns failure as required by LSP",
            )
        )
    finally:
        uninitialized.terminate()

    duplicate = LspClient(compiler)
    try:
        duplicate.send(request("initialize", {}, 1))
        duplicate.receive()
        duplicate.send(request("initialize", {}, 2))
        response = duplicate.receive()
        duplicate.send(request("shutdown", None, 3))
        duplicate.receive()
        duplicate.send(request("exit", None))
        code, stderr = duplicate.finish()
        cases.append(
            Case(
                "duplicate_initialize_error",
                response.get("id") == 2
                and response.get("error", {}).get("code") == -32600
                and code == 0
                and stderr == "",
                "duplicate initialize is rejected without destabilizing shutdown",
            )
        )
    finally:
        duplicate.terminate()
    return cases


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh11" / "native-lsp",
    )
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    output = args.output.resolve()
    if output.exists():
        if not args.force:
            raise SystemExit(f"output directory already exists: {output}")
        if output == Path(output.anchor) or len(output.parts) < 3:
            raise SystemExit(f"refusing to replace broad output path: {output}")
        shutil.rmtree(output)
    output.mkdir(parents=True)

    fixture = json.loads(
        (ROOT / "tests" / "tooling" / "sh11" / "session.json").read_text(
            encoding="utf-8"
        )
    )
    help_result = subprocess.run(
        [str(compiler), "help"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )
    cases = [
        Case(
            "help_discovers_lsp",
            help_result.returncode == 0 and "openc lsp --stdio" in help_result.stdout,
            "public help exposes the native language server",
        )
    ]
    first_cases, transcript_a = run_primary_session(compiler, fixture)
    second_cases, transcript_b = run_primary_session(compiler, fixture)
    cases.extend(first_cases)
    cases.extend(run_negative_sessions(compiler))

    transcript_a_text = canonical_json(transcript_a)
    transcript_b_text = canonical_json(transcript_b)
    (output / "lsp-transcript-a.json").write_text(
        transcript_a_text, encoding="utf-8", newline="\n"
    )
    (output / "lsp-transcript-b.json").write_text(
        transcript_b_text, encoding="utf-8", newline="\n"
    )
    cases.append(
        Case(
            "deterministic_transcript",
            transcript_a_text == transcript_b_text
            and [case.passed for case in first_cases]
            == [case.passed for case in second_cases],
            "independent native sessions produce byte-identical transcripts",
        )
    )
    cases.append(
        Case(
            "content_length_utf8_framing",
            all(
                entry.get("message", {}).get("jsonrpc") == "2.0"
                for entry in transcript_a["messages"]
            ),
            "every decoded frame is a JSON-RPC 2.0 message with byte framing",
        )
    )

    passed = sum(case.passed for case in cases)
    report = {
        "schema": "openc.sh11_native_lsp_verification.v1",
        "milestone": "SH-11_NATIVE_LANGUAGE_SERVICE_COMPLETENESS",
        "status": "PASS" if passed == len(cases) else "FAIL",
        "compiler_under_test": native,
        "transport": "stdio-content-length",
        "transcript_schema": "openc.lsp_transcript.v1",
        "transcript_sha256": hashlib.sha256(
            transcript_a_text.encode("utf-8")
        ).hexdigest(),
        "deterministic_transcript_bytes": transcript_a_text == transcript_b_text,
        "cases": [case.__dict__ for case in cases],
        "total": len(cases),
        "passed": passed,
        "failed": len(cases) - passed,
        "required_d_seed": False,
        "retained_d_seed_executed": False,
        "linux_and_freestanding_gate": False,
    }
    report_path = output / "sh11-lsp-verification.json"
    report_path.write_text(
        canonical_json(report), encoding="utf-8", newline="\n"
    )
    print(
        f"SH-11 native LSP: {report['status']}; "
        f"cases={passed}/{len(cases)} "
        f"transcript={report['transcript_sha256']} "
        f"seed_executed=false report={report_path}"
    )
    if report["status"] != "PASS":
        for case in cases:
            if not case.passed:
                print(f"FAIL {case.name}: {case.detail}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
