#!/usr/bin/env python3
"""Summarize paired phase deltas from a guarded SH-27 candidate matrix.

Worker subphases are nested in the worker wall and overlap other workers.
These deltas are diagnostic clues, not additive savings or causal attribution.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import median


CRITICAL_FIELDS = (
    "wall_ms", "lex_parse_ms", "index_ms", "acceptance_ms",
    "expression_ms", "assignment_ms", "calls_ms", "ir_lower_ms",
    "native_emit_ms", "type_queries", "type_cache_hits", "type_uncached",
    "type_failures", "assignment_type_queries",
)


def numeric_phase(sample: dict, field: str) -> int | None:
    timing = sample.get("compiler_timings")
    if not isinstance(timing, dict):
        return None
    if field == "total_ms":
        value = timing.get("total_ms")
    elif field.startswith("phases_ms."):
        value = timing.get("phases_ms", {}).get(field.split(".", 1)[1])
    else:
        value = (
            timing.get("native_parallel_profile", {})
            .get("critical_chunk", {}).get(field)
        )
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def analyze(path: Path, candidate_filter: str | None = None) -> dict:
    report = json.loads(path.read_text(encoding="utf-8"))
    if report.get("schema") != "openc.sh27.candidate_matrix.v1":
        raise ValueError("not an SH-27 candidate matrix report")
    result = {
        "schema": "openc.sh27.candidate_matrix_phase_summary.v1",
        "report": str(path.resolve()),
        "note": (
            "Critical-worker phases are nested and may overlap other workers; "
            "do not sum them or equate a counter delta with wall savings."
        ),
        "workloads": {},
    }
    for workload_id, lane in report["workloads"].items():
        comparisons = {}
        for name, comparison in lane["comparisons"].items():
            if candidate_filter is not None and name != candidate_filter:
                continue
            fields = ("total_ms",) + tuple(
                f"phases_ms.{name}" for name in (
                    "project_load", "declarations", "resolution",
                    "validation", "lowering_and_c_emission", "tinycc",
                )
            ) + CRITICAL_FIELDS
            phase_rows = {}
            for field in fields:
                values = [
                    (numeric_phase(pair["baseline"], field),
                     numeric_phase(pair["candidate"], field))
                    for pair in comparison["pairs"]
                ]
                if not values or any(old is None or new is None for old, new in values):
                    continue
                phase_rows[field] = {
                    "baseline_median": median(old for old, _ in values),
                    "candidate_median": median(new for _, new in values),
                    "median_paired_delta": median(new - old for old, new in values),
                    "paired_deltas": [new - old for old, new in values],
                }
            comparisons[name] = {
                "status": comparison["status"],
                "elapsed_median_paired_delta_seconds": comparison[
                    "median_paired_delta_seconds"
                ],
                "candidate_wins": comparison["candidate_wins"],
                "null_noise_floor_seconds": comparison["null_noise_floor_seconds"],
                "phases": phase_rows,
            }
        result["workloads"][workload_id] = comparisons
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--candidate")
    parser.add_argument("--compact", action="store_true")
    args = parser.parse_args()
    result = analyze(args.report, args.candidate)
    if args.compact:
        for workload_id, comparisons in result["workloads"].items():
            for name, comparison in comparisons.items():
                print(
                    f"{workload_id} {name}: elapsed "
                    f"{comparison['elapsed_median_paired_delta_seconds']:+.6f}s, "
                    f"wins {comparison['candidate_wins']}, "
                    f"null floor {comparison['null_noise_floor_seconds']:.6f}s"
                )
                for field, values in comparison["phases"].items():
                    print(
                        f"  {field}: {values['median_paired_delta']:+} "
                        f"(baseline {values['baseline_median']}, "
                        f"candidate {values['candidate_median']})"
                    )
    else:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
