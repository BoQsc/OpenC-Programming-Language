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

`openc artifact` now accepts `--timings=PATH` alongside its separate artifact
`--report=PATH`. The native-worker proof and paired/production harnesses retain
the compiler-owned phase record for each sample. The timing record identifies
the selected chunk count, including serial fallback on a one-file project;
it does not assert that every requested native thread launched.
Its top-level phases are wall elapsed: when chunks run in parallel, validation
contains the serial flow pass, while `lowering_and_c_emission` includes the
fused worker stage. `validation_profile.acceptance_ms` and its groups are
**summed worker elapsed**, not wall time, in that mode. The proof rejects a
timing record with the wrong basis so we do not mistake aggregate worker time
for the compiler's critical path.

Clean Windows [run 35829019593](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35829019593)
passes the checked-out-source fixed point, 278/278 conformance, 25/25 x64
substrate, both worker-count proofs, the RAM trade-off, paired speed gates,
and the pinned C/D comparator at commit `9d37ca2`. Its machine-readable
artifact is `OpenC-SH27-native-parallel-35829019593` (ID `10735889275`,
864,115 bytes). This verifies the timing-report change on a clean runner;
the comparator step remains evidence-only, not a throughput-parity gate.

One guarded local two-worker proof after that accounting correction recorded
4,531 ms serial validation and 5,844 ms fused stage for self-build; the
large-function case recorded 172/750 ms and control flow 156/391 ms. These
are single samples, not stable speed estimates. They show that the serial
front-end still matters on the compiler itself and the fused stage still
dominates the bounded generated examples. The next performance change needs
paired wall-time evidence and a substantive reduction in first-time semantic
work; merely relabeling the phase or summing worker timings cannot close the
C/D deficit.

An experimental `artifact --source-chunks=auto` policy now uses measured
project source bytes and file count: fewer than two files or under 192 KiB
stays serial; at least four files and 512 KiB–3 MiB selects four chunks;
other multi-file inputs from 192 KiB–4 MiB select two; larger inputs stay
serial. It is opt-in, deterministic, and recorded as `source_chunks_policy`
plus the selected `parallel_source_chunks` in the timing report. The 512 MiB
Job-memory guard remains part of the proof and benchmarks; source size alone
is not a universal memory-safety guarantee, so this is not the default.

The local auto proof selects serial on the one-file and 80 KiB many-file
cases, two workers on 207 KiB control flow, and four on the 742 KiB large
case and 2.07 MiB compiler self-build. All five outputs are byte-exact;
one-error and repeated two-error diagnostics match serial, 278/278 native
conformance and 25/25 x64 substrate pass. Eleven order-alternated local
pairs each show 11/11 adaptive wins:

| Workload | Serial median | Auto median | Paired median delta | Auto Job-private peak |
| --- | ---: | ---: | ---: | ---: |
| Control flow | 1.729 s | 1.204 s | -0.449 s | 97.3 MiB |
| Large functions | 1.824 s | 1.209 s | -0.580 s | 306.1 MiB |
| Compiler self-build | 12.799 s | 8.458 s | -3.978 s | 284.3 MiB |

The corresponding ignored local reports are `adaptive-auto-proof.json` and
`adaptive-auto-{control,large,selfhost}-pairs.json`. A local three-run
OpenC/DMD comparator also passes compilation, execution, output, and RAM
checks, but OpenC/DMD ratios remain 2.263x on large functions and 2.788x
on control flow. Its status is `PARTIAL_COMPARATOR_SET`, because MSVC,
Clang, and LDC were not included locally. Clean Windows
[run 35831483331](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35831483331)
at `89eecff` passes the fixed point, conformance, x64 substrate, manual and
adaptive byte/diagnostic/RAM proofs, all nine eleven-pair speed gates, and
both four-chunk and adaptive pinned MSVC/Clang/DMD/LDC comparator lanes. Its
JSON artifact is `OpenC-SH27-native-parallel-35831483331` (ID
`10737339417`, 1,348,499 bytes). The workflow deliberately treats the
comparator lanes as evidence, not parity gates. The local DMD deficit, broader
real-project coverage, failure-injection matrix, and incremental reuse keep
the policy experimental and SH-27 open.

## Opt-in parallel flow validation

