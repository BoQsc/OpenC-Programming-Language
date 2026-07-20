"""OpenC project, target, lock, and build-context loading."""
from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
import json
from pathlib import Path
from typing import Any, Iterable

from .diagnostics import DiagnosticEngine
from .model import Diagnostic, Phase, Severity
from .typesys import TargetFacts


@dataclass(slots=True)
class Project:
    root: Path
    project_file: Path
    name: str
    version: str
    edition: str
    profile: str
    target_name: str
    modules: dict[str, list[Path]]
    output_directory: Path
    build_context: dict[str, bool | int | str] = field(default_factory=dict)
    extensions: list[str] = field(default_factory=list)
    generated_sources: list[Path] = field(default_factory=list)
    runtime_directory: Path | None = None
    standard_library_directory: Path | None = None
    c_compiler: str | None = None
    c_flags: list[str] = field(default_factory=list)
    linker_flags: list[str] = field(default_factory=list)

    def all_source_paths(self) -> list[Path]:
        result: list[Path] = []
        for paths in self.modules.values():
            result.extend(paths)
        result.extend(self.generated_sources)
        return sorted(set(path.resolve() for path in result), key=str)

    def module_for_path(self, path: Path) -> str:
        resolved = path.resolve()
        matches = [name for name, paths in self.modules.items() if resolved in {item.resolve() for item in paths}]
        if len(matches) != 1:
            raise ValueError(f"source path {path} maps to {len(matches)} logical modules")
        return matches[0]

    def target(self) -> TargetFacts:
        if self.target_name == "linux-x86_64":
            target = TargetFacts.linux_x86_64()
        elif self.target_name == "windows-x86_64":
            target = TargetFacts.windows_x86_64()
        else:
            target = TargetFacts(name=self.target_name, hosted=self.target_name != "freestanding")
            target.build_context["target.os"] = "freestanding" if self.target_name == "freestanding" else self.target_name
        target.build_context.update(self.build_context)
        target.build_context["project.profile"] = self.profile
        return target

    def input_hashes(self) -> dict[str, str]:
        result: dict[str, str] = {}
        for path in self.all_source_paths():
            result[str(path.relative_to(self.root) if path.is_relative_to(self.root) else path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        result[str(self.project_file.relative_to(self.root))] = hashlib.sha256(self.project_file.read_bytes()).hexdigest()
        return dict(sorted(result.items()))


class ProjectLoader:
    def __init__(self, diagnostics: DiagnosticEngine):
        self.diagnostics = diagnostics

    def load(self, path: Path) -> Project:
        project_file = path if path.is_file() else path / "openc.project.json"
        if not project_file.exists():
            self.diagnostics.raise_error(
                "OPENC-PROJECT-NOT-FOUND-001", Phase.TOOL,
                f"project configuration not found: {project_file}", category="project.load",
            )
        try:
            data = json.loads(project_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            self.diagnostics.raise_error(
                "OPENC-PROJECT-JSON-001", Phase.TOOL,
                f"cannot read project configuration: {exc}", category="project.load",
            )
        root = project_file.parent.resolve()
        self.require_object(data, "project")
        name = self.require_string(data, "name")
        version = self.require_string(data, "version", default="0.0.0")
        edition = self.require_string(data, "edition", default="OpenC 1.0")
        profile = self.require_string(data, "profile", default="standard")
        target_name = self.require_string(data, "target", default="linux-x86_64")
        module_data = data.get("modules")
        if not isinstance(module_data, dict) or not module_data:
            self.diagnostics.raise_error(
                "OPENC-PROJECT-MODULES-001", Phase.TOOL,
                "project must declare a nonempty modules object", category="project.modules",
            )
        modules: dict[str, list[Path]] = {}
        seen_paths: dict[Path, str] = {}
        for module_name, entries in sorted(module_data.items()):
            if not isinstance(module_name, str) or not module_name:
                self.project_error("module names must be nonempty strings")
            if isinstance(entries, str):
                entries = [entries]
            if not isinstance(entries, list) or not entries:
                self.project_error(f"module '{module_name}' must map to one or more source paths")
            paths: list[Path] = []
            for entry in entries:
                if not isinstance(entry, str):
                    self.project_error(f"module '{module_name}' source path must be a string")
                source_path = (root / entry).resolve()
                if source_path in seen_paths:
                    self.project_error(
                        f"source '{entry}' is assigned to both '{seen_paths[source_path]}' and '{module_name}'"
                    )
                if not source_path.is_file():
                    self.project_error(f"source file does not exist: {entry}")
                seen_paths[source_path] = module_name
                paths.append(source_path)
            modules[module_name] = paths
        output_directory = (root / self.require_string(data, "output_directory", default="build")).resolve()
        generated = [(root / value).resolve() for value in self.string_list(data.get("generated_sources", []), "generated_sources")]
        build_context = data.get("build_context", {})
        if not isinstance(build_context, dict) or not all(isinstance(key, str) and isinstance(value, (bool, int, str)) for key, value in build_context.items()):
            self.project_error("build_context must map strings to bool, integer, or text values")
        extensions = self.string_list(data.get("extensions", []), "extensions")
        runtime_dir = (root / data["runtime_directory"]).resolve() if isinstance(data.get("runtime_directory"), str) else None
        stdlib_dir = (root / data["standard_library_directory"]).resolve() if isinstance(data.get("standard_library_directory"), str) else None
        toolchain = data.get("toolchain", {})
        if not isinstance(toolchain, dict):
            self.project_error("toolchain must be an object")
        c_compiler = toolchain.get("c_compiler") if isinstance(toolchain.get("c_compiler"), str) else None
        c_flags = self.string_list(toolchain.get("c_flags", []), "toolchain.c_flags")
        linker_flags = self.string_list(toolchain.get("linker_flags", []), "toolchain.linker_flags")
        return Project(
            root, project_file.resolve(), name, version, edition, profile, target_name,
            modules, output_directory, dict(build_context), extensions, generated,
            runtime_dir, stdlib_dir, c_compiler, c_flags, linker_flags,
        )

    def project_error(self, message: str) -> None:
        self.diagnostics.raise_error(
            "OPENC-PROJECT-INVALID-001", Phase.TOOL, message, category="project.validation",
        )

    def require_object(self, value: Any, label: str) -> None:
        if not isinstance(value, dict):
            self.project_error(f"{label} must be a JSON object")

    def require_string(self, data: dict, key: str, default: str | None = None) -> str:
        value = data.get(key, default)
        if not isinstance(value, str) or not value:
            self.project_error(f"{key} must be a nonempty string")
        return value

    def string_list(self, value: Any, label: str) -> list[str]:
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            self.project_error(f"{label} must be an array of strings")
        return list(value)
