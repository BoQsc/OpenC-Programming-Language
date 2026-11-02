#!/usr/bin/env python3
"""Exercise the real benchmark CLI's deliberate parity-failure path."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

from benchmark_sh27_production import sha256


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("refusing to replace an existing enforcement report")
    output.parent.mkdir(parents=True, exist_ok=True)
    reference = json.loads(args.reference.read_text(encoding="utf-8"))
    if reference["status"] != "PASS_PARITY" or not reference["checks"]["all_requested_compilers_present"]:
        parser.error("a complete passing five-compiler reference is required")
    corpus_path = Path(reference["corpus"]["path"])
    if sha256(corpus_path) != reference["corpus"]["sha256"]:
        parser.error("reference corpus has changed")
    corpus = json.loads(corpus_path.read_text(encoding="utf-8"))
    corpus["parity"]["maximum_openc_to_comparator_median_ratio"] = 0.000001
    probe = output.with_name(output.stem + "-negative-corpus.json")
    probe.write_text(json.dumps(corpus, indent=2) + "\n", encoding="utf-8")
    negative_path = output.with_name(output.stem + "-negative.json")
    command = [sys.executable, str(Path(__file__).with_name("benchmark_sh27_production.py")),
               "--corpus", str(probe), "--runs", "3", "--self-build-runs", "1",
               "--require-all", "--enforce-parity", "--output", str(negative_path)]
    for name in ("openc", "msvc", "clang", "dmd", "ldc"):
        tool = reference["tools"][name]
        if sha256(Path(tool["path"])) != tool["sha256"]:
            parser.error(f"reference {name} binary has changed")
        command += ["--" + name, tool["path"]]
    result = {"schema": "openc.sh27.parity_enforcement.v1", "status": "FAIL",
              "scope": "deliberate negative CLI proof; not a production speed result",
              "reference_sha256": sha256(args.reference), "command": command}
    with output.with_suffix(".log").open("w", encoding="utf-8") as log:
        completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    negative = json.loads(negative_path.read_text(encoding="utf-8")) if negative_path.is_file() else {}
    checks = {
        "cli_returns_failure": completed.returncode == 1,
        "report_identifies_parity_failure": negative.get("status") == "FAIL_PARITY",
        "compile_execution_memory_checks_still_pass": negative.get("checks", {}).get("all_compile_memory_and_execution_checks_passed") is True,
        "all_five_compilers_still_present": negative.get("checks", {}).get("all_requested_compilers_present") is True,
        "no_parity_claim_on_deficit": negative.get("claims", {}).get("broad_production_parity") is False,
        "corpus_v1_bytes_preserved": sha256(corpus_path) == reference["corpus"]["sha256"],
    }
    result.update(checks=checks, negative_exit_code=completed.returncode,
                  negative_report=str(negative_path),
                  negative_report_sha256=sha256(negative_path) if negative_path.is_file() else None)
    if all(checks.values()):
        result["status"] = "PASS"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("SH-27 deliberate parity failure:", result["status"], flush=True)
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
