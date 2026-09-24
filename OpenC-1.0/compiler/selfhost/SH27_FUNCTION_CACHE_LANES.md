# SH-27 function-keyed cache ownership cut

Decision: **retain isolated, opt-in, and serial**. This cut moves seven
syntax-node-indexed arrays from `IrFunctionScratch` into the source-lifetime
`IrPreparedSource` view without allocating copies: name resolution, call
selection, type, type-profile-seen, resolved type reference, left expression,
and right expression caches. It does not start function workers or claim a
throughput gain.

## Enforced lane boundary

The opt-in path rejects zero-length, overlapping, out-of-order, or out-of-
source function declaration spans before publishing the prepared source.
Each function receives a fixed encoded owner node for the duration of its
lowering call; this is separate from `context.function_node`, which name
resolution may temporarily change. The seven arrays have an audited set of
nine write sites. Every lowering-time write checks half-open ownership
**before** touching its source-sized array; an out-of-lane write is omitted
and causes a fail-closed `OPENC-FUNCTION-CACHE-OWNERSHIP-MISS` after that
function. Seven read sites similarly bypass entries outside the active lane,
so a future worker could not read an entry another worker is writing. The
half-open check rejects a zero-length node at a boundary between adjacent
functions. The default path has no owner and retains its old cache behavior.

This is a field-level ownership result, not an assertion that the entire
lowering context is concurrency-safe. The existing five parent/argument
arrays remain frozen after explicit readiness checks. No full syntax,
token, or declaration arena is duplicated. `IrFunctionScratch` pointer
fields fall from 20 to 13. Four of those are already independently copied
project caches; the remaining **nine source-borrowed pointers** are
`type_data`, `spelling_cache`, `local_values`, `block_data`,
`instruction_data`, `instruction_detail`, `operand_data`, `break_data`, and
`continue_data`.

## Guarded evidence (2026-09-24)

The final source passed byte-exact Stage1/2/3 fixed point. All three PE
SHA-256 hashes were
`860bc4cabed5c8ac69bce1588cdcadb896ca3a58ce653958447a1c1ce2fe03d2`.
Peak private / working-set bytes were Stage1 260,313,088 / 60,432,384;
Stage2 260,734,976 / 60,534,784; Stage3 260,059,136 / 60,440,576.
Report: `build-output/selfhost-sh27/sh27-cache-lanes-final-20260924/bootstrap-current/bootstrap-current.json`.

An opt-in Stage3→Stage4 self-build produced the same PE hash under the strict
256 MiB private / 64 MiB working-set limits: peak private 260,612,096,
working set 60,579,840, Job private 260,612,096 bytes. The largest actual
per-source four-project-cache snapshot was 120,736 bytes; the reported
27,044,864-byte cache figure sums allocations over all source records and
is **not** simultaneous resident memory. Zero late type additions were
reported. Report:
`build-output/selfhost-sh27/sh27-cache-lanes-final-20260924/strict-selfbuild/owned-project-caches-selfbuild.json`.

Four focused cases passed exact default/opt-in checks: positive- and
zero-arity calls (including executable bytes and execution), duplicate
declarations, an import cycle, and the invalid-name fixture (exact
exit/stdout/stderr). Generated large/control sources passed exact PE and
runtime-output comparisons. Static ownership tests passed 11/11.
Reports: `build-output/selfhost-sh27/sh27-cache-lanes-final-20260924/fixtures/function-index-freeze.json`
and `build-output/selfhost-sh27/sh27-cache-lanes-final-20260924/corpus/function-type-freeze.json`.

## Next hard gate

`type_data` / `types` can still append derived type IDs during function
lowering. The existing type prepass and post-function length assertion are
useful probes but not a pre-write immutable type registry; concurrent appends
would race and could make IDs/output nondeterministic. The shared
`spelling_cache` is hash-indexed, not function-partitioned, and the seven
local/IR buffer pointers still borrow source storage. Those need bounded
per-worker ownership or a proved immutable handoff. Function-order native
output and category-order diagnostics also require deterministic merge.
With only 7,823,360 bytes of private-memory headroom in the strict self-build,
unbudgeted worker copies are not acceptable. No worker count or default
promotion follows from this cut.
