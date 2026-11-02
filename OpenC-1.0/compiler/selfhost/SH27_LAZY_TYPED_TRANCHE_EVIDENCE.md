# SH-27 lazy typed-operation tranche: substantial bypass, no throughput signal

Status: **isolated and unpromoted**. Source commit `b5a8066` on
`codex/sh27-lazy-typed-ops` starts from production compiler source
`1b58d5e`. It tags successful first-visit facts in the existing type-cache
slot, puts literal/operator/edge/symbol payloads in existing source caches,
and lets covered lowering paths consume those facts. It adds no arena or
eager whole-source pass. Unsupported and expected-type-sensitive cases use
the original path; `check` and invalid artifact behavior remain on exact
fallback paths.

The guarded Stage 1/2/3 bootstrap passed a byte-exact Stage 2/3 fixed point.
Stage 3 peak private/working set was 255,303,680/60,084,224 bytes under the
512 MiB Job guard. Large/control generated PEs were byte-exact with baseline
and executed identically; six focused check/artifact diagnostic fixtures
matched. The Stage-3 compiler SHA-256 was
`3abc7bf489d78b379c17505f8daa3c7124a899e69e9bc51f137a3d92bf42c822`.
Full conformance and strict 20-generation self-build were not run because
the two-lane speed gate failed.

The candidate counted 142,342/27,398 bypassed calls to the *old*
`ir_node_type_uncached` on large/control and 109,318/23,494 lowerer nodes
consuming tagged facts. These counters do not claim that equivalent semantic
work disappeared: the direct first-visit evaluator still resolves types,
children, symbols, and operators, and the caches remain source-scoped because
whole-source acceptance precedes function lowering.

| Guarded 11-pair local matrix | Large functions | Control flow |
| --- | ---: | ---: |
| Candidate-minus-baseline median | -30 ms, 7/11 wins | +9 ms, 4/11 wins |
| Same-run baseline-vs-baseline null floor | 65 ms | 40 ms |

Every generated compile, executed output, artifact-identity, and matrix RAM
check passed; throughput did not. Critical-worker phase deltas were noisy and
nested; they cannot be added into a wall saving. The raw ignored report is
`OpenC-1.0/build-output/sh27-lazy-typed-ops/matrix-01.json` in the isolated
worktree.

Decision: keep this as a useful experimental interface, not a promoted SH-27
speed solution. Replacing a generic first-visit routine with another routine
that computes the same semantics is not enough. The next cut must change
semantic work or the acceptance/lowering ownership schedule, and prove it on
both whole-compiler lanes.
