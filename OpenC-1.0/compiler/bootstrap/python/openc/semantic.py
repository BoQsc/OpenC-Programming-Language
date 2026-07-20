"""OpenC declaration, name, type, flow, ownership, and unsafe analysis.

The authored reference checker intentionally keeps each normative category
visible even though the implementation is compact.  It consumes parsed modules,
resolves declarations, evaluates constants, checks function bodies, and returns
fully typed syntax trees for lowering.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable, Iterator, Sequence

from .consteval import ConstantEvaluator
from .diagnostics import DiagnosticEngine
from .flow import (
    FlowBinding, FlowState, InitState, OwnerState, PresenceState,
)
from .model import (
    AggregateExpr, ArrayExpr, AssignExpr, BinaryExpr, BlockStmt, BreakStmt,
    CallExpr, CastExpr, ConstDecl, ConstructExpr, ContinueStmt, Decl, DestroyExpr,
    EnumDecl, Expr, ExprStmt, ForStmt, FunctionDecl, IfStmt, ImportDecl,
    IndexExpr, LiteralExpr, LocalDecl, MemberExpr, NameExpr, ParamDecl, Phase,
    RangeExpr, ReturnStmt, ScopeStmt, SemanticType, SourceUnit, Span, StatusExpr,
    StructDecl, SwitchStmt, TypeQueryExpr, UnaryExpr, UnsafeStmt, WhenDecl,
    WhenStmt, WhileStmt, Symbol,
)
from .ownership import BorrowRecord, OwnershipChecker
from .symbols import Module, ModuleGraph, Scope
from .typesys import TargetFacts, TypeRegistry


@dataclass(slots=True)
class FunctionSignature:
    symbol: Symbol
    declaration: FunctionDecl
    result: SemanticType
    result_mode: str
    params: list[tuple[ParamDecl, SemanticType]]


@dataclass(slots=True)
class SemanticProgram:
    modules: ModuleGraph
    types: TypeRegistry
    signatures: dict[int, FunctionSignature]
    selected_units: list[SourceUnit]


class SemanticAnalyzer:
    def __init__(self, diagnostics: DiagnosticEngine, target: TargetFacts | None = None):
        self.diagnostics = diagnostics
        self.target = target or TargetFacts()
        self.types = TypeRegistry(self.target, diagnostics)
        self.constants = ConstantEvaluator(self.types, diagnostics)
        self.modules = ModuleGraph(diagnostics)
        self.signatures: dict[int, FunctionSignature] = {}
        self.current_module: Module | None = None
        self.current_source_id = ""
        self.current_function: FunctionSignature | None = None
        self.current_scope: Scope | None = None
        self.flow: FlowState | None = None
        self.ownership = OwnershipChecker(diagnostics)
        self.import_cycles: list[list[str]] = []

    def analyze(self, units: Sequence[SourceUnit]) -> SemanticProgram:
        selected_units: list[SourceUnit] = []
        for unit in units:
            module_name = unit.module_name or "main"
            selected = self.select_when_declarations(unit.declarations)
            selected_unit = SourceUnit(unit.span, unit.imports, selected, module_name)
            selected_units.append(selected_unit)
            self.modules.add_source(
                module_name,
                unit.span.source_id,
                selected,
                [item.module for item in unit.imports],
            )

        self.check_import_cycles()
        self.predeclare_types(selected_units)
        self.define_type_bodies(selected_units)
        self.define_symbols(selected_units)
        self.resolve_constants(selected_units)
        self.resolve_function_signatures(selected_units)
        self.check_export_interfaces()
        self.check_function_bodies(selected_units)
        return SemanticProgram(self.modules, self.types, self.signatures, selected_units)

    def select_when_declarations(self, declarations: Sequence[Decl]) -> list[Decl]:
        result: list[Decl] = []
        for decl in declarations:
            if isinstance(decl, WhenDecl):
                assert decl.condition is not None
                value = self.constants.evaluate(decl.condition, when_context=True)
                if value.type.kind != "bool":
                    self.diagnostics.raise_error(
                        "OPENC-WHEN-EXPR-001", Phase.CONSTANT,
                        "when condition must have type bool", decl.condition.span, "constant.when",
                    )
                if bool(value.value):
                    result.extend(self.select_when_declarations(decl.declarations))
            else:
                result.append(decl)
        return result

    def check_import_cycles(self) -> None:
        # Declaration collection is order independent, so an import cycle is not by itself
        # invalid.  The cycle is retained for constant-initialization diagnostics: if no
        # pending constant in a strongly connected component can be evaluated, the cycle is
        # reported instead of being accepted through implementation order.
        self.import_cycles = self.modules.detect_cycles()

    def predeclare_types(self, units: Sequence[SourceUnit]) -> None:
        for unit in units:
            module_name = unit.module_name or "main"
            for decl in unit.declarations:
                if isinstance(decl, StructDecl):
                    full = f"{module_name}.{decl.name}"
                    if self.types.lookup(full) or self.types.lookup(decl.name):
                        self.diagnostics.raise_error(
                            "OPENC-TYPE-DUPLICATE-001", Phase.DECLARATION,
                            f"duplicate type '{decl.name}'", decl.span, "declaration.type",
                        )
                    value = SemanticType("resource" if decl.resource else "struct", full, resource=decl.resource)
                    self.types.types[full] = value
                    if decl.name not in self.types.types:
                        self.types.types[decl.name] = value
                elif isinstance(decl, EnumDecl):
                    full = f"{module_name}.{decl.name}"
                    value = SemanticType("enum", full)
                    self.types.types[full] = value
                    if decl.name not in self.types.types:
                        self.types.types[decl.name] = value

    def define_type_bodies(self, units: Sequence[SourceUnit]) -> None:
        for unit in units:
            module_name = unit.module_name or "main"
            for decl in unit.declarations:
                if isinstance(decl, StructDecl):
                    semantic = self.types.lookup(f"{module_name}.{decl.name}")
                    assert semantic is not None
                    fields: dict[str, SemanticType] = {}
                    for field in decl.fields:
                        if field.name in fields:
                            self.diagnostics.raise_error(
                                "OPENC-STRUCT-FIELD-DUPLICATE-001", Phase.DECLARATION,
                                f"duplicate field '{field.name}'", field.span, "declaration.field",
                            )
                        field_type = self.resolve_type_syntax(field.type_syntax, module_name)
                        self.validate_field_type(decl, field, field_type)
                        fields[field.name] = field_type
                    semantic.fields = fields
                elif isinstance(decl, EnumDecl):
                    semantic = self.types.lookup(f"{module_name}.{decl.name}")
                    assert semantic is not None
                    next_value = 0
                    items: dict[str, int] = {}
                    for item in decl.items:
                        if item.name in items:
                            self.diagnostics.raise_error(
                                "OPENC-ENUM-ITEM-DUPLICATE-001", Phase.DECLARATION,
                                f"duplicate enum item '{item.name}'", item.span, "declaration.enum",
                            )
                        if item.value is not None:
                            value = self.constants.evaluate(item.value)
                            if not value.type.is_integer():
                                self.diagnostics.raise_error(
                                    "OPENC-ENUM-VALUE-TYPE-001", Phase.CONSTANT,
                                    "enum value must be an integer constant", item.value.span, "constant.enum",
                                )
                            next_value = int(value.value)
                        items[item.name] = next_value
                        next_value += 1
                    semantic.enum_items = items
                    base = decl.base_type.name if decl.base_type and decl.base_type.name else "u32"
                    semantic.fields["__base__"] = self.types.types[base]

    def validate_field_type(self, decl: StructDecl, field, field_type: SemanticType) -> None:
        if field_type.kind in {"ref", "slice", "storage", "void"}:
            self.diagnostics.raise_error(
                "OPENC-STRUCT-FIELD-TYPE-001", Phase.TYPE,
                f"field '{field.name}' cannot have type {field_type.display()}", field.span, "type.field",
            )
        if not decl.resource and (field_type.resource or field.ownership):
            self.diagnostics.raise_error(
                "OPENC-STRUCT-RESOURCE-FIELD-001", Phase.OWNERSHIP,
                "ordinary structs cannot contain ownership-bearing fields", field.span, "ownership.aggregate",
            )
        if field.ownership and field_type.kind != "ptr":
            self.diagnostics.raise_error(
                "OPENC-RESOURCE-OWN-PTR-001", Phase.OWNERSHIP,
                "own resource field must have ptr type", field.span, "ownership.aggregate",
            )

    def define_symbols(self, units: Sequence[SourceUnit]) -> None:
        for unit in units:
            module = self.modules.modules[unit.module_name or "main"]
            for decl in unit.declarations:
                symbol: Symbol
                if isinstance(decl, StructDecl):
                    value_type = self.types.lookup(f"{module.name}.{decl.name}")
                    symbol = Symbol(decl.name, "type", value_type, decl, module.name, decl.exported, False)
                elif isinstance(decl, EnumDecl):
                    value_type = self.types.lookup(f"{module.name}.{decl.name}")
                    symbol = Symbol(decl.name, "type", value_type, decl, module.name, decl.exported, False)
                elif isinstance(decl, ConstDecl):
                    symbol = Symbol(decl.name, "constant", None, decl, module.name, decl.exported, False)
                elif isinstance(decl, FunctionDecl):
                    symbol = Symbol(decl.name, "function", None, decl, module.name, decl.exported, False)
                else:
                    continue
                module.scope.define(symbol, self.diagnostics, decl.span)
                if decl.exported:
                    existing = module.exported.get(decl.name)
                    if existing is None:
                        module.exported[decl.name] = [symbol] if symbol.kind == "function" else symbol
                    elif symbol.kind == "function" and isinstance(existing, list):
                        existing.append(symbol)
                    else:
                        self.diagnostics.raise_error(
                            "OPENC-MODULE-EXPORT-DUPLICATE-001", Phase.DECLARATION,
                            f"duplicate exported name '{decl.name}'", decl.span, "module.export",
                        )

    def resolve_constants(self, units: Sequence[SourceUnit]) -> None:
        pending: list[tuple[Module, ConstDecl]] = []
        for unit in units:
            module = self.modules.modules[unit.module_name or "main"]
            for decl in unit.declarations:
                if isinstance(decl, ConstDecl):
                    pending.append((module, decl))
        while pending:
            progressed = False
            remaining: list[tuple[Module, ConstDecl]] = []
            for module, decl in pending:
                try:
                    value_type = self.resolve_type_syntax(decl.type_syntax, module.name) if decl.type_syntax else None
                    assert decl.value is not None and value_type is not None
                    value = self.constants.evaluate(decl.value, value_type)
                    if not self.types.can_losslessly_convert(value.type, value_type):
                        self.diagnostics.raise_error(
                            "OPENC-CONV-LOSSY-001", Phase.CONSTANT,
                            f"constant value cannot convert losslessly to {value_type.display()}",
                            decl.value.span, "constant.conversion",
                        )
                    self.constants.define(f"{module.name}.{decl.name}", value)
                    self.constants.define(decl.name, value)
                    symbol = module.scope.lookup_local(decl.name)
                    if isinstance(symbol, Symbol):
                        symbol.type = value_type
                    progressed = True
                except Exception as exc:
                    # Unknown constant names are retried; structured compiler errors propagate.
                    if getattr(exc, "diagnostic", None) and exc.diagnostic.rule_id == "OPENC-CONSTANT-NAME-001":
                        remaining.append((module, decl))
                    else:
                        raise
            if not progressed and remaining:
                module, decl = remaining[0]
                cycle = next((item for item in self.import_cycles if module.name in item), None)
                if cycle:
                    self.diagnostics.raise_error(
                        "OPENC-MODULE-CONST-CYCLE-001", Phase.CONSTANT,
                        "module constant initialization cycle: " + " -> ".join(cycle + [cycle[0]]),
                        decl.span, "constant.module_cycle",
                    )
                self.diagnostics.raise_error(
                    "OPENC-CONSTANT-CYCLE-001", Phase.CONSTANT,
                    f"constant '{module.name}.{decl.name}' participates in a cycle or unresolved dependency",
                    decl.span, "constant.cycle",
                )
            pending = remaining

    def resolve_function_signatures(self, units: Sequence[SourceUnit]) -> None:
        for unit in units:
            module = self.modules.modules[unit.module_name or "main"]
            for decl in unit.declarations:
                if not isinstance(decl, FunctionDecl):
                    continue
                result = self.types.types["void"] if decl.result_mode == "void" else self.resolve_type_syntax(decl.result_type, module.name)
                params: list[tuple[ParamDecl, SemanticType]] = []
                for param in decl.params:
                    param_type = self.resolve_type_syntax(param.type_syntax, module.name)
                    self.validate_parameter_mode(param, param_type)
                    params.append((param, param_type))
                symbols = module.scope.lookup_local(decl.name)
                assert isinstance(symbols, list)
                symbol = next(item for item in symbols if item.declaration is decl)
                symbol.type = result
                symbol.mode = decl.result_mode
                signature = FunctionSignature(symbol, decl, result, decl.result_mode, params)
                self.signatures[id(decl)] = signature
        self.check_overload_duplicates()

    def validate_parameter_mode(self, param: ParamDecl, value_type: SemanticType) -> None:
        if param.mode == "ordinary" and value_type.resource:
            self.diagnostics.raise_error(
                "OPENC-RESOURCE-PARAM-VALUE-001", Phase.TYPE,
                "resource parameter must use ref, ref const, own, or out mode",
                param.span, "type.parameter",
            )
        if param.mode == "own" and not (value_type.resource or value_type.kind == "ptr"):
            self.diagnostics.raise_error(
                "OPENC-OWN-PARAM-TYPE-001", Phase.TYPE,
                "own parameter requires a resource type or raw pointer", param.span, "type.parameter",
            )
        if param.mode == "out_own" and value_type.kind != "ptr":
            self.diagnostics.raise_error(
                "OPENC-OUT-OWN-TYPE-001", Phase.TYPE,
                "out own parameter requires ptr type", param.span, "type.parameter",
            )
        if param.mode.startswith("out") and value_type.const:
            self.diagnostics.raise_error(
                "OPENC-OUT-CONST-001", Phase.TYPE,
                "out parameter cannot be const", param.span, "type.parameter",
            )

    def check_overload_duplicates(self) -> None:
        for module in self.modules.modules.values():
            for name, value in module.scope.symbols.items():
                if not isinstance(value, list):
                    continue
                seen: dict[tuple, FunctionDecl] = {}
                for symbol in value:
                    decl = symbol.declaration
                    assert isinstance(decl, FunctionDecl)
                    sig = self.signatures[id(decl)]
                    key = tuple((param.mode, param_type.key()) for param, param_type in sig.params)
                    if key in seen:
                        self.diagnostics.raise_error(
                            "OPENC-OVERLOAD-DUPLICATE-001", Phase.DECLARATION,
                            f"duplicate overload '{name}'", decl.span, "declaration.overload",
                        )
                    seen[key] = decl

    def check_export_interfaces(self) -> None:
        for module in self.modules.modules.values():
            for name, value in module.exported.items():
                symbols = value if isinstance(value, list) else [value]
                for symbol in symbols:
                    decl = symbol.declaration
                    if isinstance(decl, FunctionDecl):
                        sig = self.signatures[id(decl)]
                        self.require_exportable_type(sig.result, decl.span)
                        for _, param_type in sig.params:
                            self.require_exportable_type(param_type, decl.span)
                    elif symbol.type:
                        self.require_exportable_type(symbol.type, decl.span if decl else None)

    def require_exportable_type(self, value_type: SemanticType, span: Span | None) -> None:
        # Private named types are checked by module identity during name resolution. The
        # authored bootstrap records the interface type graph here for deterministic output.
        if value_type.kind in {"storage"}:
            self.diagnostics.raise_error(
                "OPENC-MODULE-EXPORT-TYPE-001", Phase.TYPE,
                f"exported interface cannot expose {value_type.display()}", span, "module.interface",
            )

    def check_function_bodies(self, units: Sequence[SourceUnit]) -> None:
        for unit in units:
            module = self.modules.modules[unit.module_name or "main"]
            for decl in unit.declarations:
                if isinstance(decl, FunctionDecl) and decl.body is not None:
                    self.check_function(module, unit.span.source_id, decl)

    def check_function(self, module: Module, source_id: str, decl: FunctionDecl) -> None:
        signature = self.signatures[id(decl)]
        self.current_module = module
        self.current_source_id = source_id
        self.current_function = signature
        self.current_scope = Scope(module.scope)
        self.flow = FlowState()
        for param, value_type in signature.params:
            binding = FlowBinding(
                param.name, value_type, param.span, InitState.UNINITIALIZED,
                PresenceState.UNKNOWN,
                OwnerState.UNINITIALIZED if value_type.resource or param.mode in {"own", "out_own"} else OwnerState.NONE,
                None, mutable=param.mode != "ordinary" or not value_type.const,
            )
            if param.mode in {"out", "out_own"}:
                binding.init = InitState.UNINITIALIZED
            else:
                binding.init = InitState.INITIALIZED
                if param.mode == "own":
                    binding.owner = OwnerState.LIVE
                elif value_type.resource:
                    binding.owner = OwnerState.NONE
            self.flow.declare(binding, self.diagnostics)
            self.current_scope.define(
                Symbol(param.name, "parameter", value_type, param, module.name, False, binding.mutable, param.mode),
                self.diagnostics, param.span,
            )
        self.check_block(decl.body, create_scope=False)
        assert self.flow is not None
        if self.flow.reachable:
            if signature.result.kind != "void":
                self.diagnostics.raise_error(
                    "OPENC-FUNCTION-RETURN-001", Phase.FLOW,
                    f"function '{decl.name}' may complete without returning {signature.result.display()}",
                    decl.body.span, "flow.return",
                )
            self.flow.verify_scope_exit(self.diagnostics, decl.body.span)
        self.verify_out_function_contract(signature, decl.body.span)
        self.current_function = None
        self.current_scope = None
        self.flow = None

    def verify_out_function_contract(self, signature: FunctionSignature, span: Span) -> None:
        # Per-return checks occur in check_return. This final check catches reachable
        # void completion of a status/out function and unresolved ownership states.
        out_params = [param.name for param, _ in signature.params if param.mode in {"out", "out_own"}]
        if out_params and signature.result.name != "status":
            self.diagnostics.raise_error(
                "OPENC-OUT-RESULT-001", Phase.TYPE,
                "function with out parameters must return status", span, "flow.status_out",
            )

    def check_block(self, block: BlockStmt, create_scope: bool = True) -> None:
        assert self.flow is not None and self.current_scope is not None
        parent_scope = self.current_scope
        entry_names = set(self.flow.bindings)
        if create_scope:
            self.current_scope = Scope(parent_scope)
        local_names: list[str] = []
        cleanup_order: list[str] = []
        for item in block.items:
            if not self.flow.reachable:
                self.diagnostics.warning(
                    "OPENC-FLOW-UNREACHABLE-001", Phase.FLOW,
                    "unreachable statement", item.span, "flow.unreachable",
                )
                break
            if isinstance(item, LocalDecl):
                local_names.append(item.name)
                self.check_local(item)
            else:
                if isinstance(item, ScopeStmt):
                    owner_name = self.check_scope_stmt(item)
                    if owner_name:
                        cleanup_order.append(owner_name)
                else:
                    self.check_statement(item)
        # Normal scope exit executes registered cleanup in reverse order.
        if self.flow.reachable:
            for owner_name in reversed(cleanup_order):
                self.ownership.consume_reserved_cleanup(self.flow, owner_name)
            self.flow.verify_scope_exit(self.diagnostics, block.span, local_names)
        for name in local_names:
            self.flow.bindings.pop(name, None)
        if create_scope:
            self.current_scope = parent_scope

    def check_local(self, decl: LocalDecl) -> None:
        assert self.current_module and self.current_scope and self.flow
        value_type = self.resolve_type_syntax(decl.type_syntax, self.current_module.name)
        owner_state = OwnerState.UNINITIALIZED if value_type.resource else OwnerState.NONE
        binding = FlowBinding(
            decl.name, value_type, decl.span, InitState.UNINITIALIZED,
            PresenceState.UNKNOWN, owner_state, None, mutable=not value_type.const,
        )
        self.flow.declare(binding, self.diagnostics)
        self.current_scope.define(
            Symbol(decl.name, "local", value_type, decl, self.current_module.name, False, not value_type.const),
            self.diagnostics, decl.span,
        )
        if decl.initializer is not None:
            # Special status/out carrier recognition.
            if value_type.kind == "status" and isinstance(decl.initializer, CallExpr):
                out_names, owning_names = self.prepare_out_call(decl.initializer)
                expr_type = self.check_expression(decl.initializer, expected=value_type)
                self.require_conversion(expr_type, value_type, decl.initializer.span)
                binding.init = InitState.INITIALIZED
                lineage = self.flow.new_lineage(decl.name, out_names, owning_names)
                binding.lineage = lineage
                for name in out_names:
                    out_binding = self.flow.bindings[name]
                    out_binding.init = InitState.CONDITIONAL
                    out_binding.lineage = lineage
                    if name in owning_names:
                        out_binding.owner = OwnerState.CONDITIONAL
                return
            expr_type = self.check_expression(decl.initializer, expected=value_type)
            self.require_conversion(expr_type, value_type, decl.initializer.span)
            if value_type.resource:
                binding.owner = OwnerState.LIVE
            binding.init = InitState.INITIALIZED
            if value_type.kind == "optional":
                binding.presence = PresenceState.ABSENT if isinstance(decl.initializer, LiteralExpr) and decl.initializer.literal_kind == "none" else PresenceState.PRESENT

    def check_statement(self, statement) -> None:
        assert self.flow is not None
        if isinstance(statement, BlockStmt):
            self.check_block(statement)
        elif isinstance(statement, ExprStmt):
            assert statement.expr is not None
            self.check_expression(statement.expr)
        elif isinstance(statement, IfStmt):
            self.check_if(statement)
        elif isinstance(statement, WhileStmt):
            self.check_while(statement)
        elif isinstance(statement, ForStmt):
            self.check_for(statement)
        elif isinstance(statement, SwitchStmt):
            self.check_switch(statement)
        elif isinstance(statement, BreakStmt):
            if self.flow.loop_depth <= 0:
                self.diagnostics.raise_error(
                    "OPENC-LOOP-CONTEXT-001", Phase.FLOW,
                    "break is only valid inside a loop", statement.span, "flow.loop",
                )
            self.flow.verify_scope_exit(self.diagnostics, statement.span)
            self.flow.reachable = False
        elif isinstance(statement, ContinueStmt):
            if self.flow.loop_depth <= 0:
                self.diagnostics.raise_error(
                    "OPENC-LOOP-CONTEXT-001", Phase.FLOW,
                    "continue is only valid inside a loop", statement.span, "flow.loop",
                )
            self.flow.verify_scope_exit(self.diagnostics, statement.span)
            self.flow.reachable = False
        elif isinstance(statement, ReturnStmt):
            self.check_return(statement)
        elif isinstance(statement, UnsafeStmt):
            self.flow.unsafe_depth += 1
            assert statement.body is not None
            self.check_block(statement.body)
            self.flow.unsafe_depth -= 1
        elif isinstance(statement, WhenStmt):
            assert statement.condition is not None and statement.body is not None
            value = self.constants.evaluate(statement.condition, when_context=True)
            if value.type.kind != "bool":
                self.diagnostics.raise_error(
                    "OPENC-WHEN-EXPR-001", Phase.CONSTANT,
                    "when condition must be bool", statement.condition.span, "constant.when",
                )
            if value.value:
                self.check_block(statement.body)
        elif isinstance(statement, ScopeStmt):
            self.check_scope_stmt(statement)
        else:
            raise AssertionError(type(statement))

    def check_scope_stmt(self, statement: ScopeStmt) -> str | None:
        assert self.flow and statement.action is not None
        action = statement.action
        if isinstance(action, DestroyExpr):
            owner_name = self.extract_owner_name(action.value)
            if owner_name is None:
                self.diagnostics.raise_error(
                    "OPENC-SCOPE-ACTION-001", Phase.OWNERSHIP,
                    "scope destroy requires a stable owner binding", statement.span, "ownership.cleanup",
                )
            assert owner_name is not None
            self.ownership.reserve_cleanup(self.flow, owner_name, "destroy", statement.span)
            return owner_name
        if isinstance(action, CallExpr):
            signature = self.resolve_call(action, scope_context=True)
            if signature.result.kind != "void":
                self.diagnostics.raise_error(
                    "OPENC-SCOPE-NOFAIL-001", Phase.TYPE,
                    "scope cleanup operation must return void", action.span, "ownership.cleanup",
                )
            owner_name = None
            for arg, (param, _) in zip(action.args, signature.params):
                if param.mode == "own":
                    candidate = self.extract_owner_name(arg.value)
                    if candidate is None or owner_name is not None:
                        self.diagnostics.raise_error(
                            "OPENC-SCOPE-OWNER-001", Phase.OWNERSHIP,
                            "scope cleanup must consume exactly one stable owner binding",
                            action.span, "ownership.cleanup",
                        )
                    owner_name = candidate
            if owner_name is None:
                self.diagnostics.raise_error(
                    "OPENC-SCOPE-OWNER-001", Phase.OWNERSHIP,
                    "scope cleanup call must consume one owner", action.span, "ownership.cleanup",
                )
            self.ownership.reserve_cleanup(self.flow, owner_name, self.call_name(action), action.span)
            return owner_name
        self.diagnostics.raise_error(
            "OPENC-SCOPE-ACTION-001", Phase.SYNTAX,
            "invalid scope cleanup action", statement.span, "ownership.cleanup",
        )
        return None

    def check_if(self, statement: IfStmt) -> None:
        assert self.flow and statement.condition and statement.then_branch
        condition_type = self.check_expression(statement.condition, expected=self.types.types["bool"])
        self.require_exact_bool(condition_type, statement.condition.span)
        entry = self.flow.clone()
        true_state = entry.clone()
        false_state = entry.clone()
        self.refine_condition(statement.condition, true_state, True)
        self.refine_condition(statement.condition, false_state, False)
        self.flow = true_state
        self.check_block(statement.then_branch)
        true_exit = self.flow.clone()
        self.flow = false_state
        if statement.else_branch is not None:
            self.check_statement(statement.else_branch)
        false_exit = self.flow.clone()
        self.flow = true_exit.merge(false_exit)

    def check_while(self, statement: WhileStmt) -> None:
        assert self.flow and statement.condition and statement.body
        entry = self.flow.clone()
        loop_state = entry.clone()
        loop_state.loop_depth += 1
        for _ in range(32):
            self.flow = loop_state.clone()
            condition_type = self.check_expression(statement.condition, expected=self.types.types["bool"])
            self.require_exact_bool(condition_type, statement.condition.span)
            body_state = self.flow.clone()
            self.refine_condition(statement.condition, body_state, True)
            self.flow = body_state
            self.check_block(statement.body)
            body_exit = self.flow.clone()
            body_exit.reachable = True  # continue/back-edge joins here.
            merged = loop_state.merge(body_exit)
            if flow_equivalent(merged, loop_state):
                loop_state = merged
                break
            loop_state = merged
        exit_state = entry.merge(loop_state)
        self.refine_condition(statement.condition, exit_state, False)
        exit_state.loop_depth = entry.loop_depth
        self.flow = exit_state

    def check_for(self, statement: ForStmt) -> None:
        assert self.flow and statement.body
        if isinstance(statement.initializer, LocalDecl):
            self.check_local(statement.initializer)
        elif isinstance(statement.initializer, Expr):
            self.check_expression(statement.initializer)
        condition = statement.condition or LiteralExpr(statement.span, None, None, False, "bool", True, "true")
        synthetic = WhileStmt(statement.span, condition, BlockStmt(statement.body.span, list(statement.body.items) + ([ExprStmt(statement.update.span, statement.update)] if statement.update else [])))
        self.check_while(synthetic)

    def check_switch(self, statement: SwitchStmt) -> None:
        assert self.flow and statement.value is not None
        subject_type = self.check_expression(statement.value)
        if subject_type.kind not in {"integer", "bool", "byte", "enum"}:
            self.diagnostics.raise_error(
                "OPENC-SWITCH-TYPE-001", Phase.TYPE,
                f"switch subject cannot have type {subject_type.display()}", statement.value.span, "type.switch",
            )
        entry = self.flow.clone()
        exits: list[FlowState] = []
        saw_default = False
        for case in statement.cases:
            self.flow = entry.clone()
            if case.is_default:
                saw_default = True
            else:
                assert case.value is not None
                value = self.constants.evaluate(case.value, subject_type)
                self.require_conversion(value.type, subject_type, case.value.span)
                self.refine_switch_case(statement.value, case.value, self.flow)
            assert case.body is not None
            self.check_block(case.body)
            exits.append(self.flow.clone())
        if not saw_default:
            exits.append(entry.clone())
        result = exits[0] if exits else entry
        for state in exits[1:]:
            result = result.merge(state)
        self.flow = result

    def check_return(self, statement: ReturnStmt) -> None:
        assert self.current_function and self.flow
        expected = self.current_function.result
        if expected.kind == "void":
            if statement.value is not None:
                self.diagnostics.raise_error(
                    "OPENC-FUNCTION-RETURN-VALUE-001", Phase.TYPE,
                    "void function cannot return a value", statement.span, "type.return",
                )
        else:
            if statement.value is None:
                self.diagnostics.raise_error(
                    "OPENC-FUNCTION-RETURN-001", Phase.TYPE,
                    f"function must return {expected.display()}", statement.span, "type.return",
                )
            assert statement.value is not None
            actual = self.check_expression(statement.value, expected=expected)
            self.require_conversion(actual, expected, statement.value.span)
            if expected.resource:
                name = self.extract_owner_name(statement.value)
                if name is None:
                    # A resource aggregate or resource-returning call creates a stable return sink.
                    if not isinstance(statement.value, (AggregateExpr, CallExpr)):
                        self.diagnostics.raise_error(
                            "OPENC-OWN-RETURN-001", Phase.OWNERSHIP,
                            "resource return requires a stable owner or resource-producing expression",
                            statement.value.span, "ownership.return",
                        )
                else:
                    self.ownership.move(self.flow, name, statement.value.span)
        self.verify_out_return(statement)
        self.flow.verify_scope_exit(self.diagnostics, statement.span)
        self.flow.reachable = False

    def verify_out_return(self, statement: ReturnStmt) -> None:
        assert self.current_function and self.flow
        out_params = [(param, value_type) for param, value_type in self.current_function.params if param.mode in {"out", "out_own"}]
        if not out_params:
            return
        outcome = self.classify_status_return(statement.value)
        if outcome == "success":
            for param, value_type in out_params:
                binding = self.flow.bindings[param.name]
                if binding.init != InitState.INITIALIZED:
                    self.diagnostics.raise_error(
                        "OPENC-OUT-CALLEE-SUCCESS-001", Phase.FLOW,
                        f"successful return requires out parameter '{param.name}' initialized exactly once",
                        statement.span, "flow.status_out",
                    )
                if param.mode == "out_own" and binding.owner != OwnerState.LIVE:
                    self.diagnostics.raise_error(
                        "OPENC-OUT-OWNCOMMIT-001", Phase.OWNERSHIP,
                        f"successful return requires one live ownership obligation for '{param.name}'",
                        statement.span, "ownership.out",
                    )
        elif outcome == "failure":
            for param, _ in out_params:
                binding = self.flow.bindings[param.name]
                if binding.init == InitState.INITIALIZED:
                    self.diagnostics.raise_error(
                        "OPENC-OUT-CALLEE-FAIL-001", Phase.FLOW,
                        f"failed return cannot publish out parameter '{param.name}'",
                        statement.span, "flow.status_out",
                    )
                if binding.owner in {OwnerState.LIVE, OwnerState.CLEANUP_RESERVED, OwnerState.DISMANTLING}:
                    self.diagnostics.raise_error(
                        "OPENC-OUT-OWNFAIL-001", Phase.OWNERSHIP,
                        f"failed return leaves ownership obligation in '{param.name}'",
                        statement.span, "ownership.out",
                    )
        elif outcome != "forwarded":
            self.diagnostics.raise_error(
                "OPENC-OUT-CALLEE-RETURN-001", Phase.FLOW,
                "out function return must be definitely successful, definitely failed, or exact proof forwarding",
                statement.span, "flow.status_out",
            )

    def classify_status_return(self, value: Expr | None) -> str:
        if isinstance(value, StatusExpr) and value.code is not None:
            try:
                code = self.constants.evaluate(value.code, self.types.types["i32"])
                return "success" if int(code.value) == 0 else "failure"
            except Exception:
                return "unknown"
        if isinstance(value, CallExpr) and self.current_function:
            out_args = [arg for arg in value.args if arg.mode == "out"]
            expected_out = [param for param, _ in self.current_function.params if param.mode in {"out", "out_own"}]
            names = [self.extract_owner_name(arg.value) for arg in out_args]
            if names == [param.name for param in expected_out]:
                return "forwarded"
        return "unknown"

    def check_expression(self, expr: Expr, expected: SemanticType | None = None) -> SemanticType:
        if isinstance(expr, LiteralExpr):
            value = self.constants.literal(expr, expected)
            expr.inferred_type = value.type
            return value.type
        if isinstance(expr, NameExpr):
            return self.check_name(expr)
        if isinstance(expr, UnaryExpr):
            return self.check_unary(expr)
        if isinstance(expr, BinaryExpr):
            return self.check_binary(expr)
        if isinstance(expr, AssignExpr):
            return self.check_assign(expr)
        if isinstance(expr, CallExpr):
            signature = self.resolve_call(expr)
            expr.inferred_type = signature.result
            return signature.result
        if isinstance(expr, MemberExpr):
            return self.check_member(expr)
        if isinstance(expr, IndexExpr):
            return self.check_index(expr)
        if isinstance(expr, RangeExpr):
            return self.check_range(expr)
        if isinstance(expr, CastExpr):
            assert expr.target_type and expr.value
            target = self.resolve_type_syntax(expr.target_type, self.current_module.name if self.current_module else "")
            source = self.check_expression(expr.value)
            self.check_cast(expr.cast_kind, source, target, expr.span)
            expr.inferred_type = target
            return target
        if isinstance(expr, TypeQueryExpr):
            assert expr.type_syntax
            value_type = self.resolve_type_syntax(expr.type_syntax, self.current_module.name if self.current_module else "")
            value = self.types.size_of(value_type) if expr.query == "size_of" else self.types.align_of(value_type)
            expr.constant_value = self.constants.literal(
                LiteralExpr(expr.span, None, None, False, "integer", value, str(value)),
                self.types.types["usize"],
            )
            expr.inferred_type = self.types.types["usize"]
            return expr.inferred_type
        if isinstance(expr, AggregateExpr):
            return self.check_aggregate(expr, expected)
        if isinstance(expr, ArrayExpr):
            return self.check_array(expr, expected)
        if isinstance(expr, StatusExpr):
            return self.check_status(expr)
        if isinstance(expr, ConstructExpr):
            return self.check_construct(expr)
        if isinstance(expr, DestroyExpr):
            return self.check_destroy(expr)
        raise AssertionError(type(expr))

    def check_name(self, expr: NameExpr) -> SemanticType:
        assert self.flow and self.current_scope and self.current_module
        if len(expr.parts) == 1:
            name = expr.parts[0]
            local = self.current_scope.lookup(name)
            if isinstance(local, Symbol):
                expr.resolved_symbol = local
                expr.inferred_type = local.type
                if local.kind in {"local", "parameter"}:
                    binding = self.flow.require_readable(name, self.diagnostics, expr.span)
                    expr.lvalue = True
                    return binding.type
                assert local.type is not None
                return local.type
            if isinstance(local, list):
                expr.inferred_type = SemanticType("overload", name)
                return expr.inferred_type
            constant = self.constants.values.get(name) or self.constants.values.get(f"{self.current_module.name}.{name}")
            if constant:
                expr.inferred_type = constant.type
                expr.constant_value = constant
                return constant.type
            self.diagnostics.raise_error(
                "OPENC-NAME-UNKNOWN-001", Phase.NAME,
                f"unknown name '{name}'", expr.span, "name.lookup",
            )
        # Enum item or qualified module name.
        first = expr.parts[0]
        type_value = self.types.lookup(first) or self.types.lookup(f"{self.current_module.name}.{first}")
        if type_value and type_value.kind == "enum" and len(expr.parts) == 2:
            item = expr.parts[1]
            if item not in type_value.enum_items:
                self.diagnostics.raise_error(
                    "OPENC-ENUM-ITEM-UNKNOWN-001", Phase.NAME,
                    f"unknown enum item '{expr.qualified}'", expr.span, "name.enum",
                )
            expr.inferred_type = type_value
            expr.constant_value = self.constants.literal(
                LiteralExpr(expr.span, None, None, False, "integer", type_value.enum_items[item], str(type_value.enum_items[item])),
                type_value.fields.get("__base__", self.types.types["u32"]),
            )
            return type_value
        module_name = ".".join(expr.parts[:-1])
        member = expr.parts[-1]
        module = self.modules.modules.get(module_name)
        if module is None:
            module = self.modules.resolve_import(self.current_module, self.current_source_id, module_name)
        if module is not None:
            value = module.exported.get(member)
            if value is None:
                self.diagnostics.raise_error(
                    "OPENC-MODULE-PRIVATE-001", Phase.NAME,
                    f"module '{module.name}' does not export '{member}'", expr.span, "module.visibility",
                )
            if isinstance(value, list):
                expr.inferred_type = SemanticType("overload", expr.qualified)
                return expr.inferred_type
            assert isinstance(value, Symbol) and value.type is not None
            expr.resolved_symbol = value
            expr.inferred_type = value.type
            return value.type
        self.diagnostics.raise_error(
            "OPENC-NAME-UNKNOWN-001", Phase.NAME,
            f"unknown qualified name '{expr.qualified}'", expr.span, "name.lookup",
        )
        raise AssertionError("unreachable")

    def check_unary(self, expr: UnaryExpr) -> SemanticType:
        assert expr.operand is not None and self.flow
        operand_type = self.check_expression(expr.operand)
        if expr.op == "!":
            self.require_exact_bool(operand_type, expr.operand.span)
            expr.inferred_type = self.types.types["bool"]
        elif expr.op in {"+", "-"}:
            if not operand_type.is_numeric():
                self.type_error(expr.span, f"unary '{expr.op}' requires numeric operand")
            expr.inferred_type = operand_type
        elif expr.op == "~":
            if not operand_type.is_integer():
                self.type_error(expr.span, "bitwise complement requires integer operand")
            expr.inferred_type = operand_type
        elif expr.op == "&":
            self.require_unsafe(expr.span, "raw address acquisition")
            if not expr.operand.lvalue:
                self.type_error(expr.span, "address-of operand must identify stable storage")
            expr.inferred_type = SemanticType("ptr", f"ptr {operand_type.display()}", element=operand_type)
        elif expr.op == "*":
            self.require_unsafe(expr.span, "raw pointer dereference")
            if operand_type.kind != "ptr" or operand_type.element is None:
                self.type_error(expr.span, "dereference requires ptr T operand")
            expr.inferred_type = operand_type.element
            expr.lvalue = not operand_type.const
        else:
            self.type_error(expr.span, f"unknown unary operator '{expr.op}'")
        return expr.inferred_type

    def check_binary(self, expr: BinaryExpr) -> SemanticType:
        assert expr.left and expr.right
        if expr.op in {"&&", "||"}:
            left = self.check_expression(expr.left, self.types.types["bool"])
            self.require_exact_bool(left, expr.left.span)
            right = self.check_expression(expr.right, self.types.types["bool"])
            self.require_exact_bool(right, expr.right.span)
            expr.inferred_type = self.types.types["bool"]
            return expr.inferred_type
        left = self.check_expression(expr.left)
        right = self.check_expression(expr.right)
        if expr.op in {"==", "!="}:
            if not self.equality_comparable(left, right):
                self.type_error(expr.span, f"types {left.display()} and {right.display()} are not equality comparable")
            expr.inferred_type = self.types.types["bool"]
        elif expr.op in {"<", "<=", ">", ">="}:
            if not ((left.is_numeric() and right.is_numeric()) or left.kind == right.kind == "enum"):
                self.type_error(expr.span, "relational comparison requires numeric or matching enum operands")
            if self.types.common_numeric_type(left, right) is None and left.kind != "enum":
                self.type_error(expr.span, "relational operands have no lossless common type")
            expr.inferred_type = self.types.types["bool"]
        elif expr.op in {"+", "-", "*", "/", "%", "&", "|", "^", "<<", ">>"}:
            if left.kind == "ptr" and expr.op in {"+", "-"} and right.is_integer():
                self.require_unsafe(expr.span, "raw pointer arithmetic")
                expr.inferred_type = left
            else:
                if expr.op in {"&", "|", "^", "<<", ">>"} and (not left.is_integer() or not right.is_integer()):
                    self.type_error(expr.span, f"operator '{expr.op}' requires integer operands")
                common = self.types.common_numeric_type(left, right)
                if common is None:
                    self.type_error(expr.span, f"operator '{expr.op}' operands have no lossless common type")
                expr.inferred_type = common
        else:
            self.type_error(expr.span, f"unknown binary operator '{expr.op}'")
        return expr.inferred_type

    def check_assign(self, expr: AssignExpr) -> SemanticType:
        assert expr.target and expr.value and self.flow
        target_type = self.check_expression(expr.target)
        if not expr.target.lvalue:
            self.type_error(expr.target.span, "assignment target is not assignable")
        target_name = self.extract_owner_name(expr.target)
        if target_name:
            binding = self.flow.get(target_name, self.diagnostics, expr.target.span)
            if not binding.mutable:
                self.diagnostics.raise_error(
                    "OPENC-CONST-ASSIGN-001", Phase.FLOW,
                    f"cannot assign to const binding '{target_name}'", expr.target.span, "flow.mutability",
                )
            if binding.init == InitState.CONDITIONAL:
                self.diagnostics.raise_error(
                    "OPENC-OUT-OVERWRITE-001", Phase.FLOW,
                    f"cannot overwrite unresolved out binding '{target_name}'", expr.target.span, "flow.status_out",
                )
            if target_type.kind == "status" and binding.lineage is not None:
                self.flow.lose_status_name(target_name, self.diagnostics, expr.target.span)
        value_type = self.check_expression(expr.value, expected=target_type)
        if expr.op != "=":
            if not target_type.is_numeric() and expr.op not in {"&=", "|=", "^="}:
                self.type_error(expr.span, f"compound assignment '{expr.op}' requires numeric target")
        self.require_conversion(value_type, target_type, expr.value.span)
        if target_name:
            binding = self.flow.bindings[target_name]
            if target_type.resource:
                source_name = self.extract_owner_name(expr.value)
                if source_name:
                    self.ownership.move(self.flow, source_name, expr.value.span)
                binding.owner = OwnerState.LIVE
            binding.init = InitState.INITIALIZED
            binding.lineage = None
            if target_type.kind == "optional":
                binding.presence = PresenceState.ABSENT if isinstance(expr.value, LiteralExpr) and expr.value.literal_kind == "none" else PresenceState.PRESENT
        expr.inferred_type = target_type
        return target_type

    def resolve_call(self, expr: CallExpr, scope_context: bool = False) -> FunctionSignature:
        assert expr.callee is not None and self.current_module and self.current_scope and self.flow
        candidates = self.lookup_function_candidates(expr.callee)
        matches: list[tuple[int, FunctionSignature]] = []
        for signature in candidates:
            if len(signature.params) != len(expr.args):
                continue
            score = 0
            valid = True
            for arg, (param, param_type) in zip(expr.args, signature.params):
                if param.mode in {"out", "out_own"}:
                    if arg.mode != "out" or not isinstance(arg.value, NameExpr) or len(arg.value.parts) != 1:
                        valid = False; break
                    binding = self.flow.bindings.get(arg.value.parts[0])
                    if binding is None or binding.init not in {InitState.UNINITIALIZED, InitState.MOVED, InitState.DESTROYED}:
                        valid = False; break
                    if not self.types.same(binding.type, param_type, ignore_const=False):
                        valid = False; break
                    continue
                if arg.mode == "out":
                    valid = False; break
                assert arg.value is not None
                arg_type = self.check_expression(arg.value, expected=param_type)
                if param.mode == "own":
                    source_name = self.extract_owner_name(arg.value)
                    if source_name is None or not (arg_type.resource or arg_type.kind == "ptr"):
                        valid = False; break
                elif param_type.kind == "ref":
                    if not arg.value.lvalue:
                        valid = False; break
                    if not self.types.same(arg_type, param_type.element, ignore_const=True):
                        valid = False; break
                elif self.types.same(arg_type, param_type):
                    score += 0
                elif self.types.can_losslessly_convert(arg_type, param_type):
                    score += 1
                else:
                    valid = False; break
            if valid:
                matches.append((score, signature))
        if not matches:
            self.diagnostics.raise_error(
                "OPENC-CALL-NO-MATCH-001", Phase.TYPE,
                f"no overload of '{self.call_name(expr)}' matches the provided arguments",
                expr.span, "type.overload",
            )
        matches.sort(key=lambda item: item[0])
        if len(matches) > 1 and matches[0][0] == matches[1][0]:
            self.diagnostics.raise_error(
                "OPENC-CALL-AMBIGUOUS-001", Phase.TYPE,
                f"call to '{self.call_name(expr)}' is ambiguous", expr.span, "type.overload",
            )
        signature = matches[0][1]
        expr.resolved_function = signature.declaration
        # Apply ownership/borrow/output effects after selection.
        for arg, (param, param_type) in zip(expr.args, signature.params):
            assert arg.value is not None
            name = self.extract_owner_name(arg.value)
            if param.mode == "own" and name:
                if scope_context:
                    continue
                self.ownership.move(self.flow, name, arg.value.span)
            elif param_type.kind == "ref" and name:
                record = self.ownership.begin_borrow(self.flow, name, not param_type.const, arg.value.span)
                self.ownership.end_borrow(self.flow, record)
        return signature

    def lookup_function_candidates(self, callee: Expr) -> list[FunctionSignature]:
        assert self.current_module and self.current_scope
        symbols: list[Symbol] = []
        if isinstance(callee, NameExpr):
            if len(callee.parts) == 1:
                value = self.current_scope.lookup(callee.parts[0])
                if isinstance(value, list):
                    symbols.extend(value)
                elif isinstance(value, Symbol) and value.kind == "function":
                    symbols.append(value)
            else:
                module_name = ".".join(callee.parts[:-1])
                member = callee.parts[-1]
                module = self.modules.modules.get(module_name) or self.modules.resolve_import(self.current_module, self.current_source_id, module_name)
                if module:
                    value = module.exported.get(member)
                    if isinstance(value, list): symbols.extend(value)
                    elif isinstance(value, Symbol) and value.kind == "function": symbols.append(value)
        elif isinstance(callee, MemberExpr):
            # Module short qualifier calls parse as MemberExpr after the parser's postfix
            # path. Convert the base name plus member into module lookup.
            if isinstance(callee.base, NameExpr):
                module = self.modules.resolve_import(self.current_module, self.current_source_id, callee.base.qualified)
                if module:
                    value = module.exported.get(callee.member)
                    if isinstance(value, list): symbols.extend(value)
                    elif isinstance(value, Symbol) and value.kind == "function": symbols.append(value)
        return [self.signatures[id(symbol.declaration)] for symbol in symbols if isinstance(symbol.declaration, FunctionDecl)]

    def prepare_out_call(self, expr: CallExpr) -> tuple[list[str], list[str]]:
        signature = self.resolve_call(expr)
        outputs: list[str] = []
        owning: list[str] = []
        for arg, (param, _) in zip(expr.args, signature.params):
            if param.mode in {"out", "out_own"}:
                assert isinstance(arg.value, NameExpr) and len(arg.value.parts) == 1
                name = arg.value.parts[0]
                outputs.append(name)
                if param.mode == "out_own" or self.flow.bindings[name].type.resource:
                    owning.append(name)
        return outputs, owning

    def check_member(self, expr: MemberExpr) -> SemanticType:
        assert expr.base is not None and self.flow
        base_type = self.check_expression(expr.base)
        if base_type.kind == "ref" and base_type.element:
            base_type = base_type.element
        if base_type.kind == "status":
            if expr.member == "ok":
                expr.inferred_type = self.types.types["bool"]
                return expr.inferred_type
            if expr.member == "code":
                expr.inferred_type = self.types.types["i32"]
                expr.lvalue = False
                return expr.inferred_type
            if expr.member == "message":
                expr.inferred_type = self.types.types["text"]
                return expr.inferred_type
        if base_type.kind == "optional":
            if expr.member == "present":
                expr.inferred_type = self.types.types["bool"]
                return expr.inferred_type
            if expr.member == "value":
                binding_name = self.extract_owner_name(expr.base)
                if binding_name:
                    binding = self.flow.get(binding_name, self.diagnostics, expr.span)
                    if binding.presence != PresenceState.PRESENT:
                        self.diagnostics.raise_error(
                            "OPENC-OPTIONAL-VALUE-001", Phase.FLOW,
                            f"optional '{binding_name}' is not proven present", expr.span, "flow.optional",
                        )
                assert base_type.element is not None
                expr.inferred_type = self.types.with_const(base_type.element, base_type.const)
                expr.lvalue = bool(expr.base.lvalue) and not base_type.const
                return expr.inferred_type
        if base_type.kind in {"array", "slice", "text"} and expr.member == "length":
            expr.inferred_type = self.types.types["usize"]
            return expr.inferred_type
        field_type = base_type.fields.get(expr.member)
        if field_type is None:
            self.diagnostics.raise_error(
                "OPENC-STRUCT-FIELD-UNKNOWN-001", Phase.TYPE,
                f"type {base_type.display()} has no field '{expr.member}'", expr.span, "type.member",
            )
        assert field_type is not None
        expr.inferred_type = self.types.with_const(field_type, base_type.const)
        expr.lvalue = bool(expr.base.lvalue) and not base_type.const
        return expr.inferred_type

    def check_index(self, expr: IndexExpr) -> SemanticType:
        assert expr.base and expr.index
        base_type = self.check_expression(expr.base)
        index_type = self.check_expression(expr.index, self.types.types["usize"])
        if not index_type.is_integer():
            self.type_error(expr.index.span, "index must have integer type")
        if base_type.kind not in {"array", "slice"} or base_type.element is None:
            self.type_error(expr.base.span, "indexing requires array or slice; text has no direct numeric indexing")
        if expr.index.constant_value is not None and base_type.length is not None:
            index = int(expr.index.constant_value.value)
            if not 0 <= index < base_type.length:
                self.diagnostics.raise_error(
                    "OPENC-ARRAY-BOUNDS-001", Phase.FLOW,
                    f"constant index {index} is outside [0, {base_type.length})", expr.index.span, "flow.bounds",
                )
        expr.inferred_type = base_type.element
        expr.lvalue = expr.base.lvalue and not base_type.const
        return expr.inferred_type

    def check_range(self, expr: RangeExpr) -> SemanticType:
        assert expr.base
        base_type = self.check_expression(expr.base)
        if base_type.kind not in {"array", "slice", "text"}:
            self.type_error(expr.base.span, "range requires array, slice, or text")
        if expr.start:
            start_type = self.check_expression(expr.start, self.types.types["usize"])
            if not start_type.is_integer(): self.type_error(expr.start.span, "range start must be integer")
        if expr.end:
            end_type = self.check_expression(expr.end, self.types.types["usize"])
            if not end_type.is_integer(): self.type_error(expr.end.span, "range end must be integer")
        if base_type.kind == "text":
            expr.inferred_type = self.types.types["text"]
        else:
            expr.inferred_type = SemanticType("slice", f"{base_type.element.display()}[]", element=base_type.element, const=base_type.const)
        return expr.inferred_type

    def check_aggregate(self, expr: AggregateExpr, expected: SemanticType | None) -> SemanticType:
        assert self.current_module and self.flow
        target = self.types.lookup(expr.type_name) or self.types.lookup(f"{self.current_module.name}.{expr.type_name}")
        if target is None or target.kind not in {"struct", "resource"}:
            self.type_error(expr.span, f"'{expr.type_name}' is not an aggregate type")
        assert target is not None
        seen: set[str] = set()
        reserved_owners: list[str] = []
        for field in expr.fields:
            if field.name in seen:
                self.diagnostics.raise_error(
                    "OPENC-STRUCT-INIT-DUPLICATE-001", Phase.TYPE,
                    f"duplicate initializer field '{field.name}'", field.span, "type.aggregate",
                )
            seen.add(field.name)
            field_type = target.fields.get(field.name)
            if field_type is None:
                self.diagnostics.raise_error(
                    "OPENC-STRUCT-INIT-UNKNOWN-001", Phase.TYPE,
                    f"unknown field '{field.name}' in {target.display()}", field.span, "type.aggregate",
                )
            assert field.value is not None and field_type is not None
            value_type = self.check_expression(field.value, expected=field_type)
            self.require_conversion(value_type, field_type, field.value.span)
            if field.ownership:
                if not target.resource:
                    self.diagnostics.raise_error(
                        "OPENC-STRUCT-OWNERSHIP-FIELD-001", Phase.OWNERSHIP,
                        "ordinary struct initializer cannot transfer ownership", field.span, "ownership.aggregate",
                    )
                source_name = self.extract_owner_name(field.value)
                if source_name is None:
                    self.diagnostics.raise_error(
                        "OPENC-RESOURCE-INIT-OWNER-001", Phase.OWNERSHIP,
                        "ownership field initializer requires stable owner source", field.span, "ownership.aggregate",
                    )
                reserved_owners.append(source_name)
            elif target.resource and field_type.resource:
                self.diagnostics.raise_error(
                    "OPENC-RESOURCE-INIT-OWNER-001", Phase.OWNERSHIP,
                    f"resource field '{field.name}' requires explicit ownership transfer", field.span, "ownership.aggregate",
                )
        missing = set(target.fields) - seen
        if missing:
            self.diagnostics.raise_error(
                "OPENC-STRUCT-INIT-MISSING-001", Phase.TYPE,
                f"missing initializer field(s): {', '.join(sorted(missing))}", expr.span, "type.aggregate",
            )
        if len(reserved_owners) != len(set(reserved_owners)):
            self.diagnostics.raise_error(
                "OPENC-RESOURCE-INIT-DUPLICATE-OWNER-001", Phase.OWNERSHIP,
                "one ownership source cannot initialize more than one field", expr.span, "ownership.aggregate",
            )
        for name in reserved_owners:
            self.ownership.move(self.flow, name, expr.span)
        expr.inferred_type = target
        return target

    def check_array(self, expr: ArrayExpr, expected: SemanticType | None) -> SemanticType:
        if expected is not None and expected.kind == "array" and expected.element:
            element_type = expected.element
        elif expr.values:
            element_type = self.check_expression(expr.values[0])
        else:
            self.type_error(expr.span, "empty array initializer requires expected fixed-array type")
        assert element_type is not None
        for value in expr.values:
            actual = self.check_expression(value, expected=element_type)
            self.require_conversion(actual, element_type, value.span)
        if expected is not None and expected.kind == "array":
            if expected.length is not None and len(expr.values) != expected.length:
                self.diagnostics.raise_error(
                    "OPENC-ARRAY-INIT-COUNT-001", Phase.TYPE,
                    f"array initializer has {len(expr.values)} elements; expected {expected.length}",
                    expr.span, "type.array",
                )
            result = expected
        else:
            result = SemanticType("array", f"{element_type.display()}[{len(expr.values)}]", element=element_type, length=len(expr.values))
        expr.inferred_type = result
        return result

    def check_status(self, expr: StatusExpr) -> SemanticType:
        assert expr.code
        code_type = self.check_expression(expr.code, self.types.types["i32"])
        self.require_conversion(code_type, self.types.types["i32"], expr.code.span)
        if expr.message:
            message_type = self.check_expression(expr.message, self.types.types["text"])
            self.require_conversion(message_type, self.types.types["text"], expr.message.span)
        expr.inferred_type = self.types.types["status"]
        return expr.inferred_type

    def check_construct(self, expr: ConstructExpr) -> SemanticType:
        assert expr.storage and expr.value and self.current_module
        target = self.types.lookup(expr.type_name) or self.types.lookup(f"{self.current_module.name}.{expr.type_name}")
        if target is None:
            self.type_error(expr.span, f"unknown constructed type '{expr.type_name}'")
        storage_type = self.check_expression(expr.storage)
        if storage_type.kind != "storage" or storage_type.element is None or not self.types.same(storage_type.element, target):
            self.type_error(expr.storage.span, f"construct requires storage {target.display()}")
        value_type = self.check_expression(expr.value, expected=target)
        self.require_conversion(value_type, target, expr.value.span)
        expr.inferred_type = SemanticType("ref", f"ref {target.display()}", element=target)
        return expr.inferred_type

    def check_destroy(self, expr: DestroyExpr) -> SemanticType:
        assert expr.value and self.flow
        value_type = self.check_expression(expr.value)
        name = self.extract_owner_name(expr.value)
        if value_type.kind == "ref" and value_type.element and value_type.element.kind != "resource":
            # destroy(ref T) ends a typed-storage lifetime and returns storage to uninitialized state.
            expr.inferred_type = self.types.types["void"]
            return expr.inferred_type
        if name is None:
            self.diagnostics.raise_error(
                "OPENC-OWN-STABLE-SINK-001", Phase.OWNERSHIP,
                "destroy requires a stable owner binding", expr.span, "ownership.destroy",
            )
        assert name is not None
        self.ownership.move(self.flow, name, expr.span)
        expr.inferred_type = self.types.types["void"]
        return expr.inferred_type

    def check_cast(self, kind: str, source: SemanticType, target: SemanticType, span: Span) -> None:
        if kind == "checked":
            if source.kind not in {"integer", "float", "enum"} or target.kind not in {"integer", "float", "enum"}:
                self.type_error(span, "checked cast supports numeric and enum values only")
        elif kind == "unchecked":
            self.require_unsafe(span, "unchecked cast")
            if source.kind not in {"integer", "float", "enum", "ptr"} or target.kind not in {"integer", "float", "enum", "ptr"}:
                self.type_error(span, "unchecked cast does not support this type pair")
        elif kind == "reinterpret":
            self.require_unsafe(span, "representation reinterpretation")
            allowed = {"integer", "float"}
            if source.kind not in allowed or target.kind not in allowed or self.types.size_of(source) != self.types.size_of(target):
                self.type_error(span, "reinterpret requires equal-size fixed numeric representations")

    def refine_condition(self, expr: Expr, state: FlowState, truth: bool) -> None:
        if isinstance(expr, UnaryExpr) and expr.op == "!" and expr.operand:
            self.refine_condition(expr.operand, state, not truth)
            return
        if isinstance(expr, BinaryExpr) and expr.left and expr.right:
            if expr.op == "&&":
                if truth:
                    self.refine_condition(expr.left, state, True)
                    self.refine_condition(expr.right, state, True)
                return
            if expr.op == "||":
                if not truth:
                    self.refine_condition(expr.left, state, False)
                    self.refine_condition(expr.right, state, False)
                return
            proof = self.status_proof(expr)
            if proof:
                lineage, success_on_true = proof
                state.resolve_lineage(lineage, "success" if truth == success_on_true else "failure")
                return
            optional = self.optional_proof(expr)
            if optional:
                name, present_on_true = optional
                binding = state.bindings.get(name)
                if binding:
                    binding.presence = PresenceState.PRESENT if truth == present_on_true else PresenceState.ABSENT
                return
        if isinstance(expr, MemberExpr) and expr.member == "ok":
            name = self.extract_owner_name(expr.base)
            if name and name in state.bindings:
                lineage = state.bindings[name].lineage
                if lineage:
                    state.resolve_lineage(lineage, "success" if truth else "failure")
        if isinstance(expr, MemberExpr) and expr.member == "present":
            name = self.extract_owner_name(expr.base)
            if name and name in state.bindings:
                state.bindings[name].presence = PresenceState.PRESENT if truth else PresenceState.ABSENT

    def status_proof(self, expr: BinaryExpr) -> tuple[int, bool] | None:
        assert self.flow and expr.left and expr.right
        def status_member(value: Expr):
            if isinstance(value, MemberExpr) and value.member in {"ok", "code"}:
                name = self.extract_owner_name(value.base)
                if name and name in self.flow.bindings:
                    return name, value.member
            return None
        left_member = status_member(expr.left)
        right_member = status_member(expr.right)
        literal = expr.right if left_member else expr.left if right_member else None
        member = left_member or right_member
        if not member or not isinstance(literal, LiteralExpr):
            return None
        name, field = member
        lineage = self.flow.bindings[name].lineage
        if lineage is None:
            return None
        if field == "ok" and literal.literal_kind == "bool" and expr.op in {"==", "!="}:
            expected = bool(literal.value)
            success_on_true = expected if expr.op == "==" else not expected
            return lineage, success_on_true
        if field == "code" and literal.literal_kind == "integer" and expr.op in {"==", "!="}:
            is_zero = int(literal.value) == 0
            success_on_true = is_zero if expr.op == "==" else not is_zero
            return lineage, success_on_true
        return None

    def optional_proof(self, expr: BinaryExpr) -> tuple[str, bool] | None:
        if expr.op not in {"==", "!="}:
            return None
        pair = [(expr.left, expr.right), (expr.right, expr.left)]
        for maybe_member, literal in pair:
            if isinstance(maybe_member, MemberExpr) and maybe_member.member == "present" and isinstance(literal, LiteralExpr) and literal.literal_kind == "bool":
                name = self.extract_owner_name(maybe_member.base)
                if name:
                    expected = bool(literal.value)
                    return name, expected if expr.op == "==" else not expected
        return None

    def refine_switch_case(self, subject: Expr, case_value: Expr, state: FlowState) -> None:
        # status.code switch cases prove failure for nonzero codes and success for zero.
        if isinstance(subject, MemberExpr) and subject.member == "code":
            name = self.extract_owner_name(subject.base)
            if name and name in state.bindings:
                lineage = state.bindings[name].lineage
                if lineage and case_value.constant_value is not None:
                    state.resolve_lineage(lineage, "success" if int(case_value.constant_value.value) == 0 else "failure")

    def resolve_type_syntax(self, syntax, module_name: str) -> SemanticType:
        if syntax is None:
            return self.types.types["void"]
        # Try current-module qualification for named user types before generic resolution.
        if syntax.constructor == "named" and syntax.name and syntax.name not in self.types.types:
            qualified = f"{module_name}.{syntax.name}"
            if qualified in self.types.types:
                syntax.name = qualified
        if syntax.inner is not None and syntax.inner.constructor == "named" and syntax.inner.name and syntax.inner.name not in self.types.types:
            qualified = f"{module_name}.{syntax.inner.name}"
            if qualified in self.types.types:
                syntax.inner.name = qualified
        if syntax.length is not None:
            length = self.constants.evaluate(syntax.length, self.types.types["usize"])
            syntax.length.constant_value = length
            if int(length.value) <= 0:
                self.diagnostics.raise_error(
                    "OPENC-ARRAY-LENGTH-001", Phase.CONSTANT,
                    "fixed array length must be positive", syntax.length.span, "constant.array",
                )
        value = self.types.resolve(syntax)
        self.validate_constructed_type(value, syntax.span)
        return value

    def validate_constructed_type(self, value: SemanticType, span: Span) -> None:
        if value.kind == "optional" and value.element:
            if value.element.kind in {"ref", "ptr", "slice", "storage", "optional"} or value.element.resource:
                self.diagnostics.raise_error(
                    "OPENC-OPTIONAL-TARGET-001", Phase.TYPE,
                    f"optional cannot contain {value.element.display()}", span, "type.optional",
                )
        if value.kind == "storage" and value.element:
            if value.element.kind in {"ref", "ptr", "optional", "slice", "text"} or value.element.resource:
                self.diagnostics.raise_error(
                    "OPENC-STORAGE-TARGET-001", Phase.TYPE,
                    f"storage cannot target {value.element.display()}", span, "type.storage",
                )
        if value.kind == "array" and value.element and value.element.kind in {"ref", "slice", "storage"}:
            self.diagnostics.raise_error(
                "OPENC-ARRAY-ELEMENT-TYPE-001", Phase.TYPE,
                f"array cannot contain {value.element.display()}", span, "type.array",
            )

    def require_conversion(self, source: SemanticType, target: SemanticType, span: Span) -> None:
        if not self.types.can_losslessly_convert(source, target):
            self.diagnostics.raise_error(
                "OPENC-CONV-LOSSY-001", Phase.TYPE,
                f"implicit conversion from {source.display()} to {target.display()} is not lossless",
                span, "type.conversion",
            )

    def require_exact_bool(self, value_type: SemanticType, span: Span) -> None:
        if value_type.kind != "bool":
            self.diagnostics.raise_error(
                "OPENC-COND-BOOL-001", Phase.TYPE,
                f"condition must have type bool, not {value_type.display()}", span, "type.condition",
            )

    def require_unsafe(self, span: Span, operation: str) -> None:
        assert self.flow
        if self.flow.unsafe_depth <= 0 and not (self.current_function and self.current_function.declaration.unsafe):
            self.diagnostics.raise_error(
                "OPENC-UNSAFE-REGION-001", Phase.UNSAFE,
                f"{operation} requires an unsafe region", span, "unsafe.boundary",
            )

    def equality_comparable(self, left: SemanticType, right: SemanticType) -> bool:
        if self.types.same(left, right):
            if left.resource or left.kind in {"ref", "storage", "slice"}:
                return False
            if left.kind in {"struct", "optional", "array"}:
                if left.kind == "optional" and left.element:
                    return self.equality_comparable(left.element, left.element)
                if left.kind == "array" and left.element:
                    return self.equality_comparable(left.element, left.element)
                return all(self.equality_comparable(value, value) for value in left.fields.values())
            return True
        return self.types.can_losslessly_convert(left, right) or self.types.can_losslessly_convert(right, left)

    @staticmethod
    def extract_owner_name(expr: Expr | None) -> str | None:
        if isinstance(expr, NameExpr) and len(expr.parts) == 1:
            return expr.parts[0]
        if isinstance(expr, MemberExpr):
            root = SemanticAnalyzer.extract_owner_name(expr.base)
            return f"{root}.{expr.member}" if root else None
        return None

    @staticmethod
    def call_name(expr: CallExpr) -> str:
        if isinstance(expr.callee, NameExpr):
            return expr.callee.qualified
        if isinstance(expr.callee, MemberExpr):
            base = SemanticAnalyzer.extract_owner_name(expr.callee.base) or "<expr>"
            return f"{base}.{expr.callee.member}"
        return "<call>"

    def type_error(self, span: Span, message: str) -> None:
        self.diagnostics.raise_error(
            "OPENC-TYPE-MISMATCH-001", Phase.TYPE, message, span, "type.mismatch",
        )


def flow_equivalent(left: FlowState, right: FlowState) -> bool:
    if left.reachable != right.reachable or set(left.bindings) != set(right.bindings):
        return False
    for name in left.bindings:
        a = left.bindings[name]; b = right.bindings[name]
        if (a.init, a.presence, a.owner, a.lineage, a.cleanup_action) != (b.init, b.presence, b.owner, b.lineage, b.cleanup_action):
            return False
    return True
