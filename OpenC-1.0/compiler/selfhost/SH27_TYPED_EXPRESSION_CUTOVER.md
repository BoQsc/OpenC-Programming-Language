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

The pinned [DMD 2.112.0 `Expression` definition](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/expression.d)
stores the semantic `type` on the expression object and stores parsed integer
values on `IntegerExp`; its [source map](https://github.com/dlang/dmd/blob/v2.112.0/compiler/src/dmd/README.md)
separates parsing, expression semantics, and native backend. This is useful
evidence for keeping resolved facts beside expression structure in OpenC,
not proof that copying DMD's AST or allocation model will produce DMD speed.
OpenC's compact record must additionally preserve its contextual typing,
checked arithmetic, and exact diagnostics.

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

## Source-grounded record and dependency contract

The native artifact path is `c_compile_project_source` in
`source/backend_c_project_source.p`: it constructs one `IrContext`, runs
`ir_initialize_node_indexes` and the other source indexes, invokes
`acceptance_validate_context`, then calls `c_lower_and_emit_function` on
that *same context*. This is the only hot path that may be cut over first;
the acceptance-only `check` path in `acceptance_driver_project.p`, JSON/D
backends, and diagnostic fallbacks must retain equivalent semantics. The
current five native arrays are each `(syntax.length + 1) * sizeof(usize)`:
`name_cache`, `call_cache`, `type_cache`, `left_expression_cache`, and
`right_expression_cache`. A dense four-word record would use four-fifths
their combined bytes before any sparse mapping; a sparse expression map is
acceptable only if its map-plus-record bytes and lookup time beat that dense
bound on the self-build and generated corpus. Do not allocate the new store
beside all five old arrays in the normal native path.

| Syntax kind | Dependency order and stable source | Record payloads | Contextual rule |
| --- | --- | --- | --- |
| Name `27`, out name `51` | Symbol context selected after function-position index; failed lookup is retryable | Successful symbol ID and type | A failed symbol is never frozen |
| Integer/float/null/none `29`-`34` | No expression children; spelling is in the source span | Parsed integer bits where applicable, type state | Expected type can change result; retain a constraint, not an unconditional type |
| Unary `35` | Parser creates child before parent | Child ID, resulting type | Pass expected type to child where current inference does |
| Binary `36`, assignment `37` | Parser creates both operands before parent, but semantic evaluation may request a different expected type | Left/right IDs, resulting type and operator/rule flags | Preserve the exact literal-fit and assignment-conversion checks |
| Call `38` | Parser creates call before argument nodes; callee ID is syntax field 3 and argument count is field 4 | Selected symbol, result type; arguments stay in indexed adjacency | Do not use syntax record order as postorder or cache a failed overload |
| Member/index/range `39`-`41` | Base and index are recovered from span/index adjacency | Stable base/index IDs and resolved type when independent | Optional, aggregate, and index expectations use fallback until proved stable |

The four words are *tagged by syntax kind*: one type/state word and three
payload words. A name/call uses a payload for the selected symbol; a binary
uses two for child IDs; a literal uses one for decoded value. Unused payload
bits may carry flags, but no valid symbol, type, child ID, or full-width
literal value may be truncated to make room. Zero is the absent state;
successful IDs use an explicit offset encoding so symbol/type/child zero is
representable. An error result remains absent or contextual, never a
reusable successful type. Allocation arithmetic must be checked before
`memory.alloc`, and normal production may not carry both full old caches
and the new store merely to simplify migration.

After the isolated parallel-declaration cut, one local diagnostic profile
shows 62 ms serial declarations but 140 ms acceptance on the large workload's
critical worker, including 78 ms in assignment rules. The 11-pair local
compiler comparison saved 108 ms on that workload. Comparing this gain with
another runner's DMD median would not be a valid speed estimate. Gate C must
target the whole first-visit assignment/type path; the clean same-run
comparator below sets the present planning budget.

The first clean parallel-declaration run passed 20/20 ratios; large
functions measured OpenC/DMD 0.666/0.608 s (1.0954x). Its independent
same-source clean repeat failed two DMD ratios: large functions
0.677/0.349 s (1.9398x) and control flow 0.392/0.234 s (1.6752x).
That runner requires about **241/100 ms** of OpenC wall-time reduction for
the public 1.25x limit and **258/111 ms** for the internal 1.20x margin.
The 78 ms local assignment-rule critical-worker time alone cannot close
this gap. Gate C must remove broader first-visit acceptance and lowering
work, then a fresh profile must select further front-end or native-backend
architecture. Do not sell a packed cache as the entire semantic cut.

The first isolated dense four-word prototype on
`codex/sh27-typed-expression-cutover` replaces the five native cache arrays
without changing semantic traversal. It passed Stage 2/3 fixed point,
278/278 conformance, exact serial/adaptive executables and invalid-input
diagnostics, and a strict 20/20 self-build chain (251.9 MB peak child
private, 54.5 MB working set). Same-host eleven-pair medians against the
unchanged compiler were **-28 ms** large functions (7/11 wins), **-39 ms**
control flow (7/11 wins), and **+136 ms** complete self-build (4/11 wins).
All generated compiler binaries were byte-identical. This is an enabling
storage experiment with a self-build regression, **not** a promoted Gate C
speedup or evidence that the 241/100 ms deficits are closed. The full cut
must fuse dependency-aware type/rule evaluation and lowering reuse before
another promotion decision.

That storage-only source passed one clean Windows pinned-comparator,
strict-memory, fixed-point, conformance, and exact-worker
[run 35920825397](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35920825397).
The normal-default medians were OpenC/DMD **0.504/0.537 s** on large
functions (0.9385x) and **0.313/0.430 s** on control flow (0.7279x), with
20/20 comparator ratios passing. This is one green run on an experimental
source, **not** an A/B proof that packing sped up compilation or a repeatable
parity result. The earlier parallel-declaration repeat failed both DMD
ratios; do not combine medians across these runs.

An attempted literal-value extension of that record was rejected before
commit. The seed-built Stage 2 compiler built, but using it for Stage 3
failed with a checked failure; `openc check` on the compiler project reported
655 semantic violations (predominantly binary comparison/conversion rules),
versus PASS with the packed-record compiler before this extension. A
null-cache direct-parser fallback did not repair it. The literal changes
were removed; the passing packed-record source remained intact. The later
boolean-plus-output prototype below repaired this bootstrap failure, but its
full semantic and performance cutover is still unproved.

The existing artifact path keeps one `IrContext` across
`acceptance_validate_context` and `c_lower_and_emit_function`; this is the
handoff point. `check` constructs an acceptance-only context and must use
the same resolver/diagnostic semantics but need not retain records for
emission. Each native worker owns source-local records; sharing mutable
records between workers would violate deterministic output and RAM bounds.

A second literal-value attempt at local commit `0390cd5` changes the helper
contract from returning `ResolutionInteger` to a boolean plus `ref i64`
result. For literal syntax nodes it stores a three-state parse result and
all 64 value bits in the existing record; acceptance and native lowering
read the same decoded value. This repaired the earlier failed Stage 3
bootstrap: the new candidate passed byte-exact Stage 2/3, 278/278
conformance, the serial/adaptive exact-output and invalid-diagnostic proof,
integer-boundary checks, and the strict 20/20 self-build chain (peak
250,068,992 private bytes and 51,949,568 working-set bytes, below both
declared child limits). But eleven same-host pairs against the storage-only
source gave only **-7 ms** large and **-5 ms** control paired medians (8/11
wins each), versus **+326 ms** complete self-build (3/11 wins, with a
9.179-second candidate outlier). All binaries remained byte-identical.
The >5% self-build paired regression rejects this as a standalone
performance promotion. Retain it only as an isolated enabling step while
testing the full semantic/rule/lowering cut; do not represent the small
generated-workload wins as SH-27 parity closure.

The literal-value successor's clean Windows
[run 35924359345](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/35924359345)
passed every step before enforced normal-default parity, then failed only
`large_functions` versus DMD: OpenC **0.701 s**, DMD **0.337 s**,
**2.0801x** against the 1.25x limit. Control flow passed at
0.317/0.337 s (0.9407x). On that same run, the large-function public
ceiling was about 0.421 s, a **280 ms** OpenC deficit. This is not an
across-run estimate of the literal change's effect; its local paired
self-build regression already rejected standalone promotion. The clean
failure confirms that the full architectural gap remains.

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
- Eager binary-rule facts in a packed typed-expression record: rejected as
  an isolated semantic-fusion experiment at `5a256cd` on
  `codex/sh27-semantic-fusion`. It passed byte-exact fixed point,
  278/278 conformance, and serial/adaptive executable and invalid-diagnostic
  proofs. Against the otherwise identical packed-record plus scalar-flow
  baseline `71da7a4`, eleven guarded order-alternated pairs gave **0 ms**
  large-function median delta (5/11 candidate wins) and **+3 ms** control
  median delta (5/11 wins); generated binaries were byte-identical. The
  result shows that moving binary rule evaluation into first type visits
  and replaying its diagnostic flags later does not reduce end-to-end wall
  time. No self-build speed claim was made; the candidate fails the targeted
  speed gate before production promotion. Keep the experiment isolated and
  redesign first-visit semantic evaluation rather than extending this
  flag-cache strategy.
- Packed binary-operator facts shared by type inference, binary acceptance,
  and native lowering: rejected as a standalone slice at `bbcfefe` on
  `codex/sh27-integrated-semantic-path`. It passed byte-exact self-host
  fixed point, 278/278 conformance, exact serial/adaptive executables and
  invalid diagnostics, and guarded Job RAM. Eleven order-alternated local
  revision pairs against the otherwise identical packed-record baseline
  `66a7d47` had **+32 ms** large-function paired median (4/11 wins), despite
  byte-identical generated binaries. This falsifies the hypothesis that
  repeated binary operator spelling checks are the material remaining
  critical path. No speed promotion or clean comparator claim is made.
  Target the first-visit assignment/call algorithm and semantic-to-lowering
  handoff as a whole; do not extend the operator-code cache.
