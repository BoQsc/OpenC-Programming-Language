"""Recursive-descent and Pratt parser for OpenC 1.0.

The parser recognizes the complete Core grammar plus the separately-scoped
Native declaration forms used by the authored Hosted standard library.  It does
not perform semantic lookup or type checking.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterable

from .diagnostics import DiagnosticEngine
from .model import (
    AggregateExpr, ArrayExpr, AssignExpr, BinaryExpr, BlockStmt, BreakStmt,
    CallArg, CallExpr, CastExpr, ConstDecl, ConstructExpr, ContinueStmt, Decl,
    DestroyExpr, EnumDecl, EnumItem, Expr, ExprStmt, FieldDecl, FieldInit,
    ForStmt, FunctionDecl, IfStmt, ImportDecl, IndexExpr, LiteralExpr,
    LocalDecl, MemberExpr, NameExpr, ParamDecl, Phase, RangeExpr, ReturnStmt,
    ScopeStmt, SourceUnit, Span, StatusExpr, StructDecl, SwitchCase, SwitchStmt,
    Token, TokenKind, TypeQueryExpr, TypeSyntax, UnaryExpr, UnsafeStmt,
    WhenDecl, WhenStmt, WhileStmt,
)


ASSIGNMENT_OPS = {"=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>="}
BINARY_PRECEDENCE: dict[str, int] = {
    "||": 1,
    "&&": 2,
    "|": 3,
    "^": 4,
    "&": 5,
    "==": 6, "!=": 6,
    "<": 7, "<=": 7, ">": 7, ">=": 7,
    "<<": 8, ">>": 8,
    "+": 9, "-": 9,
    "*": 10, "/": 10, "%": 10,
}
UNARY_OPS = {"!", "~", "+", "-", "&", "*"}
PRIMITIVE_TYPES = {
    "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "isize",
    "usize", "bool", "byte", "f32", "f64", "text", "status",
}
SIGNED_TYPES = {"i8", "i16", "i32", "i64"}
UNSIGNED_TYPES = {"u8", "u16", "u32", "u64"}


@dataclass(slots=True)
class ParserOptions:
    allow_native: bool = True
    parse_all_when_bodies: bool = True


class Parser:
    def __init__(self, tokens: list[Token], diagnostics: DiagnosticEngine, options: ParserOptions | None = None):
        self.tokens = tokens
        self.diagnostics = diagnostics
        self.options = options or ParserOptions()
        self.index = 0

    def parse_source_unit(self, module_name: str | None = None) -> SourceUnit:
        start = self.current().span
        imports: list[ImportDecl] = []
        declarations: list[Decl] = []
        while self.match("import"):
            imports.append(self.parse_import(self.previous()))
        while not self.at_end():
            declarations.append(self.parse_top_decl())
        end = self.current().span
        return SourceUnit(start.merge(end), imports, declarations, module_name)

    def parse_import(self, start_token: Token) -> ImportDecl:
        module, end_span = self.parse_qualified_name()
        semicolon = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after import")
        return ImportDecl(start_token.span.merge(semicolon.span), module)

    def parse_top_decl(self) -> Decl:
        exported = self.match("export")
        start = self.previous().span if exported else self.current().span
        if self.match("when"):
            condition = self.parse_when_expression()
            self.expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after when condition")
            declarations: list[Decl] = []
            while not self.check("}") and not self.at_end():
                declarations.append(self.parse_top_decl())
            end = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after when declarations")
            return WhenDecl(start.merge(end.span), "<when>", exported, condition, declarations)

        layout: str | None = None
        if self.match("layout"):
            if not self.options.allow_native:
                self.syntax_error("OPENC-NATIVE-NOT-ENABLED-001", "layout declarations require the Native component")
            self.expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after layout")
            layout = self.expect_identifier("expected layout ABI name").text
            self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after layout ABI")

        if self.match("struct"):
            return self.parse_struct(start, exported, False, layout)
        if self.match("resource"):
            if layout is not None:
                self.syntax_error("OPENC-NATIVE-LAYOUT-RESOURCE-001", "layout cannot be applied to a resource declaration")
            return self.parse_struct(start, exported, True, None)
        if self.match("enum"):
            if layout is not None:
                self.syntax_error("OPENC-NATIVE-LAYOUT-ENUM-001", "layout enum is not part of OpenC Native 1.0")
            return self.parse_enum(start, exported)
        if self.match("const"):
            if layout is not None:
                self.syntax_error("OPENC-NATIVE-LAYOUT-CONST-001", "layout cannot be applied to a constant")
            type_syntax = self.parse_type(context="module_const", allow_ref=False, allow_storage=False)
            name = self.expect_identifier("expected constant name")
            self.expect("=", "OPENC-SYNTAX-ASSIGN-001", "expected '=' in constant declaration")
            value = self.parse_expression(constant=True)
            end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after constant")
            return ConstDecl(start.merge(end.span), name.text, exported, type_syntax, value)

        external_abi: str | None = None
        external_symbol: str | None = None
        if self.match("external"):
            if not self.options.allow_native:
                self.syntax_error("OPENC-NATIVE-NOT-ENABLED-001", "external declarations require the Native component")
            self.expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after external")
            external_abi = self.expect_identifier("expected external ABI name").text
            if self.match(","):
                symbol = self.current()
                if symbol.kind != TokenKind.TEXT:
                    self.syntax_error("OPENC-NATIVE-SYMBOL-001", "external symbol alias must be a text literal")
                self.advance()
                external_symbol = str(symbol.value)
            self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after external ABI")

        unsafe = self.match("unsafe")
        result_mode = "ordinary"
        if self.match("void"):
            result_type = None
            result_mode = "void"
        elif self.match("own"):
            result_type = self.parse_ptr_type(self.previous().span)
            result_mode = "own"
        else:
            result_type = self.parse_type(context="result", allow_storage=False)

        name = self.expect_identifier("expected function name")
        self.expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after function name")
        params: list[ParamDecl] = []
        if not self.check(")"):
            while True:
                params.append(self.parse_parameter())
                if not self.match(","):
                    break
        self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after parameters")

        if external_abi is not None:
            end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "external function declaration requires ';'")
            return FunctionDecl(
                start.merge(end.span), name.text, exported, result_type, result_mode,
                params, None, unsafe, external_abi, external_symbol,
            )

        if layout is not None:
            self.syntax_error("OPENC-NATIVE-LAYOUT-FUNCTION-001", "layout cannot be applied to a function")
        body = self.parse_block()
        return FunctionDecl(
            start.merge(body.span), name.text, exported, result_type, result_mode,
            params, body, unsafe, None, None,
        )

    def parse_struct(self, start: Span, exported: bool, resource: bool, layout: str | None) -> StructDecl:
        name = self.expect_identifier("expected declaration name")
        self.expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after declaration name")
        fields: list[FieldDecl] = []
        while not self.check("}") and not self.at_end():
            field_start = self.current().span
            ownership = resource and self.match("own")
            if ownership:
                type_syntax = self.parse_ptr_type(self.previous().span)
            else:
                type_syntax = self.parse_type(context="resource_field" if resource else "struct_field", allow_ref=False, allow_storage=False)
            field_name = self.expect_identifier("expected field name")
            default = None
            if self.match("="):
                if ownership:
                    self.syntax_error("OPENC-RESOURCE-FIELD-DEFAULT-001", "owning resource fields cannot declare defaults")
                default = self.parse_expression(constant=True)
            end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after field declaration")
            fields.append(FieldDecl(field_start.merge(end.span), field_name.text, type_syntax, default, ownership))
        close = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after fields")
        if self.match(";"):
            self.syntax_error("OPENC-STRUCT-TRAILING-SEMICOLON-001", "struct and resource declarations do not use a trailing semicolon", self.previous())
        return StructDecl(start.merge(close.span), name.text, exported, fields, resource, layout)

    def parse_enum(self, start: Span, exported: bool) -> EnumDecl:
        base_type = None
        if self.current().text in UNSIGNED_TYPES:
            token = self.advance()
            base_type = TypeSyntax(token.span, "named", token.text)
        name = self.expect_identifier("expected enum name")
        self.expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after enum name")
        items: list[EnumItem] = []
        while not self.check("}") and not self.at_end():
            item = self.expect_identifier("expected enum item name")
            value = None
            if self.match("="):
                value = self.parse_expression(constant=True)
            item_span = item.span.merge(value.span) if value is not None else item.span
            items.append(EnumItem(item_span, item.text, value))
            if not self.match(","):
                break
        close = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after enum")
        if self.match(";"):
            self.syntax_error("OPENC-ENUM-TRAILING-SEMICOLON-001", "enum declarations do not use a trailing semicolon", self.previous())
        return EnumDecl(start.merge(close.span), name.text, exported, base_type, items)

    def parse_parameter(self) -> ParamDecl:
        start = self.current().span
        mode = "ordinary"
        if self.match("out"):
            mode = "out"
            if self.match("own"):
                mode = "out_own"
                type_syntax = self.parse_ptr_type(self.previous().span)
            else:
                type_syntax = self.parse_type(context="out_parameter", allow_ref=False, allow_storage=False)
        elif self.match("own"):
            mode = "own"
            if self.check("ptr"):
                type_syntax = self.parse_ptr_type(self.current().span)
            else:
                type_syntax = self.parse_named_type(allow_const=False)
        else:
            type_syntax = self.parse_type(context="parameter", allow_storage=False)
        name = self.expect_identifier("expected parameter name")
        return ParamDecl(start.merge(name.span), name.text, type_syntax, mode)

    def parse_block(self) -> BlockStmt:
        open_token = self.expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{'")
        items: list = []
        while not self.check("}") and not self.at_end():
            if self.looks_like_local_decl():
                items.append(self.parse_local_decl())
            else:
                items.append(self.parse_statement())
        close = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after block")
        return BlockStmt(open_token.span.merge(close.span), items)

    def looks_like_local_decl(self) -> bool:
        token = self.current().text
        if token in {"ref", "ptr", "optional", "storage", "const"} | PRIMITIVE_TYPES:
            return True
        if self.current().kind == TokenKind.IDENTIFIER:
            # Qualified type names are followed by an identifier after optional dots/suffix.
            cursor = self.index
            while cursor + 1 < len(self.tokens) and self.tokens[cursor + 1].text == ".":
                cursor += 2
            if cursor + 1 < len(self.tokens) and self.tokens[cursor + 1].kind == TokenKind.IDENTIFIER:
                return True
            if cursor + 1 < len(self.tokens) and self.tokens[cursor + 1].text == "[":
                return True
        return False

    def parse_local_decl(self) -> LocalDecl:
        start = self.current().span
        type_syntax = self.parse_type(context="local")
        name = self.expect_identifier("expected local variable name")
        initializer = None
        if self.match("="):
            initializer = self.parse_expression()
        end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after local declaration")
        return LocalDecl(start.merge(end.span), name.text, type_syntax, initializer)

    def parse_statement(self):
        if self.check("{"):
            return self.parse_block()
        if self.match("if"):
            start = self.previous().span
            condition = self.parse_expression()
            then_branch = self.parse_required_block("if")
            else_branch = None
            if self.match("else"):
                if self.match("if"):
                    else_branch = self.parse_if_after_keyword(self.previous().span)
                else:
                    else_branch = self.parse_required_block("else")
            end = else_branch.span if else_branch else then_branch.span
            return IfStmt(start.merge(end), condition, then_branch, else_branch)
        if self.match("while"):
            start = self.previous().span
            condition = self.parse_expression()
            body = self.parse_required_block("while")
            return WhileStmt(start.merge(body.span), condition, body)
        if self.match("for"):
            start = self.previous().span
            initializer = None
            if not self.check(";"):
                if self.looks_like_local_decl_for_header():
                    type_syntax = self.parse_type(context="local")
                    name = self.expect_identifier("expected for-loop variable name")
                    init_expr = self.parse_expression() if self.match("=") else None
                    init_span = type_syntax.span.merge(init_expr.span if init_expr else name.span)
                    initializer = LocalDecl(init_span, name.text, type_syntax, init_expr)
                else:
                    initializer = self.parse_expression()
            self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after for initializer")
            condition = None if self.check(";") else self.parse_expression()
            self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after for condition")
            update = None if self.check("{") else self.parse_expression()
            body = self.parse_required_block("for")
            return ForStmt(start.merge(body.span), initializer, condition, update, body)
        if self.match("switch"):
            return self.parse_switch(self.previous().span)
        if self.match("break"):
            end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after break")
            return BreakStmt(self.previous(1).span.merge(end.span))
        if self.match("continue"):
            end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after continue")
            return ContinueStmt(self.previous(1).span.merge(end.span))
        if self.match("return"):
            start = self.previous().span
            value = None if self.check(";") else self.parse_expression()
            end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after return")
            return ReturnStmt(start.merge(end.span), value)
        if self.match("scope"):
            start = self.previous().span
            action = self.parse_expression()
            if not isinstance(action, (CallExpr, DestroyExpr)):
                self.syntax_error("OPENC-SCOPE-ACTION-001", "scope action must be a call or destroy expression")
            end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after scope action")
            return ScopeStmt(start.merge(end.span), action)
        if self.match("unsafe"):
            start = self.previous().span
            body = self.parse_required_block("unsafe")
            return UnsafeStmt(start.merge(body.span), body)
        if self.match("when"):
            start = self.previous().span
            condition = self.parse_when_expression()
            body = self.parse_required_block("when")
            return WhenStmt(start.merge(body.span), condition, body)
        expr = self.parse_expression()
        end = self.expect(";", "OPENC-SYNTAX-SEMICOLON-001", "expected ';' after expression")
        return ExprStmt(expr.span.merge(end.span), expr)

    def parse_if_after_keyword(self, start: Span) -> IfStmt:
        condition = self.parse_expression()
        then_branch = self.parse_required_block("if")
        else_branch = None
        if self.match("else"):
            if self.match("if"):
                else_branch = self.parse_if_after_keyword(self.previous().span)
            else:
                else_branch = self.parse_required_block("else")
        end = else_branch.span if else_branch else then_branch.span
        return IfStmt(start.merge(end), condition, then_branch, else_branch)

    def parse_required_block(self, owner: str) -> BlockStmt:
        if not self.check("{"):
            self.syntax_error("OPENC-SYNTAX-BRACES-001", f"{owner} body requires braces")
        return self.parse_block()

    def looks_like_local_decl_for_header(self) -> bool:
        return self.looks_like_local_decl()

    def parse_switch(self, start: Span) -> SwitchStmt:
        value = self.parse_expression()
        self.expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after switch value")
        cases: list[SwitchCase] = []
        saw_default = False
        while not self.check("}") and not self.at_end():
            if self.match("case"):
                case_start = self.previous().span
                case_value = self.parse_expression(constant=True)
                body = self.parse_required_block("case")
                cases.append(SwitchCase(case_start.merge(body.span), case_value, body, False))
                continue
            if self.match("default"):
                if saw_default:
                    self.syntax_error("OPENC-SWITCH-DEFAULT-DUPLICATE-001", "switch cannot contain more than one default case")
                saw_default = True
                case_start = self.previous().span
                body = self.parse_required_block("default")
                cases.append(SwitchCase(case_start.merge(body.span), None, body, True))
                continue
            self.syntax_error("OPENC-SYNTAX-SWITCH-001", "expected case, default, or '}' in switch")
        close = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after switch")
        return SwitchStmt(start.merge(close.span), value, cases)

    def parse_type(self, context: str, allow_ref: bool = True, allow_storage: bool = True) -> TypeSyntax:
        start = self.current().span
        leading_const = self.match("const")
        if self.match("ref"):
            if not allow_ref or leading_const:
                self.syntax_error("OPENC-TYPE-CONSTRUCTOR-ORDER-001", "ref must begin the type and is not allowed in this context")
            inner_const = self.match("const")
            inner = self.parse_named_type(allow_const=False, allow_suffix="array")
            return TypeSyntax(start.merge(inner.span), "ref", inner=inner, const=inner_const)
        if self.match("ptr"):
            if leading_const:
                self.syntax_error("OPENC-TYPE-CONSTRUCTOR-ORDER-001", "ptr must begin the type")
            inner_const = self.match("const")
            inner = self.parse_named_type(allow_const=False, allow_suffix=None)
            return TypeSyntax(start.merge(inner.span), "ptr", inner=inner, const=inner_const)
        if self.match("optional"):
            inner = self.parse_named_type(allow_const=False, allow_suffix="array")
            return TypeSyntax(start.merge(inner.span), "optional", inner=inner, const=leading_const)
        if self.match("storage"):
            if not allow_storage or leading_const:
                self.syntax_error("OPENC-TYPE-CONSTRUCTOR-ORDER-001", "storage must begin the type and is not allowed in this context")
            inner = self.parse_named_type(allow_const=False, allow_suffix="array")
            return TypeSyntax(start.merge(inner.span), "storage", inner=inner)
        named = self.parse_named_type(allow_const=False, allow_suffix="value")
        named.const = leading_const
        return named

    def parse_named_type(self, allow_const: bool, allow_suffix: str | None = None) -> TypeSyntax:
        start = self.current().span
        const = allow_const and self.match("const")
        name, name_span = self.parse_qualified_name()
        base = TypeSyntax(start.merge(name_span), "named", name, None, const)
        if allow_suffix is not None and self.match("["):
            bracket_start = self.previous().span
            if self.match("]"):
                if allow_suffix != "value":
                    self.syntax_error("OPENC-TYPE-SLICE-CONTEXT-001", "slice suffix is not allowed in this type context")
                return TypeSyntax(base.span.merge(self.previous().span), "slice", inner=base)
            length = self.parse_expression(constant=True)
            close = self.expect("]", "OPENC-SYNTAX-BRACKET-001", "expected ']' after array length")
            return TypeSyntax(base.span.merge(close.span), "array", inner=base, length=length)
        return base

    def parse_ptr_type(self, start: Span) -> TypeSyntax:
        self.expect("ptr", "OPENC-TYPE-PTR-001", "expected ptr type")
        const = self.match("const")
        inner = self.parse_named_type(allow_const=False, allow_suffix=None)
        return TypeSyntax(start.merge(inner.span), "ptr", inner=inner, const=const)

    def parse_expression(self, constant: bool = False, min_precedence: int = 0) -> Expr:
        left = self.parse_unary(constant)
        while True:
            token = self.current()
            if token.text in ASSIGNMENT_OPS and min_precedence <= 0 and not constant:
                op = self.advance()
                right = self.parse_expression(False, 0)
                left = AssignExpr(left.span.merge(right.span), None, None, False, op.text, left, right)
                continue
            precedence = BINARY_PRECEDENCE.get(token.text)
            if precedence is None or precedence < min_precedence:
                break
            op = self.advance()
            right = self.parse_expression(constant, precedence + 1)
            left = BinaryExpr(left.span.merge(right.span), None, None, False, op.text, left, right)
        return left

    def parse_unary(self, constant: bool) -> Expr:
        if self.current().text in UNARY_OPS:
            op = self.advance()
            if constant and op.text in {"&", "*"}:
                self.syntax_error("OPENC-CONSTANT-UNSAFE-001", "pointer operators are not allowed in constant expressions", op)
            operand = self.parse_unary(constant)
            return UnaryExpr(op.span.merge(operand.span), None, None, False, op.text, operand)
        if self.match("cast"):
            return self.parse_cast(self.previous(), "checked", constant)
        if self.match("cast_unchecked"):
            if constant:
                self.syntax_error("OPENC-CONSTANT-CAST-001", "unchecked cast is not allowed in a constant expression", self.previous())
            return self.parse_cast(self.previous(), "unchecked", constant)
        if self.match("reinterpret"):
            if constant:
                self.syntax_error("OPENC-CONSTANT-REINTERPRET-001", "reinterpret is not allowed in a constant expression", self.previous())
            return self.parse_cast(self.previous(), "reinterpret", constant)
        if self.match("construct"):
            if constant:
                self.syntax_error("OPENC-CONSTANT-CONSTRUCT-001", "construct is not allowed in a constant expression", self.previous())
            return self.parse_construct(self.previous())
        if self.match("destroy"):
            if constant:
                self.syntax_error("OPENC-CONSTANT-DESTROY-001", "destroy is not allowed in a constant expression", self.previous())
            start = self.previous().span
            self.expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after destroy")
            value = self.parse_expression()
            close = self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after destroy argument")
            return DestroyExpr(start.merge(close.span), None, None, False, value)
        if self.match("size_of") or self.match("align_of"):
            op = self.previous()
            self.expect("(", "OPENC-SYNTAX-PAREN-001", f"expected '(' after {op.text}")
            type_syntax = self.parse_type(context="type_query")
            close = self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after type query")
            return TypeQueryExpr(op.span.merge(close.span), None, None, False, op.text, type_syntax)
        return self.parse_postfix(constant)

    def parse_cast(self, start_token: Token, kind: str, constant: bool) -> Expr:
        self.expect("(", "OPENC-SYNTAX-PAREN-001", f"expected '(' after {start_token.text}")
        type_syntax = self.parse_type(context="cast")
        self.expect(",", "OPENC-SYNTAX-COMMA-001", "expected ',' between cast type and value")
        value = self.parse_expression(constant)
        close = self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after cast")
        return CastExpr(start_token.span.merge(close.span), None, None, False, kind, type_syntax, value)

    def parse_construct(self, start_token: Token) -> Expr:
        self.expect("(", "OPENC-SYNTAX-PAREN-001", "expected '(' after construct")
        type_name, _ = self.parse_qualified_name()
        self.expect(",", "OPENC-SYNTAX-COMMA-001", "expected ',' after construct type")
        storage = self.parse_expression()
        self.expect(",", "OPENC-SYNTAX-COMMA-001", "expected ',' before constructed value")
        value = self.parse_expression()
        close = self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after construct")
        return ConstructExpr(start_token.span.merge(close.span), None, None, False, type_name, storage, value)

    def parse_postfix(self, constant: bool) -> Expr:
        expr = self.parse_primary(constant)
        while True:
            if self.match("("):
                if constant:
                    self.syntax_error("OPENC-CONSTANT-CALL-001", "function calls are not allowed in constant expressions", self.previous())
                args: list[CallArg] = []
                if not self.check(")"):
                    while True:
                        arg_start = self.current().span
                        mode = "out" if self.match("out") else "ordinary"
                        value = self.parse_expression()
                        args.append(CallArg(arg_start.merge(value.span), value, mode))
                        if not self.match(","):
                            break
                close = self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after arguments")
                expr = CallExpr(expr.span.merge(close.span), None, None, False, expr, args)
                continue
            if self.match("."):
                member = self.expect_identifier("expected member name after '.'")
                expr = MemberExpr(expr.span.merge(member.span), None, None, False, expr, member.text)
                continue
            if self.match("["):
                open_token = self.previous()
                start_expr = None if self.check("..") or self.check("]") else self.parse_expression(constant)
                if self.match(".."):
                    end_expr = None if self.check("]") else self.parse_expression(constant)
                    close = self.expect("]", "OPENC-SYNTAX-BRACKET-001", "expected ']' after range")
                    expr = RangeExpr(expr.span.merge(close.span), None, None, False, expr, start_expr, end_expr)
                else:
                    if start_expr is None:
                        self.syntax_error("OPENC-SYNTAX-INDEX-001", "index expression cannot be empty", open_token)
                    close = self.expect("]", "OPENC-SYNTAX-BRACKET-001", "expected ']' after index")
                    expr = IndexExpr(expr.span.merge(close.span), None, None, False, expr, start_expr)
                continue
            break
        return expr

    def parse_primary(self, constant: bool) -> Expr:
        token = self.current()
        if token.kind == TokenKind.INTEGER:
            self.advance()
            return LiteralExpr(token.span, None, None, False, "integer", token.value, token.text)
        if token.kind == TokenKind.FLOAT:
            self.advance()
            return LiteralExpr(token.span, None, None, False, "float", token.value, token.text)
        if token.kind == TokenKind.TEXT:
            self.advance()
            return LiteralExpr(token.span, None, None, False, "text", token.value, token.text)
        if token.text in {"true", "false", "null", "none"}:
            self.advance()
            kind = "bool" if token.text in {"true", "false"} else token.text
            value = token.text == "true" if kind == "bool" else None
            return LiteralExpr(token.span, None, None, False, kind, value, token.text)
        if self.match("status") and self.check("{"):
            return self.parse_status_initializer(self.previous())
        if self.match("{"):
            return self.parse_array_initializer(self.previous(), constant)
        if self.match("("):
            expr = self.parse_expression(constant)
            close = self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' after expression")
            expr.span = self.previous(1).span.merge(close.span) if hasattr(expr, "span") else close.span
            return expr
        if token.kind == TokenKind.IDENTIFIER:
            name, name_span = self.parse_qualified_name()
            if self.check("{"):
                return self.parse_aggregate_initializer(name, name_span, constant)
            return NameExpr(name_span, None, None, False, name.split("."))
        self.syntax_error("OPENC-SYNTAX-EXPRESSION-001", "expected expression")
        raise AssertionError("unreachable")

    def parse_status_initializer(self, start_token: Token) -> StatusExpr:
        self.expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after status")
        code = None
        message = None
        seen: set[str] = set()
        if not self.check("}"):
            while True:
                field = self.expect_identifier("expected status field name")
                if field.text not in {"code", "message"}:
                    self.syntax_error("OPENC-STATUS-FIELD-001", f"unknown status field '{field.text}'", field)
                if field.text in seen:
                    self.syntax_error("OPENC-STATUS-FIELD-DUPLICATE-001", f"duplicate status field '{field.text}'", field)
                seen.add(field.text)
                self.expect("=", "OPENC-SYNTAX-ASSIGN-001", "expected '=' in status initializer")
                value = self.parse_expression()
                if field.text == "code":
                    code = value
                else:
                    message = value
                if not self.match(","):
                    break
                if self.check("}"):
                    break
        close = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after status initializer")
        if code is None:
            self.syntax_error("OPENC-STATUS-CODE-REQUIRED-001", "status initializer requires a code field", start_token)
        return StatusExpr(start_token.span.merge(close.span), None, None, False, code, message)

    def parse_array_initializer(self, open_token: Token, constant: bool) -> ArrayExpr:
        values: list[Expr] = []
        if not self.check("}"):
            while True:
                values.append(self.parse_expression(constant))
                if not self.match(","):
                    break
                if self.check("}"):
                    break
        close = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after array initializer")
        return ArrayExpr(open_token.span.merge(close.span), None, None, False, values)

    def parse_aggregate_initializer(self, type_name: str, name_span: Span, constant: bool) -> AggregateExpr:
        self.expect("{", "OPENC-SYNTAX-BRACES-001", "expected '{' after aggregate type")
        fields: list[FieldInit] = []
        if not self.check("}"):
            while True:
                field_start = self.current().span
                ownership = self.match("own")
                name = self.expect_identifier("expected aggregate field name")
                self.expect("=", "OPENC-SYNTAX-ASSIGN-001", "expected '=' after field name")
                if ownership:
                    if constant:
                        self.syntax_error("OPENC-CONSTANT-OWNERSHIP-001", "ownership initializer is not constant")
                    source_name, source_span = self.parse_qualified_name()
                    value = NameExpr(source_span, None, None, False, source_name.split("."))
                else:
                    value = self.parse_expression(constant)
                fields.append(FieldInit(field_start.merge(value.span), name.text, value, ownership))
                if not self.match(","):
                    break
                if self.check("}"):
                    break
        close = self.expect("}", "OPENC-SYNTAX-BRACES-001", "expected '}' after aggregate initializer")
        return AggregateExpr(name_span.merge(close.span), None, None, False, type_name, fields)

    def parse_when_expression(self) -> Expr:
        return self.parse_when_or()

    def parse_when_or(self) -> Expr:
        left = self.parse_when_and()
        while self.match("||"):
            op = self.previous()
            right = self.parse_when_and()
            left = BinaryExpr(left.span.merge(right.span), None, None, False, op.text, left, right)
        return left

    def parse_when_and(self) -> Expr:
        left = self.parse_when_equality()
        while self.match("&&"):
            op = self.previous()
            right = self.parse_when_equality()
            left = BinaryExpr(left.span.merge(right.span), None, None, False, op.text, left, right)
        return left

    def parse_when_equality(self) -> Expr:
        left = self.parse_when_relational()
        if self.current().text in {"==", "!="}:
            op = self.advance()
            right = self.parse_when_relational()
            return BinaryExpr(left.span.merge(right.span), None, None, False, op.text, left, right)
        return left

    def parse_when_relational(self) -> Expr:
        left = self.parse_when_unary()
        if self.current().text in {"<", "<=", ">", ">="}:
            op = self.advance()
            right = self.parse_when_unary()
            return BinaryExpr(left.span.merge(right.span), None, None, False, op.text, left, right)
        return left

    def parse_when_unary(self) -> Expr:
        if self.match("!"):
            op = self.previous()
            operand = self.parse_when_unary()
            return UnaryExpr(op.span.merge(operand.span), None, None, False, "!", operand)
        if self.match("("):
            open_token = self.previous()
            expr = self.parse_when_expression()
            close = self.expect(")", "OPENC-SYNTAX-PAREN-001", "expected ')' in when condition")
            expr.span = open_token.span.merge(close.span)
            return expr
        token = self.current()
        if token.kind == TokenKind.INTEGER:
            self.advance()
            return LiteralExpr(token.span, None, None, False, "integer", token.value, token.text)
        if token.kind == TokenKind.TEXT:
            self.advance()
            return LiteralExpr(token.span, None, None, False, "text", token.value, token.text)
        if token.text in {"true", "false"}:
            self.advance()
            return LiteralExpr(token.span, None, None, False, "bool", token.text == "true", token.text)
        if token.text in {"+", "-"} and self.peek_token().kind == TokenKind.INTEGER:
            sign = self.advance()
            number = self.advance()
            value = number.value if sign.text == "+" else -number.value
            return LiteralExpr(sign.span.merge(number.span), None, None, False, "integer", value, sign.text + number.text)
        if token.kind == TokenKind.IDENTIFIER:
            name, span = self.parse_qualified_name()
            if "." not in name:
                self.syntax_error("OPENC-WHEN-CONTEXT-001", "when context names must be fully qualified", token)
            return NameExpr(span, None, None, False, name.split("."))
        self.syntax_error("OPENC-WHEN-EXPR-001", "expression form is not allowed in a when condition")
        raise AssertionError("unreachable")

    def parse_qualified_name(self) -> tuple[str, Span]:
        first = self.expect_identifier("expected identifier")
        parts = [first.text]
        span = first.span
        while self.match("."):
            part = self.expect_identifier("expected identifier after '.'")
            parts.append(part.text)
            span = span.merge(part.span)
        return ".".join(parts), span

    def expect_identifier(self, message: str) -> Token:
        token = self.current()
        if token.kind != TokenKind.IDENTIFIER or token.text in {
            "import", "export", "struct", "resource", "enum", "const", "unsafe",
            "void", "own", "out", "when", "ref", "ptr", "optional", "storage",
            "if", "else", "while", "for", "switch", "case", "default", "break",
            "continue", "return", "scope", "cast", "cast_unchecked", "reinterpret",
            "construct", "destroy", "size_of", "align_of", "true", "false", "null", "none",
        }:
            self.syntax_error("OPENC-SYNTAX-IDENTIFIER-001", message, token)
        return self.advance()

    def expect(self, text: str, rule_id: str, message: str) -> Token:
        if not self.check(text):
            self.syntax_error(rule_id, message)
        return self.advance()

    def match(self, text: str) -> bool:
        if self.check(text):
            self.advance()
            return True
        return False

    def check(self, text: str) -> bool:
        return self.current().text == text

    def advance(self) -> Token:
        token = self.current()
        if not self.at_end():
            self.index += 1
        return token

    def current(self) -> Token:
        return self.tokens[self.index]

    def peek_token(self, distance: int = 1) -> Token:
        index = min(self.index + distance, len(self.tokens) - 1)
        return self.tokens[index]

    def previous(self, distance: int = 1) -> Token:
        return self.tokens[max(0, self.index - distance)]

    def at_end(self) -> bool:
        return self.current().kind == TokenKind.EOF

    def syntax_error(self, rule_id: str, message: str, token: Token | None = None) -> None:
        token = token or self.current()
        self.diagnostics.raise_error(rule_id, Phase.SYNTAX, message, token.span, "syntax")
