"""Core data model for the authored OpenC 1.0 bootstrap compiler.

This module intentionally uses only the Python standard library.  It contains
source spans, diagnostics, tokens, syntax-tree nodes, semantic types, symbols,
and target-independent IR records shared by the compiler and first-party tools.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass, field, fields, is_dataclass
from enum import Enum
from typing import Any, Iterable, Iterator, Mapping, Sequence


@dataclass(frozen=True, slots=True)
class Position:
    offset: int
    line: int
    column: int


@dataclass(frozen=True, slots=True)
class Span:
    source_id: str
    start: Position
    end: Position

    @staticmethod
    def synthetic(source_id: str = "<generated>") -> "Span":
        p = Position(0, 1, 1)
        return Span(source_id, p, p)

    def merge(self, other: "Span") -> "Span":
        if self.source_id != other.source_id:
            return self
        start = self.start if self.start.offset <= other.start.offset else other.start
        end = self.end if self.end.offset >= other.end.offset else other.end
        return Span(self.source_id, start, end)

    def to_json(self) -> dict[str, Any]:
        return {
            "source": self.source_id,
            "start": asdict(self.start),
            "end": asdict(self.end),
        }


class Severity(str, Enum):
    ERROR = "error"
    WARNING = "warning"
    NOTE = "note"
    HELP = "help"


class Phase(str, Enum):
    SOURCE = "source"
    LEXICAL = "lexical"
    SYNTAX = "syntax"
    DECLARATION = "declaration"
    NAME = "name"
    TYPE = "type"
    CONSTANT = "constant"
    FLOW = "flow"
    OWNERSHIP = "ownership"
    BORROW = "borrow"
    UNSAFE = "unsafe"
    TARGET = "target"
    RUNTIME = "runtime"
    TOOL = "tool"


@dataclass(slots=True)
class RelatedDiagnostic:
    message: str
    span: Span | None = None
    severity: Severity = Severity.NOTE

    def to_json(self) -> dict[str, Any]:
        result: dict[str, Any] = {"severity": self.severity.value, "message": self.message}
        if self.span is not None:
            result["span"] = self.span.to_json()
        return result


@dataclass(slots=True)
class Diagnostic:
    rule_id: str
    phase: Phase
    severity: Severity
    message: str
    span: Span | None = None
    category: str = ""
    related: list[RelatedDiagnostic] = field(default_factory=list)
    help: list[str] = field(default_factory=list)

    def to_json(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "rule_id": self.rule_id,
            "phase": self.phase.value,
            "severity": self.severity.value,
            "message": self.message,
            "category": self.category,
            "related": [item.to_json() for item in self.related],
            "help": list(self.help),
        }
        if self.span is not None:
            result["span"] = self.span.to_json()
        return result


class OpenCError(Exception):
    """Exception carrying one structured compiler diagnostic."""

    def __init__(self, diagnostic: Diagnostic):
        super().__init__(diagnostic.message)
        self.diagnostic = diagnostic


class TokenKind(str, Enum):
    IDENTIFIER = "identifier"
    INTEGER = "integer"
    FLOAT = "float"
    TEXT = "text"
    SYMBOL = "symbol"
    EOF = "eof"


@dataclass(frozen=True, slots=True)
class Token:
    kind: TokenKind
    text: str
    span: Span
    value: Any = None

    def is_text(self, text: str) -> bool:
        return self.text == text


@dataclass(slots=True)
class Node:
    span: Span

    def children(self) -> Iterable["Node"]:
        for item in fields(self):
            if item.name == "span":
                continue
            value = getattr(self, item.name)
            if isinstance(value, Node):
                yield value
            elif isinstance(value, list):
                for entry in value:
                    if isinstance(entry, Node):
                        yield entry


@dataclass(slots=True)
class TypeSyntax(Node):
    constructor: str
    name: str | None = None
    inner: "TypeSyntax | None" = None
    const: bool = False
    length: "Expr | None" = None

    def display(self) -> str:
        if self.constructor == "named":
            prefix = "const " if self.const else ""
            return prefix + (self.name or "<missing>")
        if self.constructor == "array":
            assert self.inner is not None
            return f"{self.inner.display()}[{expr_display(self.length)}]"
        if self.constructor == "slice":
            assert self.inner is not None
            return f"{self.inner.display()}[]"
        if self.constructor in {"ref", "ptr"}:
            assert self.inner is not None
            qualifier = "const " if self.const else ""
            return f"{self.constructor} {qualifier}{self.inner.display()}"
        if self.constructor in {"optional", "storage"}:
            assert self.inner is not None
            prefix = "const " if self.const else ""
            return f"{prefix}{self.constructor} {self.inner.display()}"
        return self.constructor


@dataclass(slots=True)
class SourceUnit(Node):
    imports: list["ImportDecl"]
    declarations: list["Decl"]
    module_name: str | None = None


@dataclass(slots=True)
class ImportDecl(Node):
    module: str


@dataclass(slots=True)
class Decl(Node):
    name: str
    exported: bool = False


@dataclass(slots=True)
class FieldDecl(Node):
    name: str
    type_syntax: TypeSyntax
    default: "Expr | None" = None
    ownership: bool = False


@dataclass(slots=True)
class StructDecl(Decl):
    fields: list[FieldDecl] = field(default_factory=list)
    resource: bool = False
    layout: str | None = None


@dataclass(slots=True)
class EnumItem(Node):
    name: str
    value: "Expr | None" = None


@dataclass(slots=True)
class EnumDecl(Decl):
    base_type: TypeSyntax | None = None
    items: list[EnumItem] = field(default_factory=list)


@dataclass(slots=True)
class ParamDecl(Node):
    name: str
    type_syntax: TypeSyntax
    mode: str = "ordinary"  # ordinary | own | out | out_own


@dataclass(slots=True)
class FunctionDecl(Decl):
    result_type: TypeSyntax | None = None
    result_mode: str = "ordinary"  # ordinary | own | void
    params: list[ParamDecl] = field(default_factory=list)
    body: "BlockStmt | None" = None
    unsafe: bool = False
    external_abi: str | None = None
    external_symbol: str | None = None


@dataclass(slots=True)
class ConstDecl(Decl):
    type_syntax: TypeSyntax | None = None
    value: "Expr | None" = None


@dataclass(slots=True)
class WhenDecl(Decl):
    condition: "Expr | None" = None
    declarations: list[Decl] = field(default_factory=list)


@dataclass(slots=True)
class Stmt(Node):
    pass


@dataclass(slots=True)
class BlockStmt(Stmt):
    items: list["Stmt | LocalDecl"] = field(default_factory=list)


@dataclass(slots=True)
class LocalDecl(Node):
    name: str
    type_syntax: TypeSyntax
    initializer: "Expr | None" = None


@dataclass(slots=True)
class ExprStmt(Stmt):
    expr: "Expr | None" = None


@dataclass(slots=True)
class IfStmt(Stmt):
    condition: "Expr | None" = None
    then_branch: BlockStmt | None = None
    else_branch: BlockStmt | "IfStmt | None" = None


@dataclass(slots=True)
class WhileStmt(Stmt):
    condition: "Expr | None" = None
    body: BlockStmt | None = None


@dataclass(slots=True)
class ForStmt(Stmt):
    initializer: LocalDecl | "Expr | None" = None
    condition: "Expr | None" = None
    update: "Expr | None" = None
    body: BlockStmt | None = None


@dataclass(slots=True)
class SwitchCase(Node):
    value: "Expr | None" = None
    body: BlockStmt | None = None
    is_default: bool = False


@dataclass(slots=True)
class SwitchStmt(Stmt):
    value: "Expr | None" = None
    cases: list[SwitchCase] = field(default_factory=list)


@dataclass(slots=True)
class BreakStmt(Stmt):
    pass


@dataclass(slots=True)
class ContinueStmt(Stmt):
    pass


@dataclass(slots=True)
class ReturnStmt(Stmt):
    value: "Expr | None" = None


@dataclass(slots=True)
class ScopeStmt(Stmt):
    action: "Expr | None" = None


@dataclass(slots=True)
class UnsafeStmt(Stmt):
    body: BlockStmt | None = None


@dataclass(slots=True)
class WhenStmt(Stmt):
    condition: "Expr | None" = None
    body: BlockStmt | None = None


@dataclass(slots=True)
class Expr(Node):
    inferred_type: "SemanticType | None" = field(default=None, repr=False)
    constant_value: "ConstValue | None" = field(default=None, repr=False)
    lvalue: bool = field(default=False, repr=False)


@dataclass(slots=True)
class LiteralExpr(Expr):
    literal_kind: str = ""
    value: Any = None
    raw: str = ""


@dataclass(slots=True)
class NameExpr(Expr):
    parts: list[str] = field(default_factory=list)
    resolved_symbol: "Symbol | None" = field(default=None, repr=False)

    @property
    def qualified(self) -> str:
        return ".".join(self.parts)


@dataclass(slots=True)
class UnaryExpr(Expr):
    op: str = ""
    operand: Expr | None = None


@dataclass(slots=True)
class BinaryExpr(Expr):
    op: str = ""
    left: Expr | None = None
    right: Expr | None = None


@dataclass(slots=True)
class AssignExpr(Expr):
    op: str = "="
    target: Expr | None = None
    value: Expr | None = None


@dataclass(slots=True)
class CallArg(Node):
    value: Expr | None = None
    mode: str = "ordinary"  # ordinary | out


@dataclass(slots=True)
class CallExpr(Expr):
    callee: Expr | None = None
    args: list[CallArg] = field(default_factory=list)
    resolved_function: FunctionDecl | None = field(default=None, repr=False)


@dataclass(slots=True)
class MemberExpr(Expr):
    base: Expr | None = None
    member: str = ""


@dataclass(slots=True)
class IndexExpr(Expr):
    base: Expr | None = None
    index: Expr | None = None


@dataclass(slots=True)
class RangeExpr(Expr):
    base: Expr | None = None
    start: Expr | None = None
    end: Expr | None = None


@dataclass(slots=True)
class CastExpr(Expr):
    cast_kind: str = "checked"  # checked | unchecked | reinterpret
    target_type: TypeSyntax | None = None
    value: Expr | None = None


@dataclass(slots=True)
class ConstructExpr(Expr):
    type_name: str = ""
    storage: Expr | None = None
    value: Expr | None = None


@dataclass(slots=True)
class DestroyExpr(Expr):
    value: Expr | None = None


@dataclass(slots=True)
class TypeQueryExpr(Expr):
    query: str = "size_of"
    type_syntax: TypeSyntax | None = None


@dataclass(slots=True)
class FieldInit(Node):
    name: str
    value: Expr | None = None
    ownership: bool = False


@dataclass(slots=True)
class AggregateExpr(Expr):
    type_name: str = ""
    fields: list[FieldInit] = field(default_factory=list)


@dataclass(slots=True)
class ArrayExpr(Expr):
    values: list[Expr] = field(default_factory=list)


@dataclass(slots=True)
class StatusExpr(Expr):
    code: Expr | None = None
    message: Expr | None = None


@dataclass(slots=True)
class SemanticType:
    kind: str
    name: str
    const: bool = False
    element: "SemanticType | None" = None
    length: int | None = None
    fields: dict[str, "SemanticType"] = field(default_factory=dict)
    resource: bool = False
    enum_items: dict[str, int] = field(default_factory=dict)

    def display(self) -> str:
        if self.kind == "array":
            return f"{self.element.display()}[{self.length}]" if self.element else "<?>[]"
        if self.kind == "slice":
            return f"{self.element.display()}[]" if self.element else "<?>[]"
        if self.kind in {"ref", "ptr", "optional", "storage"}:
            qualifier = "const " if self.const and self.kind in {"ref", "ptr"} else ""
            inner = self.element.display() if self.element else "<?>"
            prefix = "const " if self.const and self.kind == "optional" else ""
            return f"{prefix}{self.kind} {qualifier}{inner}"
        return ("const " if self.const else "") + self.name

    def key(self) -> tuple[Any, ...]:
        return (
            self.kind,
            self.name,
            self.const,
            self.element.key() if self.element else None,
            self.length,
            self.resource,
        )

    def is_integer(self) -> bool:
        return self.kind == "integer"

    def is_float(self) -> bool:
        return self.kind == "float"

    def is_numeric(self) -> bool:
        return self.is_integer() or self.is_float()

    def is_scalar(self) -> bool:
        return self.kind in {"integer", "float", "bool", "byte", "enum", "ptr"}

    def is_copyable(self) -> bool:
        if self.resource or self.kind in {"ref", "slice", "storage"}:
            return False
        if self.kind == "array" and self.element:
            return self.element.is_copyable()
        if self.kind == "optional" and self.element:
            return self.element.is_copyable()
        return all(field_type.is_copyable() for field_type in self.fields.values())


@dataclass(slots=True)
class ConstValue:
    type: SemanticType
    value: Any


@dataclass(slots=True)
class Symbol:
    name: str
    kind: str
    type: SemanticType | None
    declaration: Node | None
    module: str = ""
    exported: bool = False
    mutable: bool = True
    mode: str = "ordinary"

    @property
    def qualified_name(self) -> str:
        return f"{self.module}.{self.name}" if self.module else self.name


@dataclass(slots=True)
class IRValue:
    name: str
    type: SemanticType


@dataclass(slots=True)
class IRInstruction:
    op: str
    args: list[Any]
    result: IRValue | None = None
    span: Span | None = None


@dataclass(slots=True)
class IRTerminator:
    op: str
    args: list[Any]
    span: Span | None = None


@dataclass(slots=True)
class IRBlock:
    name: str
    instructions: list[IRInstruction] = field(default_factory=list)
    terminator: IRTerminator | None = None


@dataclass(slots=True)
class IRFunction:
    name: str
    result_type: SemanticType | None
    params: list[IRValue]
    blocks: list[IRBlock]
    unsafe: bool = False
    external_abi: str | None = None


@dataclass(slots=True)
class IRModule:
    name: str
    functions: list[IRFunction] = field(default_factory=list)
    types: list[SemanticType] = field(default_factory=list)
    constants: dict[str, ConstValue] = field(default_factory=dict)


def expr_display(expr: Expr | None) -> str:
    if expr is None:
        return ""
    if isinstance(expr, LiteralExpr):
        return expr.raw or repr(expr.value)
    if isinstance(expr, NameExpr):
        return expr.qualified
    if isinstance(expr, UnaryExpr):
        return f"{expr.op}{expr_display(expr.operand)}"
    if isinstance(expr, BinaryExpr):
        return f"({expr_display(expr.left)} {expr.op} {expr_display(expr.right)})"
    if isinstance(expr, AssignExpr):
        return f"({expr_display(expr.target)} {expr.op} {expr_display(expr.value)})"
    if isinstance(expr, MemberExpr):
        return f"{expr_display(expr.base)}.{expr.member}"
    if isinstance(expr, IndexExpr):
        return f"{expr_display(expr.base)}[{expr_display(expr.index)}]"
    if isinstance(expr, RangeExpr):
        return f"{expr_display(expr.base)}[{expr_display(expr.start)}..{expr_display(expr.end)}]"
    if isinstance(expr, CallExpr):
        args = ", ".join(("out " if arg.mode == "out" else "") + expr_display(arg.value) for arg in expr.args)
        return f"{expr_display(expr.callee)}({args})"
    if isinstance(expr, TypeQueryExpr):
        return f"{expr.query}({expr.type_syntax.display() if expr.type_syntax else '?'})"
    return expr.__class__.__name__


def to_data(value: Any) -> Any:
    """Convert compiler records to deterministic JSON-compatible data."""
    if isinstance(value, Enum):
        return value.value
    if isinstance(value, Span):
        return value.to_json()
    if isinstance(value, SemanticType):
        return {
            "kind": value.kind,
            "name": value.name,
            "const": value.const,
            "element": to_data(value.element),
            "length": value.length,
            "resource": value.resource,
            "fields": {k: to_data(v) for k, v in sorted(value.fields.items())},
            "enum_items": dict(sorted(value.enum_items.items())),
        }
    if is_dataclass(value):
        result: dict[str, Any] = {"kind": value.__class__.__name__}
        for item in fields(value):
            if item.name.startswith("resolved_") or item.name in {"inferred_type", "constant_value", "lvalue"}:
                continue
            result[item.name] = to_data(getattr(value, item.name))
        return result
    if isinstance(value, Mapping):
        return {str(k): to_data(v) for k, v in sorted(value.items(), key=lambda pair: str(pair[0]))}
    if isinstance(value, (list, tuple)):
        return [to_data(item) for item in value]
    return value


def walk(node: Node) -> Iterator[Node]:
    yield node
    for child in node.children():
        yield from walk(child)
