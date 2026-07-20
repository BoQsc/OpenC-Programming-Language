"""Logical modules, symbols, lexical scopes, and overload sets."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable

from .diagnostics import DiagnosticEngine
from .model import Decl, FunctionDecl, Phase, SemanticType, Span, Symbol


class Scope:
    def __init__(self, parent: "Scope | None" = None):
        self.parent = parent
        self.symbols: dict[str, Symbol | list[Symbol]] = {}

    def define(self, symbol: Symbol, diagnostics: DiagnosticEngine, span: Span | None = None) -> None:
        existing = self.symbols.get(symbol.name)
        if existing is None:
            self.symbols[symbol.name] = [symbol] if symbol.kind == "function" else symbol
            return
        if symbol.kind == "function":
            if isinstance(existing, list) and all(item.kind == "function" for item in existing):
                existing.append(symbol)
                return
        diagnostics.raise_error(
            "OPENC-NAME-DUPLICATE-001", Phase.DECLARATION,
            f"duplicate declaration of '{symbol.name}'", span, "declaration.duplicate",
        )

    def lookup_local(self, name: str) -> Symbol | list[Symbol] | None:
        return self.symbols.get(name)

    def lookup(self, name: str) -> Symbol | list[Symbol] | None:
        scope: Scope | None = self
        while scope is not None:
            value = scope.lookup_local(name)
            if value is not None:
                return value
            scope = scope.parent
        return None


@dataclass(slots=True)
class Module:
    name: str
    source_ids: list[str] = field(default_factory=list)
    declarations: list[Decl] = field(default_factory=list)
    imports_by_source: dict[str, list[str]] = field(default_factory=dict)
    scope: Scope = field(default_factory=Scope)
    exported: dict[str, Symbol | list[Symbol]] = field(default_factory=dict)

    def short_name(self) -> str:
        return self.name.rsplit(".", 1)[-1]


class ModuleGraph:
    def __init__(self, diagnostics: DiagnosticEngine):
        self.diagnostics = diagnostics
        self.modules: dict[str, Module] = {}

    def get_or_create(self, name: str) -> Module:
        if name not in self.modules:
            self.modules[name] = Module(name)
        return self.modules[name]

    def add_source(self, module_name: str, source_id: str, declarations: Iterable[Decl], imports: Iterable[str]) -> None:
        module = self.get_or_create(module_name)
        if source_id in module.source_ids:
            self.diagnostics.raise_error(
                "OPENC-MODULE-SOURCE-DUPLICATE-001", Phase.DECLARATION,
                f"source unit '{source_id}' was assigned to module '{module_name}' more than once",
                category="module.mapping",
            )
        module.source_ids.append(source_id)
        module.declarations.extend(declarations)
        module.imports_by_source[source_id] = list(imports)

    def resolve_import(self, current: Module, source_id: str, qualifier: str) -> Module | None:
        imports = current.imports_by_source.get(source_id, [])
        matches = [name for name in imports if name == qualifier or name.rsplit(".", 1)[-1] == qualifier]
        if len(matches) > 1:
            self.diagnostics.raise_error(
                "OPENC-MODULE-QUALIFIER-AMBIGUOUS-001", Phase.NAME,
                f"short module qualifier '{qualifier}' is ambiguous",
                category="module.qualifier",
                help=["use the fully qualified module name"],
            )
        if not matches:
            return self.modules.get(qualifier)
        return self.modules.get(matches[0])

    def detect_cycles(self) -> list[list[str]]:
        edges: dict[str, set[str]] = {name: set() for name in self.modules}
        for name, module in self.modules.items():
            for imports in module.imports_by_source.values():
                edges[name].update(item for item in imports if item in self.modules)
        index = 0
        stack: list[str] = []
        on_stack: set[str] = set()
        indices: dict[str, int] = {}
        low: dict[str, int] = {}
        cycles: list[list[str]] = []

        def visit(name: str) -> None:
            nonlocal index
            indices[name] = index
            low[name] = index
            index += 1
            stack.append(name)
            on_stack.add(name)
            for target in sorted(edges[name]):
                if target not in indices:
                    visit(target)
                    low[name] = min(low[name], low[target])
                elif target in on_stack:
                    low[name] = min(low[name], indices[target])
            if low[name] == indices[name]:
                component: list[str] = []
                while stack:
                    item = stack.pop()
                    on_stack.remove(item)
                    component.append(item)
                    if item == name:
                        break
                if len(component) > 1 or (len(component) == 1 and name in edges[name]):
                    cycles.append(sorted(component))

        for name in sorted(self.modules):
            if name not in indices:
                visit(name)
        return cycles
