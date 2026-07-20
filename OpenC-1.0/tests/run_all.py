#!/usr/bin/env python3
"""Future execution driver for the authored OpenC source tree.

This script is intentionally shipped unexecuted. It invokes external D tools only
when a future maintainer runs it in a recorded environment.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def run(command: list[str], cwd: Path = ROOT) -> dict:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    return {
        "command": command,
        "cwd": str(cwd),
        "exit_code": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dub", default=os.environ.get("DUB", "dub"))
    parser.add_argument("--report", default=str(ROOT / "build" / "test-report.json"))
    args = parser.parse_args()
    results = [
        run([args.dub, "test", "--root=runtime"]),
        run([args.dub, "test", "--root=standard_library"]),
        run([args.dub, "test", "--root=compiler", "--config=library"]),
        run([args.dub, "test", "--root=tools"]),
        run([args.dub, "test", "--root=tests", "--config=compiler-frontend"]),
        run([args.dub, "test", "--root=tests", "--config=project"]),
        run([args.dub, "test", "--root=tests", "--config=runtime"]),
        run([args.dub, "test", "--root=tests", "--config=tools"]),
    ]
    report = {
        "schema": "openc.authored_test_execution.v1",
        "status": "EXECUTED" if all(r["exit_code"] == 0 for r in results) else "FAILED",
        "results": results,
    }
    path = Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report["status"] == "EXECUTED" else 1

if __name__ == "__main__":
    raise SystemExit(main())
