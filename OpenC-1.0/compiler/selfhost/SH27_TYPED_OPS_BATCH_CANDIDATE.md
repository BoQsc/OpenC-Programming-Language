# SH-27 typed-expression / rule batch candidate

Status: **rejected as a throughput candidate; not promoted**.
Branch `codex/sh27-typed-ops-batch` starts at `6794d56`.

This candidate combines a source-local four-word typed-expression record
with a valid-source single expression traversal for assignment and binary
acceptance. The record replaces five native syntax-node caches (type,
resolved name, selected call, left child, right child); it also shares decoded
integer literal bits and the validated assignment destination type with
native lowering. The acceptance-only `check` path keeps its existing caches.
The native source context owns and frees its record; mutable facts are not
shared between workers.

The batched traversal asks the existing validators to check one indexed node
at a time. It does not assume syntax-node creation order is dependency order:
child expressions and call arguments remain resolved through the indexed
recursive path. Diagnostics are suppressed only during the batch preflight.
If any assignment or binary violation occurs, the original category-ordered
passes run again and emit diagnostics in their original order. This costs
extra work on invalid input but keeps the common valid source on one scan.

Preliminary correctness proof in the isolated worktree:

- Guarded Stage 1/2/3 self-build: PASS; all three compiler binaries have SHA-256
  `d7ecc7865c5d7bfc0cc587f424058e45b3c5700e10a2c97c53bec8539a2c5720`.
- Peak child private bytes over the three builds: 255,537,152; peak working
  set bytes: 59,637,760, under the 512 MiB Job guard.
- Ten targeted invalid native-artifact fixtures had byte-identical exit code,
  stdout, and stderr against the preceding scalar-flow compiler: assignment
  target/conversion, const reassignment, call arity, integer destination
  range, overload ambiguity, division overflow, signed bitwise, shift width,
  and resource equality.

The root task's guarded eleven-pair generated-workload matrix is the ignored
local artifact
`C:\Users\Windows10_new\Documents\OpenC Programming Language\OpenC-1.0\build-output\selfhost-sh27\sh27-typed-ops-matrix-20260924.json`;
it is **not externally published**. Its status is FAIL for throughput. Every
compile, execution, and memory guard passed, and generated binaries were
deterministic and byte-exact between baseline and candidate. Yet large
functions had a **0 ms** paired median delta (5/11 candidate wins, one tie;
154 ms null floor), while control flow regressed by **7 ms** (5/11 wins;
80 ms null floor). The cut therefore fails the SH-27 throughput gate.
No full 278-fixture suite or self-build pair is needed to promote a cut that
already failed both target lanes. The fixed-point and targeted invalid tests
remain useful correctness evidence, not a speed claim.

The same matrix's critical-chunk timing counters explain why an apparent
assignment gain is not real. In paired medians, `assignment_ms` moved down
94 ms for large functions and 110 ms for control flow, because batch work
now occurs outside that timer. Large-function `expression_ms` nevertheless
rose 14 ms, `acceptance_ms` rose 17 ms, and critical-chunk wall rose 15 ms.
Control-flow expression time was flat and critical-chunk wall fell 16 ms,
but whole-compiler elapsed still regressed by 7 ms. These nested,
millisecond-rounded phase medians are **not additive**; the whole elapsed
paired result is the selection criterion.

The failure is architectural. The batched pass still calls the old validators
for every node, and those validators still invoke `ir_node_type` recursively
on each first visit. The new record shares successful facts, but the earlier
profile showed almost no repeated first visits to remove. The batch deletes
one outer syntax scan but adds one function dispatch per checked expression.
The assignment destination and literal handoffs save only later repeat
queries. This work did **not** replace the expensive first-visit semantic
analysis or lower from a complete typed operation stream.

The next coherent replacement is a function-scoped typed-operation pipeline:

1. Index stable expression edges and call-argument adjacency once. Use an
   explicit dependency worklist with visiting/done states; never assume call
   argument nodes precede their call node in syntax-record order.
2. For each statement root, compute its expected-type context and resolve
   names, call selections, literal bits, operands, result type, conversion,
   and assignment/binary rule outcome in one semantic visit. Record only
   successful expectation-independent facts; contextual and failed nodes
   remain retryable or take the old validator fallback.
3. Buffer only error events, tagged by current diagnostic category and source
   order, then replay them in the existing public category order. The valid
   path must not rerun either old rule-family validator.
4. Make native lowering consume these typed operations directly. For covered
   name/literal/binary/assignment/call expressions it must not invoke
   `ir_node_type`, child-span search, overload selection, or literal parsing
   again. Unsupported nodes retain the old path until their semantics are
   proved, with a measured fallback counter.
5. Replace, rather than supplement, existing broad per-node caches. Bound
   live bytes by source/function lifetime and the 512 MiB process-tree Job;
   prove diagnostic, artifact, fixed-point, and representative-project
   equivalence before a paired promotion decision.

The acceptance criteria must include a profile proving that first-visit
type/rule work and lowering re-resolution actually disappeared. Otherwise
another storage or scan-layout change is not a Gate C implementation.
