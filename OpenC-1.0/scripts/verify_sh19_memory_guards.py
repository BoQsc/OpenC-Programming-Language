#!/usr/bin/env python3
"""Verify SH-19 process RAM enforcement and bounded output capture."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SELFHOST = ROOT / "compiler" / "selfhost"
sys.path.insert(0, str(SELFHOST))

from windows_process_measure import run_measured


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-19 memory-guard verification requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    checks: dict[str, bool] = {}
    observations: dict[str, object] = {}

    with tempfile.TemporaryDirectory(prefix="openc-sh19-memory-") as temporary:
        record = Path(temporary) / "forced-budget.json"
        forced = subprocess.run(
            [
                sys.executable,
                str(SELFHOST / "run_with_memory_guard.py"),
                "--max-private-mib", "1",
                "--max-working-set-mib", "64",
                "--record", str(record),
                "--", sys.executable, "-c",
                "x=bytearray(16*1024*1024);__import__('time').sleep(2)",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=30,
        )
        forced_record = json.loads(record.read_text(encoding="utf-8"))
        checks["forced_private_budget_exits_86"] = forced.returncode == 86
        checks["forced_private_budget_is_recorded"] = (
            forced_record.get("status") == "FAIL"
            and forced_record.get("memory_status") == "FAIL"
            and forced_record.get("measurement", {}).get("memory_limit_exceeded")
            and forced_record.get("measurement", {}).get("memory_limit_name")
            == "private_bytes"
        )
        checks["forced_private_budget_diagnostic"] = (
            "fatal[OPENC-PROCESS-MEMORY-BUDGET]" in forced.stderr
        )
        observations["forced_private_bytes"] = forced_record["measurement"][
            "memory_observed_bytes"
        ]

        captured = run_measured(
            [sys.executable, "-c", "print('x' * 131072)"],
            cwd=ROOT,
            max_private_bytes=64 * 1024 * 1024,
            max_working_set_bytes=64 * 1024 * 1024,
            max_captured_output_bytes=4096,
        )
        checks["large_output_does_not_deadlock"] = captured["exit_code"] == 0
        checks["large_output_is_bounded"] = (
            captured["stdout_truncated"]
            and len(str(captured["stdout"]).encode("utf-8")) == 4096
        )
        checks["large_output_stays_inside_process_budget"] = not captured[
            "memory_limit_exceeded"
        ]
        observations["output_probe"] = {
            key: captured[key]
            for key in (
                "elapsed_seconds",
                "peak_private_bytes",
                "peak_working_set_bytes",
                "stdout_truncated",
            )
        }

    result = {
        "schema": "openc.sh19_memory_guards.v1",
        "status": "PASS" if all(checks.values()) else "FAIL",
        "checks": checks,
        "observations": observations,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n"
    )
    print(
        f"SH-19 memory guards: {result['status']}; "
        f"{sum(checks.values())}/{len(checks)}"
    )
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
