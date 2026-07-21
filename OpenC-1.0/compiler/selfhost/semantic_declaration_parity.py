#!/usr/bin/env python3
"""Prove exact stage-0/stage-1 declaration, symbol, and type-table parity."""
from __future__ import annotations

import argparse
import difflib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, cwd=ROOT, text=True, capture_output=True, encoding="utf-8"
    )


def focused_cases() -> list[tuple[str, dict[str, list[str]], dict[str, str]]]:
    return [
        (
            "primitive_signatures",
            {"app": ["main.p"]},
            {"main.p": "export i32 f(i8 a, u16 b, i64 c, usize d, f32 e, bool f, byte g, text h, status i);\n"},
        ),
        (
            "aggregate_fields",
            {"app": ["types.p"]},
            {"types.p": "struct Pair { i32 left = 1; const u32 right; }\n"},
        ),
        (
            "resource_ownership",
            {"app": ["types.p"]},
            {"types.p": "resource Buffer { own ptr byte data; usize length; } struct Holder { Buffer buffer; }\n"},
        ),
        (
            "enum_items",
            {"app": ["types.p"]},
            {"types.p": "enum u8 Color { red = 1, green, blue = 7 }\n"},
        ),
        (
            "module_constants",
            {"app": ["constants.p"]},
            {"constants.p": "const i32 answer = 42; const text label = \"OpenC\";\n"},
        ),
        (
            "parameter_modes",
            {"app": ["api.p"]},
            {"api.p": "unsafe own ptr byte make(out i32 code, out own text message, own ptr byte seed);\n"},
        ),
        (
            "type_constructors",
            {"app": ["api.p"]},
            {"api.p": "void views(ref i32 a, ref const i32 b, ptr byte c, ptr const byte d, optional text e, storage i64 f);\n"},
        ),
        (
            "type_suffixes",
            {"app": ["api.p"]},
            {"api.p": "void containers(i32[] values, byte[16] digest, const u32[] words);\n"},
        ),
        (
            "function_overloads",
            {"app": ["api.p"]},
            {"api.p": "i32 choose(i32 value); i64 choose(i64 value);\n"},
        ),
        (
            "duplicate_top_level",
            {"app": ["a.p", "b.p"]},
            {"a.p": "struct Same { i32 first; }\n", "b.p": "struct Same { i32 second; }\n"},
        ),
        (
            "duplicate_field",
            {"app": ["types.p"]},
            {"types.p": "struct Bad { i32 value; i64 value; }\n"},
        ),
        (
            "multi_source_predeclaration",
            {"app": ["api.p", "types.p"]},
            {"api.p": "Node identity(Node value);\n", "types.p": "struct Node { i32 value; }\n"},
        ),
        (
            "qualified_cross_module",
            {"app": ["main.p"], "model": ["model.p"]},
            {"main.p": "import model; model.Point copy(model.Point value);\n", "model.p": "export struct Point { i32 x; i32 y; }\n"},
        ),
        (
            "visibility_and_order",
            {"zeta": ["z.p"], "alpha": ["a.p"]},
            {"a.p": "export struct A { i32 x; } i32 a();\n", "z.p": "struct Z { i32 z; } export i32 z();\n"},
        ),
        (
            "conditional_declarations",
            {"app": ["conditional.p"]},
            {"conditional.p": "when true { i32 enabled(i32 value); struct Nested { i32 field; } }\n"},
        ),
        (
            "implicit_named_type",
            {"app": ["api.p"]},
            {"api.p": "External pass(External value);\n"},
        ),
    ]


