#!/usr/bin/env python3
"""Build the pre-flow-worker compiler from a pinned commit under RAM guards."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from benchmark_sh27_paired_revision import bootstrap, resolve_commit
from benchmark_sh27_production import ROOT, require_disk_headroom


REPOSITORY = ROOT.parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-ref", required=True)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    commit = resolve_commit(args.baseline_ref)
    seed = args.seed.resolve(strict=True)
    output_dir = args.output_dir.resolve()
    require_disk_headroom(output_dir.parent)
    output_dir.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="openc-sh27-flow-baseline-") as temporary:
        temporary_root = Path(temporary).resolve()
        worktree = temporary_root / "baseline"
        created = False
        try:
            subprocess.run(
                ["git", "worktree", "add", "--detach", str(worktree), commit],
                cwd=REPOSITORY, capture_output=True, text=True, check=True,
            )
            created = True
            compiler, record = bootstrap(
                "baseline", worktree / "OpenC-1.0", seed, output_dir
            )
        finally:
            if created:
                target = worktree.resolve()
                if not target.is_relative_to(temporary_root):
                    raise RuntimeError("refusing to remove unexpected worktree")
                subprocess.run(
                    ["git", "worktree", "remove", "--force", str(target)],
                    cwd=REPOSITORY, capture_output=True, text=True, check=True,
                )
    result = {
        "schema": "openc.sh27.flow_baseline.v1",
        "status": "PASS",
        "baseline_commit": commit,
        "compiler": str(compiler),
        "bootstrap": record,
    }
    (output_dir / "baseline.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    print(f"SH-27 flow baseline: PASS; compiler={compiler}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
