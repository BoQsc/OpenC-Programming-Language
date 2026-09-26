"""Bootstrap a pinned prior compiler and run clean Windows COFF speed pairs."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

from benchmark_sh27_paired_revision import bootstrap, resolve_commit
from benchmark_sh27_production import ROOT

REPOSITORY = ROOT.parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-ref", required=True)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--pairs", type=int, default=11)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not 3 <= args.pairs <= 31:
        parser.error("pairs must be 3..31")
    baseline_ref = resolve_commit(args.baseline_ref)
    candidate_ref = resolve_commit("HEAD")
    if baseline_ref == candidate_ref:
        parser.error("baseline and candidate cannot be the same commit")
    seed = args.seed.resolve(strict=True)
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    run_root = output.parent / "source-partition-identity-runs"
    run_root.mkdir(parents=True, exist_ok=True)
    report = {
        "schema": "openc.sh27.source_partition_identity_ci.v1",
        "status": "FAIL", "baseline_commit": baseline_ref,
        "candidate_commit": candidate_ref, "pairs": args.pairs,
    }
    with tempfile.TemporaryDirectory(prefix="openc-identity-baseline-") as temp:
        temporary_root = Path(temp).resolve()
        baseline_tree = temporary_root / "baseline"
        created = False
        try:
            subprocess.run(
                ["git", "worktree", "add", "--detach", str(baseline_tree),
                 baseline_ref], cwd=REPOSITORY, check=True,
                capture_output=True, text=True,
            )
            created = True
            baseline, baseline_bootstrap = bootstrap(
                "baseline", baseline_tree / "OpenC-1.0", seed, run_root)
            candidate, candidate_bootstrap = bootstrap(
                "candidate", ROOT, seed, run_root)
            report["bootstrap"] = {
                "baseline": baseline_bootstrap,
                "candidate": candidate_bootstrap,
            }
            paired_path = run_root / "identity-pairs.json"
            paired = subprocess.run([
                sys.executable,
                str(Path(__file__).with_name(
                    "benchmark_source_partition_identity.py")),
                str(baseline), str(candidate), "--pairs", str(args.pairs),
                "--project", str(ROOT / "compiler/selfhost/openc.project.json"),
                "--report", str(paired_path),
            ], cwd=REPOSITORY, check=False)
            report["paired_exit_code"] = paired.returncode
            if paired_path.is_file():
                pair_report = json.loads(paired_path.read_text(encoding="utf-8"))
                report["paired_status"] = pair_report["status"]
                report["paired_summary"] = pair_report.get("summary")
            report["status"] = "PASS" if paired.returncode == 0 and report.get(
                "paired_status") == "PASS" else "FAIL"
        except Exception as exc:
            report["error"] = str(exc)
        finally:
            if created:
                target = baseline_tree.resolve()
                if not target.is_relative_to(temporary_root):
                    raise RuntimeError("refusing to remove unexpected worktree")
                subprocess.run(
                    ["git", "worktree", "remove", "--force", str(target)],
                    cwd=REPOSITORY, check=True, capture_output=True, text=True,
                )
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"],
                      "paired_summary": report.get("paired_summary"),
                      "error": report.get("error")}, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
