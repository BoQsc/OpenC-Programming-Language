"""Target-independent structured Core IR and verifier."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Iterable

from .diagnostics import DiagnosticEngine
from .model import Phase, SemanticType, Span, to_data


@dataclass(slots=True)
class Value:
    name: str
    type: SemanticType


@dataclass(slots=True)
class Instruction:
    op: str
    operands: list[Any] = field(default_factory=list)
    result: Value | None = None
    span: Span | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class Terminator:
    op: str
    operands: list[Any] = field(default_factory=list)
    targets: list[str] = field(default_factory=list)
    span: Span | None = None


@dataclass(slots=True)
class BasicBlock:
    name: str
    instructions: list[Instruction] = field(default_factory=list)
    terminator: Terminator | None = None


@dataclass(slots=True)
class Function:
    name: str
    result_type: SemanticType
    params: list[Value]
    blocks: list[BasicBlock]
    external_abi: str | None = None
    unsafe: bool = False


@dataclass(slots=True)
class Module:
    name: str
    functions: list[Function] = field(default_factory=list)
    constants: dict[str, Any] = field(default_factory=dict)
    named_types: list[SemanticType] = field(default_factory=list)


@dataclass(slots=True)
class Program:
    modules: list[Module]
    target: str
    source_hashes: dict[str, str]

    def to_json(self) -> dict[str, Any]:
        return to_data(self)


class Verifier:
    def __init__(self, diagnostics: DiagnosticEngine):
        self.diagnostics = diagnostics

    def verify(self, program: Program) -> None:
        function_names: set[str] = set()
        for module in program.modules:
            for function in module.functions:
                qualified = f"{module.name}.{function.name}"
                if qualified in function_names:
                    self.diagnostics.raise_error(
                        "OPENC-IR-FUNCTION-DUPLICATE-001", Phase.TOOL,
                        f"duplicate IR function '{qualified}'", category="ir.function",
                    )
                function_names.add(qualified)
                self.verify_function(function)

    def verify_function(self, function: Function) -> None:
        blocks = {block.name: block for block in function.blocks}
        if not blocks and function.external_abi is None:
            self.diagnostics.raise_error(
                "OPENC-IR-BLOCK-001", Phase.TOOL,
                f"IR function '{function.name}' has no blocks", category="ir.block",
            )
        value_names = {param.name for param in function.params}
        for block in function.blocks:
            if block.terminator is None:
                self.diagnostics.raise_error(
                    "OPENC-IR-TERMINATOR-001", Phase.TOOL,
                    f"IR block '{block.name}' has no terminator", category="ir.block",
                )
            for instruction in block.instructions:
                if instruction.result:
                    if instruction.result.name in value_names:
                        self.diagnostics.raise_error(
                            "OPENC-IR-VALUE-DUPLICATE-001", Phase.TOOL,
                            f"duplicate IR value '{instruction.result.name}'", instruction.span,
                            "ir.value",
                        )
                    value_names.add(instruction.result.name)
            if block.terminator:
                for target in block.terminator.targets:
                    if target not in blocks:
                        self.diagnostics.raise_error(
                            "OPENC-IR-TARGET-001", Phase.TOOL,
                            f"IR terminator references unknown block '{target}'", block.terminator.span,
                            "ir.block",
                        )
