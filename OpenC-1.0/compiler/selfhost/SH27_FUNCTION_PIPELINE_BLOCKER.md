# SH-27 function-level acceptance scheduling: blocked by the freeze boundary

Status: **do not implement on `5bc95f8`**. This is an architectural dependency
and measured ceiling, not a scheduling speedup or a promoted compiler patch.
The typed-op prebuild is a rejected throughput candidate, and its immutable
arena is not an immutable *source semantic state*.

## What is and is not frozen

`ir_scalar_prepare_source` traverses the source-wide `expression_nodes` list,
resolves dependency edges through `IrContext`, writes an eight-word record per
syntax node, and only then sets `scalar_ready`. After that point, the
`scalar_operations` array is read-only. But preparation runs inside
`acceptance_validate_context` after type/field/local checks and before the
assignment/binary, condition, function/scope/enum, call, storage, optional,
pointer, and ownership validators finish. It therefore does not permit
acceptance plus typed construction to be scheduled as function jobs. The
builder's calls to name resolution, call selection and type rules also write
source-local caches. `c_emit_source_record` then lowers all functions in one
syntax-order loop, mutating local SSA, IR buffers, type/layout/export caches,
and `next_value`. Sharing this `IrContext` among the four current threads
would race; cloning it for every function would duplicate work and memory.

The arena is eligible only for a subset of scalar syntax; unsupported and
invalid sources fall back to the old whole-source path. This is not a
source-general immutable semantic contract. It is also not a useful base to
retain merely for scheduling: the guarded 11-pair matrix specialized all
8/8 large and 4/4 control sources, but measured a **+2 ms** large paired
median (5/11 wins; 50 ms null floor) and **-6 ms** control (7/11; 11 ms null
floor). Critical large expression time rose **63 ms** and critical wall rose
**16 ms** while assignment/call time moved into eager preparation. The
generated large run reached 177,979,392 bytes peak private and 83,742,720
bytes peak working set under the matrix's 512 MiB limits; those are **not**
the strict 256/64 MiB compiler-selfbuild proof. Raw matrix:
`build-output/selfhost-sh27/sh27-typed-pipeline-matrix-20260924.json` in the
main workspace. `SH27_TYPED_PIPELINE_REJECTION.md` at `e56e420` records the
candidate decision.

The arena alone reserves `(syntax_nodes + 1) * 64` bytes, up to almost
16 MiB for *one* eligible source. Four independent copies can reserve nearly
64 MiB before per-worker IR, context caches, output, and stacks. The prior
strict self-build's peak private was 255,336,448 bytes against 268,435,456
(13,099,008 bytes headroom) and working set 60,116,992 against 67,108,864
(6,991,872 bytes headroom). Those numbers are from a different compiler
revision, so they prove neither that this candidate exceeds the cap nor that
it fits; they show why unconditional cloning cannot be certified.

## Scheduling ceiling from the existing four-worker trace

The existing 11-pair worker-balance trace had median critical walls 328 ms
large and 313 ms control. A lower+emit-only, zero-overhead tail model yielded
ideal medians 262/278 ms: 70/16 ms modeled gains. Even if **all** critical
acceptance, IR lowering and native emission could move as infinitely
divisible zero-overhead work after the worker's other work, the same
four-worker tail-capacity model yields median ideal walls **246/266 ms**:
**78/16 ms** modeled gains. This is a counterfactual using per-sample phase
and worker-wall measurements, not a measured speedup or a rigorous lower
bound: acceptance tasks become ready at different points, other workers
have their own work, and phases may have dependencies. The clean runner's
same-source DMD failure required roughly 57/8 ms large/control reduction;
that leaves narrow modeled room for task setup, shared-state preparation,
memory reservation, synchronization and ordered merge. A function queue
alone is not an evidenced SH-27 parity solution.

For reproducibility, each sample sets `movable = acceptance_ms + ir_lower_ms
+ native_emit_ms` from its reported critical chunk, `release = critical_wall
- movable`, and worker availability to `release` for the critical worker or
`max(release, other_worker_wall)` otherwise. Binary-search the first integer
millisecond `T` where `sum(max(0, T - availability_i)) >= movable`, never
below the largest other-worker wall; the figures above are medians of those
per-sample ideals and gains. This assumes the phases are disjoint top-level
critical-chunk categories and does not sum nested expression/assignment/call
counters.

## Precise preparatory change before revisiting scheduling

1. Replace the mixed mutable `IrContext` handoff with an immutable
   `PreparedSource` view after parse/index/declaration resolution, containing
   token/syntax and source/symbol indices. Retain it for the lifetime of all
   function jobs. Define and test which fields are immutable; do not publish
   a pointer until all writes to those fields have completed.
2. Define a function-local semantic operation that accepts
   `(PreparedSource, FunctionDescriptor, WorkerScratch)` and performs the
   required assignment/binary/call/condition checks **in the lowering walk**,
   without a second source-wide typed arena. This is the interface under
   investigation by the deferred-validation track. Separate genuinely
   source-global checks (type/field/import/enum/export contracts) and run
   them once before function jobs. No function may mutate shared type/name/
   call caches; any needed derived type or memo data belongs to scratch or a
   frozen lookup table.
3. Give each worker one reusable, budgeted `WorkerScratch` for local values,
   IR, SSA numbering, type/layout overlays and output. Normalize native SSA
   IDs or preassign deterministic function-local ranges; success output is
   stored by `(source_record, declaration_ordinal)` and concatenated only in
   that order. On any semantic failure, discard speculative output, release
   worker arenas, and replay the existing serial validator for exact source/
   rule-order diagnostics, as the current rejected-build worker path does.
4. Add a measured source-local memory reservation before launching jobs.
   Count retained prepared state plus all four scratch/output maxima against
   256 MiB private, 64 MiB working set on strict self-build, and 512 MiB
   process-tree guards. Fall back to the existing source-owner path if the
   reservation or freeze proof fails; never add a fifth worker or clone a
   16-MiB arena speculatively.
5. Only after that interface exists: prove byte-exact Stage 2/3, serial vs
   scheduled native output, invalid diagnostics, full conformance, strict
   20/20 self-build, and an order-alternated guarded 11-pair whole-compiler
   comparison with null control. The clean C/D comparator remains decisive.

Decision: stop this implementation branch at the contract boundary. Do not
merge the rejected eager arena, and do not claim the theoretical tail model
as a speedup. Revisit function scheduling only when the deferred semantic/
lowering cut supplies a truly immutable prepared source and isolated scratch
without adding another full syntax traversal.
