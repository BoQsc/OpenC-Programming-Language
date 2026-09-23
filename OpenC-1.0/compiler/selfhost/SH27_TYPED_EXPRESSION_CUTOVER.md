# SH-27 typed-expression cutover contract

Status: **design in progress; no compiler speedup claimed**. This is the
implementation contract for Gate C of `SH27_COMPLETION_ROADMAP.md`, not a
substitute for its normal-default DMD parity gate.

## Why a cache tweak is insufficient

The two earlier clean normal-default five-compiler runs failed only
`large_functions` versus DMD (1.390x and 1.376x). A later adaptive-default
policy achieved one clean 20/20 pass; its independent repeat passed strict
memory and correctness but failed DMD ratios at 1.936x large functions and
1.380x control flow. Real-project headroom remains unproved. The large-function
assignment pass accounts for 90,368 of 92,678 uncached type evaluations in
the diagnostic profile, but every one of those 92,678 evaluations visits a
different node. A larger memo table cannot remove the first evaluation.
The latest first-visit histogram splits the large workload almost evenly
among names (26,881), literals (32,772), and binary expressions (32,769).
The target is to remove work across the *whole* acceptance-to-lowering path,
not to tune a single helper or add a parser-edge sidecar; the latter already
regressed the large workload in an isolated eleven-pair experiment.

The implementation must also address an inaccurate shorthand in the roadmap:
there is **not** already a dependency-ordered semantic sweep. The backend
indexes nodes in `ir_initialize_node_indexes`, then
`acceptance_validate_context` runs separate assignment, binary, and other
rule-family passes. `ir_node_type` recursively infers types on demand.
`parse_binary_climbing` and `parse_assignment` create a parent after its
operands, but `parse_postfix` creates a call node *before* its arguments.
Syntax record order is therefore not a universal expression topological
order. No new code may rely on `child < parent` without proving it for the
specific expression kind.

## Target shape

One source-local, bounded typed-expression store lives from source indexing
through acceptance and native lowering. It replaces, rather than supplements,
the five broad per-syntax-node arrays now used for name selection, call
selection, type, left operand, and right operand. A four-word tagged record
per expression node is the initial RAM ceiling: type/result state, payload
A, payload B, and flags. Payloads are kind-specific (symbol for a name or
call, child IDs for unary/binary/assignment, parsed integer bits for a
literal). A record is indexed through a compact expression-node map; avoid
allocating a full four-word record for every declaration or statement. If
the map or tags force more live bytes than the arrays they replace, redesign
the layout before promoting it. Keep current cache arrays behind the
test-only comparison path until cutover is proved, but never allocate both
in normal production mode.

The record has three distinct states: absent, resolved, and contextual.
Only successful expectation-independent results may be reused unconditionally.
An integer literal, null, none, aggregate, or any other expected-type-sensitive
node retains a tagged contextual rule and can be evaluated under a new
expected type. A failed name/overload/type lookup remains retryable because
function selection and argument indexing can change later in validation.
The record may retain a successful symbol or parsed literal without forcing
its contextual type. Integer parsing must happen once for accepted literal
spelling and feed acceptance and lowering; overflow and invalid-literal
diagnostics must remain byte-for-byte identical.

The existing artifact path keeps one `IrContext` across
`acceptance_validate_context` and `c_lower_and_emit_function`; this is the
handoff point. `check` constructs an acceptance-only context and must use
the same resolver/diagnostic semantics but need not retain records for
emission. Each native worker owns source-local records; sharing mutable
records between workers would violate deterministic output and RAM bounds.

## Implementation sequence (one architectural change, gated cuts)

1. **Freeze the phase budget.** Capture a clean-runner critical-path report
   for the currently promoted adaptive-default revision, with normal default,
   explicit serial, and explicit chunk modes separate. Attribute first-visit
   wall time among
   symbol selection, literal parse, operand discovery, contextual type
   inference, assignment rules, and binary rules. Count calls and temporary
   allocation bytes in a diagnostic build. Keep instrumentation out of timed
   A/B samples. This decides whether the typed cut can plausibly remove the
   earlier 60-79 ms observed serial-policy parity deficit and provide margin
   on the current default; if it cannot, move the critical path to
   declaration/index parallelism instead of finishing an expensive cache
   refactor for its own sake.
