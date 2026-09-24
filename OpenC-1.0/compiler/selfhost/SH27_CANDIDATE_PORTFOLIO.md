# SH-27 throughput candidate portfolio

Status: **no compiler-speed candidate promoted; SH-27 remains open**.
This file is the short decision index for broad experiments. Detailed raw
samples are in ignored `build-output/selfhost-sh27/` locally or the linked
GitHub Actions artifact. A local result is a triage result, not the clean
20-ratio C/D parity certificate.

## Shared decision contract

All executable candidates start from compiler source `6794d56` (same compiler
source as the `e4e4e9a` worker-profile baseline), keep their source in
isolated branches, and use guarded Stage 2/3 fixed point before comparison.
The [matrix runner](benchmark_sh27_candidate_matrix.py) freezes the SH-27
corpus, runs 11 adjacent baseline/candidate pairs per large/control workload,
rotates order, runs a baseline-vs-baseline null control, and keeps compiler
jobs serial under the process-tree memory/time guards. It requires exact
executed exit/stdout/stderr and deterministic candidate artifacts; only an
explicit codegen policy allows cross-revision PE bytes to differ. Selection
also requires a median gain beyond the null absolute paired delta and a
majority of wins. The [clean batch workflow](../../../.github/workflows/openc-performance-batch.yml)
can reproduce a frozen branch batch on one Windows runner; it is not the
final five-compiler parity gate.

| Independent candidate | Large paired median / wins / null floor | Control paired median / wins / null floor | Decision |
| --- | --- | --- | --- |
| Indexed call summary | -138 ms / 7 of 11 / 249 ms | +21 ms / 5 of 11 / 110 ms | Reject: no signal; call subphase did not shrink. |
| Function-level lowering scheduler | Optimistic zero-overhead model: at most 70 ms | Optimistic model: at most 16 ms | Defer: no immutable source facts or RAM-safe scratch ownership. |
| Packed typed record + batched old validators | 0 ms / 5 of 11 / 154 ms | +7 ms / 5 of 11 / 80 ms | Reject: displaced timers; first-visit work unchanged. |
| Direct native slot layout | -46 ms / 6 of 11 / 136 ms | +11 ms / 4 of 11 / 34 ms | Reject: no whole-compile signal; strict RAM unproved. |
| Adjacent direct-value handoff | -121 ms / 7 of 11 / 80 ms | -29 ms / 8 of 11 / 38 ms | Reject as speed proof: large corpus removes only one pair; apparent win lacks causation. |
| RAX through immediate arithmetic | +7 ms / 5 of 11 / 79 ms | +14 ms / 4 of 11 / 23 ms | Reject for compile throughput despite 31% less large native code. |
| Eager typed-operation pipeline | +2 ms / 5 of 11 / 50 ms | -6 ms / 7 of 11 / 11 ms | Reject: extra traversal repeats semantic work. |
| Scalar validation fused into lowering | Local -98 ms / 7 of 11 / 84 ms; hosted -2 ms / 6 of 11 / 10 ms | Local -15 ms / 6 of 11 / 43 ms; hosted +10 ms / 3 of 11 / 10 ms | Reject speed claim: real scans removed, 278/278 and strict 20/20 pass, clean gain fails. |
| Compact child/name sidecar | Existing indexed/cached paths already serve lowering; no source speed run | Same structural no-go | Reject before implementation: duplicate indexes add memory, not a demonstrated critical-path cut. |
| Per-source scratch arena/reuse | Optimistic heap proxy suggests roughly 6–12 ms critical-worker opportunity | Roughly 1–3 ms critical-worker opportunity | Reject before compiler build: control opportunity below clean 10 ms null; zeroed payload and RAM risk remain. |
| Same-type scalar binary fast path | Local -29 ms / 7 of 11 / 70 ms; hosted -1 ms / 7 of 11 / 5 ms | Local -14 ms / 8 of 11 / 38 ms; hosted -1 ms / 7 of 11 / 2 ms | Reject: clean effect below null on both lanes; no first-visit type work removed. |

The table records *candidate minus baseline*, so negative is faster. The null
floor is same-run baseline-vs-baseline median absolute paired jitter. A
subphase counter or native code-size reduction is not interchangeable with
whole compiler wall time. Detailed evidence is in
`SH27_CALL_PATH_BATCH_EVIDENCE.md`,
`SH27_FUNCTION_SCHEDULING_DECISION.md`,
`SH27_FUNCTION_PIPELINE_BLOCKER.md`,
`SH27_TYPED_OPS_BATCH_CANDIDATE.md`,
`SH27_BACKEND_VALUE_LOCATION_EVIDENCE.md`,
`SH27_DIRECT_VALUE_PATH_EVIDENCE.md`, and
`SH27_TYPED_PIPELINE_REJECTION.md`,
`SH27_LOWERING_FUSION_EVIDENCE.md`, and
`SH27_COMPACT_CHILD_NAME_SIDECAR_NO_GO.md`, and
`SH27_SCRATCH_OWNERSHIP_NO_GO.md`, and
`SH27_SCALAR_FAST_PATH_NO_GO.md`. The opt-in first-visit probe and
its bounded hypotheses are in `SH27_ACCEPTANCE_FIRST_VISIT_PROFILE_EVIDENCE.md`.

## Next decisive batch

1. **Typed first-visit redesign:** acceptance is 157/141 ms of the
   large/control critical-worker wall. Design a typed plan built on first
   required visit and consumed by later checks/lowering, not another eager
   whole-source pass. Prove fewer type/semantic first visits and no new
   traversal or oversized arena before a clean two-lane speed claim.
2. **Bounded independent tracks:** the source-scratch arena and compact
   child/name sidecar are closed as no-go candidates. Model worker
   rebalancing against the 94/16 ms spread ceiling only after immutable
   prepared-source ownership; the bounds are non-additive, not forecasts.
3. **Function scheduling only after an ownership boundary:** the current
   mutable source context is not safe for independently scheduled functions.
   Design a read-only `PreparedSource` and per-worker bounded `WorkerScratch`
   before implementing function-level acceptance/lowering work sharing.
4. **Clean final proof, not a local lucky run:** a surviving source needs
   complete conformance, exact invalid diagnostics, 20-generation 64/256 MiB
   child plus 512 MiB Job proof, representative self-build/project benchmarks,
   then two independent normal-default clean 20/20 C/D comparator runs of the
   *same final source*. Incremental builds and release gates still remain
   afterward under `SH27_EXECUTION_PLAN.md`.
