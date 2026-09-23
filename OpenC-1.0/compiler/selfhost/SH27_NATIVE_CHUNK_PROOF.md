# SH-27 native source workers (experimental)

This isolated branch now executes four native source chunks concurrently on
Windows x64. `openc artifact --kind=exe --source-chunks=4` starts three Windows
threads through documented DLL APIs and runs the fourth chunk on the caller.
Each chunk owns its mutable type table, export cache, layout caches, timings,
and binary object stream. The streams merge in source-record order. The
ordinary `openc build` path remains serial; no release artifact is replaced.
The generated compiler does not use a C runtime, TinyCC, D, Python, an
external assembler, or an external linker to compile programs. Python is
optional verification tooling only.

The native allocator reserves and releases live bytes with locked atomic
operations. Its 256 MiB single-allocation and 512 MiB live-byte limits still
apply. A partial thread-launch failure joins started threads and runs only
unstarted chunks on the caller. Failed type-table freeze or output-capacity
checks reject the experimental build. The binary streams use a 12x per-range
source-byte capacity plus 128 KiB, clamped to the existing global ceiling.

Worker acceptance diagnostics are suppressed. A build with any semantic
errors releases the worker arenas, replays validation serially, and reports
errors in source-record order. This costs extra time only on rejected builds.
The proof includes two simultaneously invalid sources, repeated five times,
in addition to the original one-error case. This is not a claim that every
possible error path has been exhaustively proven under concurrency.

## Local proof on the corrected revision

The byte-exact Stage 2/Stage 3 compiler SHA-256 is
`f4008fc4dfcdcc50e7cba8aa64f4289c14a58ded4317412d04e2277934a89231`.
The four valid workloads (221-source compiler, 24-file many-functions,
eight-file large-functions, four-file control-flow) produce byte-identical
serial and parallel executables under the 512 MiB process-tree private and
working-set guards. Both invalid fixtures preserve the serial diagnostic
stream. Native conformance passes 278/278, x64 substrate 25/25, and the
SH-27 Python harness 10/10. The detailed local report is
`build-output/selfhost-sh27/native-call-repro/ordered-proof.json`.

Eleven order-alternated, same-command `artifact` pairs on the corrected
compiler, each with exact output-hash and 512 MiB process-tree guards, show:

| Workload | Serial median | Four chunks median | Median paired delta | Wins | Peak parallel Job private |
| --- | ---: | ---: | ---: | ---: | ---: |
| Control flow | 0.931 s | 0.548 s | -0.369 s | 11/11 | 162.0 MiB |
| Large functions | 1.397 s | 0.900 s | -0.484 s | 11/11 | 306.1 MiB |
| Compiler self-build | 9.471 s | 5.761 s | -3.674 s | 11/11 | 281.7 MiB |

The reports are `ordered-paired-control.json`, `ordered-paired-large.json`,
and `ordered-paired-selfhost.json` beside the proof report. The harness keeps
only first-pair binaries; later hashes are recorded before deleting their
generated outputs to avoid exhausting local disk. An earlier diagnostic fix
revision also showed 11/11 wins on each workload, but the table above is for
the final corrected revision. Local numbers are not clean-runner C/D parity
results.

Run the proof and paired benchmark with:

```text
python compiler/selfhost/verify_sh27_native_chunks.py --compiler PATH/TO/openc.exe --output build-output/selfhost-sh27/native-proof.json
python compiler/selfhost/benchmark_sh27_native_parallel.py --compiler PATH/TO/openc.exe --workload control_flow --pairs 11 --output build-output/selfhost-sh27/control-pairs.json
```

`.github/workflows/openc-native-parallel.yml` runs on commits to this
experimental branch or by manual dispatch. It rebuilds the checked-out
compiler to a guarded byte-exact fixed point, runs correctness and diagnostic
proofs, and requires a majority of paired speed wins on all three workloads.
Its first clean-runner result is pending; the local bootstrap smoke test
produced the same compiler hash as the direct self-rebuild.

## Promotion boundary and next work

This is an opt-in, Windows-x64-only compiler experiment. Before production
promotion, collect a passing clean Windows workflow run, expand the
invalid-source and thread-failure matrix, measure RAM and
speed for two as well as four workers, and decide an adaptive default that
does not impose a 2.5x private-memory penalty on small programs. Compare that
default against pinned MSVC, Clang, DMD, and LDC on the same clean runner.
Incremental object reuse, representative real projects, and broad C/D-class
throughput remain open SH-27 goals. Linux and freestanding remain optional.

For provenance, this branch first proved serially isolated chunks, then
atomic allocator accounting, then right-sized output buffers. A preliminary
thread experiment access-violated. The subsequent call-boundary investigation
found an invalid absolute-address relocation in the native object stream and
a by-reference temporary-copy at the launch intrinsic. RIP-relative callback
addresses and an explicit state pointer corrected those defects; the current
parallel proof does not rely on the discarded experiment.
