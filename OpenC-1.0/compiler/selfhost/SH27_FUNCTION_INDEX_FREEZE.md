# SH-27 prepared function index freeze

Decision: **keep isolated, opt-in, and serial**. This cut removes five
syntax-sized arrays from mutable `IrFunctionScratch` without copying them:
`block_parent_cache`, `control_parent_cache`, `call_argument_first`,
`call_argument_last`, and `argument_next`. It does not launch function jobs or
establish a speed improvement.

## Readiness and no-write argument

`ir_initialize_parent_position_caches` fills both parent arrays for every
syntax node before acceptance. Immediately before publishing
`IrPreparedSource`, the opt-in path rejects any parent sentinel above
`syntax.length`. The only later parent writers, `ir_block_parent` and
`ir_control_parent`, return their cached result when it is at or below that
length. Thus those writer branches are unreachable for the checked nodes.

Every syntax node of call kind 38 is placed in the indexed `call_nodes` list
by `ir_initialize_node_indexes`. After successful source acceptance, the
opt-in path calls `ir_index_call_arguments` for each indexed call. For a
positive-arity call it verifies that first/last links exist, each link is
in range, the chain has exactly the declared number of arguments, and the
final link is zero. This rejects missing links, excess links, and cycles.
The only later argument-link writer is `ir_record_call_argument`, called
from `ir_index_call_arguments`; that function returns before writing when
the first link is already nonzero. Zero-argument calls return before writing
as well. Failed per-source acceptance returns before this preparation.
Global module-cycle or duplicate-declaration errors explicitly disable
PreparedSource emission, leaving ordinary source-order diagnostics intact.

A before/after weighted checksum covers the five arrays. It is a **diagnostic
tripwire, not collision-free proof of immutability**; the readiness checks
and static writer-path audit above establish the specific no-write argument.
An unfamiliar legal source whose adjacency cannot be completed fails closed
in opt-in mode with `OPENC-FUNCTION-INDEX-CACHE-NOT-READY`. Normal builds
remain unchanged.

There is no additional array allocation in this cut. A naive extra worker
copy of just these five arrays would request
`5 * (syntax.length + 1) * sizeof(usize)` bytes per worker; freezing them
avoids that source-sized multiplication under the strict 256 MiB private /
64 MiB working-set compiler self-build gates.

## Guarded evidence (2026-09-24)

The final source passed byte-exact Stage1/2/3 fixed point. All three PE
SHA-256 hashes were
`593f91566712556d5dcae1df9e414360d05650b3869c4df3641a337822a29255`.
Peak private / working-set bytes were Stage1 259,739,648 / 60,076,032;
Stage2 259,870,720 / 60,706,816; Stage3 259,842,048 / 59,756,544.
Report: `build-output/selfhost-sh27/sh27-index-freeze-sum-20260924/bootstrap-current/bootstrap-current.json`.

An opt-in Stage3→Stage4 self-build produced that same PE hash with peak
private 260,620,288 and working set 60,252,160 bytes. It prepared 21,735
indexed calls across compiler sources in 15 ms of recorded preparation time.
The prior project-cache ownership copy remained bounded; its maximum actual
source snapshot was 120,624 bytes. Report:
`build-output/selfhost-sh27/sh27-index-freeze-sum-20260924/selfbuild/owned-project-caches-selfbuild.json`.

The frozen generated large/control corpus passed exact PE bytes, executed
stdout/stderr/exit, and zero late type additions. The opt-in preparation
covered 256 and 64 indexed calls respectively. The generated large default
already uses over 64 MiB working set, so this separate corpus check used its
canonical 512 MiB private / 512 MiB working-set guards. Report:
`build-output/selfhost-sh27/sh27-index-freeze-sum-20260924/corpus/function-type-freeze.json`.

The dedicated strict-guard fixture check passed 4/4 exact default/opt-in
comparisons: a valid program with one zero-argument and one positive-arity
call (exact executable and execution), duplicate declarations, a two-module
import cycle, and the existing invalid name fixture (exact
exit/stdout/stderr). Report:
`build-output/selfhost-sh27/sh27-index-freeze-sum-20260924/fixtures/function-index-freeze.json`.
Static ownership checks passed 10/10.

## Remaining ownership gate

`IrFunctionScratch` now has 20 pointer fields, down from 25; four are the
independently allocated project-cache copies from the previous cut. The
remaining **16 source-borrowed pointer fields** comprise nine mutable
type/first-visit caches (`type_data`, name, spelling, call selection, type,
profile-seen, resolved type reference, left expression, right expression)
and seven local/IR buffer pointers. The `types`, `blocks`, `instructions`,
and `operands` descriptors, SSA numbering, output, timings, and diagnostics
also need independent bounded ownership and deterministic merge before any
function jobs are safe. The type-registry length assertion is still
post-function, not a pre-write freeze. No default promotion is proposed.
