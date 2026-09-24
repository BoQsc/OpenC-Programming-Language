# SH-27: replace assignment/binary acceptance with function semantic IR

Status: **Phase B2 generated-corpus coverage tranche** on isolated branch
`codex/sh27-function-semantic-ir`, based on unchanged production compiler
source `1b58d5e`. No throughput result or promotion is implied.
The correct but below-noise kind-29/36 cache-slot experiment is preserved
separately as `codex/sh27-lowering-consumption-cut` at `b1d0b26`.

## Why the cut must delete a traversal

The pinned opt-in first-visit profile counts 92,678/20,358 distinct uncached
type evaluations on large/control, **zero** repeated uncached evaluations,
and 90,368/13,120 uncached evaluations during the assignment sweep. The
first-visit profile also counts 255,235/44,867 expression-child candidate
visits, 58,391/13,009 name candidate visits, and 440,600/88,664 sampled
rule visits. It does not profile every acceptance rule. A cache hit in later
lowering cannot remove the original visit or its source-wide sweep.

On the same corpus, the clean unprofiled critical worker median is 312/219 ms
for large/control. Nested acceptance expression time is 94/125 ms, of which
assignment is 79/94 ms. IR lowering is 62/32 ms. Entire acceptance is
157/141 ms. These are medians of independently rounded, sometimes nested
fields; they must not be added as a forecast. If both the whole expression
acceptance stage and *all* IR lowering vanished, the deliberately impossible
upper bound would be **156/157 ms** on the critical worker. Removing the
assignment/binary sweeps alone is bounded by the 94/125 ms expression stage,
and real gain is lower because other expression checks and necessary IR remain.
A different worker may become critical. These profiles predate `1b58d5e`, so
the bounds are directional, not a measured speedup for this revision.

## Existing duplicate path and proposed replacement

| Current production path | Current work | Proposed valid fast path |
| --- | --- | --- |
| `ir_index_initialize.p`: `ir_initialize_node_indexes` | Builds expression/edge indexes | Keep; count eligible assignment/binary nodes in this existing sweep |
| `acceptance_driver_source.p`: feature sweep, then `acceptance_validate_assignments` and `acceptance_validate_binary` | Walks all expression nodes twice and starts first recursive type visits | Delete both sweeps for fully eligible native-build sources; retain as legacy/check path |
| `ir_part3_uncached.p`: `ir_node_type_uncached` kinds 27, 29–38 | Rediscovers name/children/operator, recursively infers child types, selects calls | Move covered first-visit semantics into the function visitor; retain legacy function only for uncovered kinds/fallback |
| `ir_lower.p`, `ir_lower_primary.p`, `ir_lower_binary.p`, `ir_lower_call.p` | Recurses through the same expression structure to emit IR and repeats type/child/operator queries | A single function-body visitor returns type plus value/address and emits IR once validated |
| `backend_c_project_source.p`: `c_emit_source_record` | Validates whole source before calling `c_lower_and_emit_function` | Fast path owns the semantic/IR visit and a source-level commit barrier; old path remains for `check`/ineligible sources |

Additional previsit hazard: `acceptance_validate_locals` checks initializer
types, `acceptance_validate_returns` checks return types, and conditions/call
rules can also invoke `ir_node_type` before lowering. The first executable
tranche therefore admits only assignment expression-statements with scalar
`+` binary trees, direct `i32` names/literals, no local initializer, no
covered return/condition expression, and no call. This is a structural
correctness tranche, **not** a whole-corpus speed candidate. Subsequent
tranches must move local initializer, return, condition and call type/rule
work into the same visitor before widening eligibility; merely skipping the
two named sweeps would leave their first visits elsewhere.

The new visitor is not an eager source-sized typed-op arena. A visit of an
eligible expression returns a small stack value `{type_id, value_id,
address_id, validity}`. It consumes the already required indexed child/call
edges, resolves names once in the current function scope, checks the old
assignment/binary rules at the point of visit, and emits the corresponding
SSA/IR operation. Function-local scratch may hold temporary call argument
types and conversion decisions; it is reset between functions and capped by
the largest function, not by the source or project. Existing source indexes
remain. DMD v2.112's `expressionsem.d` + `glue/e2ir.d` demonstrate the useful
architectural property—lowering consumes a semantically resolved expression
instead of recovering it from text—but are only comparison material; no DMD
source or D semantics are copied.

### Dependency and semantic rules

1. Assignment visits the LHS as an address/lvalue, determines symbol kind,
   mutability and exact expected element type, then visits the RHS under that
   expectation. A direct name still follows the existing symbol-kind and
   const checks. Preserve the current aggregate/reference store flags.
