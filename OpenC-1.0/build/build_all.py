#!/usr/bin/env python3
"""Build canonical OpenC D targets and write a machine-readable report."""
from __future__ import annotations
import argparse, json, os, platform, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def execute(command: list[str], *, cwd: Path = ROOT) -> dict:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    return {
        "command": command,
        "cwd": str(cwd),
        "exit_code": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dub", default=os.environ.get("DUB", "dub"))
    parser.add_argument("--compiler", default=os.environ.get("DC", ""))
    parser.add_argument("--build", default="release", choices=["debug", "release"])
    parser.add_argument("--tools", action="store_true")
    parser.add_argument("--report", type=Path, default=ROOT / "build-output" / "build-report.json")
    args = parser.parse_args()
    suffix = [f"--build={args.build}"]
    if args.compiler:
        suffix.append(f"--compiler={args.compiler}")
    commands = [
        [args.dub, "build", "--root=runtime", *suffix],
        [args.dub, "build", "--root=standard_library", *suffix],
        [args.dub, "build", "--root=compiler", "--config=compiler", *suffix],
    ]
    if args.tools:
        for config in ["formatter", "language-server", "explain", "validate", "info", "runner"]:
            commands.append([args.dub, "build", "--root=tools", f"--config={config}", *suffix])
    results = [execute(command) for command in commands]
    report = {
        "schema": "openc.authored_build_report.v1",
        "evidence_state": "EXECUTED",
        "host": platform.platform(),
        "dub": shutil.which(args.dub) or args.dub,
        "results": results,
        "success": all(item["exit_code"] == 0 for item in results),
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report["success"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
