#!/usr/bin/env python3
"""Prove exact stage-0/stage-1 name, constant, and overload parity."""
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
            "lexical_scopes",
            {"app": ["main.p"]},
            {"main.p": (
                "i32 combine(i32 left, i32 right) {\n"
                "    i32 base = left + right;\n"
                "    { i32 nested = base + 1; return nested; }\n"
                "}\n"
            )},
        ),
        (
            "constant_domains",
            {"app": ["main.p"]},
            {"main.p": (
                "const i32 answer = 6 * 7;\n"
                "const bool enabled = true && !false;\n"
                "const text label = \"OpenC\";\n"
                "enum Level { zero, one, two }\n"
                "i32 main() { return answer; }\n"
            )},
        ),
        (
            "overload_exact",
            {"app": ["main.p"]},
            {"main.p": (
                "i32 choose(i32 value) { return value; }\n"
                "i64 choose(i64 value) { return value; }\n"
                "i32 main() { return choose(7); }\n"
            )},
        ),
        (
            "overload_lossless",
            {"app": ["main.p"]},
            {"main.p": (
                "i64 widen(i64 value) { return value; }\n"
                "i64 main() { i32 value = 7; return widen(value); }\n"
            )},
        ),
        (
            "qualified_cross_module",
            {"app": ["main.p"], "model": ["model.p"]},
            {
                "main.p": "import model; i32 main() { return model.identity(9); }\n",
                "model.p": "export i32 identity(i32 value) { return value; }\n",
            },
        ),
        (
            "unknown_name",
            {"app": ["main.p"]},
            {"main.p": "i32 main() { return missing; }\n"},
        ),
        (
            "overload_no_match",
            {"app": ["main.p"]},
            {"main.p": (
                "i32 only(text value) { return 1; }\n"
                "i32 main() { return only(1); }\n"
            )},
        ),
        (
            "overload_ambiguous",
            {"app": ["main.p"]},
            {"main.p": (
                "i32 same(i32 value) { return value; }\n"
                "i64 same(i32 value) { return value; }\n"
                "i32 main() { return same(1); }\n"
            )},
        ),
        (
            "constant_divide_by_zero",
            {"app": ["main.p"]},
            {"main.p": "const i32 broken = 7 / 0; i32 main() { return 0; }\n"},
        ),
    ]


def compare(project: Path, stage0: Path, stage1: Path) -> tuple[bool, str, str]:
    reference = run([str(stage0), "semantic-resolve-observe", str(project.resolve())])
    candidate = run([str(stage1), "--semantic-resolve", str(project.resolve())])
    exact = (
        reference.returncode == candidate.returncode
        and reference.stdout == candidate.stdout
        and reference.stderr == candidate.stderr
    )
    if exact:
        return True, "", reference.stdout
    difference = "".join(
        difflib.unified_diff(
            reference.stdout.splitlines(keepends=True),
            candidate.stdout.splitlines(keepends=True),
            fromfile="stage0",
            tofile="stage1",
            n=3,
        )
    )
    return False, (
        f"exit stage0={reference.returncode} stage1={candidate.returncode}\n"
        f"stage0 stderr: {reference.stderr}\n"
        f"stage1 stderr: {candidate.stderr}\n{difference[:20000]}"
    ), reference.stdout


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
    observations = {"bindings": 0, "constants": 0, "calls": 0}
    observed_rules: set[str] = set()
    cases: list[tuple[str, Path]] = [
        ("canonical:programs/A_COMPUTATION", ROOT / "programs" / "A_COMPUTATION" / "openc.project.json")
    ]
    focused = focused_cases()

    with tempfile.TemporaryDirectory(prefix="semantic-resolution-parity-", dir=output) as temporary:
        temporary_root = Path(temporary)
        for name, modules, files in focused:
            case_root = temporary_root / name
            case_root.mkdir()
            project = case_root / "openc.project.json"
            project.write_text(
                json.dumps({"target": "windows-x86_64", "modules": modules}),
                encoding="utf-8", newline="\n",
            )
            for relative, content in files.items():
                (case_root / relative).write_text(content, encoding="utf-8", newline="\n")
            cases.append((f"probe:{name}", project))

        for name, project in cases:
            matched, detail, observation = compare(project, stage0, stage1)
            if not matched:
                failures.append({"case": name, "detail": detail})
                continue
            for line in observation.splitlines():
                if line.startswith("BIND "):
                    observations["bindings"] += 1
                elif line.startswith("CONST "):
                    observations["constants"] += 1
                elif line.startswith("CALL "):
                    observations["calls"] += 1
                elif line.startswith("ERROR "):
                    observed_rules.add(line.split()[1])

    required_rules = {
        "OPENC-NAME-UNKNOWN-001",
        "OPENC-CALL-NOMATCH-001",
        "OPENC-CALL-AMBIGUOUS-001",
        "OPENC-ARITH-DIVZERO-001",
    }
    if required_rules - observed_rules:
        failures.append({
            "case": "<diagnostic-coverage>",
            "detail": "missing resolution rule coverage: " + ", ".join(sorted(required_rules - observed_rules)),
        })

    result = {
        "schema": "openc.self_host_semantic_resolution_parity.v1",
        "stage": "SH-3B_NAME_CONSTANT_OVERLOAD_PARITY",
        "status": "PASS" if not failures else "FAIL",
        "protocol": "OPENC-SEMANTIC-RESOLUTION-OBSERVATION 1",
        "stage0": str(stage0),
        "stage1": str(stage1),
        "canonical_projects": 1,
        "focused_probes": len(focused),
        "comparisons": len(cases),
        "observed_records": observations,
        "resolution_rules_observed": sorted(observed_rules),
        "failures": failures,
        "matched_fields": [
            "process_exit", "module_order", "source_order", "observation_order",
            "use_name", "use_span", "target_symbol_kind", "target_identity",
            "target_span", "resolved_type", "constant_owner", "constant_type",
            "constant_domain", "constant_value", "selected_overload",
            "call_result_type", "resolution_diagnostic_rule", "resolution_diagnostic_span",
        ],
    }
    (output / "semantic-resolution-parity-result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8", newline="\n",
    )
    if failures:
        first = failures[0]
        raise SystemExit(f"semantic resolution parity failed: {first['case']}\n{first['detail']}")
    print(
        "self-host semantic resolution parity: PASS; "
        f"canonical=1 probes={len(focused)} comparisons={len(cases)} "
        f"bindings={observations['bindings']} constants={observations['constants']} "
        f"calls={observations['calls']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
