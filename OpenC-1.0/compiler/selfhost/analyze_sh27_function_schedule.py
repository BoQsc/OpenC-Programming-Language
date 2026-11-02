#!/usr/bin/env python3
"""Bound function-level native scheduling from an existing SH-27 checkpoint.

This is a counterfactual cost model, not a compiler throughput measurement.
Only IR lowering and native emission are considered movable; source parsing,
indexing, and acceptance remain on the current source owner. The tail model
assumes zero task creation, context cloning, synchronization, and merge cost.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import median


def tail_makespan(walls: list[int], critical: int, movable: int) -> int:
    """Ideal divisible-work makespan when critical work releases at its tail."""
    release = walls[critical] - movable
    available = [release if i == critical else max(release, wall)
                 for i, wall in enumerate(walls)]
    low = max(wall for i, wall in enumerate(walls) if i != critical)
    high = walls[critical]
    while low < high:
        middle = (low + high) // 2
        capacity = sum(max(0, middle - ready) for ready in available)
        if capacity >= movable:
            high = middle
        else:
            low = middle + 1
    return low


def sample_record(sample: dict) -> dict[str, int]:
    profile = sample["compiler_timings"]["native_parallel_profile"]
    walls = [int(value) for value in profile["chunk_walls_ms"]]
    if len(walls) != 4:
        raise ValueError("expected exactly four native workers")
    detail = profile["critical_chunk"]
    critical_wall = int(detail["wall_ms"])
    if max(walls) != critical_wall:
        raise ValueError("critical wall does not match worker walls")
    critical = walls.index(critical_wall)
    movable = int(detail["ir_lower_ms"]) + int(detail["native_emit_ms"])
    if movable < 0 or movable > critical_wall:
        raise ValueError("invalid movable time")
    strict_floor = max(max(wall for i, wall in enumerate(walls)
                           if i != critical), critical_wall - movable)
    ideal = tail_makespan(walls, critical, movable)
    return {
        "critical_wall_ms": critical_wall,
        "movable_lower_emit_ms": movable,
        "zero_cost_floor_ms": strict_floor,
        "tail_ideal_ms": ideal,
        "tail_ideal_gain_ms": critical_wall - ideal,
    }


def analyze(path: Path) -> dict:
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema") not in {
        "openc.sh27.native_parallel_checkpoint.v1",
        "openc.sh27.native_parallel_paired.v1",
    }:
        raise ValueError("unsupported checkpoint schema")
    samples = document["samples"]["parallel"]
    if not samples:
        raise ValueError("checkpoint has no parallel samples")
    records = [sample_record(sample) for sample in samples]
    return {
        "schema": "openc.sh27.function_schedule_model.v1",
        "checkpoint": str(path.resolve()),
        "workload": document["workload"],
        "samples": len(records),
        "assumptions": [
            "Only critical-worker IR lowering and native emission move.",
            "The strict floor assumes all movable work costs zero.",
            "The illustrative tail model releases movable work after all other critical-worker work.",
            "Tail tasks are divisible with zero creation, cloning, synchronization, and merge cost.",
            "This is not a measured speedup or a proof that a scheduler can fit the RAM cap.",
        ],
        "medians_ms": {key: median(record[key] for record in records)
                       for key in records[0]},
        "records": records,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkpoint", type=Path)
    arguments = parser.parse_args()
    print(json.dumps(analyze(arguments.checkpoint), indent=2))


if __name__ == "__main__":
    main()
