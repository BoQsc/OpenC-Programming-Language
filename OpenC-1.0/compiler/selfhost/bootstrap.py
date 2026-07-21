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
    stage1 = output / "openc-selfhost-frontend.exe"

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
    run([
        sys.executable,
        str(ROOT / "compiler" / "selfhost" / "project_parity.py"),
        f"--stage0={stage0}",
        f"--stage1={stage1}",
        f"--output={output}",
    ])
    project_parity = json.loads(
        (output / "project-parity-result.json").read_text(encoding="utf-8")
    )
    run([
        sys.executable,
        str(ROOT / "compiler" / "selfhost" / "semantic_declaration_parity.py"),
        f"--stage0={stage0}",
        f"--stage1={stage1}",
        f"--output={output}",
    ])
    semantic_declaration_parity = json.loads(
        (output / "semantic-declaration-parity-result.json").read_text(encoding="utf-8")
    )
    run([
        sys.executable,
        str(ROOT / "compiler" / "selfhost" / "semantic_resolution_parity.py"),
        f"--stage0={stage0}",
        f"--stage1={stage1}",
        f"--output={output}",
    ])
    semantic_resolution_parity = json.loads(
        (output / "semantic-resolution-parity-result.json").read_text(encoding="utf-8")
    )
    run([
        sys.executable,
        str(ROOT / "compiler" / "selfhost" / "semantic_flow_safety_parity.py"),
        f"--stage0={stage0}",
        f"--stage1={stage1}",
        f"--output={output}",
    ])
    semantic_flow_safety_parity = json.loads(
        (output / "semantic-flow-safety-parity-result.json").read_text(encoding="utf-8")
    )
    run([
        sys.executable,
        str(ROOT / "compiler" / "selfhost" / "semantic_ir_parity.py"),
        f"--stage0={stage0}",
        f"--stage1={stage1}",
        f"--output={output}",
    ])
    semantic_ir_parity = json.loads(
        (output / "semantic-ir-parity-result.json").read_text(encoding="utf-8")
    )

    record = {
        "schema": "openc.self_host_stage_result.v1",
        "stage": "SH-3_SEMANTIC_AND_IR_PARITY",
        "status": "PASS",
        "stage0": str(stage0),
        "source": "compiler/selfhost/source/main.p",
        "artifact": str(stage1),
        "self_scan_protocol": executed.stdout.splitlines()[0],
        "lexer_parity_result": str(output / "lexer-parity-result.json"),
        "parser_parity_result": str(output / "parser-parity-result.json"),
        "project_parity_result": str(output / "project-parity-result.json"),
        "semantic_declaration_parity_result": str(
            output / "semantic-declaration-parity-result.json"
        ),
        "semantic_resolution_parity_result": str(
            output / "semantic-resolution-parity-result.json"
        ),
        "semantic_flow_safety_parity_result": str(
            output / "semantic-flow-safety-parity-result.json"
        ),
        "semantic_ir_parity_result": str(output / "semantic-ir-parity-result.json"),
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
            "stage1_project_loading": True,
            "stage1_multi_source_composition": True,
            "stage1_module_import_graph": True,
            "stage1_project_module_parity": True,
            "stage1_owned_semantic_type_storage": True,
            "stage1_declaration_symbol_type_parity": True,
            "stage1_name_constant_overload_parity": True,
            "stage1_flow_safety_parity": True,
            "stage1_semantic_outcome_parity": True,
            "stage1_canonical_ir_parity": True,
            "canonical_sources_compared": parser_parity["canonical_sources"],
            "focused_lexer_probes": lexer_parity["focused_probes"],
            "focused_parser_probes": parser_parity["focused_probes"],
            "syntax_node_kinds_matched": parser_parity["syntax_node_kind_count"],
            "parser_rules_matched": parser_parity["parser_rule_count"],
            "canonical_projects_compared": project_parity["canonical_projects"],
            "focused_project_probes": project_parity["focused_probes"],
            "project_module_rules_matched": project_parity["module_graph_rules"],
            "semantic_declaration_projects_compared": semantic_declaration_parity["comparisons"],
            "semantic_declaration_records_matched": semantic_declaration_parity["observed_records"]["declarations"],
            "semantic_type_records_matched": semantic_declaration_parity["observed_records"]["types"],
            "semantic_resolution_projects_compared": semantic_resolution_parity["comparisons"],
            "semantic_bindings_matched": semantic_resolution_parity["observed_records"]["bindings"],
            "semantic_constants_matched": semantic_resolution_parity["observed_records"]["constants"],
            "semantic_calls_matched": semantic_resolution_parity["observed_records"]["calls"],
            "semantic_flow_comparisons": semantic_flow_safety_parity["semantic_comparisons"],
            "semantic_flow_rules_observed": len(
                semantic_flow_safety_parity["flow_safety_rules_observed"]
            ),
            "semantic_ir_comparisons": semantic_ir_parity["ir_comparisons"],
            "semantic_rejections_matched": semantic_ir_parity["semantic_rejections"],
            "semantic_ir_instructions_matched": semantic_ir_parity["observed_records"]["instructions"],
            "semantic_ir_opcodes_matched": len(semantic_ir_parity["observed_records"]["opcodes"]),
            "stage1_compiles_openc": False,
            "self_hosted": False,
            "dmd_independent": False,
        },
    }
    (output / "stage1-result.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "self-host semantic and canonical IR parity: PASS; "
        f"canonical={parser_parity['canonical_sources']} "
        f"lexer_probes={lexer_parity['focused_probes']} "
        f"parser_probes={parser_parity['focused_probes']} "
        f"projects={project_parity['comparisons']} "
        f"semantic_projects={semantic_declaration_parity['comparisons']} "
        f"resolution_projects={semantic_resolution_parity['comparisons']} "
        f"flow={semantic_flow_safety_parity['semantic_comparisons']} "
        f"ir={semantic_ir_parity['ir_comparisons']} "
        f"rejected={semantic_ir_parity['semantic_rejections']} "
        f"artifact={stage1}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
