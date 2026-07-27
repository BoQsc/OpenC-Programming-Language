#!/usr/bin/env python3
"""Materialize the complete native conformance plan from canonical fixtures."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "conformance" / "fixtures" / "MANIFEST.json"
PLAN = ROOT / "conformance" / "fixtures" / "NATIVE_PLAN.tsv"
PROJECTS = ROOT / "conformance" / "fixtures" / "native-projects"
PLAN_SCHEMA = "openc.native_conformance_plan.v1"


def fixture_expected(fixture: dict[str, object]) -> tuple[str, str, dict[str, object]]:
    expected_record = fixture.get("expected", {})
    if not isinstance(expected_record, dict):
        expected_record = {}
    nested = expected_record.get("expected")
    if not isinstance(nested, dict) and "result" in expected_record:
        nested = expected_record
    if not isinstance(nested, dict):
        nested = {}
    expected = str(nested.get("result", "accept"))
    declared_kind = str(expected_record.get("fixture_kind", ""))
    kind = (
        declared_kind
        if declared_kind in {"runtime", "command", "record"}
        else str(fixture.get("kind", "source"))
    )
    if kind == "records":
        kind = "record"
    rule = str(nested.get("diagnostic_rule", ""))
    if not rule and expected != "accept" and kind != "runtime":
        rule = str(nested.get("rule", ""))
        rules = nested.get("rules", [])
        if not rule and isinstance(rules, list) and rules:
            rule = str(rules[0])
    return kind, expected, nested


def clean_field(value: object, fixture_id: str) -> str:
    result = str(value)
    if "\t" in result or "\r" in result or "\n" in result:
        raise SystemExit(f"native plan field is not TSV-safe: {fixture_id}")
    return result


def project_name(fixture_id: str) -> str:
    return fixture_id.replace("/", "__") + ".json"


def project_document(
    fixture: dict[str, object],
    fixture_path: Path,
) -> dict[str, object]:
    source_files = fixture.get("source_files", [])
    if not isinstance(source_files, list) or not source_files:
        raise SystemExit(f"source fixture has no sources: {fixture.get('id')}")
    by_leaf = {Path(str(source)).name: str(source) for source in source_files}
    expected_record = fixture.get("expected", {})
    modules_value = (
        expected_record.get("modules")
        if isinstance(expected_record, dict)
        else None
    )
    modules: dict[str, list[str]] = {}
    if isinstance(modules_value, dict):
        for module_name in sorted(modules_value):
            module_sources = modules_value[module_name]
            if not isinstance(module_sources, list):
                raise SystemExit(
                    f"module source list is invalid: {fixture.get('id')}"
                )
            resolved = []
            for leaf in module_sources:
                source = by_leaf.get(str(leaf))
                if source is None:
                    raise SystemExit(
                        f"module source not found: {fixture.get('id')}:{leaf}"
                    )
                resolved.append(source)
            modules[str(module_name)] = resolved
    else:
        modules["fixture.main"] = sorted(by_leaf.values())

    project_parent = PROJECTS
    relative_modules = {
        name: [
            Path(os.path.relpath(ROOT / source, project_parent)).as_posix()
            for source in sources
        ]
        for name, sources in modules.items()
    }
    return {
        "name": f"native-conformance-{fixture.get('id', fixture_path.name)}",
        "version": "1.0.0",
        "edition": "OpenC 1.0",
        "profile": (
            str(expected_record.get("profile", "standard"))
            if isinstance(expected_record, dict)
            else "standard"
        ),
        "target": "windows-x86_64",
        "modules": relative_modules,
    }


def render() -> tuple[str, dict[str, str]]:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = manifest.get("fixtures", [])
    if not isinstance(entries, list):
        raise SystemExit("fixture manifest has no fixture array")
    lines = [f"{PLAN_SCHEMA}\t1\t{len(entries)}"]
    projects: dict[str, str] = {}
    seen: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise SystemExit("fixture manifest entry must be an object")
        fixture_id = str(entry.get("id", ""))
        if not fixture_id or fixture_id in seen:
            raise SystemExit(f"missing or duplicate fixture ID: {fixture_id}")
        seen.add(fixture_id)
        fixture_dir = ROOT / str(entry.get("path", ""))
        fixture_file = fixture_dir / "fixture.json"
        fixture = json.loads(fixture_file.read_text(encoding="utf-8"))
        if fixture.get("id") != fixture_id:
            raise SystemExit(f"fixture ID mismatch: {fixture_id}")
        kind, expected, nested = fixture_expected(fixture)
        rule = ""
        project = ""
        source_paths = ""
        stdout_specified = "0"
        expected_stdout = ""
        auxiliary = ""
        if kind in {"valid", "invalid", "diagnostic", "runtime"}:
            name = project_name(fixture_id)
            document = project_document(fixture, fixture_file)
            projects[name] = (
                json.dumps(document, indent=2, sort_keys=True) + "\n"
            )
            project = f"native-projects/{name}"
            source_paths = "|".join(
                Path(
                    os.path.relpath(ROOT / str(source), MANIFEST.parent)
                ).as_posix()
                for source in fixture.get("source_files", [])
            )
            if kind != "runtime":
                _, _, nested_expected = fixture_expected(fixture)
                diagnostic = str(nested_expected.get("diagnostic_rule", ""))
                if not diagnostic and expected != "accept":
                    diagnostic = str(nested_expected.get("rule", ""))
                    rules = nested_expected.get("rules", [])
                    if not diagnostic and isinstance(rules, list) and rules:
                        diagnostic = str(rules[0])
                rule = diagnostic
            if kind == "runtime":
                stdout_value = nested.get("stdout")
                if isinstance(stdout_value, list):
                    stdout_specified = "1"
                    expected_stdout = "".join(str(part) for part in stdout_value)
        elif kind in {"command", "record"}:
            sources = fixture.get("source_files", [])
            if not isinstance(sources, list) or len(sources) != 1:
                raise SystemExit(
                    f"native tooling fixture needs one source: {fixture_id}"
                )
            auxiliary = Path(
                os.path.relpath(ROOT / str(sources[0]), MANIFEST.parent)
            ).as_posix()
        else:
            raise SystemExit(f"unsupported native fixture kind: {fixture_id}:{kind}")

        fields = (
            fixture_id,
            kind,
            expected,
            rule,
            project,
            source_paths,
            stdout_specified,
            expected_stdout,
            auxiliary,
        )
        lines.append("\t".join(clean_field(field, fixture_id) for field in fields))
    if len(seen) != manifest.get("fixture_count"):
        raise SystemExit("native plan does not cover the complete manifest")
    return "\n".join(lines) + "\n", projects


def check(plan_text: str, projects: dict[str, str]) -> None:
    errors = []
    if not PLAN.is_file() or PLAN.read_text(encoding="utf-8") != plan_text:
        errors.append("conformance/fixtures/NATIVE_PLAN.tsv is stale")
    actual = {
        path.name: path.read_text(encoding="utf-8")
        for path in PROJECTS.glob("*.json")
    } if PROJECTS.is_dir() else {}
    if actual != projects:
        missing = sorted(set(projects) - set(actual))
        extra = sorted(set(actual) - set(projects))
        changed = sorted(
            name for name in set(actual) & set(projects)
            if actual[name] != projects[name]
        )
        errors.append(
            "native fixture projects are stale "
            f"(missing={len(missing)}, extra={len(extra)}, changed={len(changed)})"
        )
    if errors:
        raise SystemExit("\n".join(errors))


def write(plan_text: str, projects: dict[str, str]) -> None:
    PLAN.write_text(plan_text, encoding="utf-8", newline="\n")
    PROJECTS.mkdir(parents=True, exist_ok=True)
    for path in PROJECTS.glob("*.json"):
        if path.name not in projects:
            path.unlink()
    for name, content in projects.items():
        (PROJECTS / name).write_text(
            content, encoding="utf-8", newline="\n"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail unless all materialized native inputs are current",
    )
    args = parser.parse_args()
    plan_text, projects = render()
    if args.check:
        check(plan_text, projects)
        action = "verified"
    else:
        write(plan_text, projects)
        action = "wrote"
    print(
        f"native conformance plan: {action}; "
        f"fixtures={len(plan_text.splitlines()) - 1} projects={len(projects)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
