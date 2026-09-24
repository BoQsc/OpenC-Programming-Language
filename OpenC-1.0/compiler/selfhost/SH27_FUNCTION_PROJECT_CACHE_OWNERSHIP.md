# SH-27 serial function-scratch project-cache ownership

Decision: **retain as an isolated opt-in ownership cut**, not a function
scheduler or speed improvement. `artifact --owned-function-project-caches`
implies the existing PreparedSource and late-type guards. The default path
does not allocate or copy these caches.

## Ownership boundary

After whole-source acceptance, the serial `IrFunctionScratch` receives
distinct copies of four project-level memo tables:
`symbol_export_cache`, `native_layout_size_cache`,
`native_layout_alignment_cache`, and `native_layout_state_cache`. The source
record retains its original pointers. The function path checks pointer
non-alias, uses the copied caches for every function handled by that one
scratch, and restores the original source pointers before scope cleanup.
Thus the four tables are no longer writable through aliases to project/source
state during opt-in function lowering. Functions assigned sequentially to
the same scratch still share that scratch's private cache. This does **not**
establish multiple independent function workers.

The snapshot is capped at 131,072 `usize` words (1 MiB) per active source.
The existing four source chunks can therefore request at most 4 MiB of
these additional live snapshots. The export table has
`symbols.length + 1` entries; the three layout tables copy only the live
`types.length` entries, not the much larger reserved `types.capacity`.
`native_layout_cache_entries` bounds every layout-cache read/write. A
late-derived type ID outside the compact snapshot follows the uncached
layout path, whose recursive calls use the same function context and never
point back at original project cache arrays. The separate type-length probe
then fails closed if lowering actually appended a type. This is not a
pre-write type-registry freeze.

The first implementation attempt copied the reserved layout capacity and
failed the intended 1 MiB bound on both generated workloads (large had only
39 live type IDs). All-symbol cache prefill was rejected statically:
`resolution_is_exported` re-lexes the source prefix for each symbol, making
that eager pass unacceptable. The compact copy preserves lazy memoization.

## Guarded evidence (2026-09-24)

The compact source passed Stage1/2/3 byte-exact fixed point under 256 MiB
child-private and 64 MiB working-set guards. All three compiler PE hashes
were SHA-256
`7ee076d252a68cd499c1f15016757e8efeedd6c8afad4d03d8284c7e33b0f8d6`.
Peak private / working-set bytes were Stage1 259,747,840 / 59,899,904;
Stage2 259,231,744 / 60,178,432; Stage3 259,256,320 / 60,059,648.
Report: `build-output/selfhost-sh27/sh27-owned-project-caches-compact-20260924/bootstrap-current/bootstrap-current.json`.

The opt-in Stage3→Stage4 self-build was byte-exact with the same PE hash,
under the same strict guards: peak private 259,600,384 and working set
60,710,912 bytes. The largest actual snapshot was 120,520 bytes per source.
`owned_function_project_cache_bytes = 26,996,480` is the **cumulative**
requested bytes over serial source records, not a simultaneous allocation or
RAM peak. Report:
`build-output/selfhost-sh27/sh27-owned-project-caches-compact-20260924/selfbuild/owned-project-caches-selfbuild.json`.

The frozen large/control generated corpus comparison passed exact executable
SHA-256, executed stdout/stderr/exit, and 0 late type additions in opt-in
mode; the checked-in invalid fixture's exit/stdout/stderr also matched
default. The large and control output hashes were respectively
`81d22e50b31b4c958bce1e3da02c7c114d67ca815934b58b2902cb97cbb76c4e`
and
`31b8906a62a954d885b37fe8a03a94010eefaa619648f42626620ca455590e50`.
Their maximum source snapshots were 33,728 and 11,200 bytes. The generated
large default already exceeds 64 MiB working set, so this comparison used
its canonical 512 MiB private / 512 MiB working-set guard. Report:
`build-output/selfhost-sh27/sh27-owned-project-caches-compact-20260924/focused/function-type-freeze.json`.
Static ownership tests passed 9/9.

## Residual gate

The `IrFunctionScratch` still has **21 pointer fields** borrowed from its
source context: 14 type/first-visit/index cache pointers (including
`type_data`, name, spelling, call/argument, type, expression and parent
caches) plus seven local/IR buffer pointers. Its `types`, `blocks`,
`instructions`, and `operands` descriptors also carry mutable state.
Further function workers would need independently owned, bounded scratch
and stable type IDs, plus deterministic SSA, output, timing and diagnostic
merge. This tranche does not satisfy that gate; see
`SH27_FUNCTION_WORK_OWNERSHIP_GATE.md`.
