"""Top-level OpenC compilation service and authored build orchestration."""
from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any, Iterable

from .backend_c import CEmitter, GeneratedFile
from .diagnostics import DiagnosticEngine
from .ir import Program as IRProgram, Verifier
from .lexer import Lexer
from .lower import Lowerer
from .model import Diagnostic, OpenCError, SourceUnit, to_data
from .parser import Parser, ParserOptions
from .project import Project, ProjectLoader
from .semantic import SemanticAnalyzer, SemanticProgram
from .source import SourceManager


@dataclass(slots=True)
class CompilationResult:
    project: Project
    sources: SourceManager
    diagnostics: DiagnosticEngine
    units: list[SourceUnit] = field(default_factory=list)
    semantic: SemanticProgram | None = None
    ir: IRProgram | None = None
    generated_files: list[GeneratedFile] = field(default_factory=list)
    output_path: Path | None = None
    build_record: dict[str, Any] = field(default_factory=dict)

    @property
    def success(self) -> bool:
        return not self.diagnostics.has_errors


class Compiler:
    def __init__(self):
        self.sources = SourceManager()
        self.diagnostics = DiagnosticEngine(self.sources)

    def load_project(self, path: Path) -> Project:
        return ProjectLoader(self.diagnostics).load(path)

    def parse_project(self, project: Project) -> list[SourceUnit]:
        units: list[SourceUnit] = []
        modules = self.resolved_modules(project)
        for module_name, paths in sorted(modules.items()):
            for path in paths:
                source_id = str(path.relative_to(project.root))
                source = self.sources.load(path, source_id)
                tokens = Lexer(source, self.diagnostics).lex()
                unit = Parser(tokens, self.diagnostics, ParserOptions(allow_native=True)).parse_source_unit(module_name)
                units.append(unit)
        for path in project.generated_sources:
            source_id = str(path.relative_to(project.root)) if path.is_relative_to(project.root) else str(path)
            source = self.sources.load(path, source_id)
            tokens = Lexer(source, self.diagnostics).lex()
            # Generated source must be explicitly assigned through a matching module map.
            module_name = project.module_for_path(path)
            units.append(Parser(tokens, self.diagnostics, ParserOptions(allow_native=True)).parse_source_unit(module_name))
        return units

    def resolved_modules(self, project: Project) -> dict[str, list[Path]]:
        modules = {name: list(paths) for name, paths in project.modules.items()}
        library_file = self.standard_library_project(project)
        if library_file is None:
            return modules
        library = ProjectLoader(self.diagnostics).load(library_file)
        for name, paths in library.modules.items():
            if name in modules:
                self.diagnostics.error(
                    "OPENC-MODULE-DUPLICATE-001",
                    phase=self._tool_phase(),
                    message=f"project module {name!r} conflicts with the standard library",
                    category="module.project",
                )
                continue
            modules[name] = list(paths)
        return modules

    def standard_library_project(self, project: Project) -> Path | None:
        candidates: list[Path] = []
        if project.standard_library_directory is not None:
            candidates.append(project.standard_library_directory / "openc.project.json")
        candidates.extend([
            project.root / "standard_library" / "openc.project.json",
            Path(__file__).resolve().parents[4] / "standard_library" / "openc.project.json",
        ])
        for candidate in candidates:
            candidate = candidate.resolve()
            if candidate.is_file():
                return candidate
        return None

    def check(self, project: Project) -> CompilationResult:
        result = CompilationResult(project, self.sources, self.diagnostics)
        try:
            result.units = self.parse_project(project)
            analyzer = SemanticAnalyzer(self.diagnostics, project.target())
            result.semantic = analyzer.analyze(result.units)
        except OpenCError:
            pass
        result.build_record = self.build_record(result, "check")
        return result

    def lower(self, project: Project) -> CompilationResult:
        result = self.check(project)
        if not result.success or result.semantic is None:
            return result
        source_hashes = project.input_hashes()
        result.ir = Lowerer(result.semantic, source_hashes, project.target_name).lower()
        Verifier(self.diagnostics).verify(result.ir)
        result.build_record = self.build_record(result, "lower")
        return result

    def generate(self, project: Project) -> CompilationResult:
        result = self.lower(project)
        if not result.success or result.semantic is None:
            return result
        emitter = CEmitter(result.semantic, project.target_name)
        result.generated_files = emitter.generate()
        generated_root = project.output_directory / "generated"
        for item in result.generated_files:
            destination = project.output_directory / item.relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(item.content, encoding="utf-8", newline="\n")
        if result.ir is not None:
            ir_path = generated_root / "openc_program.core-ir.json"
            ir_path.write_text(json.dumps(result.ir.to_json(), indent=2, sort_keys=True) + "\n", encoding="utf-8")
        result.build_record = self.build_record(result, "generate")
        return result

    def build(self, project: Project, output: Path | None = None) -> CompilationResult:
        result = self.generate(project)
        if not result.success:
            return result
        output = output or default_output_path(project)
        output.parent.mkdir(parents=True, exist_ok=True)
        generated_dir = project.output_directory / "generated"
        runtime_root = project.runtime_directory or default_runtime_root(project.root)
        compiler = project.c_compiler or discover_c_compiler(project.target_name)
        command = build_command(
            compiler, project.target_name, generated_dir, runtime_root, output,
            project.c_flags, project.linker_flags,
        )
        process = subprocess.run(command, cwd=project.root, text=True, capture_output=True)
        result.output_path = output
        result.build_record = self.build_record(result, "build")
        result.build_record["backend_command"] = command
        result.build_record["backend_exit_code"] = process.returncode
        result.build_record["backend_stdout"] = process.stdout
        result.build_record["backend_stderr"] = process.stderr
        if process.returncode != 0:
            self.diagnostics.error(
                "OPENC-BACKEND-COMPILER-001", phase=self._tool_phase(),
                message=f"C bootstrap backend failed with exit code {process.returncode}",
                category="backend.c",
                help=[process.stderr.strip()] if process.stderr.strip() else [],
            )
        result.build_record["success"] = result.success
        write_build_record(project, result.build_record)
        return result

    def build_record(self, result: CompilationResult, phase: str) -> dict[str, Any]:
        project = result.project
        generated_hashes = {
            item.relative_path: hashlib.sha256(item.content.encode("utf-8")).hexdigest()
            for item in result.generated_files
        }
        return {
            "schema": "openc.build_record.v1",
            "compiler": {"name": "openc-bootstrap-python", "version": "1.0.0-rc.6"},
            "project": {"name": project.name, "version": project.version, "file": str(project.project_file)},
            "edition": project.edition,
            "profile": project.profile,
            "target": project.target_name,
            "phase": phase,
            "inputs": project.input_hashes(),
            "generated": dict(sorted(generated_hashes.items())),
            "diagnostics": self.diagnostics.to_json(),
            "success": result.success,
            "evidence_state": "EXECUTED" if phase == "build" else "AUTHORED",
        }

    @staticmethod
    def _tool_phase():
        from .model import Phase
        return Phase.TOOL


