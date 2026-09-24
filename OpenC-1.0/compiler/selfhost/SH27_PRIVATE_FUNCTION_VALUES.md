# SH-27 bounded local and control-stack ownership

Decision: **retain isolated, opt-in, and serial**. Native source lowering has
no spelling hash table: `c_emit_source_record` sets its pointer to null and
capacity to zero because spelling-only caching is unsound under local
shadowing. The prepared-source path now rejects a non-null/nonzero spelling
table before publication, and the two spelling fields leave mutable
`IrFunctionScratch`.

The same opt-in path gives each serial scratch an independent snapshot of
`local_values`, plus independent break and continue stacks. It checks
non-null allocations and cross-aliasing against every live source and
private pointer, then restores the source-owned pointers
before release. Local values are copied from the accepted source state; the
two stacks are initialized to zero because `ir_lower_function` resets both
depths before use and loop/switch lowering writes an entry before reading it.
The stack allocations retain the original `syntax.length + 1` slot bound.

The local copy is capped at 512 KiB. A combined gate caps local values,
break/continue stacks, and the existing private live-type snapshot at
**1 MiB per active source chunk**; four current source chunks therefore
reserve at most 4 MiB for this group. Oversized or unsupported sources fail
closed only in opt-in mode. No source, token, symbol, or syntax arena is
cloned, and no function workers are launched.

## Guarded evidence (2026-09-24)

After the final cross-alias safety edit, the source passed byte-exact
Stage2/3 fixed point. Both PE SHA-256 hashes were
`e8e99402e942ff5e57134f11e0a08982655579198cbdb58e36f980a2d7a0ee3c`.
Peak private / working-set bytes were Stage1 196,218,880 / 61,345,792;
Stage2 266,821,632 / 68,612,096; Stage3 261,214,208 / 60,792,832.
The bootstrap used 512 MiB guards; Stage2 working set exceeded the strict
64 MiB limit, so the separately guarded Stage4 result below is the strict
opt-in evidence. Report:
`build-output/selfhost-sh27/sh27-private-local-stacks-final-20260924/bootstrap-current/bootstrap-current.json`.

An opt-in Stage3→Stage4 self-build produced that same PE hash under the
strict 256 MiB private / 64 MiB working-set limits. Peak private and Job
private were 261,926,912 bytes and working set was 61,468,672 bytes;
the observed private headroom was 6,508,544 bytes. Four focused cases
passed exact default/opt-in comparison (calls, duplicate declarations,
module cycle, invalid name). Generated large/control sources passed exact
PE and runtime-output comparisons. Static ownership tests passed 13/13.
Reports: `build-output/selfhost-sh27/sh27-private-local-stacks-final-20260924/strict-selfbuild/owned-project-caches-selfbuild.json`,
`build-output/selfhost-sh27/sh27-private-local-stacks-final-20260924/fixtures/function-index-freeze.json`,
and `build-output/selfhost-sh27/sh27-private-local-stacks-final-20260924/corpus/function-type-freeze.json`.

## Remaining hard ownership gate

`IrFunctionScratch` now has 12 pointer fields: eight point to bounded
scratch-owned allocations (one type registry, four project caches, local
values, break stack, continue stack). The remaining **four source-borrowed
mutable pointers** are `block_data`, `instruction_data`,
`instruction_detail`, and `operand_data`.

Their current source-sized initial allocations alone total
`40 * (floor(N/2) + 4*N + 224)` bytes for `N = syntax.length`, or roughly
`180*N + 8,960` bytes per additional whole-source copy. Those buffers may
already require 7,208,960 bytes for a 40,000-node source—more than the
observed 6,508,544-byte strict headroom for even one extra copy. They may
also double in `ir_reserve_block`, `ir_reserve_instruction`, and
`ir_reserve_operand`; `ir_grow_record_storage` does not currently provide
bounded allocation failure propagation. A naive four-worker clone is
therefore not proved to fit the remaining 6,508,544-byte private headroom and is a
**no-go**. The next cut needs function-local initial capacities, a shared
global byte reservation, and fail-closed growth through all append sites,
followed by deterministic function-order code and diagnostic merging.
None of those conditions is established here; workers and default promotion
remain disabled.

## Integrated scheduler go/no-go

**No-go now for an independent function scheduler.** This ownership cut
removes aliases but does not move acceptance, type analysis, or native
emission work off the critical path. The prior reproducible zero-overhead
function-schedule model in `SH27_FUNCTION_SCHEDULING_DECISION.md` gave only
70 ms large / 16 ms control ideal gains for moving critical-worker lower
and emit. Those are historical counterfactuals, not new measured wins; a
fresh same-run profile is required after current compiler changes. The
control lane left very little room for queue, scratch, and merge overhead.

A single substantial scheduling implementation is justified only if one
integrated patch can establish all of the following before launch:

1. Function-local initial IR capacities, a transactional capped growth path
   through `ir_grow_record_storage` and its block/instruction/operand callers,
   and one global reservation for at most four total workers. The reservation
   includes live type/local/stack/project snapshots, four IR record buffers,
   per-function code/relocation/diagnostic results, and existing source-chunk
   memory. It must pass 256 MiB child-private and 64 MiB working-set self-build
   gates, plus the established 512 MiB large/control corpus gates, with a
   deterministic serial fallback before partial allocation when over budget.
2. A stable source/function ordinal table and function-local result buffers.
   Native code, constants, relocations, exports, `next_value`/SSA IDs, and
   `BuildTimings` are merged in original function order. Direct worker output
   to shared `DBuffer` or `io` is prohibited. Acceptance stays once per source;
   any native error is captured and replayed in the original diagnostic order.
3. Guarded Stage2/3 fixed point, exact default/opt-in PE bytes and executed
   stdout/stderr/exit for valid sources, and exact invalid diagnostics for
   duplicate declarations, cycles, name/type errors, and native failures.
   One source with many functions must actually show more than one worker
   doing lowering/emit work, with no hidden source-wide duplicate traversal.
4. Fresh same-run paired large/control comparisons beat their null controls
   by a majority of pairs and preserve all RAM/time guards, followed by a
   clean runner confirmation. Otherwise the architecture remains an isolated
   correctness experiment, not a SH-27 speed promotion.

This is one integrated implementation decision, not a queue of further
pointer-by-pointer cuts. Without transactional IR growth and the ordered
merge, ownership alone cannot produce safe or convincing throughput.
