#!/usr/bin/env python3
"""Guardedly rebuild the checked-out compiler for the native-worker CI lane."""
from __future__ import annotations

import argparse
import os
from pathlib import Path

from benchmark_sh27_production import (
    MIB, REPOSITORY, bootstrap_current_compiler, require_disk_headroom,
)


def main() -> int:
    if os.name != "nt":
        raise SystemExit("SH-27 native worker bootstrap requires Windows")
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--seed", type=Path,
        default=REPOSITORY / ".github" / "bootstrap" / "openc-stage0.exe",
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    seed = args.seed.resolve(strict=True)
    output_dir = args.output_dir.resolve()
    require_disk_headroom(output_dir.parent)
    output_dir.mkdir(parents=True, exist_ok=False)
    compiler, record = bootstrap_current_compiler(
        seed=seed, run_root=output_dir,
        environment=dict(os.environ), sample_interval=0.01,
        max_private_bytes=512 * MIB,
        max_working_set_bytes=512 * MIB,
        max_output_bytes=2 * MIB,
    )
    print(
        f"SH-27 native worker bootstrap: {record['status']}; "
        f"compiler={compiler}", flush=True,
    )
    return 0 if record["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
