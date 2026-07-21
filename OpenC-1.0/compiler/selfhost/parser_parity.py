#!/usr/bin/env python3
"""Compare stage-0 and compiler-in-OpenC parser observations."""
from __future__ import annotations

import argparse
import difflib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANONICAL_ROOTS = (
    ROOT / "compiler",
    ROOT / "conformance",
    ROOT / "examples",
    ROOT / "programs",
    ROOT / "standard_library",
    ROOT / "tests",
    ROOT / "runtime",
    ROOT / "tools",
)

PROBES = {
    "valid_parser_surface.p": """import system.io;
struct Point { i32 x = 0; i32 y; }
resource Box { own ptr byte data; usize length; }
enum u8 Color { red = 1, blue }
const i32 answer = 6 * 7;
when true { i32 declared(i32 value); }
unsafe i32 main() {
    i32 value = 0;
    Point point = Point{ x = 1, y = 2 };
    i32[3] values = {1, 2, 3};
    status result = status{ code = 0, message = "" };
    if true { value += 1; } else if false { value = 2; } else { value = 3; }
    while value < 4 { value = value + 1; }
    for (i32 index = 0; index < 2; index = index + 1) { continue; }
    switch value { case 1 { break; } default { value = 0; } }
    when true { value = value << 1; }
    unsafe { ptr i32 address = &value; value = *address; }
    value = cast(i32, value) + cast_unchecked(i32, value);
    value = reinterpret(i32, value);
    value = values[0] + values[0..2][0];
    value = size_of(Point) + align_of(Point);
    scope destroy(point);
    return value;
}
""",
    "invalid_loop_context.p": "i32 main() { break; continue; return 0; }\n",
    "invalid_status_field.p": "i32 main() { status s = status{ bad = 1 }; return 0; }\n",
    "invalid_braces.p": "struct Missing { i32 value;\n",
    "invalid_bracket.p": "i32 main() { i32[2 value; return 0; }\n",
    "invalid_comma.p": "i32 main() { i32 value = cast(i32 1); return value; }\n",
    "invalid_expression.p": "i32 main() { @; return 0; }\n",
    "invalid_identifier.p": "struct { i32 value; }\n",
    "invalid_initializer.p": "struct S { i32 x; } i32 main() { S s = S{ x 1 }; return 0; }\n",
    "invalid_parenthesis.p": "i32 main( { return 0; }\n",
    "invalid_semicolon.p": "i32 main() { i32 value = 1 return value; }\n",
    "invalid_switch.p": "i32 main() { switch 1 { nope { } } return 0; }\n",
    "invalid_top.p": "@\n",
    "invalid_type_order.p": "i32 invalid(const ref i32 value);\n",
    "invalid_type_suffix.p": "i32 invalid(i32[1][2] value);\n",
}

EXPECTED_PARSER_RULES = {
    "OPENC-LOOP-CONTEXT-001",
    "OPENC-STATUS-FIELD-001",
    "OPENC-SYNTAX-BRACES-001",
    "OPENC-SYNTAX-BRACKET-001",
    "OPENC-SYNTAX-COMMA-001",
    "OPENC-SYNTAX-EXPR-001",
    "OPENC-SYNTAX-IDENTIFIER-001",
    "OPENC-SYNTAX-INITIALIZER-001",
    "OPENC-SYNTAX-PAREN-001",
    "OPENC-SYNTAX-PROGRESS-001",
    "OPENC-SYNTAX-SEMICOLON-001",
    "OPENC-SYNTAX-SWITCH-001",
    "OPENC-SYNTAX-TOP-DECL-001",
    "OPENC-TYPE-CONSTRUCTOR-ORDER-001",
    "OPENC-TYPE-SUFFIX-001",
}

EXPECTED_NODE_KINDS = {
    "source_unit", "import_decl", "function_decl", "struct_decl",
    "resource_decl", "enum_decl", "enum_item", "module_const_decl",
    "when_decl", "field_decl", "parameter", "block", "local_decl",
    "expression_stmt", "if_stmt", "while_stmt", "for_stmt", "switch_stmt",
    "switch_case", "default_case", "break_stmt", "continue_stmt",
    "return_stmt", "scope_stmt", "unsafe_stmt", "when_stmt", "type_ref",
    "qualified_name", "integer_literal", "float_literal", "text_literal",
    "bool_literal", "null_literal", "none_literal", "unary_expr",
    "binary_expr", "assignment_expr", "call_expr", "member_expr",
    "index_expr", "range_expr", "cast_expr", "reinterpret_expr",
    "construct_expr", "destroy_expr", "type_query_expr", "status_initializer",
    "aggregate_initializer", "aggregate_field", "array_initializer",
    "out_argument", "missing",
}


def canonical_sources() -> list[Path]:
    sources: set[Path] = set()
    for root in CANONICAL_ROOTS:
        if root.is_dir():
            sources.update(path.resolve() for path in root.rglob("*.p"))
    return sorted(sources, key=lambda path: path.relative_to(ROOT).as_posix())


