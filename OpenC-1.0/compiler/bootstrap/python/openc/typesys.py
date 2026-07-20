"""OpenC semantic type system, layout facts, and lossless conversions."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable

from .diagnostics import DiagnosticEngine
from .model import Phase, SemanticType, TypeSyntax


INTEGER_WIDTHS: dict[str, tuple[int, bool]] = {
    "i8": (8, True), "i16": (16, True), "i32": (32, True), "i64": (64, True),
    "u8": (8, False), "u16": (16, False), "u32": (32, False), "u64": (64, False),
    "byte": (8, False),
}
FLOAT_WIDTHS = {"f32": 32, "f64": 64}


@dataclass(slots=True)
class TargetFacts:
    name: str = "generic-64"
    pointer_width: int = 64
    isize_width: int = 64
    usize_width: int = 64
    endianness: str = "little"
    max_alignment: int = 16
    hosted: bool = True
    build_context: dict[str, bool | int | str] = field(default_factory=lambda: {
        "target.os": "generic",
        "target.arch": "x86_64",
        "target.pointer_width": 64,
        "target.endianness": "little",
        "target.hosted": True,
        "project.profile": "standard",
    })

    @staticmethod
    def linux_x86_64() -> "TargetFacts":
        return TargetFacts(
            name="linux-x86_64", pointer_width=64, isize_width=64, usize_width=64,
            endianness="little", max_alignment=16, hosted=True,
            build_context={
                "target.os": "linux", "target.arch": "x86_64",
                "target.pointer_width": 64, "target.endianness": "little",
                "target.hosted": True, "project.profile": "standard",
            },
        )

    @staticmethod
    def windows_x86_64() -> "TargetFacts":
        return TargetFacts(
            name="windows-x86_64", pointer_width=64, isize_width=64, usize_width=64,
            endianness="little", max_alignment=16, hosted=True,
            build_context={
                "target.os": "windows", "target.arch": "x86_64",
                "target.pointer_width": 64, "target.endianness": "little",
                "target.hosted": True, "project.profile": "standard",
            },
        )


class TypeRegistry:
    def __init__(self, target: TargetFacts, diagnostics: DiagnosticEngine):
        self.target = target
        self.diagnostics = diagnostics
        self.types: dict[str, SemanticType] = {}
        self._install_builtins()

    def _install_builtins(self) -> None:
        for name, (width, signed) in INTEGER_WIDTHS.items():
            self.types[name] = SemanticType("integer", name)
        self.types["isize"] = SemanticType("integer", "isize")
        self.types["usize"] = SemanticType("integer", "usize")
        self.types["bool"] = SemanticType("bool", "bool")
        self.types["f32"] = SemanticType("float", "f32")
        self.types["f64"] = SemanticType("float", "f64")
        self.types["text"] = SemanticType("text", "text")
        self.types["status"] = SemanticType(
            "status", "status", fields={
                "code": self.types["i32"],
                "message": self.types["text"],
                "ok": self.types["bool"],
            },
        )
        self.types["void"] = SemanticType("void", "void")
        self.types["null"] = SemanticType("null", "null")
        self.types["none"] = SemanticType("none", "none")

    def define_struct(self, name: str, fields: dict[str, SemanticType], resource: bool = False) -> SemanticType:
        kind = "resource" if resource else "struct"
        value = SemanticType(kind, name, fields=fields, resource=resource)
        self.types[name] = value
        return value

    def define_enum(self, name: str, items: dict[str, int], base: str = "u32") -> SemanticType:
        value = SemanticType("enum", name, enum_items=items)
        value.fields["__base__"] = self.types[base]
        self.types[name] = value
        return value

    def lookup(self, name: str) -> SemanticType | None:
        return self.types.get(name)

    def resolve(self, syntax: TypeSyntax, rule_id: str = "OPENC-TYPE-UNKNOWN-001") -> SemanticType:
        if syntax.constructor == "named":
            assert syntax.name is not None
            base = self.lookup(syntax.name)
            if base is None:
                self.diagnostics.raise_error(
                    rule_id, Phase.TYPE, f"unknown type '{syntax.name}'", syntax.span, "type.unknown"
                )
            assert base is not None
            return self.with_const(base, syntax.const)
        assert syntax.inner is not None
        inner = self.resolve(syntax.inner, rule_id)
        if syntax.constructor == "array":
            length = None
            if syntax.length is not None and getattr(syntax.length, "constant_value", None) is not None:
                length = int(syntax.length.constant_value.value)
            return SemanticType("array", f"{inner.display()}[{length if length is not None else '?'}]", element=inner, length=length)
        if syntax.constructor == "slice":
            return SemanticType("slice", f"{inner.display()}[]", element=inner, const=syntax.const)
        if syntax.constructor == "ref":
            return SemanticType("ref", f"ref {inner.display()}", element=inner, const=syntax.const)
        if syntax.constructor == "ptr":
            return SemanticType("ptr", f"ptr {inner.display()}", element=inner, const=syntax.const)
        if syntax.constructor == "optional":
            return SemanticType("optional", f"optional {inner.display()}", element=inner, const=syntax.const)
        if syntax.constructor == "storage":
            return SemanticType("storage", f"storage {inner.display()}", element=inner)
        self.diagnostics.raise_error(
            "OPENC-TYPE-CONSTRUCTOR-001", Phase.TYPE,
            f"unsupported type constructor '{syntax.constructor}'", syntax.span, "type.constructor",
        )
        raise AssertionError("unreachable")

    @staticmethod
    def with_const(value: SemanticType, const: bool) -> SemanticType:
        if not const or value.const:
            return value
        return SemanticType(
            value.kind, value.name, True, value.element, value.length,
            dict(value.fields), value.resource, dict(value.enum_items),
        )

    def integer_info(self, value: SemanticType) -> tuple[int, bool] | None:
        name = value.name.replace("const ", "")
        if name == "isize":
            return self.target.isize_width, True
        if name == "usize":
            return self.target.usize_width, False
        return INTEGER_WIDTHS.get(name)

    def float_width(self, value: SemanticType) -> int | None:
        return FLOAT_WIDTHS.get(value.name.replace("const ", ""))

    def integer_range(self, value: SemanticType) -> tuple[int, int]:
        info = self.integer_info(value)
        if info is None:
            raise ValueError(f"not an integer type: {value.display()}")
        width, signed = info
        if signed:
            return -(1 << (width - 1)), (1 << (width - 1)) - 1
        return 0, (1 << width) - 1

    def same(self, left: SemanticType, right: SemanticType, ignore_const: bool = False) -> bool:
        if ignore_const:
            left_key = (left.kind, left.name, left.element.key() if left.element else None, left.length, left.resource)
            right_key = (right.kind, right.name, right.element.key() if right.element else None, right.length, right.resource)
            return left_key == right_key
        return left.key() == right.key()

    def can_losslessly_convert(self, source: SemanticType, target: SemanticType) -> bool:
        if self.same(source, target):
            return True
        if source.kind == "null" and target.kind == "ptr":
            return True
        if source.kind == "none" and target.kind == "optional":
            return True
        if source.kind == "array" and target.kind == "slice" and source.element and target.element:
            return self.same(source.element, target.element, ignore_const=True)
        if source.kind == "ref" and target.kind == "ref" and source.element and target.element:
            return (not source.const or target.const) and self.same(source.element, target.element, ignore_const=True)
        if source.kind == "ptr" and target.kind == "ptr" and source.element and target.element:
            return (not source.const or target.const) and self.same(source.element, target.element, ignore_const=True)
        if source.is_integer() and target.is_integer():
            s_info = self.integer_info(source)
            t_info = self.integer_info(target)
            assert s_info and t_info
            sw, ss = s_info; tw, ts = t_info
            if ss == ts:
                return tw >= sw
            if not ss and ts:
                return tw > sw
            return False
        if source.is_float() and target.is_float():
            sw = self.float_width(source); tw = self.float_width(target)
            assert sw is not None and tw is not None
            return tw >= sw
        if target.kind == "optional" and target.element is not None:
            return self.can_losslessly_convert(source, target.element)
        return False

    def common_numeric_type(self, left: SemanticType, right: SemanticType) -> SemanticType | None:
        if not left.is_numeric() or not right.is_numeric():
            return None
        if self.same(left, right):
            return left
        if self.can_losslessly_convert(left, right):
            return right
        if self.can_losslessly_convert(right, left):
            return left
        return None

    def size_of(self, value: SemanticType) -> int:
        if value.kind == "void":
            return 0
        if value.kind == "bool" or value.name == "byte":
            return 1
        info = self.integer_info(value)
        if info:
            return info[0] // 8
        width = self.float_width(value)
        if width:
            return width // 8
        if value.kind in {"ptr", "ref", "slice", "text"}:
            return self.target.pointer_width // 8 * (2 if value.kind in {"slice", "text"} else 1)
        if value.kind == "status":
            return 4 + self.size_of(self.types["text"])
        if value.kind == "optional" and value.element:
            return self.align_up(1, self.align_of(value.element)) + self.size_of(value.element)
        if value.kind == "array" and value.element and value.length is not None:
            return self.size_of(value.element) * value.length
        if value.kind == "storage" and value.element:
            return self.size_of(value.element)
        if value.kind in {"struct", "resource"}:
            offset = 0
            max_align = 1
            for field_type in value.fields.values():
                align = self.align_of(field_type)
                max_align = max(max_align, align)
                offset = self.align_up(offset, align)
                offset += self.size_of(field_type)
            return self.align_up(offset, max_align)
        if value.kind == "enum":
            return self.size_of(value.fields.get("__base__", self.types["u32"]))
        return self.target.pointer_width // 8

    def align_of(self, value: SemanticType) -> int:
        if value.kind in {"struct", "resource"}:
            return min(self.target.max_alignment, max((self.align_of(t) for t in value.fields.values()), default=1))
        size = max(1, self.size_of(value))
        alignment = 1
        while alignment * 2 <= size and alignment * 2 <= self.target.max_alignment:
            alignment *= 2
        return alignment

    @staticmethod
    def align_up(value: int, alignment: int) -> int:
        return (value + alignment - 1) // alignment * alignment
