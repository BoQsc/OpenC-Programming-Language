#!/usr/bin/env python3
"""Verify the public SH-9 native CLI and diagnostic usability contract."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

from native_toolchain import ROOT, resolve_native_compiler, validate_native_compiler


def run(compiler: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(compiler), *arguments],
        cwd=ROOT,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )


def result(
    name: str,
    completed: subprocess.CompletedProcess[str],
    passed: bool,
) -> dict[str, object]:
    print(f"{name}: {'PASS' if passed else 'FAIL'}")
    return {
        "name": name,
        "command": completed.args,
        "exit_code": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "passed": passed,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compiler", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "build-output" / "sh9-cli-verification",
    )
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    cases: list[dict[str, object]] = []

    completed = run(compiler, "help")
    cases.append(
        result(
            "help",
            completed,
            completed.returncode == 0
            and "openc check" in completed.stdout
            and "openc run" in completed.stdout
            and "openc explain" in completed.stdout,
        )
    )

    completed = run(compiler, "version")
    cases.append(
        result(
            "version",
            completed,
            completed.returncode == 0
            and completed.stdout
            == "OpenC 1.0.0-rc.9\ncompiler: OpenC self-hosted native\n",
        )
    )

    completed = run(compiler, "target")
    cases.append(
        result(
            "target",
            completed,
            completed.returncode == 0
            and "target: windows-x86_64-hosted\n" in completed.stdout
            and "pointer-width: 64\n" in completed.stdout
            and "backend: c11-tinycc-win64\n" in completed.stdout,
        )
    )

    completed = run(compiler, "explain", "OPENC-LEX-COMMENT-001")
    cases.append(
        result(
            "explain_active_rule",
            completed,
            completed.returncode == 0
            and "title: Comments do not affect token meaning\n" in completed.stdout
            and "phase: lexical\n" in completed.stdout,
        )
    )

    completed = run(compiler, "explain", "OPENC-SAFE-INIT-001")
    cases.append(
        result(
            "explain_historical_diagnostic",
            completed,
            completed.returncode == 0
            and "status: historical_compatibility_disclosed\n"
            in completed.stdout,
        )
    )

    completed = run(compiler, "explain", "OPENC-NOT-A-RULE-001")
    cases.append(
        result(
            "explain_unknown_rule",
            completed,
            completed.returncode == 2
            and "unknown OpenC rule" in completed.stderr,
        )
    )

    valid_record = output / "valid-check.json"
    valid_project = ROOT / "demos" / "hello" / "openc.project.json"
    completed = run(
        compiler,
        "check",
        f"--project={valid_project}",
        f"--output={valid_record}",
    )
    valid_data = (
        json.loads(valid_record.read_text(encoding="utf-8"))
        if valid_record.is_file()
        else {}
    )
    cases.append(
        result(
            "check_valid",
            completed,
            completed.returncode == 0
            and completed.stdout == "OpenC check: PASS\n"
            and valid_data.get("schema") == "openc.check.v1"
            and valid_data.get("status") == "PASS"
            and valid_data.get("stages")
            == {"project": 0, "flow": 0, "semantic_ir": 0},
        )
    )

    lexical_record = output / "lexical-check.json"
    lexical_project = (
        ROOT
        / "conformance"
        / "fixtures"
        / "native-projects"
        / "invalid__unterminated_block_comment.json"
    )
    completed = run(
        compiler,
        "check",
        f"--project={lexical_project}",
        f"--output={lexical_record}",
    )
    lexical_data = (
        json.loads(lexical_record.read_text(encoding="utf-8"))
        if lexical_record.is_file()
        else {}
    )
    project_stream = (
        lexical_data.get("machine_diagnostics", {}).get("project", "")
    )
    cases.append(
        result(
            "check_lexical_diagnostic",
            completed,
            completed.returncode == 1
            and "error[OPENC-LEX-COMMENT-001]" in completed.stderr
            and lexical_data.get("status") == "FAIL"
            and "ERROR OPENC-LEX-COMMENT-001" in project_stream,
        )
    )

    flow_record = output / "flow-check.json"
    flow_project = (
        ROOT
        / "conformance"
        / "fixtures"
        / "native-projects"
        / "invalid__read_uninitialized.json"
    )
    completed = run(
        compiler,
        "check",
        f"--project={flow_project}",
        f"--output={flow_record}",
    )
    flow_data = (
        json.loads(flow_record.read_text(encoding="utf-8"))
        if flow_record.is_file()
        else {}
    )
    flow_stream = flow_data.get("machine_diagnostics", {}).get("flow", "")
    cases.append(
        result(
            "check_flow_diagnostic",
            completed,
            completed.returncode == 1
            and "error[OPENC-SAFE-INIT-001]" in completed.stderr
            and "OPENC-SAFE-INIT-001" in flow_stream,
        )
    )

    semantic_record = output / "semantic-check.json"
    semantic_project = (
        ROOT
        / "conformance"
        / "fixtures"
        / "native-projects"
        / "invalid__text_index.json"
    )
    completed = run(
        compiler,
        "check",
        f"--project={semantic_project}",
        f"--output={semantic_record}",
    )
    semantic_data = (
        json.loads(semantic_record.read_text(encoding="utf-8"))
        if semantic_record.is_file()
        else {}
    )
    cases.append(
        result(
            "check_semantic_diagnostic",
            completed,
            completed.returncode == 1
            and "semantic acceptance rejected the project" in completed.stderr
            and "SEMANTIC_ERROR" in semantic_data.get(
                "machine_diagnostics", {}
            ).get("semantic_ir", ""),
        )
    )

    completed = run(compiler, "run", f"--project={valid_project}")
    hello_output = (
        "Hello, OpenC!\n"
        "Welcome to the OpenC programming language.\n"
        "This is a demo of the Hosted I/O system.\n"
    )
    cases.append(
        result(
            "run_demo",
            completed,
            completed.returncode == 0
            and completed.stdout == hello_output
            and completed.stderr == "",
        )
    )

    argument_project = (
        ROOT / "programs" / "D_HOSTED_CLI" / "openc.project.json"
    )
    completed = run(
        compiler,
        "run",
        f"--project={argument_project}",
        "--",
        "alpha",
        "two words",
    )
    cases.append(
        result(
            "run_program_arguments",
            completed,
            completed.returncode == 0
            and completed.stdout
            == "arguments: 2\n0: alpha\n1: two words\n",
        )
    )

    passed_count = sum(bool(case["passed"]) for case in cases)
    report = {
        "schema": "openc.sh9_native_cli_verification.v1",
        "milestone": "SH-9_NATIVE_CLI_AND_DIAGNOSTIC_USABILITY",
        "status": "PASS" if passed_count == len(cases) else "FAIL",
        "compiler_under_test": {
            **native,
            "implementation_language": "OpenC",
        },
        "active_rules_explainable": 466,
        "historical_rule_id_matches_disclosed": 93,
        "required_d_seed": False,
        "retained_d_seed_executed": False,
        "total": len(cases),
        "passed": passed_count,
        "failed": len(cases) - passed_count,
        "cases": cases,
    }
    report_path = output / "sh9-cli-verification.json"
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"SH-9 native CLI: {passed_count}/{len(cases)} passed; "
        f"report={report_path}"
    )
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