2. Binary visits both operands even for `false &&` and `true ||` so invalid
   unevaluated operands remain errors. It derives operator, both types,
   literal-fit/conversion, signed-bitwise, shift range and division-overflow
   checks before returning typed IR. Short-circuit affects runtime blocks,
   never semantic visitation.
3. Integer/float/null/optional literals are expectation-sensitive. A type
   inferred without an expected type must not be reused as the final type
   under a parameter/assignment expectation. The visitor carries the
   expectation explicitly and applies the same conversion and fit rules.
4. Calls require callee/overload choice before final expected argument types.
   The call visitor first obtains argument type facts needed for selection,
   then selects the target, and only then emits/coerces arguments left to
   right. Keep those facts in call-local scratch so a second full child walk
   is not introduced. Builtin fallback and unresolved selections retain the
   current `ir_select_call` behavior. The first executable tranche may treat
   calls as opaque legacy leaves **only if** all nested assignment/binary
   nodes are still visited exactly once; otherwise the source is ineligible.
5. `ir_lower_mode` address/value/borrow modes and pointer faults are part of
   the result contract, not a post-hoc type guess. No producer of an invalid
   type may be passed to native emission.

## Fail-closed, exact-diagnostic state boundary

`openc check` keeps the legacy acceptance pipeline unchanged. In native
`build`, preserve the current flow/declaration prechecks. Replace the current
`acceptance_expression_features` pass with an eligibility census over the
existing `expression_nodes` index. A source with global initializers,
unsupported expression forms, unowned nodes, or ambiguous call nesting uses
the **legacy source path before any speculative lowering**. Semicolon-only
function declarations are not bodies and cannot be assigned a later block.

For an eligible source, the visitor validates every covered syntactic node,
including nodes in dead/short-circuit branches. Exact expected and visited
assignment/binary counts must match before the source commits. Coverage must
be established by the indexed single-parent expression graph, not by count
equality alone: duplicate visits cannot cancel missed nodes. If a rule fails
or coverage unexpectedly fails, workers suppress speculative diagnostics,
discard their private chunk output and per-source scratch, then run the old
project acceptance path on a clean context to reproduce category order,
reason, span, and `SEMANTIC_ERROR` count. In particular, assignment errors
precede binary details even if the visitor encountered a binary first.
Only after all deferred rules, remaining acceptance families, and coverage
checks pass may native bytes be merged/final PE emitted. Do not replay using
the mutating speculative `IrContext` or merely reset `types.length` without
proving all type/cache mutations are append-only.

This uses the existing chunk isolation in `backend_c_parallel.p` and
`backend_c_parallel_state.p`: chunk output and type/layout caches are worker
owned until merge. The implementation must audit `c_emit_source_record`
(`backend_c_project_source.p`) and the fallback boundary in `backend_emit.p`
so no partial PE, type registry mutation, or speculative diagnostic leaks.
Release speculative worker state before legacy replay to stay under strict
64/256/512 MiB guards. Do not launch parallel workers until this serial
contract is proved.

The current chunked native path already suppresses worker diagnostics and
holds output/type copies privately, then destroys those workers before
source-order legacy replay on errors (`backend_c_parallel_state.p`). The
prototype may use this boundary only for 2/4-source-chunk builds; one-source
serial emission remains entirely legacy until it has an equivalent clean
fallback. If a speculative coverage mismatch replays as *valid*, run that
source through legacy emission rather than treating the mismatch as a user
error. No replay may reuse a mutating worker `IrContext`.

## Executable tranche and kill criteria

**Phase A is correctness-only.** Prove source-all-or-nothing routing, clean
diagnostic replay, exact PE/runtime, and actual deleted assignment/binary
sweeps on narrow expression-statement fixtures. Do not time or advertise a
fixture-only result as SH-27 speed progress.

**Phase B is the throughput cut.** Move local initializer, return and
condition first visits into the same visitor, then calls with callee-before-
argument expectations. Require substantial eligibility on both generated
large/control corpora and the compiler self-build before any performance
claim. If those sources mostly remain legacy, Phase A does not advance the
SH-27 throughput gate.

1. Introduce a function-local `semantic_ir_visit` for scalar name/literal,
   binary and assignment, with call-local facts only where required. Keep
   legacy visitor for unsupported syntax. The first tranche must actually
   route eligible `build` sources around both acceptance sweeps and the
   covered `ir_node_type_uncached` path; interface-only types or retained
   fact slots do not count.
