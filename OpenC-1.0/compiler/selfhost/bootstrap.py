#!/usr/bin/env python3
"""Build and execute the first compiler-in-OpenC seed stage."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str], cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed ({completed.returncode}): {' '.join(command)}\n"
            f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return completed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    args = parser.parse_args()

    stage0 = args.stage0.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = ROOT / "compiler" / "selfhost" / "openc.project.json"
    source = ROOT / "compiler" / "selfhost" / "source" / "main.p"
    stage1 = output / "openc-selfhost-parser.exe"

    run([
        str(stage0), "build", f"--project={project}", f"--output={stage1}",
        f"--build_record={output / 'stage1-build-record.json'}",
    ])
    executed = run([str(stage1), str(source)])
    if not executed.stdout.startswith("OPENC-LEX-OBSERVATION 2\n"):
        raise SystemExit("stage-1 lexer did not emit its versioned observation protocol")
    run([
        sys.executable,
        str(ROOT / "compiler" / "selfhost" / "lexer_parity.py"),
        f"--stage0={stage0}",
        f"--stage1={stage1}",
        f"--output={output}",
    ])
    lexer_parity = json.loads(
        (output / "lexer-parity-result.json").read_text(encoding="utf-8")
    )
    run([
        sys.executable,
        str(ROOT / "compiler" / "selfhost" / "parser_parity.py"),
        f"--stage0={stage0}",
        f"--stage1={stage1}",
        f"--output={output}",
    ])
    parser_parity = json.loads(
        (output / "parser-parity-result.json").read_text(encoding="utf-8")
    )

    record = {
        "schema": "openc.self_host_stage_result.v1",
        "stage": "SH-2C_PARSER_PARITY",
        "status": "PASS",
        "stage0": str(stage0),
        "source": "compiler/selfhost/source/main.p",
        "artifact": str(stage1),
        "self_scan_protocol": executed.stdout.splitlines()[0],
        "lexer_parity_result": str(output / "lexer-parity-result.json"),
        "parser_parity_result": str(output / "parser-parity-result.json"),
        "claims": {
            "compiler_source_written_in_openc": True,
            "stage0_builds_stage1": True,
            "stage1_lexes_own_source": True,
            "stage1_exact_lexer_parity": True,
            "stage1_single_lexical_pass": True,
            "stage1_owned_token_storage": True,
            "stage1_owned_diagnostic_storage": True,
            "stage1_byte_accurate_source_positions": True,
            "stage1_owned_syntax_storage": True,
            "stage1_parser_parity": True,
            "stage1_declaration_type_statement_expression_parser": True,
            "stage1_parser_recovery": True,
            "canonical_sources_compared": parser_parity["canonical_sources"],
            "focused_lexer_probes": lexer_parity["focused_probes"],
            "focused_parser_probes": parser_parity["focused_probes"],
            "syntax_node_kinds_matched": parser_parity["syntax_node_kind_count"],
            "parser_rules_matched": parser_parity["parser_rule_count"],
            "stage1_compiles_openc": False,
            "self_hosted": False,
            "dmd_independent": False,
        },
    }
    (output / "stage1-result.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "self-host parser parity: PASS; "
        f"canonical={parser_parity['canonical_sources']} "
        f"lexer_probes={lexer_parity['focused_probes']} "
        f"parser_probes={parser_parity['focused_probes']} "
        f"artifact={stage1}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
