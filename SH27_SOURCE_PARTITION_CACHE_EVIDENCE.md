# SH-27 source-partition COFF and compiler edit reuse

Status: **isolated local correctness/fixed-point/RAM PASS; clean hosted repeat
pending; no normal-default speed promotion; SH-27 active**.

The self-host compiler remains one OpenC *language module*, preserving its
unqualified cross-file name visibility. The isolated `module-coff-set` path
can now partition its resolved native function stream by contiguous source
records into 2, 4, 8, 16, or 32 independently linked COFF objects. The
`--source-partitions=32 --cache-prefix=... --source-chunks=4` mode uses a
whole-project declaration projection plus partition-local exact source bytes
for authenticated object keys. A body change invalidates only its group;
any declaration-projection change conservatively invalidates all groups.
The exact-input front-end snapshot for the earlier per-module mode is *not*
reused here, so flow and acceptance diagnostics still run on every build.

The cold/broad-miss path uses two native workers to preserve RAM margin;
sparse edits use four, with worker output buffers sized to missed sources.
Previously authenticated saved objects are released before worker acceptance
and authenticated a second time when linked. A late altered record/object
aborts before producing a complete output; retry-on-late-corruption is still
an open cache-availability improvement. The cache remains opt-in.

## Local source identity and proof

Byte-exact Stage 2/3 compiler SHA-256:
`096de8376587a67723db5efee7aa245f4efb710fc07510695f9bcd55a86cbaf7`.
Ignored raw reports are `OpenC-1.0/build-output/sp27-coff-final.json`,
`sp27-cache-scheduled.json`, `sp27-strict20-final.json`,
`sp27-large-coff-final.json`, and `sp27-conformance.json`.

- The actual 228-source compiler linked correctly from 2, 8, and 32 COFF
  objects, totaling 1,671 functions in each variant. The 32-object linked
  compiler ran and rebuilt the canonical compiler to the same SHA above.
  Its second build was byte-deterministic at the same partition count.
  Different counts legitimately have different PE padding and SHA values.
- In a copied compiler project, a cold 32-object cache build had 0 hits/32
  misses. A warm build had 32 hits/0 misses. Changing digit-predicate code
  in one source while preserving that file's size and modification time had
  31 hits/1 miss; the new compiler binary differed from the old binary and
  was byte-identical to a fresh uncached 32-object build. Truncating one
  cache record caused 31 hits/1 clean miss and the original exact output.
  Changing the declaration projection caused 0 hits/32 misses. Cached and
  uncached invalid-source builds failed with identical diagnostics and no
  executable. All local child builds were guarded at 256 MiB private/64 MiB
  working set; the clean workflow also applies a 512/128 MiB outer guard.
- Single local wall observations, **not parity evidence**: cold 28.436 s,
  warm 3.972 s, body edit 4.592 s, and fresh uncached 32-object body edit
  37.631 s. The cached edit's compiler-owned validation/lowering phases
  were 1.609/2.250 s. The largest sampled cold private/working-set peak
  was 224,722,944 / 57,589,760 bytes; the warm peak was
  224,927,744 / 61,812,736 bytes. The body-edit peak was
  226,537,472 / 62,660,608 bytes. These numbers are local and are not
  compared against a different-host C or D timing.
- Strict native stability passed 13/13 checks and 20/20 byte-exact chained
  generations, with maximum sampled child private/working-set peaks
  246,845,440 / 65,503,232 bytes. Native conformance passed 278/278.
  The existing large-COFF overflow/cached compiler fixed-point,
  multi-module automatic cache, and selected-lowering/diagnostic suites
  passed on this source revision.

## Honest next gate

This closes the earlier **one giant native object** limitation for the
isolated compiler project and proves a real one-source edited-object reuse
path. It does *not* make SH-27 complete. The 32-object cold path is much
slower than direct native emission, and its 4–5 s warm/edit path has not
shown a reproducible win over ordinary compiler self-build. The next
architectural work is (1) a bounded exact-input front-end snapshot for
the source-partition set, (2) safe per-source semantic/acceptance reuse or
parallel validation that reduces edited-build wall time without growing RAM,
(3) faster bounded COFF link/object I/O, then (4) normal-default integration
only after paired, guarded measurements show an advantage. Larger retained
projects, two clean final-source 20/20 C/D parity runs, editor/release
certification, and a clean hosted repeat also remain.
