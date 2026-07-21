#!/usr/bin/env python3
"""Prove exact stage-0/stage-1 canonical JSON IR parity."""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import tempfile

from semantic_flow_safety_parity import MANIFEST, ROOT, project_for_fixture


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, cwd=ROOT, text=True, capture_output=True, encoding="utf-8"
    )


def payload(process: subprocess.CompletedProcess[str]) -> dict[str, object] | None:
    lines = process.stdout.splitlines()
    if process.returncode != 0 or len(lines) != 2:
        return None
    if lines[0] != "OPENC-SEMANTIC-IR-OBSERVATION 1":
        return None
    try:
        return json.loads(lines[1])
    except json.JSONDecodeError:
        return None


def outcome(process: subprocess.CompletedProcess[str]) -> str:
    if payload(process) is not None:
        return "ACCEPT"
    lines = process.stdout.splitlines()
    if len(lines) >= 2:
        if lines[1].startswith("FRONTEND_ERROR"):
            return "FRONTEND_ERROR"
        if lines[1].startswith("SEMANTIC_ERROR"):
            return "SEMANTIC_ERROR"
        if lines[1].startswith("PROJECT_ERROR"):
            return "PROJECT_ERROR"
    return "INVALID_PROTOCOL"


def first_difference(reference: object, candidate: object, path: str = "$" ) -> str:
    if type(reference) is not type(candidate):
        return f"{path}: type {type(reference).__name__} != {type(candidate).__name__}"
    if isinstance(reference, dict):
        if reference.keys() != candidate.keys():
            return f"{path}: keys {sorted(reference)} != {sorted(candidate)}"
        for key in reference:
            found = first_difference(reference[key], candidate[key], f"{path}.{key}")
            if found:
                return found
        return ""
    if isinstance(reference, list):
        if len(reference) != len(candidate):
            return f"{path}: length {len(reference)} != {len(candidate)}"
        for index, (left, right) in enumerate(zip(reference, candidate)):
            found = first_difference(left, right, f"{path}[{index}]")
            if found:
                return found
        return ""
    return "" if reference == candidate else f"{path}: {reference!r} != {candidate!r}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage0", type=Path, default=ROOT / "compiler" / "openc.exe")
    parser.add_argument("--stage1", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "build-output" / "selfhost")
    parser.add_argument("--case", default="", help="only compare case names containing this text")
    parser.add_argument("--jobs", type=int, default=8, help="parallel comparison workers")
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
    maintained = [
        (f"maintained:{name}", ROOT / "programs" / name / "openc.project.json")
        for name in ("A_COMPUTATION", "MANIFEST_VALIDATOR", "CORE_EXERCISER")
    ]
    failures: list[dict[str, str]] = []
    compared = 0
    rejected = 0
    functions = 0
    blocks = 0
    instructions = 0
    opcodes: Counter[str] = Counter()

    with tempfile.TemporaryDirectory(prefix="semantic-ir-", dir=output) as temporary:
        temporary_root = Path(temporary)
        cases: list[tuple[str, Path]] = maintained[:]
        for index, entry in enumerate(source_entries):
            project = project_for_fixture(entry, temporary_root / f"fixture-{index}.json")
            if project is not None:
                cases.append((f"fixture:{entry['id']}", project))

        if args.case:
            cases = [case for case in cases if args.case in case[0]]

        def compare_case(case: tuple[str, Path]) -> tuple[str, dict[str, object] | None, dict[str, str] | None, str]:
            name, project = case
            reference_process = run([str(stage0), "semantic-ir-observe", str(project.resolve())])
            reference = payload(reference_process)
            candidate_process = run([str(stage1), "--semantic-ir", str(project.resolve())])
            if reference is None:
                reference_outcome = outcome(reference_process)
                candidate_outcome = outcome(candidate_process)
                if reference_outcome != candidate_outcome:
                    return name, None, {
                        "case": name,
                        "detail": (
                            f"rejection phase {reference_outcome} != {candidate_outcome}; "
                            f"stage1 exit={candidate_process.returncode}\n"
                            f"stdout:\n{candidate_process.stdout[:10000]}\n"
                            f"stderr:\n{candidate_process.stderr[:10000]}"
                        ),
                    }, reference_outcome
                return name, None, None, reference_outcome
            candidate = payload(candidate_process)
            if candidate is None:
                return name, reference, {
                    "case": name,
                    "detail": (
                        f"stage1 did not emit canonical IR; exit={candidate_process.returncode}\n"
                        f"stdout:\n{candidate_process.stdout[:10000]}\n"
                        f"stderr:\n{candidate_process.stderr[:10000]}"
                    ),
                }, "ACCEPT"
            mismatch = first_difference(reference, candidate)
            if mismatch:
                return name, reference, {"case": name, "detail": mismatch}, "ACCEPT"
            return name, reference, None, "ACCEPT"

        with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
            for _, reference, failure, reference_outcome in executor.map(compare_case, cases):
                if reference is None:
                    rejected += 1
                else:
                    compared += 1
                    for module in reference["modules"]:
                        for function in module["functions"]:
                            functions += 1
                            for block in function["blocks"]:
                                blocks += 1
                                for instruction in block["instructions"]:
                                    instructions += 1
                                    opcodes[instruction["opcode"]] += 1
                if failure is not None:
                    failures.append(failure)
    result = {
        "schema": "openc.self_host_semantic_ir_parity.v1",
        "stage": "SH-3D_CANONICAL_IR_PARITY",
        "status": "PASS" if not failures else "FAIL",
        "protocol": "OPENC-SEMANTIC-IR-OBSERVATION 1",
        "stage0": str(stage0),
        "stage1": str(stage1),
        "maintained_projects": len(maintained),
        "authored_source_fixtures": len(source_entries),
        "semantic_rejections": rejected,
        "ir_comparisons": compared,
        "observed_records": {
            "functions": functions,
            "blocks": blocks,
            "instructions": instructions,
            "opcodes": dict(sorted(opcodes.items())),
        },
        "failures": failures,
        "matched_fields": [
            "process_exit", "schema", "entry_module", "entry_function",
            "module_order", "function_order", "function_attributes", "block_order",
            "instruction_order", "result_id", "opcode", "type_id", "text",
            "source_id", "byte_span", "operand_order", "operand_value", "operand_immediate",
        ],
    }
    (output / "semantic-ir-parity-result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    if failures:
        first = failures[0]
        raise SystemExit(
            f"semantic IR parity failed: {len(failures)} of {compared}; "
            f"first={first['case']}\n{first['detail']}"
        )
    print(
        "self-host canonical IR parity: PASS; "
        f"ir={compared} rejected={rejected} functions={functions} "
        f"blocks={blocks} instructions={instructions} opcodes={len(opcodes)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
