# SH-27 source-evidence ownership flow gate

Status: **locally proved, not clean-CI proved or SH-27 complete**. Candidate
source commit `884c1ef` is isolated on `codex/sh27-flow-front-end-cut` and
compared with the unchanged parallel-declaration compiler at `4205c1c`.
The purpose is to remove an entire inapplicable ownership analysis from
scalar functions, not to treat an internal phase counter as a parity result.

## Hypothesis and exact boundary

The latest local native profile of the parallel-declaration source records
ownership analysis as 31 ms on `large_functions` and 48 ms on
`control_flow` (summed flow-worker subphase clocks, not end-to-end wall
time). The generated source has no `own` or `destroy` construct and its
functions have no resource-typed/owned symbol. The old validator still
called `flow_analyze_ownership` for every function, where it repeated
function-body word scans before returning.

`flow_source_features` now records possible `destroy` text in the same
source scan that already detects `own`. The function-owner symbol index
already marks resource/owned symbols. Skip the ownership analysis only
when a function has a known owner, neither source-level construct appears,
and the indexed owner has no relevant symbol. Unknown owner, any possible
`own` or `destroy`, and any relevant symbol retain the existing full
analysis. This is a conservative proof gate: source-wide text hits may
run unnecessary validation, but cannot suppress an applicable function.
It does not skip initialization, out, borrow, pointer, unsafe, or other
flow rules.

## Local guarded proof

- Byte-exact Stage 2/Stage 3 bootstrap: PASS.
- Native conformance: 278/278. Serial/adaptive executable bytes and
  invalid-control-flow diagnostics: exact. All five generated workloads
  and two invalid cases passed the 512 MiB Job proof.
- Strict 20-generation compiler self-build: 20/20 exact closures; peak
  child private **251,482,112 bytes** (<256 MiB) and working set
  **55,050,240 bytes** (<64 MiB).
- Eleven order-alternated same-host revision pairs, normal default and
  guarded execution, produced byte-identical generated executables:

| Workload | Median paired candidate minus baseline | Candidate wins | Decision |
| --- | ---: | ---: | --- |
| Large functions | -9 ms | 6/11 | Small gain; not enough for large-function parity |
| Control flow | -26 ms | 9/11 | Material reduction of the previously measured 100 ms control deficit |
| Complete compiler self-build | -47 ms | 8/11 | No self-build regression; fixed-point output passes |

The independent medians from the generated-workload pair reports were
0.812/0.793 s for large functions and 0.513/0.481 s for control flow
(baseline/candidate). These do **not** determine C/D parity; the pinned
comparators were not present in the local paired lane. The self-build pair
report compares two prebuilt fixed-point compilers on identical current
compiler source and records exact candidate fixed-point closure. Its
individual runs were noisy, so the paired median, wins, and strict chain
are retained rather than presenting a cross-run median subtraction.

The candidate diagnostic snapshot reports zero ownership-analysis time on
the generated large/control workloads, but that counter is only evidence
that the gate selected the intended path. The paired wall times above are
the speed evidence. This cut removes a useful part of the control-flow
gap, not the 241 ms large-function budget. SH-27 still requires the fused
semantic/lowering or another measured larger architecture, representative
projects, incremental reuse, and two final clean normal-default parity
runs. Run clean CI before promoting this candidate into any production
branch; retain raw local reports under ignored
`build-output/selfhost-sh27/sh27-flow-front-end-cut-20260924/`.
