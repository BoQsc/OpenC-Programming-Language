"""UTF-8 source management and stable source-location mapping."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .model import Diagnostic, OpenCError, Phase, Position, Severity, Span


@dataclass(slots=True)
class SourceFile:
    source_id: str
    path: Path | None
    text: str
    raw: bytes
    line_starts: list[int]

    @classmethod
    def from_bytes(cls, source_id: str, raw: bytes, path: Path | None = None) -> "SourceFile":
        try:
            text = raw.decode("utf-8", errors="strict")
        except UnicodeDecodeError as exc:
            start = Position(exc.start, 1, exc.start + 1)
            end = Position(exc.end, 1, exc.end + 1)
            raise OpenCError(Diagnostic(
                rule_id="OPENC-SOURCE-UTF8-001",
                phase=Phase.SOURCE,
                severity=Severity.ERROR,
                message="source input is not valid UTF-8",
                span=Span(source_id, start, end),
                category="source.encoding",
            )) from exc
        starts = [0]
        for index, char in enumerate(text):
            if char == "\n":
                starts.append(index + 1)
        return cls(source_id, path, text, raw, starts)

    @classmethod
    def from_path(cls, path: Path, source_id: str | None = None) -> "SourceFile":
        return cls.from_bytes(source_id or str(path), path.read_bytes(), path)

    def position(self, offset: int) -> Position:
        offset = max(0, min(offset, len(self.text)))
        lo, hi = 0, len(self.line_starts)
        while lo + 1 < hi:
            mid = (lo + hi) // 2
            if self.line_starts[mid] <= offset:
                lo = mid
            else:
                hi = mid
        start = self.line_starts[lo]
        return Position(offset, lo + 1, offset - start + 1)

    def span(self, start: int, end: int) -> Span:
        return Span(self.source_id, self.position(start), self.position(end))

    def line_text(self, line: int) -> str:
        if line < 1 or line > len(self.line_starts):
            return ""
        start = self.line_starts[line - 1]
        end = self.line_starts[line] - 1 if line < len(self.line_starts) else len(self.text)
        return self.text[start:end].rstrip("\r")


class SourceManager:
    def __init__(self) -> None:
        self._sources: dict[str, SourceFile] = {}

    def add_bytes(self, source_id: str, raw: bytes, path: Path | None = None) -> SourceFile:
        source = SourceFile.from_bytes(source_id, raw, path)
        self._sources[source_id] = source
        return source

    def add_text(self, source_id: str, text: str, path: Path | None = None) -> SourceFile:
        return self.add_bytes(source_id, text.encode("utf-8"), path)

    def add_virtual(self, source_id: str, text: str) -> SourceFile:
        """Register an in-memory UTF-8 source with no filesystem path."""
        return self.add_text(source_id, text)

    def load(self, path: Path, source_id: str | None = None) -> SourceFile:
        source = SourceFile.from_path(path, source_id)
        self._sources[source.source_id] = source
        return source

    def get(self, source_id: str) -> SourceFile:
        return self._sources[source_id]

    def all(self) -> Iterable[SourceFile]:
        return self._sources.values()
