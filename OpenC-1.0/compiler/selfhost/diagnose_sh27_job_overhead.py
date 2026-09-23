#!/usr/bin/env python3
"""Compare the pre-Job and Job-scoped SH-27 samplers on one Windows host."""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile

from windows_process_measure import run_measured as guarded_run


root = Path(__file__).resolve().parents[2]
repository = root.parent
prior = subprocess.run(
    ["git", "show", "816706b:OpenC-1.0/compiler/selfhost/windows_process_measure.py"],
    cwd=repository, capture_output=True, text=True, check=True,
).stdout
namespace: dict[str, object] = {"__name__": "prior_windows_process_measure"}
exec(compile(prior, "prior_windows_process_measure.py", "exec"), namespace)
prior_run = namespace["run_measured"]

source = root / "benchmarks/sh27/runtime/d/main.d"
configured = os.environ.get("DC")
if configured:
    candidate = Path(configured)
    name = candidate.name if candidate.suffix else candidate.name + ".exe"
    binary64 = candidate.parent.parent / "bin64" / name
    dmd = binary64 if binary64.is_file() else candidate
else:
    located = shutil.which("dmd.exe") or shutil.which("dmd")
    if not located:
        raise SystemExit("pinned DMD is required for sampler comparison")
    dmd = Path(located)
if not dmd.is_file():
    raise SystemExit(f"missing DMD executable: {dmd}")
with tempfile.TemporaryDirectory(prefix="sh27-job-overhead-") as scratch:
    directory = Path(scratch)
    output = directory / "program.exe"
    command = [
        str(dmd), "-O", "-release", "-boundscheck=off", str(source),
        f"-of={output}", f"-od={directory}",
    ]
    samples: dict[str, list[float]] = {"old": [], "job": []}
    for pair in range(11):
        order = ("old", "job") if pair % 2 == 0 else ("job", "old")
        for name in order:
            runner = prior_run if name == "old" else guarded_run
            result = runner(
                command, cwd=directory, environment=dict(os.environ),
                sample_interval=0.01,
                max_private_bytes=512 * 1024 * 1024,
                max_working_set_bytes=512 * 1024 * 1024,
            )
            if result["exit_code"] != 0 or not output.is_file():
                raise RuntimeError((name, pair, result))
            samples[name].append(float(result["elapsed_seconds"]))
    print("old", samples["old"])
    print("job", samples["job"])
    print("medians", {name: statistics.median(times) for name, times in samples.items()})
    print("paired_job_minus_old", statistics.median([
        job - old for job, old in zip(samples["job"], samples["old"])
    ]))
