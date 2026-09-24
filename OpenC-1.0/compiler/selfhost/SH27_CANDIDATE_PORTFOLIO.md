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
`SH27_TYPED_PIPELINE_REJECTION.md`. The opt-in first-visit probe and its
bounded hypotheses are in `SH27_ACCEPTANCE_FIRST_VISIT_PROFILE_EVIDENCE.md`.

## Next decisive batch

1. **Fused validation and lowering:** remove a separate valid-source scalar
   rule traversal, not add an eager fact arena. Keep `check` and invalid
   diagnostic replay exact. Require a counter for *old traversal omitted*,
   byte-exact fixed point and artifacts, strict memory, then 11 paired runs.
2. **Critical-path and allocation profiler:** attribute the first large and
   control worker's wall to actual child/name/call scans, rules, scratch
   allocation, lowering, and emission without summing nested clocks. Use the
   result to choose the next two source cuts and set plausible millisecond
   bounds before another implementation batch. The opt-in probe is complete:
   large/control critical-worker acceptance is 157/141 ms in the unprofiled
   11-pair trace, with 255k/45k child-candidate and 58k/13k name-candidate
   visits. An independent parser-built compact sidecar is now being screened
   only if it replaces those visits rather than adding another cache.
3. **Function scheduling only after an ownership boundary:** if fused lowering
   yields a read-only prepared-source/function boundary and budgeted scratch,
   try acceptance/lowering work sharing across the existing four workers.
   Otherwise keep the source worker policy and record a no-go. The current
   eager typed arena does **not** provide that boundary.
4. **Clean final proof, not a local lucky run:** a surviving source needs
   complete conformance, exact invalid diagnostics, 20-generation 64/256 MiB
   child plus 512 MiB Job proof, representative self-build/project benchmarks,
   then two independent normal-default clean 20/20 C/D comparator runs of the
   *same final source*. Incremental builds and release gates still remain
   afterward under `SH27_EXECUTION_PLAN.md`.
