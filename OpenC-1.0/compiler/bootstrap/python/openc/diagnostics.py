"""Structured diagnostic collection, formatting, and JSON emission."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from .model import Diagnostic, OpenCError, Phase, RelatedDiagnostic, Severity, Span
from .source import SourceManager


class DiagnosticEngine:
    def __init__(self, sources: SourceManager | None = None) -> None:
        self.sources = sources
        self.items: list[Diagnostic] = []

    def emit(self, diagnostic: Diagnostic) -> None:
        self.items.append(diagnostic)

    def error(
        self,
        rule_id: str,
        phase: Phase,
        message: str,
        span: Span | None = None,
        category: str = "",
        related: Iterable[RelatedDiagnostic] = (),
        help: Iterable[str] = (),
    ) -> Diagnostic:
        item = Diagnostic(rule_id, phase, Severity.ERROR, message, span, category, list(related), list(help))
        self.emit(item)
        return item

    def warning(
        self,
        rule_id: str,
        phase: Phase,
        message: str,
        span: Span | None = None,
        category: str = "",
    ) -> Diagnostic:
        item = Diagnostic(rule_id, phase, Severity.WARNING, message, span, category)
        self.emit(item)
        return item

    def raise_error(self, *args, **kwargs) -> None:
        raise OpenCError(self.error(*args, **kwargs))

    @property
    def has_errors(self) -> bool:
        return any(item.severity == Severity.ERROR for item in self.items)

    def to_json(self) -> list[dict]:
        return [item.to_json() for item in self.items]

    def write_json(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_json(), indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def write_jsonl(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="\n") as handle:
            for item in self.items:
                handle.write(json.dumps(item.to_json(), sort_keys=True) + "\n")

    def format_human(self, diagnostic: Diagnostic) -> str:
        prefix = f"{diagnostic.severity.value} {diagnostic.rule_id}"
        lines = [f"{prefix}: {diagnostic.message}"]
        if diagnostic.span is not None:
            span = diagnostic.span
            lines.append(f"  --> {span.source_id}:{span.start.line}:{span.start.column}")
            if self.sources is not None and span.source_id in {s.source_id for s in self.sources.all()}:
                source = self.sources.get(span.source_id)
                text = source.line_text(span.start.line)
                if text:
                    lines.append(f"   | {text}")
                    width = max(1, span.end.offset - span.start.offset)
                    lines.append("   | " + " " * (span.start.column - 1) + "^" * width)
        for related in diagnostic.related:
            lines.append(f"{related.severity.value}: {related.message}")
            if related.span is not None:
                lines.append(
                    f"  --> {related.span.source_id}:{related.span.start.line}:{related.span.start.column}"
                )
        for help_text in diagnostic.help:
            lines.append(f"help: {help_text}")
        return "\n".join(lines)

    def render(self) -> str:
        return "\n\n".join(self.format_human(item) for item in self.items)
