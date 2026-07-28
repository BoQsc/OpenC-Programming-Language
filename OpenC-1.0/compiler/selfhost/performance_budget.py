#!/usr/bin/env python3
"""Shared validation for authored Windows-native performance budgets."""
from __future__ import annotations

import json
from pathlib import Path


def load_budget(path: Path, section: str) -> tuple[dict, dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "openc.windows_native_performance_budgets.v1":
        raise ValueError(f"unsupported performance budget schema: {path}")
    if section not in data.get("budgets", {}):
        raise ValueError(f"missing performance budget section {section}: {path}")
    return data, data["budgets"][section]


def measurement_checks(
    measurement: dict[str, object],
    budget: dict[str, object],
) -> dict[str, bool]:
    return {
        "process_exit_zero": measurement.get("exit_code") == 0,
        "elapsed_within_budget": (
            float(measurement.get("elapsed_seconds", float("inf")))
            <= float(budget["max_elapsed_seconds"])
        ),
        "peak_private_within_budget": (
            int(measurement.get("peak_private_bytes", 2**63))
            <= int(budget["max_peak_private_bytes"])
        ),
        "peak_working_set_within_budget": (
            int(measurement.get("peak_working_set_bytes", 2**63))
            <= int(budget["max_peak_working_set_bytes"])
        ),
    }
