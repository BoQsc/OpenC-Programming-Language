# SH-27 clean branch-batch comparison

`.github/workflows/openc-performance-batch.yml` runs one Windows 2025 job.
It can be started by a commit touching compiler/performance inputs on a
`codex/sh27-*` branch, or manually after the workflow file is present on the
repository's default branch. A push compares that branch with the frozen
baseline SHA. Manual dispatch accepts one to three `codex/sh27-*` branch names,
a full 40-hex baseline SHA, 3–31 pairs (default 11), and an optional
`require_gain` failure gate. The default baseline is
`6794d56f65f361fad21d7964337c06ba3f168906`; change it explicitly when
the approved baseline advances.

The Python driver resolves all candidates from fetched **same-repository
remote branches**, requires each to descend from the baseline, freezes their
commit SHAs before creating detached worktrees, and rejects absent, duplicate,
non-`codex/sh27-*`, or otherwise invalid refs. It never uses an input as shell
syntax. The read-only checkout drops persisted Git credentials. This protects
the workflow from accidental external/PR ref selection; it is **not** a
sandbox for malicious code in a branch held by a repository writer, because
the compiler generated from that branch must eventually run.

Each revision uses the same seed, which must match the seed in the frozen
baseline. The active workload corpus must likewise match the baseline's
checked-in corpus byte-for-byte. Stages 2 and 3 must be byte-exact. A further Stage 4 self-build
must match Stage 3 byte-for-byte while staying within 256 MiB child private
and 64 MiB working set. Bootstrap stages are individually limited to 512 MiB
private/working set and 180 seconds. All builds run one after another.
Failed candidate bootstraps are recorded and do not prevent other valid
candidates from reaching the matrix; a failed baseline aborts comparison.

The shared matrix generates the checked-in large-function and control-flow
corpus once per workload, runs baseline/candidate adjacent pairs in rotating
order with a baseline-vs-baseline null control, and never runs compiler
processes concurrently. Each candidate compilation has a 120-second cap,
512 MiB private/working-set guard, exact executed stdout/stderr/exit checks,
and deterministic output checks. Codegen candidates may emit different
baseline machine bytes, but differences in runtime behavior still fail.
`require_gain` additionally demands a majority of paired wins and a median
gain greater than the null-control noise floor; leave it off when screening
several experiments and compare their individual results afterward.

The uploaded artifact contains the top-level request and resolved commit
SHAs, per-revision source-file SHA-256 manifest and compiler EXE hash, every
bootstrap and strict-stage measurement, the matrix JSON, generated corpus
hashes, paired phase-summary JSON, per-run timings/output hashes, and program artifacts. A failed job
still uploads any evidence written before failure. This is a **candidate
screen**, not SH-27 release certification: the final selected source still
needs the complete conformance/RAM and two independent clean C/D comparator
runs required by `SH27_EXECUTION_PLAN.md`.

Fast local orchestration tests (no bootstrap or benchmark):

```text
python -m unittest discover -s OpenC-1.0/compiler/selfhost -p test_benchmark_sh27_*.py -v
```
