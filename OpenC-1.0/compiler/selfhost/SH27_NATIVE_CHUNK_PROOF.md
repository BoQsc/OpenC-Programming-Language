# SH-27 native source workers (experimental)

This isolated branch now executes two or four native source chunks
concurrently on Windows x64. `openc artifact --kind=exe --source-chunks=4`
starts three Windows threads through documented DLL APIs and runs the fourth
chunk on the caller; `--source-chunks=2` starts one thread plus the caller.
Each active chunk owns its mutable type table, export cache, layout caches,
timings, and binary object stream. Inactive two-worker slots allocate no
private type or layout caches. Streams merge in source-record order. The
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
SH-27 Python harness (now 12/12). The detailed local report is
`build-output/selfhost-sh27/native-call-repro/ordered-proof.json`.

Eleven order-alternated, same-command `artifact` pairs on the corrected
compiler, each with exact output-hash and 512 MiB process-tree guards, show:

| Workload | Serial median | Four chunks median | Median paired delta | Wins | Peak parallel Job private |
| --- | ---: | ---: | ---: | ---: | ---: |
| Control flow | 0.931 s | 0.548 s | -0.369 s | 11/11 | 162.0 MiB |
| Large functions | 1.397 s | 0.900 s | -0.484 s | 11/11 | 306.1 MiB |
| Compiler self-build | 9.471 s | 5.761 s | -3.674 s | 11/11 | 281.7 MiB |

The four-worker reports are `ordered-paired-control.json`,
`ordered-paired-large.json`, and `ordered-paired-selfhost.json` beside the
proof report. The harness keeps only first-pair binaries; later hashes are
recorded before deleting their generated outputs to avoid exhausting local
disk. The four-worker table is local evidence, not clean-runner C/D parity.

## Two-worker RAM/speed trade-off

The two-worker compiler reaches a byte-exact Stage 2/Stage 3 fixed point at
SHA-256 `638777dbb794f89b23d0f190819c396806aa6ab09b7d59bb46deb041abac26cb`.
Both two- and four-worker modes pass the same five-workload byte comparison
(including a one-file fallback), one-error and repeated two-error diagnostic
comparisons, and 512 MiB guards
on this revision. Native conformance passes 278/278 and x64 substrate 25/25.
The two-worker proof's large-function process-tree private peak is 191.6 MiB
versus 306.1 MiB with four workers. The matching proof reports are
`two-worker-five-workload-proof.json` and
`four-worker-five-workload-proof.json` in the ignored local SH-27 output tree.

Eleven local order-alternated pairs on the two-worker revision show:

| Workload | Serial median | Two chunks median | Median paired delta | Wins | Peak two-worker Job private |
| --- | ---: | ---: | ---: | ---: | ---: |
| Control flow | 0.842 s | 0.612 s | -0.230 s | 11/11 | 97.4 MiB |
| Large functions | 1.335 s | 1.088 s | -0.275 s | 10/11 | 191.7 MiB |
| Compiler self-build | 9.519 s | 6.924 s | -2.488 s | 11/11 | 223.0 MiB |

The two-worker paired reports are `two-worker-paired-control.json`,
`two-worker-paired-large.json`, and `two-worker-paired-selfhost-retry.json`.
An earlier self-build pair run stopped at the 256 MiB disk-headroom guard
after ten complete passing pairs; it did not fail compilation. The harness
now checkpoints every completed pair so guard stops preserve measurements.
The full retry passed. The two-worker path remains opt-in and trades speed
for substantially lower peak memory; these separate local runs are not an
order-alternated direct comparison of two versus four workers.

`verify_sh27_worker_tradeoff.py` requires at least 32 MiB less Job private
memory with two workers on control flow, large functions, and self-build,
using passing proofs from the same compiler. Local savings are 64.4, 114.4,
and 60.3 MiB respectively. The commit/manual workflow runs both worker
counts and this RAM gate. Clean Windows [run 35826688929](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35826688929)
passes every step at `51bcb47`, including the pinned C/D corpus. Its JSON
artifact is `OpenC-SH27-native-parallel-35826688929` (ID `10735084414`,
362,653 bytes). As with the earlier clean run, job success certifies
correctness, memory, and the required relative speed gains—not C/D parity.

Run the proof and paired benchmark with:

```text
python compiler/selfhost/verify_sh27_native_chunks.py --compiler PATH/TO/openc.exe --source-chunks 2 --output build-output/selfhost-sh27/native-two-proof.json
python compiler/selfhost/benchmark_sh27_native_parallel.py --compiler PATH/TO/openc.exe --source-chunks 2 --workload control_flow --pairs 11 --output build-output/selfhost-sh27/two-control-pairs.json
```

`.github/workflows/openc-native-parallel.yml` runs on commits to this
experimental branch or by manual dispatch. It rebuilds the checked-out
compiler to a guarded byte-exact fixed point, runs correctness and diagnostic
proofs, and requires a majority of paired speed wins on all three workloads.
Clean Windows run [35823166323](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35823166323)
passes every step at commit `e5a4daa`: guarded byte-exact bootstrap,
conformance, x64 substrate, ordered diagnostics, RAM, and majority paired
speed gains on all three workloads. Its machine-readable JSON artifact is
`OpenC-SH27-native-parallel-35823166323` (ID `10733434100`, 149,873 bytes).
The local bootstrap smoke test produced the same compiler hash as the direct
self-rebuild. The clean runner's exact timing samples are in its artifact;
the table above remains explicitly local evidence.

The production corpus harness now has explicit `--openc-source-chunks 2` and
`--openc-source-chunks 4` options; its default remains the serial `build`
command. A three-run local four-worker OpenC/DMD64 2.112.0 pass preserves
every compile, execution, output, and RAM gate but measures OpenC at 2.421x
DMD on large functions and 2.275x on control flow. The two-worker local pass
also preserves all correctness and RAM gates but measures 2.917x and 2.726x
DMD respectively. These are partial comparator sets, not C/D parity claims.
The extended commit/manual worker workflow also passes the full pinned MSVC,
Clang, DMD, and LDC corpus on a clean Windows host: [run 35824022202](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35824022202)
at `fdd0e5a`. Its JSON artifact is
`OpenC-SH27-native-parallel-35824022202` (ID `10734212162`, 198,538 bytes).
The workflow succeeds when comparator evidence is complete and all
correctness/memory gates pass, even if throughput parity still misses; the
exact clean-host ratios are in that artifact and are not inferred here.

## Promotion boundary and next work

This is an opt-in, Windows-x64-only compiler experiment. Before production
promotion, expand the invalid-source and thread-failure matrix and decide an
adaptive default that
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
