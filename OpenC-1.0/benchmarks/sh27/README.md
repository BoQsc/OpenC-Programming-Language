# SH-27 production compiler corpus

`CORPUS.json` is the canonical, bounded specification for the first SH-27
production-comparator tranche. The harness generates equivalent OpenC `.p`,
ISO C `.c`, and D `.d` programs. Each compiler must parse declarations and
function bodies, perform semantic checks, generate native code, and link a
Windows executable. The produced executable must run successfully.

The generated workload descriptions cover command startup, many-file
project overhead, many/large-function scaling, and a bounded control-flow
case with conditional branches, local variables, and loops. The checked-in
`runtime/{openc,c,d}` fixtures additionally exercise executable startup,
64 rounds of 4 KiB allocation, typed data writes and reads, file I/O, and
cleanup. Each run must print the expected line and produce the exact 4 KiB
payload digest. The harness also measures a same-output one-source-edit
sequence and the complete OpenC compiler self-build. It rotates compiler
order to reduce systematic bias and records every command, compiler identity,
source-tree fingerprint, raw sample, median, p95, output bytes and SHA-256,
and cache policy. Compiler and executable processes both have 512 MiB private
and working-set limits, bounded captured output, and executable timeouts.

Run on Windows from `OpenC-1.0`:

```text
python compiler/selfhost/benchmark_sh27_production.py --runs 3 --output build-output/selfhost-sh27/production-comparators.json
```

Use `--require-all` when MSVC, `clang-cl`, and DMD must all be present. The
`--msvc-toolset` and `--expected-*-version` switches make clean-host tool
selection/version drift blocking. The GitHub gate requires the x64 DMD driver,
not the package's default 32-bit executable. Use `--enforce-parity` for a blocking
parity run. Without that switch, a correctly measured performance deficit is
retained as evidence and does not hide behind a failed workflow. Missing
tools, compiler failures, version drift, RAM-limit violations, invalid
executables, or malformed results are always failures in `--require-all`
mode.

Python is an optional evidence orchestrator here. It is not used by `openc
build`, is not packaged as part of the compiler, and does not weaken the
already-complete standalone toolchain independence claim. Likewise, the C and
D compilers are comparison subjects only.

This tranche deliberately does not claim that generated arithmetic/control
flow plus the small runtime fixture represents every production codebase.
Incremental object
reuse, LDC, and broader real-project suites remain explicit SH-27 expansion
items until measured. A 1.25x compiler-time parity gate includes the runtime
fixture; executable-time results are reported separately, without promoting a
single small fixture to a broad runtime-performance claim.

For attribution between two OpenC revisions, manually run the
`OpenC paired revision performance` GitHub workflow with an earlier commit SHA
as `baseline_ref`. Its `benchmark_sh27_paired_revision.py` harness rebuilds
both revisions from the retained seed, requires a stage-two/stage-three exact
fixed point for each, then alternates guarded builds of the identical large
corpus on one Windows runner. It records all raw samples and program hashes;
a successful run proves correctness and measured deltas, not necessarily that
the candidate is faster. Cross-run compiler ratios are not a substitute for
this same-host A/B comparison.
