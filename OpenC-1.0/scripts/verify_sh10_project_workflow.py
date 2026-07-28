#!/usr/bin/env python3
"""Verify the complete SH-10 native project-workflow contract."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess

from native_toolchain import ROOT, resolve_native_compiler, validate_native_compiler


def run(compiler: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(compiler), *arguments],
        cwd=ROOT,
        text=True,
        capture_output=True,
        encoding="utf-8",
    )


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}


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
        default=ROOT / "build-output" / "sh10-project-workflow",
    )
    args = parser.parse_args()

    compiler = resolve_native_compiler(args.compiler)
    native = validate_native_compiler(compiler)
    output = args.output.resolve()
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)
    cases: list[dict[str, object]] = []

    completed = run(compiler, "help")
    cases.append(
        result(
            "help",
            completed,
            completed.returncode == 0
            and "openc fmt" in completed.stdout
            and "openc info" in completed.stdout
            and "openc test" in completed.stdout,
        )
    )

    source = output / "format-fixture.p"
    source.write_text(
        (
            'unsafe   void main(){usize value=1;value+=1;'
            'value<<=1;io.println("SH-10");}\r\n'
        ),
        encoding="utf-8",
        newline="",
    )
    project = output / "openc.project.json"
    project.write_text(
        json.dumps(
            {
                "name": "sh10-format-fixture",
                "version": "1.0.0",
                "edition": "OpenC 1.0",
                "profile": "standard",
                "target": "windows-x86_64-hosted",
                "modules": {"sh10.fixture": ["format-fixture.p"]},
                "output_directory": "build",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    format_record = output / "format-check.json"
    completed = run(
        compiler,
        "fmt",
        "--check",
        str(source),
        f"--output={format_record}",
    )
    data = load(format_record)
    cases.append(
        result(
            "fmt_check_detects_change",
            completed,
            completed.returncode == 1
            and data.get("schema") == "openc.format.v1"
            and data.get("status") == "WOULD_CHANGE"
            and data.get("changed") == 1,
        )
    )

    write_record = output / "format-write.json"
    completed = run(
        compiler,
        "fmt",
        "--write",
        str(source),
        f"--output={write_record}",
    )
    data = load(write_record)
    formatted = source.read_bytes()
    reparsed = run(compiler, "--parse", str(source))
    cases.append(
        result(
            "fmt_write",
            completed,
            completed.returncode == 0
            and data.get("status") == "PASS"
            and data.get("mode") == "write"
            and b"\r" not in formatted
            and formatted.endswith(b"\n")
            and b"+=" in formatted
            and b"<<=" in formatted
            and reparsed.returncode == 0,
        )
    )

    completed = run(compiler, "fmt", "--check", str(source))
    cases.append(
        result(
            "fmt_idempotent_check",
            completed,
            completed.returncode == 0
            and completed.stdout == "OpenC fmt: PASS\n",
        )
    )

    project_record = output / "format-project.json"
    completed = run(
        compiler,
        "fmt",
        "--check",
        f"--project={project}",
        f"--output={project_record}",
    )
    data = load(project_record)
    cases.append(
        result(
            "fmt_project",
            completed,
            completed.returncode == 0
            and data.get("files") == 1
            and data.get("changed") == 0,
        )
    )

    invalid = output / "invalid.p"
    invalid.write_text("unsafe void main( {\n", encoding="utf-8", newline="\n")
    before = invalid.read_bytes()
    completed = run(compiler, "fmt", "--write", str(invalid))
    cases.append(
        result(
            "fmt_rejects_invalid_source",
            completed,
            completed.returncode == 1 and invalid.read_bytes() == before,
        )
    )

    hello = ROOT / "demos" / "hello" / "openc.project.json"
    context_record = output / "context.json"
    completed = run(
        compiler,
        "info",
        f"--project={hello}",
        f"--output={context_record}",
    )
    context = load(context_record)
    cases.append(
        result(
            "info_context",
            completed,
            completed.returncode == 0
            and completed.stdout.startswith("OpenC project context\n")
            and context.get("schema") == "openc.tool_context.v1"
            and context.get("view") == "context"
            and context.get("implementation", {}).get("language") == "OpenC"
            and context.get("dependencies") == [],
        )
    )

    completed = run(compiler, "info", f"--project={hello}", "--json")
    try:
        stdout_context = json.loads(completed.stdout)
    except json.JSONDecodeError:
        stdout_context = {}
    cases.append(
        result(
            "info_json_stdout",
            completed,
            completed.returncode == 0
            and stdout_context.get("schema") == "openc.tool_context.v1",
        )
    )

    for flag, key in (
        ("--sources", "sources"),
        ("--modules", "modules"),
        ("--dependencies", "dependencies"),
        ("--target", "target"),
        ("--types", "types"),
        ("--limits", "limits"),
    ):
        record = output / f"info-{key}.json"
        completed = run(
            compiler,
            "info",
            f"--project={hello}",
            flag,
            "--json",
            f"--output={record}",
        )
        data = load(record)
        cases.append(
            result(
                f"info_{key}",
                completed,
                completed.returncode == 0
                and data.get("view") == key
                and key in data,
            )
        )

    manifest = ROOT / "tests" / "tooling" / "sh10" / "openc.tests.json"
    list_report = output / "test-list.json"
    completed = run(
        compiler,
        "test",
        f"--manifest={manifest}",
        "--list",
        f"--report={list_report}",
    )
    data = load(list_report)
    cases.append(
        result(
            "test_list_is_name_sorted",
            completed,
            completed.returncode == 0
            and [item.get("name") for item in data.get("results", [])]
            == ["calculator", "hello", "ownership"]
            and data.get("mode") == "list",
        )
    )

    no_run_report = output / "test-no-run.json"
    completed = run(
        compiler,
        "test",
        f"--manifest={manifest}",
        "--filter=hello",
        "--no-run",
        "--jobs=3",
        f"--report={no_run_report}",
    )
    data = load(no_run_report)
    cases.append(
        result(
            "test_filter_no_run",
            completed,
            completed.returncode == 0
            and data.get("mode") == "no-run"
            and data.get("requested_jobs") == 3
            and data.get("summary", {}).get("selected") == 1
            and data.get("results", [{}])[0].get("status") == "PASS",
        )
    )

    direct_report = output / "test-direct.json"
    completed = run(
        compiler,
        "test",
        f"--project={hello}",
        "--no-run",
        f"--report={direct_report}",
    )
    data = load(direct_report)
    cases.append(
        result(
            "test_direct_project",
            completed,
            completed.returncode == 0
            and data.get("summary", {}).get("passed") == 1,
        )
    )

    full_report = output / "test-full.json"
    completed = run(
        compiler,
        "test",
        f"--manifest={manifest}",
        "--jobs=2",
        f"--report={full_report}",
    )
    data = load(full_report)
    cases.append(
        result(
            "test_manifest_executes",
            completed,
            completed.returncode == 0
            and data.get("status") == "PASS"
            and data.get("summary", {}).get("passed") == 3
            and all(
                item.get("source_hash", {}).get("algorithm")
                == "openc-stable32"
                for item in data.get("results", [])
            ),
        )
    )

    language_manifest = output / "language-failure.tests.json"
    language_manifest.write_text(
        json.dumps(
            {
                "schema": "openc.test_manifest.v1",
                "tests": [
                    {
                        "name": "language-failure",
                        "project": str(
                            ROOT
                            / "conformance"
                            / "fixtures"
                            / "native-projects"
                            / "invalid__text_index.json"
                        ),
                        "expected_exit": 0,
                    }
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    language_report = output / "language-failure.json"
    completed = run(
        compiler,
        "test",
        f"--manifest={language_manifest}",
        f"--report={language_report}",
    )
    data = load(language_report)
    cases.append(
        result(
            "test_language_failure",
            completed,
            completed.returncode == 1
            and data.get("summary", {}).get("language_failures") == 1
            and data.get("results", [{}])[0].get("status")
            == "LANGUAGE_FAILURE",
        )
    )

    assertion_manifest = output / "assertion-failure.tests.json"
    assertion_manifest.write_text(
        json.dumps(
            {
                "schema": "openc.test_manifest.v1",
                "tests": [
                    {
                        "name": "assertion-failure",
                        "project": str(hello),
                        "expected_exit": 7,
                    }
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    assertion_report = output / "assertion-failure.json"
    completed = run(
        compiler,
        "test",
        f"--manifest={assertion_manifest}",
        f"--report={assertion_report}",
    )
    data = load(assertion_report)
    cases.append(
        result(
            "test_assertion_failure",
            completed,
            completed.returncode == 1
            and data.get("summary", {}).get("assertion_failures") == 1
            and data.get("results", [{}])[0].get("status")
            == "ASSERTION_FAILURE",
        )
    )

    completed = run(
        compiler,
        "test",
        f"--project={hello}",
        "--target=linux-x86_64-hosted",
    )
    cases.append(
        result(
            "test_rejects_unsupported_target",
            completed,
            completed.returncode == 64
            and "windows-x86_64-hosted" in completed.stderr,
        )
    )

    passed_count = sum(bool(case["passed"]) for case in cases)
    report = {
        "schema": "openc.sh10_native_project_workflow_verification.v1",
        "milestone": "SH-10_NATIVE_PROJECT_WORKFLOW_COMPLETENESS",
        "status": "PASS" if passed_count == len(cases) else "FAIL",
        "compiler_under_test": {
            **native,
            "implementation_language": "OpenC",
        },
        "format_record_schema": "openc.format.v1",
        "context_record_schema": "openc.tool_context.v1",
        "test_record_schema": "openc.test_result.v1",
        "deterministic_test_execution_order": "name-sorted",
        "required_d_seed": False,
        "retained_d_seed_executed": False,
        "linux_and_freestanding_gate": False,
        "total": len(cases),
        "passed": passed_count,
        "failed": len(cases) - passed_count,
        "cases": cases,
    }
    report_path = output / "sh10-project-workflow-verification.json"
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"SH-10 native project workflow: {passed_count}/{len(cases)} passed; "
        f"report={report_path}"
    )
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