2. Record `eligible_sources`, `legacy_sources`, `visited_assignments`,
   `visited_binaries`, `legacy_assignment_sweep_visits`,
   `legacy_binary_sweep_visits`, `covered_uncached_type_calls`, and reasons
   for every fallback. A successful fast-path sample must show zero legacy
   assignment/binary sweep visits and zero covered uncached type calls.
3. Guarded Stage 1→3 fixed point, byte-exact PEs/runtime, and exact
   `check`/`build` diagnostics on valid, invalid, short-circuit, expected-
   sensitive literal, overload, and semicolon-declaration cases come before
   any timing. Check 64/256 MiB strict self-build as well as 512 MiB corpus
   limits; memory must not grow from an extra source-sized arena.
4. Then run serial 11-pair large/control with an adjacent baseline-vs-
   baseline null control. Promote only a whole-wall gain above each lane's
   null floor with no protected regression. If the removed-work counters are
   real but wall gain stays below noise, stop and profile the next dominant
   phase; do not enlarge a cache or claim SH-27 closure from counters.

The earlier fused-lowering prototype (`31f4450`) already showed that moving
acceptance time into an expression phase without removing work fails on a
clean Windows runner. This design is falsified if the old sweeps still run,
if the visitor itself performs a second recursive semantic walk, if invalid
diagnostics require emitting partial output, if strict RAM worsens, or if the
two-lane whole-wall result stays below the measured null floor.

## Phase A proof and strict limitations

The first executable cut is restricted to native two-/four-source worker
builds whose source contains only direct `i32` assignment statement roots,
`+` binary trees, simple names/literals, uninitialized locals, and simple
returns. The bounded preflight rejects syntax above 2048 nodes, so the
generated large/control workloads and compiler self-build do **not** exercise
this route. It is a correctness wedge, not an SH-27 performance candidate.

Guarded Stage 1→3 bootstrap at
`build-output/sh27-function-semantic-ir-phase-a-bootstrap-01/bootstrap-current`
passed a byte-exact Stage 2/3 fixed point, SHA-256
`0ce0821b8a6ff5e5c3bc1be1038454ad229f5d4336ff05c6b2666f62e8264c07`.
Stage 3 peaked at 256,790,528 private bytes and 60,399,616 working-set
bytes under the 512 MiB bootstrap guard. The two-source valid fixture
activated 2/2 sources, with 3/3 expected/visited assignments and 3/3
expected/visited binaries; legacy sweep visits, covered uncached type calls,
and clean replays were all zero. Candidate and frozen-production baseline
emitted the same 6,144-byte PE, SHA-256
`aab2b07a98b5a5a18b4287280dec34006317c8c5161a9b8cb332bf6078d5c43d`,
both exiting 7 with empty stdout/stderr. The invalid unresolved-name fixture
triggered one clean replay; no PE was written, and baseline/candidate
diagnostics and exit status matched exactly. These artifacts are ignored
local evidence, not published release results.

Phase B1 replaced the O(statement × expression) containment loop with a
linear census plus disjoint expression-root DFS, using only existing kind-38
call-cache slots for kind-36/37 ownership marks. Duplicate ownership and
depth above 64 reject the fast path. It removed the 2048-node source cap and
covers `i64` `+`, `-`, and `*` (including exact multiply-by-one lowering).
The valid generated eight-source large-functions workload activates 7/8
sources. Source 0, which contains the call-heavy `main`, rejects at the
unsupported-expression preflight. The seven active sources cover 21,504
assignments and 28,672 binary nodes: expected counts equal lowering visits,
while legacy sweep visits, covered uncached type calls, and clean replays are
all zero. The candidate and frozen production compiler produced byte-identical
1,344,512-byte PEs, SHA-256
`81d22e50b31b4c958bce1e3da02c7c114d67ca815934b58b2902cb97cbb76c4e`,
and both programs exited 0 with empty output. The guarded 512/512 MiB compile
passed. Stage 2/3 compiler self-build fixed point passed with SHA-256
`0c3cc3e5076f21fbe86b6b4eec36820ead5b7c299fba4d3707e24237f24b689a`.
These are local ignored artifacts under
`build-output/sh27-function-semantic-ir-phase-b1-bootstrap-02` and
`build-output/sh27-function-semantic-ir-phase-b1-large-*-{timings,memory}.json`;
they are not a published release result.

Phase B2 subsequently covers all generated large/control sources, including
the critical source-0 call and condition paths, but compiler self-build
eligibility remains zero. Its exactness and limitations are recorded in
`SH27_FUNCTION_SEMANTIC_IR_B2_EVIDENCE.md`. The strict 64/256 MiB self-build
and paired/null wall-time gate remain pending; B2 must not be promoted as
SH-27 throughput closure.
