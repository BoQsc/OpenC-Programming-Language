"""Lower typed OpenC syntax into structured target-independent Core IR."""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

from .ir import BasicBlock, Function, Instruction, Module, Program, Terminator, Value
from .model import (
    AssignExpr, BinaryExpr, BlockStmt, BreakStmt, CallExpr, CastExpr, ConstDecl,
    ConstructExpr, ContinueStmt, DestroyExpr, Expr, ExprStmt, ForStmt,
    FunctionDecl, IfStmt, IndexExpr, LiteralExpr, LocalDecl, MemberExpr,
    NameExpr, RangeExpr, ReturnStmt, ScopeStmt, SourceUnit, StatusExpr,
    SwitchStmt, TypeQueryExpr, UnaryExpr, UnsafeStmt, WhenStmt, WhileStmt,
)
from .semantic import SemanticProgram


class FunctionLowerer:
    def __init__(self, module_name: str, declaration: FunctionDecl, semantic: SemanticProgram):
        self.module_name = module_name
        self.declaration = declaration
        self.semantic = semantic
        self.signature = semantic.signatures[id(declaration)]
        self.blocks: list[BasicBlock] = []
        self.current = self.new_block("entry")
        self.temp_index = 0
        self.block_index = 0
        self.break_targets: list[str] = []
        self.continue_targets: list[str] = []
        self.cleanup_scopes: list[list[Expr]] = [[]]

    def new_block(self, prefix: str) -> BasicBlock:
        name = prefix if not self.blocks else f"{prefix}.{len(self.blocks)}"
        block = BasicBlock(name)
        self.blocks.append(block)
        return block

    def temp(self, value_type, prefix: str = "tmp") -> Value:
        self.temp_index += 1
        return Value(f"%{prefix}.{self.temp_index}", value_type)

    def emit(self, op: str, operands: list[Any], value_type=None, span=None, metadata=None) -> Value | None:
        result = self.temp(value_type, op) if value_type is not None else None
        self.current.instructions.append(Instruction(op, operands, result, span, metadata or {}))
        return result

    def terminate(self, op: str, operands=None, targets=None, span=None) -> None:
        self.current.terminator = Terminator(op, operands or [], targets or [], span)

    def lower(self) -> Function:
        if self.declaration.body is not None:
            self.lower_block(self.declaration.body, create_cleanup_scope=False)
            if self.current.terminator is None:
                self.emit_cleanups(all_scopes=True)
                self.terminate("return", [], [], self.declaration.body.span)
        params = [Value(param.name, value_type) for param, value_type in self.signature.params]
        return Function(
            self.declaration.name, self.signature.result, params, self.blocks,
            self.declaration.external_abi, self.declaration.unsafe,
        )

    def lower_block(self, block: BlockStmt, create_cleanup_scope: bool = True) -> None:
        if create_cleanup_scope:
            self.cleanup_scopes.append([])
        for item in block.items:
            if self.current.terminator is not None:
                break
            if isinstance(item, LocalDecl):
                self.emit("declare", [item.name, item.type_syntax.display()], span=item.span)
                if item.initializer is not None:
                    value = self.lower_expr(item.initializer)
                    self.emit("store", [item.name, value], span=item.span)
            else:
                self.lower_stmt(item)
        if create_cleanup_scope:
            if self.current.terminator is None:
                self.emit_cleanups(scope_count=1)
            self.cleanup_scopes.pop()

    def lower_stmt(self, stmt) -> None:
        if isinstance(stmt, BlockStmt):
            self.lower_block(stmt)
        elif isinstance(stmt, ExprStmt):
            if stmt.expr: self.lower_expr(stmt.expr)
        elif isinstance(stmt, ReturnStmt):
            value = self.lower_expr(stmt.value) if stmt.value else None
            self.emit_cleanups(all_scopes=True)
            self.terminate("return", [value] if value else [], span=stmt.span)
        elif isinstance(stmt, ScopeStmt):
            assert stmt.action is not None
            self.cleanup_scopes[-1].append(stmt.action)
            self.emit("register_cleanup", [self.describe_expr(stmt.action)], span=stmt.span)
        elif isinstance(stmt, UnsafeStmt):
            assert stmt.body
            self.emit("unsafe_begin", [], span=stmt.span)
            self.lower_block(stmt.body)
            self.emit("unsafe_end", [], span=stmt.span)
        elif isinstance(stmt, IfStmt):
            self.lower_if(stmt)
        elif isinstance(stmt, WhileStmt):
            self.lower_while(stmt)
        elif isinstance(stmt, ForStmt):
            self.lower_for(stmt)
        elif isinstance(stmt, SwitchStmt):
            self.lower_switch(stmt)
        elif isinstance(stmt, BreakStmt):
            self.emit_cleanups(scope_count=1)
            self.terminate("branch", [], [self.break_targets[-1]], stmt.span)
        elif isinstance(stmt, ContinueStmt):
            self.emit_cleanups(scope_count=1)
            self.terminate("branch", [], [self.continue_targets[-1]], stmt.span)
        elif isinstance(stmt, WhenStmt):
            if stmt.condition and stmt.condition.constant_value and stmt.condition.constant_value.value:
                assert stmt.body
                self.lower_block(stmt.body)

    def lower_if(self, stmt: IfStmt) -> None:
        assert stmt.condition and stmt.then_branch
        condition = self.lower_expr(stmt.condition)
        then_block = self.new_block("if.then")
        else_block = self.new_block("if.else")
        merge_block = self.new_block("if.merge")
        self.terminate("cond_branch", [condition], [then_block.name, else_block.name], stmt.condition.span)
        self.current = then_block
        self.lower_block(stmt.then_branch)
        if self.current.terminator is None:
            self.terminate("branch", [], [merge_block.name], stmt.then_branch.span)
        self.current = else_block
        if stmt.else_branch is not None:
            if isinstance(stmt.else_branch, BlockStmt):
                self.lower_block(stmt.else_branch)
            else:
                self.lower_if(stmt.else_branch)
        if self.current.terminator is None:
            self.terminate("branch", [], [merge_block.name], stmt.span)
        self.current = merge_block

    def lower_while(self, stmt: WhileStmt) -> None:
        assert stmt.condition and stmt.body
        cond_block = self.new_block("while.cond")
        body_block = self.new_block("while.body")
        exit_block = self.new_block("while.exit")
        self.terminate("branch", [], [cond_block.name], stmt.span)
        self.current = cond_block
        condition = self.lower_expr(stmt.condition)
        self.terminate("cond_branch", [condition], [body_block.name, exit_block.name], stmt.condition.span)
        self.break_targets.append(exit_block.name)
        self.continue_targets.append(cond_block.name)
        self.current = body_block
        self.lower_block(stmt.body)
        if self.current.terminator is None:
            self.terminate("branch", [], [cond_block.name], stmt.body.span)
        self.break_targets.pop(); self.continue_targets.pop()
        self.current = exit_block

    def lower_for(self, stmt: ForStmt) -> None:
        if isinstance(stmt.initializer, LocalDecl):
            self.emit("declare", [stmt.initializer.name, stmt.initializer.type_syntax.display()], span=stmt.initializer.span)
            if stmt.initializer.initializer:
                self.emit("store", [stmt.initializer.name, self.lower_expr(stmt.initializer.initializer)], span=stmt.initializer.span)
        elif isinstance(stmt.initializer, Expr):
            self.lower_expr(stmt.initializer)
        cond_block = self.new_block("for.cond")
        body_block = self.new_block("for.body")
        update_block = self.new_block("for.update")
        exit_block = self.new_block("for.exit")
        self.terminate("branch", [], [cond_block.name], stmt.span)
        self.current = cond_block
        condition = self.lower_expr(stmt.condition) if stmt.condition else True
        self.terminate("cond_branch", [condition], [body_block.name, exit_block.name], stmt.span)
        self.break_targets.append(exit_block.name); self.continue_targets.append(update_block.name)
        self.current = body_block
        assert stmt.body
        self.lower_block(stmt.body)
        if self.current.terminator is None:
            self.terminate("branch", [], [update_block.name], stmt.body.span)
        self.current = update_block
        if stmt.update: self.lower_expr(stmt.update)
        self.terminate("branch", [], [cond_block.name], stmt.span)
        self.break_targets.pop(); self.continue_targets.pop()
        self.current = exit_block

    def lower_switch(self, stmt: SwitchStmt) -> None:
        assert stmt.value
        subject = self.lower_expr(stmt.value)
        merge = self.new_block("switch.merge")
        case_blocks = [self.new_block("switch.case") for _ in stmt.cases]
        default_target = merge.name
        case_operands: list[Any] = []
        targets: list[str] = []
        for case, block in zip(stmt.cases, case_blocks):
            if case.is_default:
                default_target = block.name
            else:
                case_operands.extend([case.value.constant_value.value if case.value and case.value.constant_value else self.describe_expr(case.value)])
                targets.append(block.name)
        self.terminate("switch", [subject, case_operands, default_target], targets, stmt.span)
        for case, block in zip(stmt.cases, case_blocks):
            self.current = block
            assert case.body
            self.lower_block(case.body)
            if self.current.terminator is None:
                self.terminate("branch", [], [merge.name], case.body.span)
        self.current = merge

    def lower_expr(self, expr: Expr | None):
        if expr is None:
            return None
        if isinstance(expr, LiteralExpr):
            return self.emit("constant", [expr.value], expr.inferred_type, expr.span)
        if isinstance(expr, NameExpr):
            return self.emit("load", [expr.qualified], expr.inferred_type, expr.span)
        if isinstance(expr, UnaryExpr):
            return self.emit(f"unary.{expr.op}", [self.lower_expr(expr.operand)], expr.inferred_type, expr.span)
        if isinstance(expr, BinaryExpr):
            left = self.lower_expr(expr.left)
            right = self.lower_expr(expr.right)
            return self.emit(f"binary.{expr.op}", [left, right], expr.inferred_type, expr.span)
        if isinstance(expr, AssignExpr):
            value = self.lower_expr(expr.value)
            target = self.describe_expr(expr.target)
            return self.emit(f"assign.{expr.op}", [target, value], expr.inferred_type, expr.span)
        if isinstance(expr, CallExpr):
            args = [self.lower_expr(arg.value) for arg in expr.args]
            modes = [arg.mode for arg in expr.args]
            return self.emit("call", [self.describe_expr(expr.callee), args, modes], expr.inferred_type, expr.span)
        if isinstance(expr, MemberExpr):
            return self.emit("member", [self.lower_expr(expr.base), expr.member], expr.inferred_type, expr.span)
        if isinstance(expr, IndexExpr):
            return self.emit("index", [self.lower_expr(expr.base), self.lower_expr(expr.index)], expr.inferred_type, expr.span)
        if isinstance(expr, RangeExpr):
            return self.emit("range", [self.lower_expr(expr.base), self.lower_expr(expr.start), self.lower_expr(expr.end)], expr.inferred_type, expr.span)
        if isinstance(expr, CastExpr):
            return self.emit(f"cast.{expr.cast_kind}", [self.lower_expr(expr.value), expr.target_type.display()], expr.inferred_type, expr.span)
        if isinstance(expr, ConstructExpr):
            return self.emit("construct", [expr.type_name, self.lower_expr(expr.storage), self.lower_expr(expr.value)], expr.inferred_type, expr.span)
        if isinstance(expr, DestroyExpr):
            return self.emit("destroy", [self.lower_expr(expr.value)], expr.inferred_type, expr.span)
        if isinstance(expr, TypeQueryExpr):
            return self.emit(expr.query, [expr.type_syntax.display()], expr.inferred_type, expr.span)
        if isinstance(expr, StatusExpr):
            return self.emit("status", [self.lower_expr(expr.code), self.lower_expr(expr.message)], expr.inferred_type, expr.span)
        return self.emit("structured_expr", [self.describe_expr(expr)], expr.inferred_type, expr.span)

    def emit_cleanups(self, scope_count: int | None = None, all_scopes: bool = False) -> None:
        scopes = self.cleanup_scopes if all_scopes else self.cleanup_scopes[-(scope_count or 1):]
        for scope in reversed(scopes):
            for action in reversed(scope):
                self.emit("cleanup", [self.describe_expr(action)], span=action.span)

    @staticmethod
    def describe_expr(expr: Expr | None) -> str:
        if expr is None: return ""
        if isinstance(expr, NameExpr): return expr.qualified
        if isinstance(expr, MemberExpr): return f"{FunctionLowerer.describe_expr(expr.base)}.{expr.member}"
        if isinstance(expr, CallExpr): return f"{FunctionLowerer.describe_expr(expr.callee)}(...)"
        return expr.__class__.__name__


class Lowerer:
    def __init__(self, semantic: SemanticProgram, source_hashes: dict[str, str], target: str):
        self.semantic = semantic
        self.source_hashes = source_hashes
        self.target = target

    def lower(self) -> Program:
        modules: list[Module] = []
        for module_name, module_info in sorted(self.semantic.modules.modules.items()):
            functions: list[Function] = []
            for decl in module_info.declarations:
                if isinstance(decl, FunctionDecl):
                    if decl.body is None:
                        signature = self.semantic.signatures[id(decl)]
                        functions.append(Function(
                            decl.name, signature.result,
                            [Value(param.name, value_type) for param, value_type in signature.params],
                            [], decl.external_abi, decl.unsafe,
                        ))
                    else:
                        functions.append(FunctionLowerer(module_name, decl, self.semantic).lower())
            constants = {
                name.rsplit(".", 1)[-1]: value.value
                for name, value in self.semantic.types.diagnostics.items
            } if False else {}
            named_types = [
                value for name, value in self.semantic.types.types.items()
                if name.startswith(module_name + ".")
            ]
            modules.append(Module(module_name, functions, constants, named_types))
        return Program(modules, self.target, dict(sorted(self.source_hashes.items())))
