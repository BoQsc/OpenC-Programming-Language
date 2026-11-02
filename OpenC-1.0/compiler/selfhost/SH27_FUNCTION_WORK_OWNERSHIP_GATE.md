# SH-27 function-work ownership gate

Decision: **no function-job scheduler in this tranche**. The committed
PreparedSource path at `b9c2463` is a serial opt-in correctness boundary.
Launching multiple functions from it would alias writable arrays and is not
safe, even for one source with many functions. No candidate executable or
throughput result is claimed for function parallelism.

## Exact alias that blocks launch

`ir_function_scratch` in `source/ir_prepared_source.p` captures 25 pointer
fields directly from the source `IrContext`, without allocating or copying
their storage. The serial loop in `source/backend_c_project_source.p` binds
that one scratch to each function in turn. The 5/5 ownership audit proves
that fields are classified and rebound; it does **not** prove that two
scratch values own separate allocations.

At least these fields are writable after acceptance:

| Storage | Post-acceptance write path | Independent-job requirement |
| --- | --- | --- |
| `type_data`, `types` | `ir_lower_mode.p` calls `semantic_derived_type`; `semantic_part2.p` scans the current type table and `semantic.p` appends a new record if absent. `ir_project.p` has another lowering-time call. | Freeze/pre-intern all needed type records in deterministic source/function order, or give each worker a private type table and prove/remap IDs at merge. |
| `name_cache`, `type_cache`, `resolved_type_ref_cache` | `ir_part2_resolution.p` and `ir_part3.p` fill first-visit entries. | Private initialized cache snapshot/overlay per worker, with a bounded allocation and no source-wide writable alias. |
| `call_cache`, `call_argument_first/last`, `argument_next`, `left_expression_cache`, `right_expression_cache` | `ir_part2_calls.p` and `ir_part1c_expression.p` fill traversal facts. | Prove disjoint function ownership for every index or use private snapshots/overlays. |
| `symbol_export_cache`, `native_layout_*_cache` | `acceptance_ranges.p` memoizes export status; `backend_native_scalar.p` writes layout state/size/alignment while emitting. | Private per-worker caches or a completed immutable memoization pass. |
| `local_values`, `block_data`, `instruction_data/detail`, `operand_data`, `break_data`, `continue_data` | `ir_project.p` resets and lowers IR; emit helpers append records. | Dedicated worker buffers with lifetime and capacity bounds. |

The existing source-chunk implementation already clones the project type
table, export cache, and three native-layout caches for **each source-chunk
worker** (`backend_c_parallel_state.p`, `c_native_source_chunk`). That is
evidence of the intended ownership model, not a function scheduler: each
source chunk builds its own source context and serially lowers its functions.
The current PreparedSource path has none of those per-function-worker clones.

## Order and budget dependencies

`acceptance_validate_context` runs over the whole source before the function
loop (`backend_c_project_source.p`). This preserves current invalid-input
diagnostic ordering, but it also leaves first-visit facts in source-lifetime
caches. A shallow `IrContext` copy only copies pointers, not those facts.

`ir_emit_value` increments `context.next_value` (`ir_part1d.p`). Separate
function jobs would start with different or overlapping SSA number ranges
unless a stable prefix/range assignment or output normalization is proven.
`native_emit_function` writes directly to a shared `DBuffer` and `BuildTimings`
and can report native budget errors directly to `io` (`backend_c_project.p`,
`backend_native_scalar_part3.p`). Ordered result, timing, and diagnostic
reduction would be required before launch, with exact default bytes and
stdout/stderr/exit for invalid inputs as acceptance criteria.

Memory cannot be inferred from the 5.2 MB four-module smoke proof. The
constructor in `backend_c_project_source.p` gives each source thirteen
syntax-sized scratch arrays (name, call, three argument links, type,
resolved type, left/right expression, block/control parent, break/continue),
or `13 * (syntax_nodes + 1) * sizeof(usize)` requested bytes before IR
buffers. A naive extra three worker copies cost at least
`3 * 13 * (syntax_nodes + 1) * 8` bytes for these arrays alone, plus type,
export, layout, local-value, IR, and output storage. Some parent caches may
be frozen and shared after proof; some IR buffers can be right-sized by
function. This formula is a **naive copy cost**, not a lower bound on an
optimized design. The existing measured scratch shape reached approximately
12.69 MB requested for one generated large source
(`SH27_SCRATCH_OWNERSHIP_NO_GO.md`), so blindly cloning all source scratch
for four function workers is not acceptable under the 256 MiB child-private
cap. A pre-launch byte calculation and serial fallback are mandatory.

## Required next cut before scheduling

1. Build a genuinely immutable post-acceptance fact snapshot, including a
   transitive write audit of the full lowering/native call graph. Add a
   runtime debug checksum to catch writes through aliases during serial
   lowering. Keep category/source-order acceptance diagnostics unchanged.
2. Allocate or partition each writable cache and IR buffer per worker,
   record its owner, and enforce a source-general byte budget **before**
   starting any function job. Reuse the source-chunk type/export/layout
   clone design only where its bytes fit; otherwise fall back to serial.
3. Resolve type-ID and SSA numbering deterministically, then emit into
   per-function output/timing/diagnostic records. Merge strictly by function
   source order, with bounded buffers and explicit error propagation.
4. Only then add an opt-in one-source/many-function scheduler. Prove exact
   valid artifact bytes and invalid stdout/stderr/exit, Stage2/3 fixed point,
   256 MiB child-private/64 MiB working-set guards, and clean paired
   large/control throughput before considering default promotion.

The stop here is an ownership gate, not a conclusion that function-level
parallelism cannot work or that its performance value is zero.
