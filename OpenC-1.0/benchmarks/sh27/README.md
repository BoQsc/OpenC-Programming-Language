# SH-27 production compiler corpus

`CORPUS.json` is the canonical, bounded specification for the first SH-27
production-comparator tranche. The harness generates equivalent OpenC `.p`,
ISO C `.c`, and D `.d` programs. Each compiler must parse declarations and
function bodies, perform semantic checks, generate native code, and link a
Windows executable. The produced executable must run successfully.

The three checked-in workload descriptions cover command startup, many-file
project overhead, and many/large-function scaling. The harness also measures a
same-output one-source-edit sequence, executable startup, output bytes and
SHA-256, compiler peak private bytes and working set, and the complete OpenC
compiler self-build. It rotates compiler order to reduce systematic bias and
records every command, compiler identity, source-tree fingerprint, raw sample,
median, p95, and cache policy.

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

This tranche deliberately does not claim that generated arithmetic programs
alone represent every production codebase. File-I/O/allocation runtime work,
incremental object reuse, LDC, and broader real-project suites remain explicit
SH-27 expansion items until measured.
