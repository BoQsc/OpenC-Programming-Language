#!/usr/bin/env python3
"""Prove exact stage-0/stage-1 flow and safety parity."""
from __future__ import annotations

import argparse
import difflib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "conformance" / "fixtures" / "MANIFEST.json"


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, cwd=ROOT, text=True, capture_output=True, encoding="utf-8"
    )


def project_for_fixture(fixture: dict[str, object], destination: Path) -> Path | None:
    sources = [ROOT / str(item) for item in fixture.get("source_files", [])]
    sources = [path.resolve() for path in sources if path.suffix == ".p"]
    if not sources:
        return None
    fixture_file = ROOT / str(fixture["path"]) / "fixture.json"
    specification = json.loads(fixture_file.read_text(encoding="utf-8"))
    expected = specification.get("expected", {})
    configured_modules = expected.get("modules") if isinstance(expected, dict) else None
    by_name = {path.name: path for path in sources}
    if isinstance(configured_modules, dict):
        modules = {
            name: [str(by_name[source_name]) for source_name in source_names]
            for name, source_names in configured_modules.items()
        }
    else:
        modules = {"fixture.main": [str(path) for path in sorted(sources)]}
    destination.write_text(
        json.dumps({"target": "windows-x86_64", "modules": modules}),
        encoding="utf-8",
        newline="\n",
    )
    return destination


def difference(
    reference: subprocess.CompletedProcess[str],
    candidate: subprocess.CompletedProcess[str],
) -> str:
    output = "".join(
        difflib.unified_diff(
            reference.stdout.splitlines(keepends=True),
            candidate.stdout.splitlines(keepends=True),
            fromfile="stage0",
            tofile="stage1",
            n=3,
        )
    )
    return (
        f"exit stage0={reference.returncode} stage1={candidate.returncode}\n"
        f"stage0 stderr: {reference.stderr}\n"
        f"stage1 stderr: {candidate.stderr}\n{output[:20000]}"
    )


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

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    source_entries = [
        entry for entry in manifest["fixtures"]
        if any(str(source).endswith(".p") for source in entry.get("source_files", []))
    ]
    failures: list[dict[str, str]] = []
    compared = 0
    frontend_cases = 0
    observed_rules: set[str] = set()
    totals = {"functions": 0, "blocks": 0, "edges": 0, "cleanups": 0, "errors": 0}

    maintained = [
        (f"maintained:{name}", ROOT / "programs" / name / "openc.project.json")
        for name in ("A_COMPUTATION", "MANIFEST_VALIDATOR", "CORE_EXERCISER")
    ]
    with tempfile.TemporaryDirectory(prefix="semantic-flow-safety-", dir=output) as temporary:
        temporary_root = Path(temporary)
        cases: list[tuple[str, Path]] = maintained[:]
        for index, entry in enumerate(source_entries):
            project = project_for_fixture(entry, temporary_root / f"fixture-{index}.json")
            if project is not None:
                cases.append((f"fixture:{entry['id']}", project))

        for name, project in cases:
            reference = run([str(stage0), "semantic-flow-safety-observe", str(project.resolve())])
            if "FRONTEND_ERROR " in reference.stdout or "PROJECT_ERROR " in reference.stdout:
                frontend_cases += 1
                continue
            candidate = run([str(stage1), "--semantic-flow-safety", str(project.resolve())])
            compared += 1
            exact = (
                reference.returncode == candidate.returncode
                and reference.stdout == candidate.stdout
                and reference.stderr == candidate.stderr
            )
            if not exact:
                failures.append({"case": name, "detail": difference(reference, candidate)})
                continue
            for line in reference.stdout.splitlines():
                fields = line.split()
                if line.startswith("ERROR "):
                    observed_rules.add(fields[3])
                elif line.startswith("SUMMARY "):
                    totals["functions"] += int(fields[3])
                    totals["blocks"] += int(fields[4])
                    totals["edges"] += int(fields[5])
                    totals["cleanups"] += int(fields[6])
                    totals["errors"] += int(fields[7])

    result = {
        "schema": "openc.self_host_semantic_flow_safety_parity.v1",
        "stage": "SH-3C_FLOW_SAFETY_PARITY",
        "status": "PASS" if not failures else "FAIL",
        "protocol": "OPENC-SEMANTIC-FLOW-SAFETY-OBSERVATION 1",
        "stage0": str(stage0),
        "stage1": str(stage1),
        "maintained_projects": len(maintained),
        "authored_source_fixtures": len(source_entries),
        "frontend_cases_covered_by_sh2": frontend_cases,
        "semantic_comparisons": compared,
        "observed_records": totals,
        "flow_safety_rules_observed": sorted(observed_rules),
        "failures": failures,
        "matched_fields": [
            "process_exit", "module_order", "source_order", "function_order",
            "function_span", "cfg_block_count", "cfg_edge_count", "cleanup_order",
            "cleanup_action_span", "diagnostic_order", "diagnostic_phase",
            "diagnostic_rule", "diagnostic_span",
        ],
    }
    (output / "semantic-flow-safety-parity-result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if failures:
        first = failures[0]
        raise SystemExit(
            f"semantic flow/safety parity failed: {len(failures)} of {compared}; "
            f"first={first['case']}\n{first['detail']}"
        )
    print(
        "self-host semantic flow/safety parity: PASS; "
        f"semantic={compared} frontend={frontend_cases} "
        f"functions={totals['functions']} blocks={totals['blocks']} "
        f"edges={totals['edges']} cleanups={totals['cleanups']} "
        f"rules={len(observed_rules)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
