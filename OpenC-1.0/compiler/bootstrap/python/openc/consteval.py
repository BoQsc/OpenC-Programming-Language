"""Exact OpenC constant and build-context evaluation."""
from __future__ import annotations

import math
from typing import Any

from .diagnostics import DiagnosticEngine
from .model import (
    AggregateExpr, ArrayExpr, BinaryExpr, ConstValue, Expr, LiteralExpr, NameExpr,
    Phase, StatusExpr, TypeQueryExpr, UnaryExpr,
)
from .typesys import TypeRegistry


class ConstantEvaluator:
    def __init__(self, types: TypeRegistry, diagnostics: DiagnosticEngine):
        self.types = types
        self.diagnostics = diagnostics
        self.values: dict[str, ConstValue] = {}

    def define(self, name: str, value: ConstValue) -> None:
        self.values[name] = value

    def evaluate(self, expr: Expr, expected=None, when_context: bool = False) -> ConstValue:
        if isinstance(expr, LiteralExpr):
            result = self.literal(expr, expected)
        elif isinstance(expr, NameExpr):
            result = self.name(expr, when_context)
        elif isinstance(expr, UnaryExpr):
            result = self.unary(expr, expected, when_context)
        elif isinstance(expr, BinaryExpr):
            result = self.binary(expr, expected, when_context)
        elif isinstance(expr, TypeQueryExpr):
            assert expr.type_syntax is not None
            value_type = self.types.resolve(expr.type_syntax)
            value = self.types.size_of(value_type) if expr.query == "size_of" else self.types.align_of(value_type)
            result = ConstValue(self.types.types["usize"], value)
        elif isinstance(expr, ArrayExpr):
            values = [self.evaluate(item, when_context=when_context) for item in expr.values]
            if not values:
                self.diagnostics.raise_error(
                    "OPENC-CONSTANT-ARRAY-EMPTY-001", Phase.CONSTANT,
                    "empty array constant requires an expected type", expr.span, "constant.array",
                )
            element_type = expected.element if expected and expected.kind == "array" else values[0].type
            for item in values:
                if not self.types.can_losslessly_convert(item.type, element_type):
                    self.diagnostics.raise_error(
                        "OPENC-CONSTANT-ARRAY-TYPE-001", Phase.CONSTANT,
                        "array constant elements do not have one lossless common type",
                        expr.span, "constant.array",
                    )
            result = ConstValue(
                expected or self.types.types.get("<?>", values[0].type),
                [item.value for item in values],
            )
        elif isinstance(expr, StatusExpr):
            assert expr.code is not None
            code = self.evaluate(expr.code, self.types.types["i32"])
            message = self.evaluate(expr.message, self.types.types["text"]) if expr.message else ConstValue(self.types.types["text"], "")
            result = ConstValue(self.types.types["status"], {"code": int(code.value), "message": str(message.value)})
        elif isinstance(expr, AggregateExpr):
            target = self.types.lookup(expr.type_name)
            if target is None:
                self.diagnostics.raise_error(
                    "OPENC-TYPE-UNKNOWN-001", Phase.CONSTANT,
                    f"unknown aggregate type '{expr.type_name}'", expr.span, "constant.aggregate",
                )
            assert target is not None
            data: dict[str, Any] = {}
            for field in expr.fields:
                if field.ownership:
                    self.diagnostics.raise_error(
                        "OPENC-CONSTANT-OWNERSHIP-001", Phase.CONSTANT,
                        "ownership field transfer is not allowed in a constant initializer",
                        field.span, "constant.aggregate",
                    )
                field_type = target.fields.get(field.name)
                if field_type is None:
                    self.diagnostics.raise_error(
                        "OPENC-STRUCT-INIT-UNKNOWN-001", Phase.CONSTANT,
                        f"unknown field '{field.name}' in '{target.name}'", field.span, "constant.aggregate",
                    )
                assert field.value is not None and field_type is not None
                data[field.name] = self.evaluate(field.value, field_type).value
            result = ConstValue(target, data)
        else:
            self.diagnostics.raise_error(
                "OPENC-CONSTANT-EXPR-001", Phase.CONSTANT,
                f"expression '{expr.__class__.__name__}' is not constant", expr.span, "constant.expression",
            )
            raise AssertionError("unreachable")
        expr.constant_value = result
        expr.inferred_type = result.type
        return result

    def literal(self, expr: LiteralExpr, expected) -> ConstValue:
        if expr.literal_kind == "integer":
            target = expected if expected and expected.is_integer() else self.types.types["i32"]
            low, high = self.types.integer_range(target)
            value = int(expr.value)
            if not low <= value <= high:
                self.diagnostics.raise_error(
                    "OPENC-LITERAL-RANGE-001", Phase.CONSTANT,
                    f"integer literal {value} is outside {target.display()} range [{low}, {high}]",
                    expr.span, "constant.literal",
                )
            return ConstValue(target, value)
        if expr.literal_kind == "float":
            target = expected if expected and expected.is_float() else self.types.types["f64"]
            value = float(expr.value)
            if not math.isfinite(value):
                self.diagnostics.raise_error(
                    "OPENC-LITERAL-RANGE-001", Phase.CONSTANT,
                    "floating literal is not finite", expr.span, "constant.literal",
                )
            return ConstValue(target, value)
        if expr.literal_kind == "text":
            return ConstValue(self.types.types["text"], str(expr.value))
        if expr.literal_kind == "bool":
            return ConstValue(self.types.types["bool"], bool(expr.value))
        if expr.literal_kind == "null":
            return ConstValue(self.types.types["null"], None)
        if expr.literal_kind == "none":
            return ConstValue(self.types.types["none"], None)
        raise AssertionError(expr.literal_kind)

    def name(self, expr: NameExpr, when_context: bool) -> ConstValue:
        name = expr.qualified
        if when_context:
            if name not in self.types.target.build_context:
                self.diagnostics.raise_error(
                    "OPENC-WHEN-CONTEXT-001", Phase.CONSTANT,
                    f"unknown build-context name '{name}'", expr.span, "constant.when",
                )
            value = self.types.target.build_context[name]
            if isinstance(value, bool):
                return ConstValue(self.types.types["bool"], value)
            if isinstance(value, int):
                return ConstValue(self.types.types["i64"], value)
            return ConstValue(self.types.types["text"], value)
        if name not in self.values:
            self.diagnostics.raise_error(
                "OPENC-CONSTANT-NAME-001", Phase.CONSTANT,
                f"'{name}' is not a known constant", expr.span, "constant.name",
            )
        return self.values[name]

    def unary(self, expr: UnaryExpr, expected, when_context: bool) -> ConstValue:
        assert expr.operand is not None
        value = self.evaluate(expr.operand, expected, when_context)
        if expr.op == "!":
            self.require_bool(value, expr)
            return ConstValue(self.types.types["bool"], not value.value)
        if expr.op == "+":
            self.require_numeric(value, expr)
            return value
        if expr.op == "-":
            self.require_numeric(value, expr)
            result = -value.value
            if value.type.is_integer():
                low, high = self.types.integer_range(value.type)
                if not low <= result <= high:
                    self.overflow(expr, value.type)
            return ConstValue(value.type, result)
        if expr.op == "~":
            if not value.type.is_integer():
                self.type_error(expr, "bitwise complement requires an integer")
            width, _ = self.types.integer_info(value.type) or (0, False)
            mask = (1 << width) - 1
            result = (~int(value.value)) & mask
            low, high = self.types.integer_range(value.type)
            if low < 0 and result > high:
                result -= 1 << width
            return ConstValue(value.type, result)
        self.type_error(expr, f"operator '{expr.op}' is not allowed in a constant expression")
        raise AssertionError("unreachable")

    def binary(self, expr: BinaryExpr, expected, when_context: bool) -> ConstValue:
        assert expr.left is not None and expr.right is not None
        left = self.evaluate(expr.left, expected, when_context)
        if expr.op == "&&":
            self.require_bool(left, expr)
            if not left.value:
                return ConstValue(self.types.types["bool"], False)
            right = self.evaluate(expr.right, self.types.types["bool"], when_context)
            self.require_bool(right, expr)
            return ConstValue(self.types.types["bool"], bool(right.value))
        if expr.op == "||":
            self.require_bool(left, expr)
            if left.value:
                return ConstValue(self.types.types["bool"], True)
            right = self.evaluate(expr.right, self.types.types["bool"], when_context)
            self.require_bool(right, expr)
            return ConstValue(self.types.types["bool"], bool(right.value))
        right = self.evaluate(expr.right, expected, when_context)

        if expr.op in {"==", "!="}:
            if not (self.types.can_losslessly_convert(left.type, right.type) or self.types.can_losslessly_convert(right.type, left.type)):
                self.type_error(expr, "equality operands are not comparable")
            value = left.value == right.value
            return ConstValue(self.types.types["bool"], value if expr.op == "==" else not value)
        if expr.op in {"<", "<=", ">", ">="}:
            if not (left.type.is_numeric() and right.type.is_numeric()) and not (left.type.kind == right.type.kind == "text"):
                self.type_error(expr, "relational operands must be compatible numeric or text constants")
            operations = {"<": lambda a, b: a < b, "<=": lambda a, b: a <= b, ">": lambda a, b: a > b, ">=": lambda a, b: a >= b}
            return ConstValue(self.types.types["bool"], operations[expr.op](left.value, right.value))
        if expr.op in {"&", "|", "^", "<<", ">>"}:
            if not left.type.is_integer() or not right.type.is_integer():
                self.type_error(expr, f"operator '{expr.op}' requires integer operands")
            result_type = self.types.common_numeric_type(left.type, right.type)
            if result_type is None:
                self.type_error(expr, "integer operands do not have a lossless common type")
            assert result_type is not None
            a, b = int(left.value), int(right.value)
            if expr.op in {"<<", ">>"}:
                width, _ = self.types.integer_info(result_type) or (0, False)
                if b < 0 or b >= width:
                    self.diagnostics.raise_error(
                        "OPENC-ARITH-SHIFT-RANGE-001", Phase.CONSTANT,
                        f"shift count {b} is outside [0, {width - 1}]", expr.span, "constant.numeric",
                    )
                result = a << b if expr.op == "<<" else a >> b
            else:
                result = {"&": a & b, "|": a | b, "^": a ^ b}[expr.op]
            return self.checked_integer(expr, result_type, result)
        if expr.op in {"+", "-", "*", "/", "%"}:
            result_type = self.types.common_numeric_type(left.type, right.type)
            if result_type is None:
                self.type_error(expr, "arithmetic operands do not have a lossless common type")
            assert result_type is not None
            a, b = left.value, right.value
            if expr.op in {"/", "%"} and b == 0:
                self.diagnostics.raise_error(
                    "OPENC-ARITH-DIVZERO-001", Phase.CONSTANT,
                    "division or remainder by zero", expr.span, "constant.numeric",
                )
            if expr.op == "+": result = a + b
            elif expr.op == "-": result = a - b
            elif expr.op == "*": result = a * b
            elif expr.op == "/":
                result = int(a / b) if result_type.is_integer() else a / b
            else:
                result = a - int(a / b) * b if result_type.is_integer() else math.fmod(a, b)
            if result_type.is_integer():
                return self.checked_integer(expr, result_type, int(result))
            if not math.isfinite(float(result)):
                self.diagnostics.raise_error(
                    "OPENC-FLOAT-NONFINITE-001", Phase.CONSTANT,
                    "constant floating operation produced a non-finite value", expr.span, "constant.numeric",
                )
            return ConstValue(result_type, float(result))
        self.type_error(expr, f"unsupported constant operator '{expr.op}'")
        raise AssertionError("unreachable")

    def checked_integer(self, expr: Expr, value_type, value: int) -> ConstValue:
        low, high = self.types.integer_range(value_type)
        if not low <= value <= high:
            self.overflow(expr, value_type)
        return ConstValue(value_type, value)

    def overflow(self, expr: Expr, value_type) -> None:
        self.diagnostics.raise_error(
            "OPENC-ARITH-STATIC-OVERFLOW-001", Phase.CONSTANT,
            f"constant operation overflows {value_type.display()}", expr.span, "constant.numeric",
        )

    def require_bool(self, value: ConstValue, expr: Expr) -> None:
        if value.type.kind != "bool":
            self.type_error(expr, "boolean operator requires bool operands")

    def require_numeric(self, value: ConstValue, expr: Expr) -> None:
        if not value.type.is_numeric():
            self.type_error(expr, "numeric unary operator requires a numeric operand")

    def type_error(self, expr: Expr, message: str) -> None:
        self.diagnostics.raise_error(
            "OPENC-CONSTANT-TYPE-001", Phase.CONSTANT, message, expr.span, "constant.type",
        )
