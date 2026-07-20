"""Stable rule explanation lookup."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class RuleDatabase:
    def __init__(self, root: Path):
        self.root = root
        index_path = root / "standard" / "core" / "metadata" / "OpenC_Core_Rule_Index.json"
        catalog_path = root / "standard" / "core" / "metadata" / "OpenC_Core_Diagnostic_Catalog.json"
        self.index = self._load(index_path)
        self.catalog = self._load(catalog_path)
        self.rules = self._index_rules(self.index)
        self.diagnostics = self._index_rules(self.catalog)

    @staticmethod
    def _load(path: Path) -> Any:
        return json.loads(path.read_text(encoding="utf-8"))

    @staticmethod
    def _index_rules(value: Any) -> dict[str, dict]:
        result: dict[str, dict] = {}
        if isinstance(value, dict):
            candidates = value.get("rules") or value.get("diagnostics") or value.get("entries") or []
        else:
            candidates = value
        if isinstance(candidates, dict):
            candidates = candidates.values()
        for item in candidates:
            if not isinstance(item, dict):
                continue
            rule_id = item.get("rule_id") or item.get("id")
            if isinstance(rule_id, str):
                result[rule_id] = item
        return result

    def explain(self, rule_id: str) -> dict[str, Any]:
        rule = self.rules.get(rule_id, {})
        diagnostic = self.diagnostics.get(rule_id, {})
        return {
            "schema": "openc.rule_explanation.v1",
            "rule_id": rule_id,
            "known": bool(rule or diagnostic),
            "title": rule.get("title") or diagnostic.get("title") or "Unknown OpenC rule",
            "summary": rule.get("summary") or rule.get("text") or diagnostic.get("message") or "",
            "chapter": rule.get("chapter") or rule.get("source") or "",
            "phase": diagnostic.get("phase") or rule.get("phase") or "",
            "category": diagnostic.get("category") or rule.get("category") or "",
            "severity": diagnostic.get("severity") or rule.get("severity") or "",
            "tests": rule.get("tests") or rule.get("fixtures") or [],
            "related": rule.get("related_rules") or [],
        }
