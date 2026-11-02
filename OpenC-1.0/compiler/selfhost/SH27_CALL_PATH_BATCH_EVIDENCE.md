# SH-27 indexed call-summary experiment (rejected)

Status: **not promoted**. The isolated source experiment is retained as
`f0c09b6` on `codex/sh27-call-path-batch`; it is not part of the production
compiler branch. Its base is `6794d56`, whose compiler source is the same as
the `e4e4e9a` critical-worker baseline. The candidate lets indexed call
selection retain the number of same-module one-parameter declarations for an
unqualified call. The overload validator selects the call before its existing
diagnostic decision and reuses that summary, while imported, unresolved, and
non-indexed paths retain their original name scan. Its intent was to remove a
duplicate function-bucket search across overload validation, ordinary call
validation, and lowering.

The checked-out-source bootstrap passed three guarded stages and a byte-exact
Stage 2/3 fixed point. The 278-case conformance run was intentionally stopped
before a result to avoid overlapping another candidate's bootstrap. This is
therefore **not** a complete correctness proof. The shared guarded 11-pair
candidate matrix did pass compilation, execution, byte-exact output, and RAM
checks on both generated workloads, but failed the speed-selection rule:

| Workload | Median paired candidate-minus-baseline | Candidate wins | Same-run null noise floor | Critical-worker acceptance/calls median deltas |
| --- | ---: | ---: | ---: | ---: |
| Large functions | -138 ms | 7/11 | 249 ms | -1 / +15 ms |
| Control flow | +21 ms | 5/11 | 110 ms | 0 / 0 ms |

The large apparent gain is below the measured null noise, control flow
regresses, and the call subphase itself does not shrink. Advancing selection
earlier plus allocating one full per-syntax summary buffer is not justified
by these observations. Do not merge this implementation or claim that it
closes the same-run DMD deficit. Raw samples are in
`build-output/selfhost-sh27/sh27-call-path-matrix-20260924.json` in the main
workspace; the isolated branch retains the source experiment for inspection.
