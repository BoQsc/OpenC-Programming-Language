"""Classical and parenthesis-style OpenC command normalization."""
from __future__ import annotations

import ast
from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class CommandRequest:
    command: str
    positionals: list[str] = field(default_factory=list)
    options: dict[str, Any] = field(default_factory=dict)
    program_args: list[str] = field(default_factory=list)

    def to_json(self) -> dict[str, Any]:
        return {
            "schema": "openc.command_request.v1",
            "command": self.command,
            "positionals": list(self.positionals),
            "options": dict(sorted(self.options.items())),
            "program_args": list(self.program_args),
        }


def normalize_parenthesis(text: str) -> CommandRequest:
    try:
        expression = ast.parse(text, mode="eval").body
    except SyntaxError as exc:
        raise ValueError(f"invalid parenthesis command: {exc.msg}") from exc
    if not isinstance(expression, ast.Call) or not isinstance(expression.func, ast.Name):
        raise ValueError("parenthesis command must be one call such as check(file=\"main\")")
    if any(keyword.arg is None for keyword in expression.keywords):
        raise ValueError("** expansion is not allowed in an OpenC command")
    positionals = [literal_value(item) for item in expression.args]
    if not all(isinstance(item, (str, int, bool)) for item in positionals):
        raise ValueError("command positional values must be scalar literals")
    options = {keyword.arg: literal_value(keyword.value) for keyword in expression.keywords}
    return CommandRequest(expression.func.id, [str(item) for item in positionals], options)


def literal_value(node: ast.AST) -> Any:
    if isinstance(node, ast.Constant) and isinstance(node.value, (str, int, bool, type(None))):
        return node.value
    if isinstance(node, ast.List):
        return [literal_value(item) for item in node.elts]
    raise ValueError("OpenC command arguments must use literal values")
