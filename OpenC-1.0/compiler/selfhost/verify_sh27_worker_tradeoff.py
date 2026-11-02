#!/usr/bin/env python3
"""Verify two-worker savings where four-worker memory is still material."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


MIB = 1024 * 1024
REQUIRED_WORKLOADS = ("control_flow", "large_functions", "selfhost")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--two-proof", type=Path, required=True)
    parser.add_argument("--four-proof", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--minimum-savings-mib", type=int, default=32)
    parser.add_argument("--low-memory-ceiling-mib", type=int, default=128)
    args = parser.parse_args()
    if args.minimum_savings_mib < 1 or args.low_memory_ceiling_mib < 1:
        raise SystemExit("memory thresholds must be positive")
    two = json.loads(args.two_proof.read_text(encoding="utf-8"))
    four = json.loads(args.four_proof.read_text(encoding="utf-8"))
    if (
        two.get("status") != "PASS" or four.get("status") != "PASS"
        or two.get("source_chunks") != 2 or four.get("source_chunks") != 4
        or two.get("compiler_sha256") != four.get("compiler_sha256")
    ):
        raise SystemExit("worker trade-off requires passing proofs from one compiler")
    minimum_bytes = args.minimum_savings_mib * MIB
    low_memory_ceiling_bytes = args.low_memory_ceiling_mib * MIB
    results: dict[str, object] = {}
    passed = True
    for name in REQUIRED_WORKLOADS:
        two_case = two["results"][name]
        four_case = four["results"][name]
        two_peak = int(two_case["chunked"]["peak_job_private_bytes"])
        four_peak = int(four_case["chunked"]["peak_job_private_bytes"])
        saving = four_peak - two_peak
        four_worker_already_small = four_peak <= low_memory_ceiling_bytes
        exact = bool(
            two_case["byte_exact"] and four_case["byte_exact"]
            and two_case["serial"]["output_sha256"]
            == four_case["serial"]["output_sha256"]
        )
        # This is a trade-off proof, not the actual RAM guard. If four workers
        # already use <= 128 MiB for a workload, an absolute 32 MiB saving
        # ceases to be a meaningful requirement. Still forbid a two-worker
        # memory regression. The separate strict 64/256 MiB benchmark and
        # 512 MiB whole-Job checks remain mandatory.
        case_passed = exact and saving >= 0 and (
            four_worker_already_small or saving >= minimum_bytes
        )
        results[name] = {
            "two_worker_peak_job_private_bytes": two_peak,
            "four_worker_peak_job_private_bytes": four_peak,
            "savings_bytes": saving,
            "four_worker_already_small": four_worker_already_small,
            "low_memory_ceiling_bytes": low_memory_ceiling_bytes,
            "output_byte_exact": exact,
            "passed": case_passed,
        }
        passed = passed and case_passed
        print(f"{name}: savings={saving / MIB:.1f} MiB passed={case_passed}")
    report = {
        "schema": "openc.sh27.native_worker_tradeoff.v1",
        "status": "PASS" if passed else "FAIL",
        "compiler_sha256": two["compiler_sha256"],
        "minimum_savings_mib": args.minimum_savings_mib,
        "low_memory_ceiling_mib": args.low_memory_ceiling_mib,
        "results": results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(f"SH-27 worker RAM trade-off: {report['status']}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
