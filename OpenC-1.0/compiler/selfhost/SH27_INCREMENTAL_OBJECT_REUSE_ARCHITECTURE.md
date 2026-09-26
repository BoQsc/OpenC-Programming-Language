# SH-27 incremental native-object reuse: feasibility boundary

Date: 2026-09-24. Isolated branch `codex/sh27-incremental-object-slice`,
based on production compiler source `1b58d5e1bde84307426c5f5ff33171765b4ecf1f`.
No production source or cache format was changed, and no timing claim is made.

## Current implementation delta (2026-09-26)

The historical boundary below has advanced in isolated, unpromoted commits:
stable per-module COFF names, a restricted native multi-object linker,
authenticated project-free saved-object relink, and a pre-allocation bounded
COFF reader now have exact-output and strict-memory proofs. The [selected
module lowering boundary](https://github.com/BoQsc/OpenC-Programming-Language/blob/2d693f4/SH27_SELECTED_MODULE_LOWERING_EVIDENCE.md)
adds `artifact --kind=module-coff-set --module=MODULE`: only that module's
sources enter IR/native emission, while all project sources still undergo
parsing, resolution, flow, and acceptance. Three separately emitted module
objects match full-build objects; after a provider body edit, its new object
plus two unchanged saved objects produces the exact fresh-build PE. Counters
prove lowered versus validation-only sources. Selection also handles a
multi-source module and retains full rejection diagnostics.

The selected-module source passed hosted strict20 in
[run 36260957581](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36260957581).
Its successor [automatic module cache](https://github.com/BoQsc/OpenC-Programming-Language/blob/2ca15c1/SH27_AUTO_MODULE_CACHE_EVIDENCE.md)
now implements authenticated hits, missed-module lowering, atomic local
publication, body/interface invalidation, and corruption/concurrency fallback.
Local tests prove zero lowered functions for a no-op and changed-provider
recompilation only. A 24-file/1153-function scale case exposed and repaired
the native linker's 1 KiB scratch ceiling. It matches clean COFF/PE bytes and
behavior on no-op/edit builds under strict RAM. Local no-op/edit medians are
0.335/0.456 s versus 1.223 s full COFF; ordinary native compilation is 0.325 s,
so **no default-build speed win is claimed**. Source validation is retained;
interface changes conservatively invalidate all modules. [Hosted cache-source
proof](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36263328048)
passed all cache/24-file checks and strict 20/20 exact rebuilds. Its 10 ms
no-op gain over ordinary native compilation disagrees with the local 11 ms
regression; a separate cold speed batch failed the gain/noise gate.
Independent front-end skipping, selective complete
dependency keys, shared-data/helper ownership, real-project/default-policy
speed and release certification remain. The internal numeric-ID stream
cache sequence below is historical; do not implement it instead of using the
now-proved stable-COFF miss/relink path. Preserve full validation until a
content-validated semantic record justifies skipping it.

## Historical starting boundary (2026-09-24)

The native build resolves declarations and types for the whole project in
`backend_emit.p`, then calls `c_emit_project` once with a single global
`IrContext` (`backend_emit.p`, around lines 448-464). `c_emit_project` appends
all modules' function records to one internal `DBuffer` in canonical module
order (`backend_c_project_close.p`, around lines 232-281). The direct PE
linker walks that stream and resolves numeric symbol IDs against the current
global symbol table (`backend_native_image.p`, around lines 184-243).
`native_build_coff_object` also takes the entire stream and emits **one
whole-project** COFF object (`backend_coff_writer.p`, around lines 76-150).
There is no reader or linker for multiple COFF inputs.

An internal native-stream module boundary is mechanically available: capture
the output length before and after each module in the sequential emission
loop, cache that byte slice, and append selected cached slices in canonical
order before calling the existing direct PE linker. This is an intermediate
vertical slice only, **not SH-27 Step 6 completion**. Step 6 still requires
deterministic per-module COFF objects and native multi-object relinking.

## Why a naive module cache is unsound

1. Each native function record identifies its defining function and
   relocation targets by project-global numeric symbol IDs. The PE linker
   uses those IDs directly (`backend_native_image.p`, lines 185, 201-230).
   An unchanged module stream may call a *different* symbol after an
   unrelated declaration insertion or reorder. A first slice can
   conservatively include the complete ID-to-ABI mapping fingerprint in its
   key; a later linker can remap stable symbol names instead.
2. The base context passes `next_value` across sources and modules, and
   lowering can derive types (`backend_c_project_source.p`, around lines
   469-470; `backend_c_project_close.p`, lines 76-93). A cache hit must
   validate the entry `next_value`, restore the recorded exit value, and
   use a frozen type closure (or invalidate when it grows).
3. Native acceptance currently runs *inside* `c_emit_source_record` during
   fused validation (`backend_c_project_source.p`, around lines 355-420).
   Skipping the source on a hit would skip diagnostics. The first safe slice
   should run the existing whole-project flow **and acceptance** passes
   before cache lookup, then run only native lowering/emission on misses.
   This bounds its speedup to the native lowering/emission portion; it does
   not skip parsing/resolution/validation.
4. A raw hash of packed `symbol_data`, `detail_data`, and `type_data` is not
   a complete interface fingerprint: symbol names are spans into source
   text (see `ir.p`, around lines 248-285), so changing a declaration's
   spelling without changing span lengths can leave the packed records
   unchanged. Signatures, layout, visibility, exported constants/defaults,
   calling convention, and imported-module relationships must all be
   represented explicitly. Hashing **all** project source bytes would be
   correct but would invalidate every module for an unrelated body edit;
   that is a whole-project cache, not true incremental reuse.
5. `system.file` exposes writes and reads but not an atomic rename/replace
   operation (`standard_library/system.file/source/file.p`). Writing a final
   cache path with `file.write_bytes` risks truncated files and concurrent
   writers. A cache-only documented Windows `MoveFileExW`/equivalent wrapper,
   unique same-directory temp name, flush, then atomic replacement is
   required. A header/version/key/length/SHA-256 and object-stream bounds
   validation must make corrupt or partial entries harmless cache misses.

These are correctness blockers to an honest small patch. I stopped before
adding a flag that could produce false hits or merely cache a whole-project
object. No heavy bootstrap was warranted for a documentation-only no-go.

## Smallest safe implementation sequence

1. **Canonical interface projection.** From the resolved semantic model,
   serialize each module's public ABI and every compile-time-visible value
   into a deterministic byte stream, including declaration spelling from
   source spans. Hash it with the existing SHA-256 implementation. Record
   direct module imports and transitive dependency-interface digests. Until
   the projection covers a declaration kind, conservatively mark that
   module/dependent pair ineligible for hits. Add unit cases for renames of
   equal length, signatures, struct layout, enums/constants, callbacks, and
   import graph changes.
2. **Stable-ID guard.** Serialize the current global numeric symbol/type-ID
   to ABI mapping, including names and relevant layout, and fingerprint it.
   Require equality on a hit. This overinvalidates after ID shifts but keeps
   the existing linker safe. A later stable-name relocation format can lift
   that restriction. Record input and output `next_value` and require the
   input match; reject hits when type closure was not frozen.
3. **Separate validation.** With cache enabled, run full flow and acceptance
   first. If any error exists, do not read or write cache entries. Freeze
   types before emission and assert no later growth. Preserve existing
   default fused path when cache is disabled. This ensures diagnostics are
   not changed by warm hits.
4. **Module stream boundaries.** In sequential native mode, capture each
   module's exact internal object-stream slice plus work-counter deltas.
   Key by compiler binary hash, cache schema/target/options, own source
   content hashes, dependency-interface digests, global ID guard, entry
   module, and input `next_value`. On a validated hit append the stream,
   restore exit state/counters, and skip only its IR lowering/emission.
   On a miss emit normally and stage the stream for cache publication.
   Reject unexpected symbol definitions or relocation targets before reuse.
5. **Atomic cache and relink.** Publish immutable entries through temp file,
   flush and atomic replacement; never trust the path alone. Relink the
   concatenated current/cached streams with the existing `native_write_image_options`.
   Cache/IO failures fall back to a normal build, not compilation failure.
   Expose `modules_hit`, `modules_missed`, `bytes_reused`, and actual skipped
   lowering/emission counts in the timing JSON.
6. **Then true COFF/multi-object.** Emit a deterministic COFF object per
   module with stable external symbol names, sections, relocations, unwind,
   imports/exports and COMDAT/duplicate policy; implement a native COFF
   reader/linker (or a rigorously specified restricted object subset).
   Reuse those independent objects under the same content/interface keys.
   This, not the internal stream slice, closes SH-27 Step 6.

## Promotion proof

Use at least a three-module project (`A` imported by `B`, unrelated `C`):

- Identical warm build: all eligible module streams hit; final PE and runtime
  output are byte-exact to uncached build; measured lower/emit work is skipped.
- Change only `A`'s body without changing its interface: `A` misses, `B` and
  `C` hit if their stable-ID guards still match. This is the essential proof
  that it is not a whole-project cache.
- Change `A`'s exported signature/layout/value or a same-length symbol name:
  `A` and dependent `B` invalidate; unrelated `C` may hit if IDs remain
  stable, otherwise conservatively misses.
- Insert/reorder declarations to shift numeric IDs: every affected stream
  invalidates, never links to an old target. Change source bytes without
  changing file size/mtime: content hash still invalidates correctly.
- Truncate/corrupt an entry, kill a writer, and run two writers concurrently:
  all results are clean misses or valid hits, never a corrupt executable.
- Compare cold/warm and baseline with serial guarded runs, fixed-point
  compiler builds, diagnostics, PE imports, runtime results, and strict RAM.
  A saved wall time without measured skipped work does not count as reuse.

Because acceptance and global resolution remain whole-project in the first
slice, this is primarily an **edit-build latency** track. It cannot by
itself close the clean-build C/D throughput gap that SH-27 also targets.
