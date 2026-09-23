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
The same paired local baseline reported 297 ms median top-level declarations
on large functions, 31 ms resolution, 125 ms validation, and 375 ms for the
lowering/native phase (which includes worker acceptance). These top-level
phase medians are separate observations from the 172 ms critical-chunk
acceptance median; do not sum a nested worker value into them. Declaration
collection is a substantial serial cost. The refreshed clean-runner profile
must decide whether the declaration/index redesign precedes the native
value-location backend experiment.

## Serial declaration cost resolved to parser work

Two opt-in diagnostic adaptive proofs of the same instrumented compiler
(`sh27-declaration-detail-20260923/auto-proof.json` and
`auto-strict-proof.json`) passed exact output, invalid-input diagnostics,
fixed-point bootstrap, and the process-tree RAM guard. The declaration
subprofile reported:

| Workload | Declaration phase, two observations | Lex/alloc | Parse/syntax alloc | Compact copy | Reread/predeclare |
| --- | ---: | ---: | ---: | ---: | ---: |
| Large functions | 312 / 281 ms | 94 / 78 ms | 202 / 203 ms | 0 / 0 ms | 0+16 / 0+0 ms |
| Control flow | 94 / 63 ms | 0 / 0 ms | 94 / 63 ms | 0 / 0 ms | 0 / 0 ms |
| Compiler self-build | 610 / 609 ms | 189 / 171 ms | 375 / 391 ms | 46 / 31 ms | 0 / 16 ms |

The Windows millisecond clock is coarse and these are diagnostic-mode
single observations, not paired speed comparisons. Nonetheless, the parser
is consistently the largest declaration subphase on large functions and
self-build; source reread and type predeclaration are not the explanation.
The current expression parser recursively enters ten binary-precedence
levels and checks operator spellings at each level. A single precedence-
climbing expression walk is the next *architectural hypothesis* to prove on
an isolated branch with exact syntax/diagnostics and paired wall time. It
must not be promoted merely because a parser counter falls.

## Isolated precedence-climbing parser prototype

On `codex/sh27-pratt-parser`, a single precedence-climbing walk replaces the
ten binary levels and classifies one- or two-byte operator tokens directly.
The Stage 2/Stage 3 compiler fixed point is byte-exact. A guarded local
baseline/candidate comparison found identical parser output and diagnostics
on all 503 checked-in `.p` compiler sources and conformance fixtures. The
candidate passed the adaptive five-workload/invalid-diagnostic proof,
native conformance **278/278**, x64 substrate **25/25**, and the 13 SH-27
Python harness tests. All compared compiler processes stayed within the
512 MiB Windows Job guard. Raw reports are under ignored
`build-output/selfhost-sh27/sh27-pratt-prototype-20260923/`.

Eleven order-alternated same-host baseline/candidate pairs gave:

| Workload and mode | Paired candidate-minus-baseline median | Candidate wins | Output proof |
| --- | ---: | ---: | --- |
| Large functions, adaptive | -46 ms | 11/11 | byte-identical executable and runtime output |
| Control flow, adaptive | -9 ms | 9/11 | byte-identical executable and runtime output |
| Large functions, serial/default | -44 ms | 11/11 | byte-identical executable and runtime output |
| Control flow, serial/default | -11 ms | 9/11 | byte-identical executable and runtime output |
| Full compiler self-build, adaptive | -64 ms | 10/11 | both compiler revisions produce the same candidate fixed-point binary |

The self-build A/B harness initially and incorrectly required the older
baseline compiler to reproduce its own binary while compiling *candidate*
source; that run reported a false failure. The corrected harness checks that
both compiler revisions produce the candidate fixed-point binary from the
same candidate source. The 11-pair rerun passed. The first failed report is
retained as `selfhost-fast-pairs.json`; the valid rerun is
`selfhost-fast-pairs-corrected.json`.

The isolated candidate subsequently passed the full clean Windows
[native proof run 35882311463](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35882311463)
at `c4f20fa`. Two independent 11-pair clean Windows revision comparisons
against `75bd633` also passed at the same compiler-source cut: the
[large-function run 35883340256](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35883340256)
reported a -39 ms paired median with 11/11 candidate wins, and the
[control-flow run 35883343485](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35883343485)
reported -4 ms with 6/11 wins, one tie, and no material regression. Both
compilers reached their Stage 2/Stage 3 fixed points, produced byte-identical
generated executables and runtime output, and passed the Job memory checks.
The local paired self-build passed 10/11 wins with -64 ms median. This clears
the parser promotion gate for the SH-27 working proof branch; it is **not**
SH-27 completion.

The native proof's two production-corpus artifacts explicitly run OpenC with
`--source-chunks=4` and `--source-chunks=auto`. Both happened to report
`PASS_PARITY` on that runner, but they are **opt-in modes**, only three samples
per lane, and not the normal/default OpenC compiler. They cannot satisfy the
roadmap's two-run, five-sample default-mode parity gate. A separate
normal-default parity-enforcing workflow is pending. The semantic first-visit
and assignment costs remain the next larger redesign target.

## Pinned DMD source comparison: architectural hypotheses

The comparator source reviewed here is official DMD **v2.112.0**, the version
pinned by the production corpus. This is a source-structure comparison, not
proof that any single DMD choice causes its measured speed advantage.

- DMD's [multiplicative and additive parser levels](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/parse.d#L9128-L9189)
  are also recursive-descent precedence levels, but they dispatch on a token
  enum (`TOK.mul`, `TOK.add`, etc.). OpenC's previous ten-level parser checked
  source spellings repeatedly with `parser_check`; the isolated prototype
  replaces that dispatch. Precedence climbing itself is **not** something
  established as necessary by DMD's design.
- DMD's [Expression](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/expression.d#L296-L305)
  retains a semantic `type`, while its
  [BinExp](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/expression.d#L2621-L2631)
  retains direct `e1`/`e2` operands. Its
  [expression-semantic entry](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/expressionsem.d#L14703-L14727)
  returns immediately for a completed expression; the assignment visitor
  operates on those direct operands. The
  [DMD backend handoff](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/glue/e2ir.d)
  consumes the semantically typed expression tree. In contrast, OpenC's
  `ir_node_type_uncached` and `ir_left_expression`/`ir_right_expression`
  often recover operands from flat syntax records and source positions on
  the first visit. The **inference** is that a compact typed-expression
  record reused across OpenC acceptance and lowering is a promising
  architectural experiment; a parser-only child-index sidecar already
  failed the local speed gate and must not be mistaken for this design.
- DMD's [root memory wrapper](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/root/rmem.d#L19-L50)
  defaults to `GC.malloc` with a malloc fallback. The earlier roadmap's
  shorthand about a DMD-wide bump allocator was unsupported and has been
  corrected. OpenC should profile its own allocation calls and lifetimes
  before selecting any arena scheme.
- DMD's [link path](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/link.d#L187-L333)
  invokes an external linker. OpenC's Windows native/CRT-free binary path is
  an independence requirement, so an external-linker substitution is not a
  valid shortcut to match DMD's compile/link measurement. Measure PE writing
  separately and improve it only if it occupies a material critical path.

The next first-visit profile should therefore time symbol resolution,
operand discovery, contextual type fallback, and allocation inside
assignment acceptance. The proposed redesign must remove those first-visit
costs across acceptance *and* lowering; reducing cache misses or moving
records between buffers is not success. Re-measure wall time and memory on
the same workload after each prototype, with DMD left as a comparator, not
a toolchain dependency.

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