The native `artifact` path now also distributes source-independent flow
validation across private error buffers for projects selected by the adaptive
source-worker policy. Control flow uses two flow workers, large functions two
(rather than four, which regressed locally), and compiler self-build four.
The ordinary `build` and `check` paths remain serial. Diagnostics merge in
source order, and the timing report distinguishes wall-clock
`validation_flow_ms` from summed-worker flow groups. It records
`parallel_flow_workers` and whether native flow threads actually launched.
The flow-state implementation explicitly assigns four nested `PackedBuffer`
length/capacity words after initialization because a pre-existing ref-to-value
aggregate lowering defect corrupted them. A separate IR correction and
regression proof below address that defect; the explicit assignments remain
compatible with older seed compilers during bootstrap.

The capped-flow candidate reaches a byte-exact Stage 2/Stage 3 fixed point,
passes all five adaptive byte/diagnostic/RAM workloads, 278/278 conformance,
25/25 x64 substrate checks, and the 512 MiB process-tree guard. A separate
transition proof compiles the new sources with the pre-flow compiler, confirms
flow-thread fallback, and checks exact executable bytes against the newly
bootstrapped threaded compiler. Eleven order-alternated local pairs against
the pinned pre-flow compiler (`fd4f630`) show:

| Workload | Pre-flow median | Candidate median | Paired median delta | Candidate wins | Peak candidate Job private |
| --- | ---: | ---: | ---: | ---: | ---: |
| Control flow | 0.849 s | 0.781 s | -0.068 s | 11/11 | 97.7 MiB |
| Large functions | 1.195 s | 1.199 s | -0.009 s | 6/11 | 306.0 MiB |
| Compiler self-build | 7.785 s | 5.356 s | -2.601 s | 11/11 | 285.4 MiB |

The large-function result is a non-regression result, not a demonstrated
speedup; the separate medians and paired median differ because measurements
are order-alternated. Local reports are `flow-proto4-*` in the ignored SH-27
output tree. The new commit/manual workflow rebuilds the pinned baseline and
requires paired gains on control flow and self-build, with a 5% paired-median
regression ceiling on large functions. Clean Windows
[run 35837859544](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35837859544)
passes the fixed point, conformance, x64 substrate, adaptive byte/diagnostic/
RAM proofs, pre-flow fallback, all three revision-paired flow gates, and both
pinned C/D comparator lanes at `5038e34`. The retained JSON artifact is
`OpenC-SH27-native-parallel-35837859544` (ID `10740382922`, 1,698,468
bytes). The public artifact download was unavailable without authentication
here, so exact clean-host timing ratios are not asserted.
The candidate's partial three-run DMD comparison passes correctness and RAM
but still measures 2.657x DMD on large functions and 2.579x on control flow.
This is not C/D-class throughput or a claim about arbitrary real projects.

## Ref-to-value aggregate correction

An aggregate literal assigning a `ref Pair` to a value-typed `Pair` field
previously stored the reference address in the first word and zero in the
second. The minimized `tests/sh27_nested_aggregate` executable fails under
the pinned pre-fix compiler but exits zero under the corrected compiler.
Aggregate IR lowering now emits an explicit pointee load when the field's
declared type is the reference's element type, without changing reference-
typed fields. `verify_sh27_nested_aggregate.py` compiles and executes both
versions under the process-tree RAM guard and retains JSON evidence.

The corrected compiler reaches a byte-exact Stage 2/Stage 3 fixed point,
passes 278/278 conformance, 25/25 x64 substrate checks, the five-workload
adaptive output/diagnostic/RAM proof, and canonical-tree structure validation.
Eleven local order-alternated pairs against the pre-fix flow compiler pass
a 5% paired-median non-regression guard on each workload: +5 ms control flow,
+22 ms large functions, and +307 ms self-build. The self-build result is close
to that guard and varied substantially across samples, so clean-runner
repetition is required before treating the performance effect as settled.
The commit/manual workflow now rebuilds a pinned pre-fix compiler and runs
these direct speed guards in addition to the existing pre-flow comparison.

## Promotion boundary and next work

This is an opt-in, Windows-x64-only compiler experiment. Before production
promotion, expand the invalid-source and thread-failure matrix, then test
adaptive selection on real projects before making it a default. The bounded
corpus and clean pinned MSVC/Clang/DMD/LDC comparisons are not enough to
guarantee speed or memory use for arbitrary programs.
Incremental object reuse, representative real projects, and broad C/D-class
throughput remain open SH-27 goals. Linux and freestanding remain optional.

For provenance, this branch first proved serially isolated chunks, then
atomic allocator accounting, then right-sized output buffers. A preliminary
thread experiment access-violated. The subsequent call-boundary investigation
found an invalid absolute-address relocation in the native object stream and
a by-reference temporary-copy at the launch intrinsic. RIP-relative callback
addresses and an explicit state pointer corrected those defects; the current
parallel proof does not rely on the discarded experiment.
