#!/usr/bin/env python3
"""Verify the OpenC-native SH-12 project-semantic language-service contract."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from native_toolchain import resolve_native_compiler, validate_native_compiler
from verify_sh11_lsp import Case, LspClient, canonical_json, request


SEMANTIC_METHODS = [
    "textDocument/documentSymbol",
    "textDocument/hover",
    "textDocument/definition",
    "textDocument/references",
    "textDocument/completion",
    "textDocument/prepareRename",
    "textDocument/rename",
]


def semantic_request(
    client: LspClient,
    transcript: list[dict],
    method: str,
    params: dict,
    request_id: int,
) -> dict:
    message = request(method, params, request_id)
    client.send(message)
    transcript.append({"direction": "client-to-server", "message": message})
    response = client.receive()
    transcript.append({"direction": "server-to-client", "message": response})
    return response


def open_document(client: LspClient, document: dict, version: int) -> dict:
    client.send(
        request(
            "textDocument/didOpen",
            {
                "textDocument": {
                    "uri": document["uri"],
                    "languageId": "openc",
                    "version": version,
                    "text": document["source"],
                }
            },
        )
    )
    return client.receive()


def semantic_record(fixture: dict, messages: list[dict]) -> dict:
    return {
        "schema": "openc.semantic_lsp_transcript.v1",
        "server": "openc-lsp",
        "target": "windows-x86_64-hosted",
        "transport": "stdio-content-length",
        "projectRoot": fixture["root_uri"],
        "documents": sorted(
            item["uri"] for item in fixture["documents"].values()
        ),
        "semanticMethods": SEMANTIC_METHODS,
        "messages": messages,
    }


def symbol_by_name(response: dict, name: str) -> dict:
    return next(
        (
            symbol
            for symbol in (response.get("result") or [])
            if symbol.get("name") == name
        ),
        {},
    )


def run_semantic_session(
    compiler: Path,
    fixture: dict,
    open_order: list[str],
) -> tuple[list[Case], dict]:
    cases: list[Case] = []
    semantic_messages: list[dict] = []
    documents = fixture["documents"]
    main = documents["main"]
    types = documents["types"]
    outside = documents["outside"]
    point_position = fixture["positions"]["point_use"]
    area_position = fixture["positions"]["area_declaration"]
    client = LspClient(compiler)
    try:
        client.send(
            request(
                "initialize",
                {
                    "rootUri": fixture["root_uri"],
                    "capabilities": {},
                },
                1,
            )
        )
        initialized = client.receive()
        capabilities = initialized.get("result", {}).get("capabilities", {})
        cases.extend(
            [
                Case(
                    "semantic_capabilities",
                    capabilities.get("documentSymbolProvider") is True
                    and capabilities.get("hoverProvider") is True
                    and capabilities.get("definitionProvider") is True
                    and capabilities.get("referencesProvider") is True,
                    "initialize advertises symbols, hover, definition, and references",
                ),
                Case(
                    "completion_capability",
                    capabilities.get("completionProvider", {}).get(
                        "resolveProvider"
                    )
                    is False,
                    "initialize advertises deterministic completion",
                ),
                Case(
                    "safe_rename_capability",
                    capabilities.get("renameProvider", {}).get(
                        "prepareProvider"
                    )
                    is True,
                    "initialize advertises validated prepare-rename",
                ),
            ]
        )
        client.send(request("initialized", {}))
        open_notifications: list[dict] = []
        for version, name in enumerate(open_order, 1):
            open_notifications.append(
                open_document(client, documents[name], version)
            )
        cases.append(
            Case(
                "multi_document_synchronization",
                len(open_notifications) == 3
                and all(
                    item.get("method")
                    == "textDocument/publishDiagnostics"
                    and item.get("params", {}).get("diagnostics") == []
                    for item in open_notifications
                ),
                "three independently synchronized documents remain valid",
            )
        )

        type_symbols = semantic_request(
            client,
            semantic_messages,
            "textDocument/documentSymbol",
            {"textDocument": {"uri": types["uri"]}},
            2,
        )
        point_symbol = symbol_by_name(type_symbols, "Point")
        origin_symbol = symbol_by_name(type_symbols, "origin")
        cases.extend(
            [
                Case(
                    "document_symbols",
                    [
                        item.get("name")
                        for item in (type_symbols.get("result") or [])
                    ]
                    == ["Point", "origin"],
                    "document symbols preserve deterministic source order",
                ),
                Case(
                    "typed_symbol_details",
                    point_symbol.get("kind") == 23
                    and point_symbol.get("detail") == "struct Point"
                    and origin_symbol.get("kind") == 14
                    and origin_symbol.get("detail") == "const origin: i32",
                    "document symbols expose declaration kinds and types",
                ),
            ]
        )

        main_symbols = semantic_request(
            client,
            semantic_messages,
            "textDocument/documentSymbol",
            {"textDocument": {"uri": main["uri"]}},
            3,
        )
        cases.append(
            Case(
                "function_symbols",
                [
                    (item.get("name"), item.get("detail"), item.get("kind"))
                    for item in (main_symbols.get("result") or [])
                ]
                == [
                    ("area", "function area: i32", 12),
                    ("main", "function main: i32", 12),
                ],
                "function symbols carry stable typed details",
            )
        )

        hover = semantic_request(
            client,
            semantic_messages,
            "textDocument/hover",
            {
                "textDocument": {"uri": main["uri"]},
                "position": area_position,
            },
            4,
        )
        cases.append(
            Case(
                "typed_hover",
                (hover.get("result") or {})
                .get("contents", {})
                .get("value")
                == "```openc\nfunction area: i32\n```",
                "hover publishes a typed OpenC declaration",
            )
        )

        definition = semantic_request(
            client,
            semantic_messages,
            "textDocument/definition",
            {
                "textDocument": {"uri": main["uri"]},
                "position": point_position,
            },
            5,
        )
        definition_result = definition.get("result") or []
        cases.append(
            Case(
                "cross_document_definition",
                len(definition_result) == 1
                and definition_result[0].get("uri") == types["uri"]
                and definition_result[0]
                .get("range", {})
                .get("start")
                == {"line": 0, "character": 7},
                "definition crosses synchronized project documents",
            )
        )

        references = semantic_request(
            client,
            semantic_messages,
            "textDocument/references",
            {
                "textDocument": {"uri": main["uri"]},
                "position": point_position,
                "context": {"includeDeclaration": True},
            },
            6,
        )
        reference_result = references.get("result") or []
        cases.extend(
            [
                Case(
                    "project_references",
                    len(reference_result) == 3
                    and {item.get("uri") for item in reference_result}
                    == {main["uri"], types["uri"]},
                    "references include declaration and uses across the project",
                ),
                Case(
                    "reference_order",
                    [item.get("uri") for item in reference_result]
                    == [main["uri"], main["uri"], types["uri"]],
                    "references are sorted by URI and source position",
                ),
            ]
        )

        completion = semantic_request(
            client,
            semantic_messages,
            "textDocument/completion",
            {
                "textDocument": {"uri": main["uri"]},
                "position": {"line": 6, "character": 11},
            },
            7,
        )
        completion_result = completion.get("result") or {}
        labels = [
            item.get("label") for item in completion_result.get("items", [])
        ]
        cases.extend(
            [
                Case(
                    "deterministic_completion",
                    completion_result.get("isIncomplete") is False
                    and labels == ["Point", "area", "main", "origin"],
                    "completion is complete, unique, and lexicographically sorted",
                ),
                Case(
                    "project_root_boundary",
                    "Foreign" not in labels,
                    "symbols outside initialize.rootUri do not enter project context",
                ),
            ]
        )

        prepared = semantic_request(
            client,
            semantic_messages,
            "textDocument/prepareRename",
            {
                "textDocument": {"uri": main["uri"]},
                "position": point_position,
            },
            8,
        )
        cases.append(
            Case(
                "prepare_rename",
                (prepared.get("result") or {}).get("placeholder") == "Point"
                and (prepared.get("result") or {})
                .get("range", {})
                .get("start")
                == {"line": 0, "character": 9},
                "prepare-rename validates and ranges the target",
            )
        )

        renamed = semantic_request(
            client,
            semantic_messages,
            "textDocument/rename",
            {
                "textDocument": {"uri": main["uri"]},
                "position": point_position,
                "newName": "Vertex",
            },
            9,
        )
        changes = (renamed.get("result") or {}).get("changes", {})
        cases.extend(
            [
                Case(
                    "project_safe_rename",
                    list(changes) == [main["uri"], types["uri"]]
                    and len(changes.get(main["uri"], [])) == 2
                    and len(changes.get(types["uri"], [])) == 1
                    and all(
                        edit.get("newText") == "Vertex"
                        for edits in changes.values()
                        for edit in edits
                    ),
                    "safe rename emits deterministic edits for all project uses",
                ),
                Case(
                    "rename_edit_order",
                    [
                        edit.get("range", {}).get("start")
                        for edit in changes.get(main["uri"], [])
                    ]
                    == [
                        {"line": 0, "character": 9},
                        {"line": 5, "character": 4},
                    ],
                    "rename edits are sorted by source position",
                ),
            ]
        )

        invalid_rename = semantic_request(
            client,
            semantic_messages,
            "textDocument/rename",
            {
                "textDocument": {"uri": main["uri"]},
                "position": point_position,
                "newName": "struct",
            },
            10,
        )
        collision_rename = semantic_request(
            client,
            semantic_messages,
            "textDocument/rename",
            {
                "textDocument": {"uri": main["uri"]},
                "position": point_position,
                "newName": "area",
            },
            11,
        )
        cases.extend(
            [
                Case(
                    "unsafe_rename_rejected",
                    invalid_rename.get("error", {}).get("code") == -32602,
                    "keywords cannot become rename targets",
                ),
                Case(
                    "rename_collision_rejected",
                    collision_rename.get("error", {}).get("code") == -32602,
                    "rename rejects collision with an existing declaration",
                ),
            ]
        )

        client.send(
            request(
                "textDocument/didClose",
                {"textDocument": {"uri": types["uri"]}},
            )
        )
        close_notification = client.receive()
        definition_after_close = semantic_request(
            client,
            semantic_messages,
            "textDocument/definition",
            {
                "textDocument": {"uri": main["uri"]},
                "position": point_position,
            },
            12,
        )
        cases.append(
            Case(
                "synchronized_close_removes_symbols",
                close_notification.get("params", {}).get("diagnostics") == []
                and definition_after_close.get("result") == [],
                "closing a document removes its declarations from project context",
            )
        )

        client.send(request("shutdown", None, 13))
        shutdown = client.receive()
        client.send(request("exit", None))
        exit_code, stderr = client.finish()
        cases.append(
            Case(
                "semantic_session_shutdown",
                shutdown.get("result") is None
                and exit_code == 0
                and stderr == "",
                "the multi-document semantic session shuts down cleanly",
            )
        )
        return cases, semantic_record(fixture, semantic_messages)
    finally:
        client.terminate()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "selfhost-sh12" / "semantic-lsp",
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
        (
            ROOT / "tests" / "tooling" / "sh12" / "session.json"
        ).read_text(encoding="utf-8")
    )
    first_cases, transcript_a = run_semantic_session(
        compiler, fixture, ["types", "main", "outside"]
    )
    second_cases, transcript_b = run_semantic_session(
        compiler, fixture, ["outside", "main", "types"]
    )
    cases = list(first_cases)
    transcript_a_text = canonical_json(transcript_a)
    transcript_b_text = canonical_json(transcript_b)
    (output / "semantic-lsp-transcript-a.json").write_text(
        transcript_a_text, encoding="utf-8", newline="\n"
    )
    (output / "semantic-lsp-transcript-b.json").write_text(
        transcript_b_text, encoding="utf-8", newline="\n"
    )
    cases.append(
        Case(
            "open_order_independent_transcript",
            transcript_a_text == transcript_b_text
            and [case.passed for case in first_cases]
            == [case.passed for case in second_cases],
            "opposite document-open orders produce byte-identical semantic transcripts",
        )
    )
    schema = json.loads(
        (
            ROOT / "schemas" / "SEMANTIC_LSP_TRANSCRIPT.schema.json"
        ).read_text(encoding="utf-8")
    )
    validation_errors = sorted(
        Draft202012Validator(schema).iter_errors(transcript_a),
        key=lambda error: list(error.path),
    )
    cases.append(
        Case(
            "semantic_transcript_schema",
            not validation_errors,
            "the semantic transcript validates against its published schema",
        )
    )
    cases.append(
        Case(
            "standalone_native_provenance",
            native.get("dmd_invoked") is False
            and native.get("dub_invoked") is False
            and native.get("python_invoked") is False,
            "the compiler under test is a verified standalone native build",
        )
    )

    passed = sum(case.passed for case in cases)
    report = {
        "schema": "openc.sh12_semantic_lsp_verification.v1",
        "milestone": "SH-12_NATIVE_SEMANTIC_LANGUAGE_INTELLIGENCE",
        "status": "PASS" if passed == len(cases) else "FAIL",
        "compiler_under_test": native,
        "transport": "stdio-content-length",
        "transcript_schema": "openc.semantic_lsp_transcript.v1",
        "transcript_sha256": hashlib.sha256(
            transcript_a_text.encode("utf-8")
        ).hexdigest(),
        "open_order_independent": transcript_a_text == transcript_b_text,
        "project_document_count": len(fixture["documents"]),
        "semantic_methods": SEMANTIC_METHODS,
        "cases": [case.__dict__ for case in cases],
        "total": len(cases),
        "passed": passed,
        "failed": len(cases) - passed,
        "required_d_seed": False,
        "retained_d_seed_executed": False,
        "linux_and_freestanding_gate": False,
    }
    report_path = output / "sh12-semantic-lsp-verification.json"
    report_path.write_text(
        canonical_json(report), encoding="utf-8", newline="\n"
    )
    print(
        f"SH-12 semantic LSP: {report['status']}; "
        f"cases={passed}/{len(cases)} "
        f"transcript={report['transcript_sha256']} "
        f"seed_executed=false report={report_path}"
    )
    if report["status"] != "PASS":
        for case in cases:
            if not case.passed:
                print(f"FAIL {case.name}: {case.detail}", file=sys.stderr)
        for error in validation_errors:
            print(f"SCHEMA {error.json_path}: {error.message}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
