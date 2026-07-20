"""Portable C11 bootstrap backend for OpenC Core, Hosted, and Native source.

The backend is an implementation technique, not a C-compatibility promise.  It
emits deterministic C11, inserts OpenC checked-operation runtime calls, retains
explicit unsafe boundaries as comments/source maps, and links against the
first-party OpenC runtime providers.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
import json
import re
from pathlib import Path
from typing import Iterable, Sequence

from .model import (
    AggregateExpr, ArrayExpr, AssignExpr, BinaryExpr, BlockStmt, BreakStmt,
    CallExpr, CastExpr, ConstDecl, ConstructExpr, ContinueStmt, DestroyExpr,
    EnumDecl, Expr, ExprStmt, ForStmt, FunctionDecl, IfStmt, IndexExpr,
    LiteralExpr, LocalDecl, MemberExpr, NameExpr, RangeExpr, ReturnStmt,
    ScopeStmt, SemanticType, SourceUnit, StatusExpr, StructDecl, SwitchStmt,
    TypeQueryExpr, UnaryExpr, UnsafeStmt, WhenStmt, WhileStmt,
)
from .semantic import SemanticProgram
from .typesys import TypeRegistry


def c_identifier(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", value)
    if not cleaned or cleaned[0].isdigit():
        cleaned = "_" + cleaned
    return cleaned


def stable_suffix(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:12]


@dataclass(slots=True)
class GeneratedFile:
    relative_path: str
    content: str


class CTypeRegistry:
    def __init__(self, types: TypeRegistry):
        self.types = types
        self.typedefs: dict[tuple, tuple[str, str]] = {}
        self.named_declarations: list[str] = []
        self.forward_declarations: list[str] = []

    def ctype(self, value: SemanticType) -> str:
        name = value.name.replace("const ", "")
        primitive = {
            "i8": "int8_t", "i16": "int16_t", "i32": "int32_t", "i64": "int64_t",
            "u8": "uint8_t", "u16": "uint16_t", "u32": "uint32_t", "u64": "uint64_t",
            "isize": "intptr_t", "usize": "uintptr_t", "byte": "uint8_t",
            "bool": "bool", "f32": "float", "f64": "double", "text": "oc_text",
            "status": "oc_status", "void": "void",
        }
        if value.kind in {"integer", "float", "bool", "byte", "text", "status", "void"}:
            return primitive.get(name, primitive.get(value.name, "void"))
        if value.kind in {"struct", "resource", "enum"}:
            return "oc_" + c_identifier(value.name)
        if value.kind in {"ref", "ptr"}:
            assert value.element is not None
            prefix = "const " if value.const else ""
            return f"{prefix}{self.ctype(value.element)} *"
        if value.kind == "array":
            return self.ensure_array(value)
        if value.kind == "slice":
            return self.ensure_slice(value)
        if value.kind == "optional":
            return self.ensure_optional(value)
        if value.kind == "storage":
            return self.ensure_storage(value)
        if value.kind == "null":
            return "void *"
        if value.kind == "none":
            return "oc_none"
        return "oc_" + c_identifier(value.display())

    def ensure_array(self, value: SemanticType) -> str:
        key = value.key()
        if key not in self.typedefs:
            assert value.element is not None and value.length is not None
            name = f"oc_array_{stable_suffix(value.display())}"
            body = f"typedef struct {name} {{ {self.ctype(value.element)} data[{value.length}]; }} {name};"
            self.typedefs[key] = (name, body)
        return self.typedefs[key][0]

    def ensure_slice(self, value: SemanticType) -> str:
        key = value.key()
        if key not in self.typedefs:
            assert value.element is not None
            name = f"oc_slice_{stable_suffix(value.display())}"
            prefix = "const " if value.const else ""
            body = f"typedef struct {name} {{ {prefix}{self.ctype(value.element)} *data; uintptr_t length; }} {name};"
            self.typedefs[key] = (name, body)
        return self.typedefs[key][0]

    def ensure_optional(self, value: SemanticType) -> str:
        key = value.key()
        if key not in self.typedefs:
            assert value.element is not None
            name = f"oc_optional_{stable_suffix(value.display())}"
            body = f"typedef struct {name} {{ bool present; {self.ctype(value.element)} value; }} {name};"
            self.typedefs[key] = (name, body)
        return self.typedefs[key][0]

    def ensure_storage(self, value: SemanticType) -> str:
        key = value.key()
        if key not in self.typedefs:
            assert value.element is not None
            name = f"oc_storage_{stable_suffix(value.display())}"
            target = self.ctype(value.element)
            body = (
                f"typedef union {name} {{ max_align_t _alignment; "
                f"unsigned char bytes[sizeof({target})]; }} {name};"
            )
            self.typedefs[key] = (name, body)
        return self.typedefs[key][0]

    def emit_compound_typedefs(self) -> list[str]:
        return [body for _, body in sorted(self.typedefs.values(), key=lambda item: item[0])]


@dataclass(slots=True)
class EmitScope:
    cleanups: list[str] = field(default_factory=list)


@dataclass(slots=True)
class LoopContext:
    scope_depth: int


class CEmitter:
    def __init__(self, semantic: SemanticProgram, target_name: str):
        self.semantic = semantic
        self.target_name = target_name
        self.ctypes = CTypeRegistry(semantic.types)
        self.lines: list[str] = []
        self.indent = 0
        self.current_module = ""
        self.current_function: FunctionDecl | None = None
        self.scopes: list[EmitScope] = []
        self.loops: list[LoopContext] = []
        self.source_map: list[dict] = []
        self.reinterpret_helpers: dict[tuple[str, str], str] = {}

    def generate(self) -> list[GeneratedFile]:
        self.pre_register_types()
        self.pre_register_reinterpret_helpers()
        header = self.generate_header()
        source = self.generate_source()
        mapping = json.dumps({"version": 1, "entries": self.source_map}, indent=2, sort_keys=True) + "\n"
        return [
            GeneratedFile("generated/openc_program.h", header),
            GeneratedFile("generated/openc_program.c", source),
            GeneratedFile("generated/openc_program.map.json", mapping),
        ]

    def pre_register_types(self) -> None:
        for value in list(self.semantic.types.types.values()):
            self.walk_type(value)

    def walk_type(self, value: SemanticType) -> None:
        if value.kind in {"array", "slice", "optional", "storage"}:
            self.ctypes.ctype(value)
        if value.element:
            self.walk_type(value.element)
        for field_type in value.fields.values():
            self.walk_type(field_type)

    def pre_register_reinterpret_helpers(self) -> None:
        def visit(value):
            if value is None:
                return
            if isinstance(value, CastExpr) and value.cast_kind == "reinterpret":
                if value.value is not None and value.value.inferred_type is not None and value.inferred_type is not None:
                    self.ensure_reinterpret_helper(
                        self.ctypes.ctype(value.value.inferred_type),
                        self.ctypes.ctype(value.inferred_type),
                    )
            for field_name in getattr(value, "__dataclass_fields__", {}):
                child = getattr(value, field_name)
                if isinstance(child, list):
                    for item in child:
                        if hasattr(item, "__dataclass_fields__"):
                            visit(item)
                elif hasattr(child, "__dataclass_fields__"):
                    visit(child)
        for module in self.semantic.modules.modules.values():
            for declaration in module.declarations:
                visit(declaration)

    def generate_header(self) -> str:
        lines = [
            "#ifndef OPENC_GENERATED_PROGRAM_H",
            "#define OPENC_GENERATED_PROGRAM_H",
            "#include <stdbool.h>",
            "#include <stddef.h>",
            "#include <stdint.h>",
            "#include <stdalign.h>",
            '#include "openc_runtime.h"',
            "",
        ]
        named = self.named_type_declarations()
        lines.extend(named)
        if named:
            lines.append("")
        lines.extend(self.ctypes.emit_compound_typedefs())
        lines.append("")
        for module_name, module in sorted(self.semantic.modules.modules.items()):
            for decl in module.declarations:
                if isinstance(decl, FunctionDecl):
                    lines.append(self.function_prototype(module_name, decl) + ";")
                elif isinstance(decl, ConstDecl) and decl.type_syntax is not None:
                    symbol = module.scope.lookup_local(decl.name)
                    if hasattr(symbol, "type") and symbol.type:
                        lines.append(f"extern const {self.ctypes.ctype(symbol.type)} {self.global_name(module_name, decl.name)};")
        lines.extend(["", "#endif", ""])
        return "\n".join(lines)

    def named_type_declarations(self) -> list[str]:
        lines: list[str] = []
        seen: set[str] = set()
        # Forward declarations allow resource/struct pointer fields to reference later types.
        for name, value in sorted(self.semantic.types.types.items()):
            if "." not in name or value.kind not in {"struct", "resource", "enum"} or value.name in seen:
                continue
            seen.add(value.name)
            c_name = self.ctypes.ctype(value)
            if value.kind == "enum":
                base = self.ctypes.ctype(value.fields.get("__base__", self.semantic.types.types["u32"]))
                lines.append(f"typedef {base} {c_name};")
                for item, number in sorted(value.enum_items.items(), key=lambda pair: pair[1]):
                    lines.append(f"#define {c_name}_{c_identifier(item)} (({c_name}){number})")
            else:
                lines.append(f"typedef struct {c_name} {c_name};")
        seen.clear()
        for name, value in sorted(self.semantic.types.types.items()):
            if "." not in name or value.kind not in {"struct", "resource"} or value.name in seen:
                continue
            seen.add(value.name)
            c_name = self.ctypes.ctype(value)
            lines.append(f"struct {c_name} {{")
            if not value.fields:
                lines.append("    uint8_t _openc_nonzero_size;")
            else:
                for field_name, field_type in value.fields.items():
                    if field_name == "__base__":
                        continue
                    lines.append(f"    {self.ctypes.ctype(field_type)} {c_identifier(field_name)};")
            lines.append("};")
        return lines

    def generate_source(self) -> str:
        self.lines = [
            '#include "openc_program.h"',
            "#include <string.h>",
            "",
        ]
        self.lines.extend(self.emit_reinterpret_helpers())
        for module_name, module in sorted(self.semantic.modules.modules.items()):
            for decl in module.declarations:
                if isinstance(decl, ConstDecl):
                    self.emit_constant(module_name, decl)
        if any(isinstance(decl, ConstDecl) for module in self.semantic.modules.modules.values() for decl in module.declarations):
            self.lines.append("")
        for module_name, module in sorted(self.semantic.modules.modules.items()):
            for decl in module.declarations:
                if isinstance(decl, FunctionDecl) and decl.body is not None:
                    self.emit_function(module_name, decl)
                    self.lines.append("")
        self.emit_host_main_wrapper()
        return "\n".join(self.lines).rstrip() + "\n"

    def emit_constant(self, module_name: str, decl: ConstDecl) -> None:
        symbol = self.semantic.modules.modules[module_name].scope.lookup_local(decl.name)
        if not hasattr(symbol, "type") or symbol.type is None or decl.value is None:
            return
        value = self.expr(decl.value, expected=symbol.type)
        self.lines.append(f"const {self.ctypes.ctype(symbol.type)} {self.global_name(module_name, decl.name)} = {value};")

    def function_prototype(self, module_name: str, decl: FunctionDecl) -> str:
        sig = self.semantic.signatures[id(decl)]
        result = self.ctypes.ctype(sig.result)
        name = decl.external_symbol if decl.external_abi and decl.external_symbol else self.function_name(module_name, decl)
        params: list[str] = []
        for param, value_type in sig.params:
            c_type = self.ctypes.ctype(value_type)
            if param.mode in {"out", "out_own"}:
                c_type = c_type + " *"
            elif value_type.kind == "ref":
                c_type = self.ctypes.ctype(value_type)
            params.append(f"{c_type} {c_identifier(param.name)}")
        if not params:
            params.append("void")
        prefix = "extern " if decl.external_abi else ""
        return f"{prefix}{result} {name}({', '.join(params)})"

    def emit_function(self, module_name: str, decl: FunctionDecl) -> None:
        self.current_module = module_name
        self.current_function = decl
        self.scopes = [EmitScope()]
        self.loops = []
        self.write(self.function_prototype(module_name, decl))
        self.write("{")
        self.indent += 1
        assert decl.body is not None
        self.emit_block_contents(decl.body)
        if self.semantic.signatures[id(decl)].result.kind == "void":
            self.emit_all_cleanups()
            self.write("return;")
        self.indent -= 1
        self.write("}")
        self.current_function = None
        self.scopes = []

    def emit_block(self, block: BlockStmt) -> None:
        self.write("{")
        self.indent += 1
        self.scopes.append(EmitScope())
        self.emit_block_contents(block)
        self.emit_scope_cleanups(self.scopes[-1])
        self.scopes.pop()
        self.indent -= 1
        self.write("}")

    def emit_block_contents(self, block: BlockStmt) -> None:
        for item in block.items:
            if isinstance(item, LocalDecl):
                self.emit_local(item)
            else:
                self.emit_stmt(item)

    def emit_local(self, decl: LocalDecl) -> None:
        assert self.current_module
        value_type = self.semantic.types.resolve(decl.type_syntax)
        name = c_identifier(decl.name)
        c_type = self.ctypes.ctype(value_type)
        if decl.initializer is None:
            self.write(f"{c_type} {name};", decl.span)
        else:
            initializer = self.expr(decl.initializer, expected=value_type)
            self.write(f"{c_type} {name} = {initializer};", decl.span)

    def emit_stmt(self, stmt) -> None:
        if isinstance(stmt, BlockStmt):
            self.emit_block(stmt)
        elif isinstance(stmt, ExprStmt):
            assert stmt.expr
            self.write(self.expr(stmt.expr) + ";", stmt.span)
        elif isinstance(stmt, IfStmt):
            assert stmt.condition and stmt.then_branch
            self.write(f"if ({self.expr(stmt.condition)})", stmt.condition.span)
            self.emit_block(stmt.then_branch)
            if stmt.else_branch is not None:
                self.write("else")
                if isinstance(stmt.else_branch, BlockStmt):
                    self.emit_block(stmt.else_branch)
                else:
                    self.emit_stmt(stmt.else_branch)
        elif isinstance(stmt, WhileStmt):
            assert stmt.condition and stmt.body
            self.write(f"while ({self.expr(stmt.condition)})", stmt.condition.span)
            self.loops.append(LoopContext(len(self.scopes)))
            self.emit_block(stmt.body)
            self.loops.pop()
        elif isinstance(stmt, ForStmt):
            init = ""
            if isinstance(stmt.initializer, LocalDecl):
                value_type = self.semantic.types.resolve(stmt.initializer.type_syntax)
                init = f"{self.ctypes.ctype(value_type)} {c_identifier(stmt.initializer.name)}"
                if stmt.initializer.initializer:
                    init += " = " + self.expr(stmt.initializer.initializer, expected=value_type)
            elif isinstance(stmt.initializer, Expr):
                init = self.expr(stmt.initializer)
            condition = self.expr(stmt.condition) if stmt.condition else "true"
            update = self.expr(stmt.update) if stmt.update else ""
            self.write(f"for ({init}; {condition}; {update})", stmt.span)
            assert stmt.body
            self.loops.append(LoopContext(len(self.scopes)))
            self.emit_block(stmt.body)
            self.loops.pop()
        elif isinstance(stmt, SwitchStmt):
            assert stmt.value
            self.write(f"switch ({self.expr(stmt.value)})", stmt.span)
            self.write("{"); self.indent += 1
            for case in stmt.cases:
                if case.is_default:
                    self.write("default:")
                else:
                    assert case.value
                    self.write(f"case {self.expr(case.value)}:")
                self.indent += 1
                assert case.body
                self.emit_block_contents(case.body)
                self.write("break;")
                self.indent -= 1
            self.indent -= 1; self.write("}")
        elif isinstance(stmt, BreakStmt):
            self.emit_cleanups_to_loop()
            self.write("break;", stmt.span)
        elif isinstance(stmt, ContinueStmt):
            self.emit_cleanups_to_loop()
            self.write("continue;", stmt.span)
        elif isinstance(stmt, ReturnStmt):
            value = self.expr(stmt.value, expected=self.semantic.signatures[id(self.current_function)].result) if stmt.value else None
            self.emit_all_cleanups()
            self.write("return" + (f" {value}" if value else "") + ";", stmt.span)
        elif isinstance(stmt, ScopeStmt):
            assert stmt.action
            self.scopes[-1].cleanups.append(self.expr(stmt.action))
            self.write(f"/* scope cleanup registered: {self.expr(stmt.action)} */", stmt.span)
        elif isinstance(stmt, UnsafeStmt):
            self.write("/* unsafe begin */", stmt.span)
            assert stmt.body
            self.emit_block(stmt.body)
            self.write("/* unsafe end */", stmt.span)
        elif isinstance(stmt, WhenStmt):
            if stmt.condition and stmt.condition.constant_value and stmt.condition.constant_value.value:
                assert stmt.body
                self.emit_block(stmt.body)

    def emit_scope_cleanups(self, scope: EmitScope) -> None:
        for action in reversed(scope.cleanups):
            self.write(action + ";")

    def emit_all_cleanups(self) -> None:
        for scope in reversed(self.scopes):
            self.emit_scope_cleanups(scope)

    def emit_cleanups_to_loop(self) -> None:
        if not self.loops:
            return
        depth = self.loops[-1].scope_depth
        for scope in reversed(self.scopes[depth:]):
            self.emit_scope_cleanups(scope)

    def expr(self, expr: Expr | None, expected: SemanticType | None = None) -> str:
        if expr is None:
            return "0"
        value_type = expr.inferred_type or expected
        if isinstance(expr, LiteralExpr):
            if expr.literal_kind == "text":
                return f"OC_TEXT_LITERAL({json.dumps(str(expr.value), ensure_ascii=False)})"
            if expr.literal_kind == "bool":
                return "true" if expr.value else "false"
            if expr.literal_kind == "null":
                return "NULL"
            if expr.literal_kind == "none":
                if expected and expected.kind == "optional":
                    return f"(({self.ctypes.ctype(expected)}){{ .present = false }})"
                return "OC_NONE"
            if expr.literal_kind == "float":
                return repr(float(expr.value))
            return str(int(expr.value))
        if isinstance(expr, NameExpr):
            if expr.resolved_symbol:
                symbol = expr.resolved_symbol
                if symbol.kind == "constant":
                    return self.global_name(symbol.module, symbol.name)
                if symbol.kind == "function":
                    decl = symbol.declaration
                    assert isinstance(decl, FunctionDecl)
                    return decl.external_symbol if decl.external_symbol else self.function_name(symbol.module, decl)
            if len(expr.parts) == 2:
                enum_type = self.semantic.types.lookup(expr.parts[0]) or self.semantic.types.lookup(f"{self.current_module}.{expr.parts[0]}")
                if enum_type and enum_type.kind == "enum":
                    return f"{self.ctypes.ctype(enum_type)}_{c_identifier(expr.parts[1])}"
            return c_identifier(expr.parts[-1]) if len(expr.parts) == 1 else "oc_" + c_identifier(expr.qualified)
        if isinstance(expr, UnaryExpr):
            operand = self.expr(expr.operand)
            return f"({expr.op}{operand})"
        if isinstance(expr, BinaryExpr):
            left = self.expr(expr.left)
            right = self.expr(expr.right)
            if value_type and value_type.is_integer() and expr.op in {"+", "-", "*", "/", "%", "<<", ">>"}:
                helper = {
                    "+": "add", "-": "sub", "*": "mul", "/": "div", "%": "rem",
                    "<<": "shl", ">>": "shr",
                }[expr.op]
                return f"oc_checked_{helper}_{self.runtime_type_suffix(value_type)}({left}, {right}, {self.span_id(expr)})"
            return f"({left} {expr.op} {right})"
        if isinstance(expr, AssignExpr):
            target = self.expr(expr.target)
            target_type = expr.target.inferred_type if expr.target else expected
            value = self.expr(expr.value, expected=target_type)
            if target_type and target_type.kind == "optional" and expr.value and expr.value.inferred_type and expr.value.inferred_type.kind not in {"optional", "none"}:
                value = f"(({self.ctypes.ctype(target_type)}){{ .present = true, .value = {value} }})"
            if expr.op != "=" and target_type and target_type.is_integer():
                operator = expr.op[0:-1]
                helper = {"+": "add", "-": "sub", "*": "mul", "/": "div", "%": "rem", "<<": "shl", ">>": "shr"}.get(operator)
                if helper:
                    value = f"oc_checked_{helper}_{self.runtime_type_suffix(target_type)}({target}, {value}, {self.span_id(expr)})"
                    return f"({target} = {value})"
            return f"({target} {expr.op} {value})"
        if isinstance(expr, CallExpr):
            assert expr.resolved_function
            sig = self.semantic.signatures[id(expr.resolved_function)]
            function_name = expr.resolved_function.external_symbol or self.function_name(sig.symbol.module, expr.resolved_function)
            args: list[str] = []
            for arg, (param, param_type) in zip(expr.args, sig.params):
                rendered = self.expr(arg.value, expected=param_type)
                if param.mode in {"out", "out_own"}:
                    rendered = "&" + rendered
                elif param_type.kind == "ref":
                    arg_type = arg.value.inferred_type if arg.value else None
                    if arg_type and arg_type.kind != "ref":
                        rendered = "&" + rendered
                args.append(rendered)
            return f"{function_name}({', '.join(args)})"
        if isinstance(expr, MemberExpr):
            assert expr.base
            base = self.expr(expr.base)
            base_type = expr.base.inferred_type
            if base_type and base_type.kind == "status" and expr.member == "ok":
                return f"oc_status_ok({base})"
            if base_type and base_type.kind == "optional":
                return f"({base}).{c_identifier(expr.member)}"
            if base_type and base_type.kind in {"array", "slice", "text"} and expr.member == "length":
                return f"({base}).length" if base_type.kind in {"slice", "text"} else str(base_type.length)
            arrow = "->" if base_type and base_type.kind in {"ref", "ptr"} else "."
            return f"({base}){arrow}{c_identifier(expr.member)}"
        if isinstance(expr, IndexExpr):
            assert expr.base and expr.index
            base = self.expr(expr.base)
            index = self.expr(expr.index)
            base_type = expr.base.inferred_type
            if base_type and base_type.kind == "array":
                length = base_type.length or 0
                return f"({base}).data[oc_bounds_index({index}, {length}, {self.span_id(expr)})]"
            if base_type and base_type.kind == "slice":
                return f"({base}).data[oc_bounds_index({index}, ({base}).length, {self.span_id(expr)})]"
            return f"({base})[{index}]"
        if isinstance(expr, RangeExpr):
            assert expr.base
            base = self.expr(expr.base)
            start = self.expr(expr.start) if expr.start else "0"
            base_type = expr.base.inferred_type
            if base_type and base_type.kind == "text":
                end = self.expr(expr.end) if expr.end else f"({base}).length"
                return f"oc_text_slice({base}, {start}, {end}, {self.span_id(expr)})"
            if base_type and base_type.kind == "array":
                total = str(base_type.length or 0)
                end = self.expr(expr.end) if expr.end else total
                slice_type = self.ctypes.ctype(expr.inferred_type)
                return f"(({slice_type}){{ .data = &({base}).data[{start}], .length = oc_range_length({start}, {end}, {total}, {self.span_id(expr)}) }})"
            if base_type and base_type.kind == "slice":
                end = self.expr(expr.end) if expr.end else f"({base}).length"
                slice_type = self.ctypes.ctype(expr.inferred_type)
                return f"(({slice_type}){{ .data = &({base}).data[{start}], .length = oc_range_length({start}, {end}, ({base}).length, {self.span_id(expr)}) }})"
        if isinstance(expr, CastExpr):
            assert expr.target_type and expr.value and expr.inferred_type
            value = self.expr(expr.value)
            target = self.ctypes.ctype(expr.inferred_type)
            if expr.cast_kind == "checked":
                return f"oc_checked_cast_{self.runtime_type_suffix(expr.inferred_type)}({value}, {self.span_id(expr)})"
            if expr.cast_kind == "reinterpret":
                source_type = expr.value.inferred_type
                assert source_type is not None
                source_c = self.ctypes.ctype(source_type)
                target_c = self.ctypes.ctype(expr.inferred_type)
                helper = self.ensure_reinterpret_helper(source_c, target_c)
                return f"{helper}({value})"
            return f"(({target})({value}))"
        if isinstance(expr, TypeQueryExpr):
            assert expr.type_syntax
            value_type = self.semantic.types.resolve(expr.type_syntax)
            return f"sizeof({self.ctypes.ctype(value_type)})" if expr.query == "size_of" else f"_Alignof({self.ctypes.ctype(value_type)})"
        if isinstance(expr, AggregateExpr):
            assert expr.inferred_type
            entries = []
            for field in expr.fields:
                field_type = expr.inferred_type.fields[field.name]
                entries.append(f".{c_identifier(field.name)} = {self.expr(field.value, expected=field_type)}")
            return f"(({self.ctypes.ctype(expr.inferred_type)}){{ {', '.join(entries)} }})"
        if isinstance(expr, ArrayExpr):
            assert expr.inferred_type
            element = expr.inferred_type.element
            values = ", ".join(self.expr(value, expected=element) for value in expr.values)
            return f"(({self.ctypes.ctype(expr.inferred_type)}){{ .data = {{ {values} }} }})"
        if isinstance(expr, StatusExpr):
            code = self.expr(expr.code, expected=self.semantic.types.types["i32"])
            message = self.expr(expr.message, expected=self.semantic.types.types["text"]) if expr.message else "OC_TEXT_EMPTY"
            return f"((oc_status){{ .code = {code}, .message = {message} }})"
        if isinstance(expr, ConstructExpr):
            assert expr.inferred_type and expr.inferred_type.element and expr.storage and expr.value
            target = self.ctypes.ctype(expr.inferred_type.element)
            return f"OC_CONSTRUCT({target}, {self.expr(expr.storage)}, {self.expr(expr.value, expected=expr.inferred_type.element)})"
        if isinstance(expr, DestroyExpr):
            assert expr.value
            return f"oc_destroy_typed({self.expr(expr.value)})"
        raise AssertionError(type(expr))

    def ensure_reinterpret_helper(self, source_c: str, target_c: str) -> str:
        key = (source_c, target_c)
        if key in self.reinterpret_helpers:
            return self.reinterpret_helpers[key]
        name = "oc_reinterpret_" + stable_suffix(source_c + "->" + target_c)
        self.reinterpret_helpers[key] = name
        return name

    def emit_reinterpret_helpers(self) -> list[str]:
        lines: list[str] = []
        for (source_c, target_c), name in sorted(self.reinterpret_helpers.items()):
            lines.extend([
                f"static inline {target_c} {name}({source_c} value)",
                "{",
                f"    _Static_assert(sizeof({source_c}) == sizeof({target_c}), \"reinterpret size mismatch\");",
                f"    {target_c} result;",
                "    memcpy(&result, &value, sizeof(result));",
                "    return result;",
                "}",
                "",
            ])
        return lines

    def span_id(self, expr: Expr) -> str:
        span = expr.span
        record = {
            "id": len(self.source_map) + 1,
            "source": span.source_id,
            "start": {"line": span.start.line, "column": span.start.column, "offset": span.start.offset},
            "end": {"line": span.end.line, "column": span.end.column, "offset": span.end.offset},
        }
        self.source_map.append(record)
        return str(record["id"])

    def runtime_type_suffix(self, value_type: SemanticType) -> str:
        name = value_type.name.replace("const ", "")
        return {"byte": "u8", "isize": "isize", "usize": "usize"}.get(name, name)

    def function_name(self, module_name: str, decl: FunctionDecl) -> str:
        return "oc_fn_" + c_identifier(module_name) + "__" + c_identifier(decl.name) + "__" + stable_suffix(self.signature_text(decl))

    def signature_text(self, decl: FunctionDecl) -> str:
        sig = self.semantic.signatures[id(decl)]
        return decl.name + "(" + ",".join(param.mode + ":" + value_type.display() for param, value_type in sig.params) + ")->" + sig.result.display()

    @staticmethod
    def global_name(module_name: str, name: str) -> str:
        return "oc_const_" + c_identifier(module_name) + "__" + c_identifier(name)

    def emit_host_main_wrapper(self) -> None:
        entry: tuple[str, FunctionDecl] | None = None
        for module_name, module in self.semantic.modules.modules.items():
            for decl in module.declarations:
                if isinstance(decl, FunctionDecl) and decl.name == "main" and decl.body is not None and not decl.params:
                    entry = (module_name, decl)
                    break
            if entry:
                break
        if entry is None:
            return
        module_name, decl = entry
        self.lines.extend([
            "int main(int argc, char **argv)",
            "{",
            "    oc_process_initialize(argc, argv);",
            f"    int32_t result = {self.function_name(module_name, decl)}();",
            "    oc_process_finalize();",
            "    return (int)result;",
            "}",
        ])

    def write(self, text: str, span=None) -> None:
        self.lines.append("    " * self.indent + text)
