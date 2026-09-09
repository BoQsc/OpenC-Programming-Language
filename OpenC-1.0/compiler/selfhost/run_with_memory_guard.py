#!/usr/bin/env python3
"""Run one compiler command with a hard, recorded Windows RAM ceiling."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from windows_process_measure import run_measured


MIB = 1024 * 1024
DEFAULT_MAX_PRIVATE_MIB = 256
DEFAULT_MAX_WORKING_SET_MIB = 64
DEFAULT_MAX_CAPTURED_OUTPUT_MIB = 8


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--max-private-mib", type=int, default=DEFAULT_MAX_PRIVATE_MIB
    )
    parser.add_argument(
        "--max-working-set-mib", type=int,
        default=DEFAULT_MAX_WORKING_SET_MIB,
    )
    parser.add_argument(
        "--max-captured-output-mib", type=int,
        default=DEFAULT_MAX_CAPTURED_OUTPUT_MIB,
    )
    parser.add_argument("--record", type=Path, required=True)
    parser.add_argument("--cwd", type=Path, default=Path.cwd())
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("a command is required after --")
    if (
        args.max_private_mib <= 0
        or args.max_working_set_mib <= 0
        or args.max_captured_output_mib <= 0
    ):
        parser.error("memory and captured-output ceilings must be positive")

    result = run_measured(
        command,
        cwd=args.cwd.resolve(),
        max_private_bytes=args.max_private_mib * MIB,
        max_working_set_bytes=(
            args.max_working_set_mib * MIB
            if args.max_working_set_mib is not None
            else None
        ),
        max_captured_output_bytes=args.max_captured_output_mib * MIB,
    )
    memory_status = "FAIL" if result["memory_limit_exceeded"] else "PASS"
    command_status = "PASS" if result["exit_code"] == 0 else "FAIL"
    record = {
        "schema": "openc.windows_process_memory_guard.v1",
        "status": (
            "PASS"
            if memory_status == "PASS" and command_status == "PASS"
            else "FAIL"
        ),
        "memory_status": memory_status,
        "command_status": command_status,
        "command": command,
        "limits": {
            "private_bytes": args.max_private_mib * MIB,
            "working_set_bytes": (
                args.max_working_set_mib * MIB
                if args.max_working_set_mib is not None
                else None
            ),
        },
        "measurement": result,
    }
    args.record.parent.mkdir(parents=True, exist_ok=True)
    args.record.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    sys.stdout.write(str(result["stdout"]))
    sys.stderr.write(str(result["stderr"]))
    if result["memory_limit_exceeded"]:
        observed_mib = int(result["memory_observed_bytes"]) / MIB
        limit_mib = int(result["memory_limit_bytes"]) / MIB
        print(
            "fatal[OPENC-PROCESS-MEMORY-BUDGET]: "
            f"{result['memory_limit_name']} reached {observed_mib:.1f} MiB "
            f"(limit {limit_mib:.1f} MiB)",
            file=sys.stderr,
        )
        return 86
    return int(result["exit_code"])


if __name__ == "__main__":
    raise SystemExit(main())