def compare(project: Path, stage0: Path, stage1: Path) -> tuple[bool, str, str, int, int]:
    reference = run([str(stage0), "semantic-decl-observe", str(project.resolve())])
    candidate = run([str(stage1), "--semantic-decl", str(project.resolve())])
    exact = (
        reference.returncode == candidate.returncode
        and reference.stdout == candidate.stdout
        and reference.stderr == candidate.stderr
    )
    if exact:
        return True, "", reference.stdout, reference.returncode, candidate.returncode
    difference = "".join(
        difflib.unified_diff(
            reference.stdout.splitlines(keepends=True),
            candidate.stdout.splitlines(keepends=True),
            fromfile="stage0",
            tofile="stage1",
            n=3,
        )
    )
    detail = (
        f"exit stage0={reference.returncode} stage1={candidate.returncode}\n"
        f"stage0 stderr: {reference.stderr}\n"
        f"stage1 stderr: {candidate.stderr}\n{difference[:20000]}"
    )
    return False, detail, reference.stdout, reference.returncode, candidate.returncode


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument("--stage1", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    args = parser.parse_args()

    stage0 = args.stage0.resolve()
    stage1 = args.stage1.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    failures: list[dict[str, str]] = []
    observations = {"declarations": 0, "parameters": 0, "fields": 0, "items": 0, "types": 0}
    observed_rules: set[str] = set()
    cases: list[tuple[str, Path]] = [
        ("canonical:compiler/selfhost/openc.project.json", ROOT / "compiler" / "selfhost" / "openc.project.json")
    ]
    focused = focused_cases()

    with tempfile.TemporaryDirectory(prefix="semantic-decl-parity-", dir=output) as temporary:
        temporary_root = Path(temporary)
        for name, modules, files in focused:
            case_root = temporary_root / name
            case_root.mkdir()
            project = case_root / "openc.project.json"
            project.write_text(
                json.dumps({"target": "windows-x86_64", "modules": modules}),
                encoding="utf-8",
                newline="\n",
            )
            for relative, content in files.items():
                (case_root / relative).write_text(content, encoding="utf-8", newline="\n")
            cases.append((f"probe:{name}", project))

        for name, project in cases:
            matched, detail, observation, _, _ = compare(project, stage0, stage1)
            if not matched:
                failures.append({"case": name, "detail": detail})
                continue
            for line in observation.splitlines():
                if line.startswith("DECL "):
                    observations["declarations"] += 1
                elif line.startswith("PARAM "):
                    observations["parameters"] += 1
                elif line.startswith("FIELD "):
                    observations["fields"] += 1
                elif line.startswith("ITEM "):
                    observations["items"] += 1
                elif line.startswith("TYPE "):
                    observations["types"] += 1
                elif line.startswith("ERROR "):
                    observed_rules.add(line.split()[1])

    required_rules = {"OPENC-NAME-DUPLICATE-001"}
    if required_rules - observed_rules:
        failures.append({
            "case": "<diagnostic-coverage>",
            "detail": "missing declaration rule coverage: " + ", ".join(sorted(required_rules - observed_rules)),
        })

    result = {
        "schema": "openc.self_host_semantic_declaration_parity.v1",
        "stage": "SH-3A_DECLARATION_SYMBOL_TYPE_PARITY",
        "status": "PASS" if not failures else "FAIL",
        "protocol": "OPENC-SEMANTIC-DECL-OBSERVATION 1",
        "stage0": str(stage0),
        "stage1": str(stage1),
        "canonical_projects": 1,
        "focused_probes": len(focused),
        "comparisons": len(cases),
        "observed_records": observations,
        "declaration_rules_observed": sorted(observed_rules),
        "failures": failures,
        "matched_fields": [
            "process_exit", "module_order", "source_order", "declaration_order",
            "symbol_kind", "visibility", "name", "source_span", "function_flags",
            "parameter_mode", "field_resource_state", "canonical_type_id",
            "type_kind", "type_display", "type_element", "array_length",
            "scalar_width", "const_qualification", "resource_qualification",
            "declaration_diagnostic_rule", "declaration_diagnostic_span",
        ],
    }
    (output / "semantic-declaration-parity-result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if failures:
        first = failures[0]
        raise SystemExit(f"semantic declaration parity failed: {first['case']}\n{first['detail']}")
    print(
        "self-host semantic declaration parity: PASS; "
        f"canonical=1 probes={len(focused)} comparisons={len(cases)} "
        f"declarations={observations['declarations']} types={observations['types']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
