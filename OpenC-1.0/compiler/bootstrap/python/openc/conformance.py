"""Local conformance-adapter and fixture-runner implementation."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from typing import Any

from .compiler import Compiler
from .diagnostics import DiagnosticEngine
from .project import ProjectLoader


@dataclass(slots=True)
class FixtureOutcome:
    fixture_id: str
    passed: bool
    expected: str
    actual: str
    diagnostics: list[dict]
    duration_ms: int
    infrastructure_error: str | None = None

    def to_json(self) -> dict[str, Any]:
        return {
            "fixture_id": self.fixture_id,
            "passed": self.passed,
            "expected": self.expected,
            "actual": self.actual,
            "diagnostics": self.diagnostics,
            "duration_ms": self.duration_ms,
            "infrastructure_error": self.infrastructure_error,
        }


class ConformanceRunner:
    def __init__(self, repository_root: Path):
        self.repository_root = repository_root

    def run_bundle(self, bundle_path: Path, output_path: Path) -> dict[str, Any]:
        bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
        fixture_entries = bundle.get("fixtures", [])
        fixtures = [self.load_fixture_entry(item) for item in fixture_entries]
        results: list[FixtureOutcome] = []
        for fixture in fixtures:
            results.append(self.run_fixture(fixture))
        report = {
            "schema": "openc.conformance_result.v1",
            "implementation": {
                "name": "openc-bootstrap-python",
                "version": "1.0.0-rc.7",
                "evidence_state": "EXECUTED",
            },
            "bundle": str(bundle_path),
            "bundle_sha256": hashlib.sha256(bundle_path.read_bytes()).hexdigest(),
            "summary": {
                "total": len(results),
                "passed": sum(item.passed for item in results),
                "failed": sum(not item.passed and item.infrastructure_error is None for item in results),
                "infrastructure_failures": sum(item.infrastructure_error is not None for item in results),
            },
            "results": [item.to_json() for item in results],
        }
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return report

    def load_fixture_entry(self, entry: Any) -> dict[str, Any]:
        if isinstance(entry, str):
            path = (self.repository_root / entry).resolve()
            data = json.loads(path.read_text(encoding="utf-8"))
            data["_fixture_root"] = str(path.parent)
            return data
        if not isinstance(entry, dict):
            raise ValueError("fixture manifest entry must be an object or path string")
        if "path" in entry:
            fixture_path = (self.repository_root / str(entry["path"]) / "fixture.json").resolve()
            data = json.loads(fixture_path.read_text(encoding="utf-8"))
            data["_fixture_root"] = str(fixture_path.parent)
            return data
        return dict(entry)

    def normalized_expectation(self, fixture: dict[str, Any]) -> tuple[str, str | None, str]:
        expected = fixture.get("expected", {})
        if isinstance(expected, dict) and isinstance(expected.get("expected"), dict):
            nested = expected["expected"]
            result = str(nested.get("result", "accept"))
            rule = nested.get("diagnostic_rule") or nested.get("rule")
            kind = str(expected.get("fixture_kind", fixture.get("kind", "source")))
            return result, str(rule) if rule else None, kind
        result = str(fixture.get("expect", fixture.get("expected_result", expected.get("result", "accept") if isinstance(expected, dict) else "accept")))
        rule = fixture.get("rule_id") or fixture.get("expected_rule")
        return result, str(rule) if rule else None, str(fixture.get("kind", fixture.get("fixture_kind", "source")))

    def run_fixture(self, fixture: dict[str, Any]) -> FixtureOutcome:
        start = time.monotonic_ns()
        fixture_id = str(fixture.get("id", "<unknown>"))
        expected, expected_rule, kind = self.normalized_expectation(fixture)
        try:
            with tempfile.TemporaryDirectory(prefix="openc-fixture-") as temporary:
                root = Path(temporary)
                project_file = self.materialize_fixture(root, fixture)
                compiler = Compiler()
                project = compiler.load_project(project_file)
                if kind == "runtime":
                    result = compiler.build(project)
                    if not result.success or result.output_path is None:
                        actual = "reject"
                    else:
                        process = subprocess.run([str(result.output_path)], cwd=root, text=True, capture_output=True, timeout=int(fixture.get("timeout_seconds", 10)))
                        actual = "run"
                        expected_exit = int(fixture.get("exit_code", 0))
                        expected_stdout = str(fixture.get("stdout", ""))
                        passed = expected in {"run", "accept"} and process.returncode == expected_exit and process.stdout == expected_stdout
                        return FixtureOutcome(
                            fixture_id, passed, expected,
                            f"exit={process.returncode};stdout={process.stdout!r}",
                            compiler.diagnostics.to_json(), elapsed_ms(start),
                        )
                else:
                    result = compiler.check(project)
                    actual = "accept" if result.success else "reject"
                primary = compiler.diagnostics.items[0].rule_id if compiler.diagnostics.items else None
                passed = actual == expected and (not expected_rule or primary == expected_rule)
                return FixtureOutcome(
                    fixture_id, passed, expected, actual,
                    compiler.diagnostics.to_json(), elapsed_ms(start),
                )
        except Exception as exc:
            return FixtureOutcome(
                fixture_id, False, expected, "infrastructure_failure", [], elapsed_ms(start), str(exc)
            )

    def materialize_fixture(self, root: Path, fixture: dict[str, Any]) -> Path:
        fixture_root = Path(str(fixture.get("_fixture_root", ""))) if fixture.get("_fixture_root") else None
        expected_record = fixture.get("expected", {})
        declared_modules = expected_record.get("modules") if isinstance(expected_record, dict) else None
        source_files = fixture.get("source_files")
        modules: dict[str, list[str]] = {}

        if fixture_root is not None and source_files:
            source_by_leaf: dict[str, Path] = {}
            for source_value in source_files:
                original = (self.repository_root / str(source_value)).resolve()
                relative = original.relative_to(fixture_root) if original.is_relative_to(fixture_root) else Path(original.name)
                destination = root / "source" / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(original, destination)
                source_by_leaf[original.name] = destination
            if isinstance(declared_modules, dict):
                for module_name, names in declared_modules.items():
                    if isinstance(names, str):
                        names = [names]
                    modules[str(module_name)] = []
                    for name in names:
                        candidate = source_by_leaf.get(str(name))
                        if candidate is None:
                            raise ValueError(f"fixture module source not found: {name}")
                        modules[str(module_name)].append(str(candidate.relative_to(root)))
            else:
                copied = sorted(source_by_leaf.values(), key=str)
                modules = {"app.main": [str(path.relative_to(root)) for path in copied]}
        else:
            inline_modules = fixture.get("modules")
            if not inline_modules:
                source = str(fixture.get("source", ""))
                source_path = root / "source" / "main"
                source_path.parent.mkdir(parents=True, exist_ok=True)
                source_path.write_text(source, encoding="utf-8", newline="\n")
                modules = {"app.main": ["source/main.p"]}
            else:
                for module_name, sources in inline_modules.items():
                    modules[str(module_name)] = []
                    if isinstance(sources, str):
                        sources = [sources]
                    for index, source in enumerate(sources):
                        path = root / "source" / str(module_name).replace(".", "/") / str(index)
                        path.parent.mkdir(parents=True, exist_ok=True)
                        text = str(source.get("source", "")) if isinstance(source, dict) else str(source)
                        path.write_text(text, encoding="utf-8", newline="\n")
                        modules[str(module_name)].append(str(path.relative_to(root)))

        project = {
            "name": "fixture",
            "version": "1.0.0",
            "edition": "OpenC 1.0",
            "profile": fixture.get("profile", expected_record.get("profile", "standard") if isinstance(expected_record, dict) else "standard"),
            "target": fixture.get("target", "linux-x86_64"),
            "modules": modules,
            "output_directory": "build",
            "runtime_directory": str(self.repository_root / "runtime"),
            "standard_library_directory": str(self.repository_root / "standard_library"),
        }
        project_file = root / "openc.project.json"
        project_file.write_text(json.dumps(project, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return project_file


def elapsed_ms(start_ns: int) -> int:
    return (time.monotonic_ns() - start_ns) // 1_000_000
