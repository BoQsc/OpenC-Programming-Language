# SH-27 critical-path baseline: 2026-09-23

Status: **diagnostic evidence, not parity or Step 0 completion**. The checked-
out compiler started from `94bee1f`; the timing-instrumented worktree was
rebuilt to a byte-exact Stage 2/Stage 3 fixed point. The final type-query
instrumented Stage 3 SHA-256 is
`a0f2f346ecc644f4d9c057731ac31812f309bd9aac08678661ddde76a9766789`.
The local host is Windows x64 with four logical CPUs. Every timed compiler
invocation used the existing 512 MiB parent/process-tree Job limits and
256 MiB disk-headroom check. Raw JSON is in ignored
`build-output/selfhost-sh27/sh27-roadmap-baseline-20260923/`,
`sh27-critical-worker-profile-20260923/`, and
`sh27-critical-acceptance-profile-20260923/`, and
`sh27-type-query-profile-20260923f/` under that same parent.

## Same-host comparator check

The pre-instrumentation Stage 3 compiler passed the three-run local OpenC /
DMD64 2.112.0 compile, execution, output, and RAM checks. MSVC, Clang, and
LDC were not present, so the report correctly says `PARTIAL_COMPARATOR_SET`.
The adaptive-mode median ratios were:

| Workload | OpenC | DMD | OpenC / DMD |
| --- | ---: | ---: | ---: |
| Large functions | 1.185 s | 0.489 s | 2.423x |
| Control flow | 0.687 s | 0.327 s | 2.101x |

These ratios are **not** compared with another run's medians. The clean pinned
five-compiler workflow remains the public parity gate. This local host showed
substantial timing variation even within five paired runs.

## Where adaptive compiler wall time goes

Five order-alternated serial/adaptive pairs of the first instrumented compiler
gave the following *median of each measurement field* (milliseconds except
the external elapsed column). Medians of separate fields need not sum.

| Adaptive lane | External elapsed | Declarations | Flow validation | Fused worker stage | Slowest chunk | Chunk acceptance | Chunk index | Chunk IR lower | Chunk native emit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Large functions | 1.253 s | 313 | 125 | 453 | 406 | 250 | 46 | 78 | 46 |
| Control flow | 0.910 s | 78 | 110 | 344 | 312 | 235 | 0 | 31 | 16 |

The new `native_parallel_profile` reports the slowest chunk's own timings,
not the sum across workers. `workers_wall_ms` measures launch/join plus any
serial fallback; `merge_wall_ms` measures ordered output concatenation. It
also records whether the native launch completed. All five generated
workloads passed byte identity between serial and adaptive modes, and invalid
control-flow inputs retained exact diagnostics. The profile verifier rejects
impossible chunk bounds or nested timing relationships.

One subsequent fixed-point sample added the subgroup attribution for the
*same critical chunk*:

| Workload | Critical source records | Chunk wall | Acceptance | Expressions | Assignments | Calls | IR lower | Native emit |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Large functions | 0–1 | 437 | 235 | 156 | 156 | 47 | 76 | 63 |
| Control flow | 0 | 250 | 157 | 141 | 110 | 0 | 47 | 15 |
| Compiler self-build | 166–221 | 2328 | 966 | 251 | 80 | 435 | 217 | 816 |

This is enough to change the *next experiment*, not to declare a precise
speedup. Assignment validation and first-time type inference are a larger
available target than native emission on the two failing generated lanes;
declaration collection is also substantial on large functions. The compiler
self-build has a different mix: call validation and native emission remain
material there. Preserve that workload as a regression guard rather than
optimizing only for generated arithmetic.

## Diagnostic type-query counts

The explicit `artifact --profile-type-queries` diagnostic switch enables
per-context `ir_node_type` query counts; ordinary `--timings` and production
benchmark runs leave them disabled. An "uncached" count means the
request reached actual inference, including legitimate expected-type-
dependent re-evaluation. It is not, by itself, proof of an erroneous cache
miss. The final instrumented proof recorded:

| Workload | Validation type queries | Uncached evaluations | Assignment-pass queries | Assignment-pass uncached |
| --- | ---: | ---: | ---: | ---: |
| Large functions | 190,982 | 92,678 | 123,136 | 90,368 |
| Control flow | 36,486 | 20,358 | 17,728 | 13,120 |
| Compiler self-build | 114,488 | 99,955 | 10,899 | 9,035 |

Thus 90,368/92,678 (97.5%) of all uncached type evaluations in the large
workload occur during assignment validation; the corresponding control-flow
fraction is 13,120/20,358 (64.4%). The self-build has a different profile,
which is why call validation and emission must remain guarded.

A second diagnostic-only profile allocated one seen-bit record per source
syntax node and distinguished each first uncached evaluation from a repeat.
The rebuilt Stage-2/Stage-3 compiler was byte-exact, and the adaptive
five-workload/invalid-diagnostic proof passed with and without profiling;
native conformance passed 278/278. Its measured native lane was:

| Workload | Uncached evaluations | Distinct nodes | Repeated uncached nodes | Assignment uncached / distinct / repeated |
| --- | ---: | ---: | ---: | ---: |
| Large functions | 92,678 | 92,678 | 0 | 90,368 / 90,368 / 0 |
| Control flow | 20,358 | 20,358 | 0 | 13,120 / 13,120 / 0 |
| Compiler self-build | 100,060 | 100,060 | 0 | 9,085 / 9,085 / 0 |