2. **Define dependency edges and storage.** For binary, assignment, unary,
   member/index, and call forms, specify how child IDs are obtained and when
   they become stable. Calls require argument indexing and cannot use syntax
   creation order as postorder. Define record validity and contextual type
   tags before porting any consumer. Include bounds and allocation-overflow
   checks; the store must remain under the 512 MiB process-tree Job guard.
3. **Build one expression evaluator.** During the existing source acceptance
   operation, walk requested expression dependencies once using an explicit
   bounded stack or proven per-kind postorder. Select function context at a
   stable root/boundary, resolve names/calls, decode literals/operators, and
   publish successful facts to the source store. Preserve recursion/fallback
   only for unsupported or contextual forms. Do not add a whole-source
   semantic prepass before the existing rule passes.
4. **Fuse the high-volume rule families.** Replace the separate assignment
   and binary expression rescans with a single dependency-aware visit that
   computes types and checks lvalue, mutability, conversion, numeric,
   logical, comparison, shift, and overflow rules. Keep diagnostic grouping
   and source order by buffering the bounded rule-family results or by an
   equivalent proof-preserving scheme. Invalid input is part of this cut,
   not deferred cleanup work.
5. **Move lowering onto the same facts.** Make `ir_lower_primary`,
   `ir_lower_binary`, name/call lowering, and dependent rules consume resolved
   child IDs, selected symbols, parsed integer values, and stable types from
   the store. Remove the replaced cache allocations and source rescans.
   Literal values must not be reparsed by acceptance and lowering. Keep the
   old path available only as a test comparator until byte-exact and
   diagnostic equivalence is established.
6. **Prove then promote atomically.** Exercise `check`, serial and parallel
   `artifact`, positive and invalid fixtures, integer/aggregate boundaries,
   byte-exact Stage 2/Stage 3 fixed point, 278 conformance cases, 25 x64
   substrate checks, and deterministic output/diagnostics. Run eleven
   order-alternated, same-host, 512 MiB Job-guarded normal-default pairs on
   large functions, control flow, and complete self-build. Require at least
   10% of the *then-measured failing-lane gap* removed with no >5% guard-lane
   regression, and a clean Windows proof. If the integrated cut fails this
   gate, retain the evidence and redesign; do not promote only its smaller
   helper optimizations.

After promotion, refresh the nonoverlapping critical-path profile. If serial
declarations are now largest, execute roadmap Step 3; if native emission is
largest, execute Step 2. Keep the adaptive policy default, close its memory
gate, deliver real incremental object reuse, add representative projects,
and run two independent normal-default twenty-ratio clean Windows parity
proofs. Those later gates remain mandatory even if this cut clears the DMD
ratio.

## Invariants to test explicitly

- Contextual literals/aggregates keep identical expected-type behavior;
  failed lookups never poison later successful resolution.
- Calls created before arguments still select the same overload and evaluate
  side effects in the same order.
- Assignment and binary diagnostics retain exact code, text, location,
  multiplicity, and rule-family ordering on invalid programs.
- Checked arithmetic, pointer/ownership rules, native ABI, unwind data, and
  deterministic bytes do not change to buy compile speed.
- Peak whole-Job memory, not only parent-process RSS, stays bounded, and
  disabled profiling allocates no diagnostic sidecars.

## Decision log

- Parser precedence climbing: promoted after clean proof; useful but not
  parity closure.
- Parser-edge-only sidecar: rejected (+41 ms median on large functions in
  its local eleven-pair adaptive experiment; no acceptance median gain).
- Larger type memo table: not selected because the profiled uncached visits
  are all distinct; only a fused first-visit path can target that cost.
- Selected-function context cache: rejected after byte-exact fixed-point
  proof and eleven order-alternated local pairs. The median candidate-minus-
  baseline delta was -5 ms on large functions and +10 ms on control flow;
  neither is a material reduction of the SH-27 gap. The experimental compiler
  edits were removed. This does not satisfy any part of the typed-record
  cutover and must not be counted as an accepted speed improvement.