def default_runtime_root(project_root: Path) -> Path:
    candidates = [
        project_root / "runtime",
        Path(__file__).resolve().parents[3] / "runtime",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[-1]


def default_output_path(project: Project) -> Path:
    suffix = ".exe" if project.target_name.startswith("windows") else ""
    return project.output_directory / "bin" / (project.name + suffix)


def discover_c_compiler(target_name: str) -> str:
    environment = os.environ.get("OPENC_C_COMPILER")
    if environment:
        return environment
    candidates = ["clang", "gcc", "cc"]
    if target_name.startswith("windows"):
        candidates = ["clang-cl", "cl", "x86_64-w64-mingw32-gcc", "clang", "gcc"]
    for candidate in candidates:
        if shutil.which(candidate):
            return candidate
    return candidates[0]


def build_command(
    compiler: str,
    target_name: str,
    generated_dir: Path,
    runtime_root: Path,
    output: Path,
    c_flags: list[str],
    linker_flags: list[str],
) -> list[str]:
    program = generated_dir / "openc_program.c"
    include = generated_dir
    common = runtime_root / "common" / "source" / "openc_runtime.c"
    if target_name.startswith("windows"):
        platform = runtime_root / "windows" / "source" / "openc_platform_windows.c"
    elif target_name.startswith("linux"):
        platform = runtime_root / "linux" / "source" / "openc_platform_linux.c"
    else:
        platform = runtime_root / "freestanding" / "source" / "openc_platform_freestanding.c"
    common_include = runtime_root / "common" / "source"
    if Path(compiler).name.lower() in {"cl", "cl.exe", "clang-cl", "clang-cl.exe"}:
        return [
            compiler, "/nologo", "/std:c11", "/W4", f"/I{include}", f"/I{common_include}",
            str(program), str(common), str(platform), f"/Fe:{output}", *c_flags, *linker_flags,
        ]
    command = [
        compiler, "-std=c11", "-Wall", "-Wextra", "-Werror", "-I", str(include),
        "-I", str(common_include), str(program), str(common), str(platform), "-o", str(output),
        *c_flags, *linker_flags,
    ]
    if target_name.startswith("windows") and "mingw" not in compiler and compiler in {"clang", "gcc"}:
        command[1:1] = ["--target=x86_64-w64-windows-gnu"]
    return command


def write_build_record(project: Project, record: dict[str, Any]) -> None:
    path = project.output_directory / "records" / "build-record.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