These counts are from
`build-output/selfhost-sh27/sh27-distinct-type-profile-20260923/auto-fixed-proof.json`
and its adjacent timing records. The self-build source/compiler revision is
newer than the first table, so its absolute count is not an A/B speed result.
The zero repeat count changes the hypothesis: the large assignment cost is
**first-visit inference and surrounding source/symbol/operand work**, not
repeated uncached inference. A bigger type cache alone cannot remove the
measured first-visit cost. Profiling allocation and first-visit kind/call
breakdowns remains necessary before promoting a fused typed-record design.

Eleven same-host order-alternated revision pairs checked the cost of this
instrumentation against the pre-instrumentation compiler on identical input.
Both compilers produced byte-identical outputs; every build stayed within the
RAM guard. Median paired candidate-minus-baseline deltas were -6 ms (large),
-15 ms (control), and +12 ms (self-build). All three passed the existing 5%
non-regression gate. These near-zero changes are **not** compiler-speedup
claims; they only show the diagnostic counters did not cause a material
measured regression on this host.
Those pairs used the intermediate candidate with counting enabled whenever
timings were requested; they are diagnostic-mode overhead evidence, not a
direct performance comparison of the final opt-in CLI revision.

The final compiler passes the same five-workload proof both with query
profiling disabled and with `--profile-type-queries` enabled. The latter is
for diagnosis only and is never used for the pinned C/D parity timing lane.

A separate eleven-pair check of the final **non-profiling** revision against
the original compiler passes the 5% guard on large functions and control
flow. Its compiler self-build check **fails** locally: median paired delta
is +0.517 s, versus 5.910 s baseline and 6.702 s candidate independent
medians. Both self-build series were substantially slower and noisier than
the earlier calm-host comparison. This is an unresolved promotion guard,
not evidence that the final revision is faster or slower on a clean host.
The clean Windows workflow must decide; do not silently waive the failure.
The commit-triggered clean Windows run for `a66e49d` subsequently completed
successfully ([run 35869263867](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35869263867)).
That clears the workflow's bounded self-build speed guard for **that commit**;
it does not erase the local noisy A/B result, prove 1.25x C/D parity, or
pre-approve the later distinct-node instrumentation in this working tree.
The later diagnostic revision `2db2aa8` also passed its clean Windows
[run 35871657516](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35871657516).

## Rejected parser-edge-only prototype

The parser already has direct left/right `NodeResult.record` IDs when it
creates binary and assignment expressions. The retained parse cache discards
them, so native semantic analysis later rediscovers operands from source
positions. The existing **serial** candidate counter recorded 150,539
expression-position probes for `large_functions`, 34,315 for `control_flow`,
and 200,635 for the compiler self-build. These are candidate visits, not
milliseconds; the parallel timing merge currently does not carry those five
older candidate counters.

An isolated, unpromoted prototype on local branch `codex/sh27-parser-edges`
(`33607b6`) retained direct binary/assignment child links with the parsed
syntax. It passed byte-exact Stage-2/Stage-3 bootstrap and the adaptive
five-workload/invalid-diagnostic proof. Eleven same-host order-alternated
adaptive pairs against `2db2aa8`, using the guarded
`benchmark_sh27_existing_compilers.py` harness, gave:

| Workload | Paired median candidate minus baseline | Candidate wins | Decision |
| --- | ---: | ---: | --- |
| Large functions | +41 ms | 4/11 | Regression; reject |
| Control flow | -8 ms | 8/11 | Too small to close the gap |

The raw local reports are
`build-output/selfhost-sh27/sh27-parser-edges-prototype-20260923/large-pairs.json`
and `control-pairs.json`. Both variants compiled and executed the same output
bytes within the 512 MiB Job guard. The measured critical-chunk acceptance
median did not improve on large functions (172 ms in both groups), so direct
parser links alone do not solve first-visit semantic cost. The branch remains
isolated and is **not** in the production compiler. The next prototype must
fuse type/symbol/operand work across acceptance and lowering; merely retaining
the operand indexes adds storage and copying without material end-to-end gain.

## Correctness and interpretation limits

- The final instrumented compiler passed exact self-hosting closure, native
  conformance **278/278**, Windows x64 substrate **25/25**, integer-boundary
  traps, and the five-workload serial/adaptive byte-and-diagnostic proof.
  The SH-27 Python harness tests pass **13/13**.
- Top-level `phases_ms` are wall elapsed. `compiler_owned` and the merged
  `validation_profile` are summed worker times in parallel mode and must not
  be added to the wall phases. Critical-chunk subcounters are sequential
  observations on one worker, but some are nested and the millisecond clock
  is coarse; do not require their sum to equal chunk wall time.
- External elapsed also includes process startup, harness measurement,
  report writing, and exit. The local host is noisy; a single sample or a
  cross-run change is not a compiler speed claim.
- Step 0 still needs allocation/query-count profiling and clean-runner
  confirmation. No broad C/D parity or representative-project claim follows
  from these measurements.

## Decision for the next architectural prototype

Profile first-visit expression kinds, name/symbol probes, operand lookup,
and allocation during acceptance. Then prototype a fused typed-expression
record produced during the existing syntax/semantic walk, carrying direct
operand and symbol references into validation and lowering. It must remove
work on the *first* visit rather than merely cache duplicate queries that
the measured workloads do not make. Preserve the fallback where inference
depends on an expected type. Require same-command paired wall-time gains,
exact diagnostics, full correctness, and the 512 MiB Job guard before
production promotion. If the refreshed critical path moves to native
lowering/emission, begin the register/value-location redesign in
`SH27_COMPLETION_ROADMAP.md`.
