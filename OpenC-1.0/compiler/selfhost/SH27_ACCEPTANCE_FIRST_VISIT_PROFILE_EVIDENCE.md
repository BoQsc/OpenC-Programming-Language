# SH-27 acceptance / first-visit profiler probe

Status: **isolated instrumentation, not a speed candidate**. This branch starts
at `6794d56`. None of its counters or histogram should be merged into the
production compiler. The new `acceptance_probe` JSON section is opt-in through
the existing `artifact --profile-type-queries --timings=...` switch.

The probe counts actual candidate visits in the indexed first-name, local/top
symbol, expression-child, and overload loops, plus visits in the expression
feature, assignment, binary, call, and overload-rule sweeps. `sampled_rule_visits`
does **not** claim to count all acceptance rules. It also records the exact
number and requested bytes of per-source scratch allocation sites in the
profiled source constructor, excluding allocator internals and later buffer
growth. The 43 per-source requests include the profiling-only type-seen
bitmap (unprofiled construction has 42). The function histogram measures
lowering-plus-emission wall with the existing Windows millisecond timer;
zero milliseconds means below one observed timer tick, not zero work.

## Guarded proof and opt-in counters

The corrected probe passed all three guarded bootstrap stages, with a
byte-exact Stage 2/3 fixed point. Stage 3 peak private/working-set was
**254,910,464 / 59,858,944 bytes**; Stage 2 was **261,324,800 /
67,579,904 bytes**. The separate strict 64 MiB Stage 2 working-set threshold
is therefore an unproved risk, not a release pass. The bootstrap record is
`build-output/selfhost-sh27/sh27-acceptance-profile-bootstrap-v2-20260924/
bootstrap-current/bootstrap-current.json` in this worktree.

One guarded opt-in compile per established SH-27 corpus passed its 512 MiB
private and working-set limits. The generated PE files are SHA-256 byte-exact
with the clean `6794d56` baseline from the 11-pair matrix: large
`81d22e50b31b4c958bce1e3da02c7c114d67ca815934b58b2902cb97cbb76c4e`;
control `31b8906a62a954d885b37fe8a03a94010eefaa619648f42626620ca455590e50`.
These are compile/output proofs, not a new runtime/conformance suite.

| Opt-in profile, whole build | Large functions | Control flow |
| --- | ---: | ---: |
| Source bytes / source files | 741,660 / 8 | 206,637 / 4 |
| Name candidate visits | 58,391 | 13,009 |
| Expression-child candidate visits | 255,235 | 44,867 |
| Overload candidate visits | 310 | 81 |
| Sampled rule visits | 440,600 | 88,664 |
| Type queries / uncached distinct first visits | 190,982 / 92,678 | 36,486 / 20,358 |
| Repeated uncached type visits | 0 | 0 |
| Source scratch allocation requests / requested bytes | 344 / 101,490,936 | 172 / 23,312,496 |
| Function wall: 0 ms / at least 8 ms | 2,012 / 37 | 238 / 19 |
| Guarded compile peak private / working-set bytes | 156,729,344 / 75,026,432 | 85,733,376 / 51,085,312 |

All intermediate 1, 2–3, and 4–7 ms histogram buckets were zero. The native
timer uses `GetTickCount64`, whose coarse effective granularity makes this
histogram useful only to show that **most individual functions are below timer
resolution**. It cannot rank sub-millisecond functions or estimate their
percentiles. The `type_query_profile` first-visit data is exact as a counter,
but the opt-in tracing adds overhead; these profiled wall times must not be
treated as baseline compilation speed. Raw corrected opt-in records are under
`build-output/selfhost-sh27/sh27-acceptance-profile-runs-v2-20260924/`.

## Ranked critical-worker wall account

Use the **unprofiled**, clean-baseline 11-pair matrix at
`C:/Users/Windows10_new/Documents/OpenC Programming Language/OpenC-1.0/
build-output/selfhost-sh27/sh27-direct-immediate-matrix-20260924.json` for
wall budgets. Its paired corpus and compiler are the same as this probe.
Each number below is a median of the baseline samples, not an additive sum
from one sample; percentages are approximate. The critical worker's phase
times are nested within its wall. Expression, assignment, and call times are
**subsets of acceptance**, and total acceptance across all workers is not
serial wall time.

| Unprofiled critical worker | Large functions, 312 ms wall | Control flow, 219 ms wall |
| --- | ---: | ---: |
| Acceptance | 157 ms (50%) | 141 ms (64%) |
| IR lowering | 62 ms (20%) | 32 ms (15%) |
| Native emission | 32 ms (10%) | 0 ms at timer resolution |
| Indexing | 31 ms (10%) | 15 ms (7%) |
| Other / phase gaps, paired median | 31 ms (10%) | 16 ms (7%) |
| Nested expression / assignment within acceptance | 94 / 79 ms | 125 / 94 ms |

Thus acceptance + IR lowering + native emission account for approximately
**80%** of the large-function critical-worker wall; acceptance + IR lowering
+ indexing account for approximately **86%** of control-flow wall. These
rankings are not obtained by adding the opt-in profiled worker times, which
were 547/375 ms and perturbed by counter collection. The production
median critical walls were 312/219 ms.

## Falsifiable architecture cuts and maximum possible savings

The bounds are deliberately generous **upper bounds on critical-worker wall**
if the named work vanished entirely. They are not forecasts and are not
additive because the categories overlap or a different worker can become
critical.

1. **Typed acceptance plan shared with lowering.** Resolve each expression's
   type, operation, and assignment compatibility once, then consume that
   immutable plan in validation and IR lowering. First-visits are distinct
   (92,678/20,358) with zero repeated uncached queries; a mere memoization
   cache is therefore the wrong hypothesis. The entire acceptance phase caps
   the critical-worker gain at **157/141 ms**. Falsify by showing the new plan
   removes visits but acceptance and two-lane wall do not improve, or changes
   diagnostics/PE output.
2. **Compact expression/name child sidecar.** Carry direct parent/child/name
   links from parser indexing so assignment/binary rules do not revisit
   syntax spans and hashed candidates. The probe saw 255,235/44,867 child
   visits and 58,391/13,009 name visits. The nested acceptance expression
   phase gives an acceptance-side cap of **94/125 ms**; assignment alone is
   bounded by **79/94 ms** and is inside that cap. Falsify by eliminating
   these visits while expression wall or unprofiled two-lane compile wall
   stays flat.
3. **Source scratch arena and reuse.** Replace 43 allocation requests per
   profiled source with a sized arena/reuse policy without increasing peak
   live memory. The 101.5/23.3 MB requested across sources are cumulative,
   not live peaks. Since these source-construction allocations sit outside
   indexed/acceptance/IR/emission phase timers, the critical-worker residual
   gives only a **31/16 ms** upper bound. Falsify if direct allocation timing
   or paired wall shows a smaller/no signal, or strict RAM worsens.
4. **Chunk ownership rebalance.** Partition large source records by measured
   first-visit cost rather than source count, while preserving diagnostics
   ordering. The median slowest-minus-second-slowest worker gap caps a pure
   schedule gain at **94/16 ms**; it cannot remove acceptance work. Falsify if
   critical wall remains after worker spread narrows or scheduling overhead
   erases the gain.

The next engineering experiment should be an architecture cut, not another
counter/cache micro-tweak: typed acceptance plus lowering has the largest
single-phase bound and is aligned with the existing critical path. Any speed
claim still needs guarded paired large/control results, full diagnostics and
conformance, fixed point, and the strict self-build RAM gate.