def execute(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, cwd=ROOT, text=True, capture_output=True, encoding="utf-8"
    )


def observed(output: str) -> tuple[set[str], set[str]]:
    rules: set[str] = set()
    nodes: set[str] = set()
    for line in output.splitlines():
        if line.startswith("ERROR ") or line.startswith("SOURCE_ERROR "):
            rules.add(line.split()[1])
        elif line.startswith("NODE "):
            nodes.add(line.split()[1])
    return rules, nodes


def compare_one(
    stage0: Path, stage1: Path, source: Path
) -> tuple[bool, str, int, set[str], set[str]]:
    reference = execute([str(stage0), "parse-observe", str(source)])
    candidate = execute([str(stage1), "--parse", str(source)])
    if reference.returncode not in (0, 1):
        return False, f"stage 0 infrastructure exit {reference.returncode}: {reference.stderr}", 0, set(), set()
    if candidate.returncode not in (0, 1):
        return False, f"stage 1 infrastructure exit {candidate.returncode}: {candidate.stderr}", 0, set(), set()
    if reference.returncode != candidate.returncode or reference.stdout != candidate.stdout:
        difference = "".join(
            difflib.unified_diff(
                reference.stdout.splitlines(keepends=True),
                candidate.stdout.splitlines(keepends=True),
                fromfile="stage0",
                tofile="stage1",
                n=3,
            )
        )
        return (
            False,
            f"exit stage0={reference.returncode} stage1={candidate.returncode}\n"
            f"{difference[:16000]}",
            0,
            set(),
            set(),
        )
    rules, nodes = observed(reference.stdout)
    return True, "", reference.returncode, rules, nodes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument(
        "--stage1", type=Path,
        default=ROOT / "build-output" / "selfhost" / "openc-selfhost-parser.exe",
    )
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    args = parser.parse_args()

    stage0 = args.stage0.resolve()
    stage1 = args.stage1.resolve()
    output = args.output.resolve()
    probe_root = output / "parser-parity-probes"
    probe_root.mkdir(parents=True, exist_ok=True)
    for name, source in PROBES.items():
        (probe_root / name).write_text(source, encoding="utf-8", newline="\n")

    canonical = canonical_sources()
    probes = sorted(probe_root.glob("*.p"), key=lambda path: path.name)
    failures: list[dict[str, str]] = []
    accepted = 0
    rejected = 0
    rules: set[str] = set()
    nodes: set[str] = set()
    for source in canonical + probes:
        matched, detail, exit_code, case_rules, case_nodes = compare_one(
            stage0, stage1, source
        )
        if not matched:
            try:
                label = source.relative_to(ROOT).as_posix()
            except ValueError:
                label = str(source)
            failures.append({"source": label, "detail": detail})
            if len(failures) == 10:
                break
        elif exit_code == 0:
            accepted += 1
        else:
            rejected += 1
        rules.update(case_rules)
        nodes.update(case_nodes)

    missing_rules = EXPECTED_PARSER_RULES - rules
    if missing_rules:
        failures.append({
            "source": "<parser-diagnostic-coverage>",
            "detail": "missing observed rules: " + ", ".join(sorted(missing_rules)),
        })
    missing_nodes = EXPECTED_NODE_KINDS - nodes
    if missing_nodes:
        failures.append({
            "source": "<syntax-node-coverage>",
            "detail": "missing observed node kinds: " + ", ".join(sorted(missing_nodes)),
        })

    total = len(canonical) + len(probes)
    result = {
        "schema": "openc.self_host_parser_parity.v1",
        "stage": "SH-2C_PARSER_PARITY",
        "status": "PASS" if not failures else "FAIL",
        "protocol": "OPENC-PARSE-OBSERVATION 1",
        "stage0": str(stage0),
        "stage1": str(stage1),
        "canonical_sources": len(canonical),
        "focused_probes": len(probes),
        "comparisons": total if not failures else accepted + rejected + len(failures),
        "accepted": accepted,
        "rejected": rejected,
        "parser_rules_observed": sorted(EXPECTED_PARSER_RULES & rules),
        "parser_rule_count": len(EXPECTED_PARSER_RULES & rules),
        "syntax_node_kinds_observed": sorted(nodes),
        "syntax_node_kind_count": len(nodes),
        "failures": failures,
        "matched_fields": [
            "process_exit", "syntax_node_creation_order", "syntax_node_kind",
            "syntax_node_byte_offset", "syntax_node_byte_length",
            "diagnostic_rule", "diagnostic_byte_offset", "diagnostic_byte_length",
            "diagnostic_line", "diagnostic_byte_column", "node_count", "error_count",
        ],
    }
    (output / "parser-parity-result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8", newline="\n",
    )
    if failures:
        first = failures[0]
        raise SystemExit(f"parser parity failed: {first['source']}\n{first['detail']}")
    print(
        "self-host parser parity: PASS; "
        f"canonical={len(canonical)} probes={len(probes)} comparisons={total}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
