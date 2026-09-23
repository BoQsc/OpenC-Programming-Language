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

Instrument type-query hits/misses and repeated node/name probes during
acceptance. Then replace repeated assignment-side recursive inference with a
typed-expression table that is built once per source, respects contextual
expected types, and is reused by validation and lowering. Preserve the
existing fallback where type inference is expectation-dependent. Require
same-command paired wall-time gains, exact diagnostics, full correctness,
and the 512 MiB Job guard before considering production promotion. If the
refreshed critical path then moves to native lowering/emission, begin the
register/value-location redesign in `SH27_COMPLETION_ROADMAP.md`.
