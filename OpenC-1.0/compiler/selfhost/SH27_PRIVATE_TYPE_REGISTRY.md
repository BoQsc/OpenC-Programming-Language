# SH-27 bounded function-local type registry

Decision: **retain isolated, opt-in, and serial**. The `--freeze-function-types`
path now lends each serial function scratch a private snapshot of the live
type records, rather than the source chunk's mutable `type_data` pointer.
This establishes a no-shared-type-record-write boundary for function lowering;
it does not enable function workers or claim a throughput improvement.

## Ownership and falsification boundary

After the existing indexed-call type prepass, the source copies exactly
`types.length` five-word records plus **one spare record** into worker-local
storage. The copy has a strict 512 KiB ceiling and rejects a null or aliased
allocation. It preserves existing type IDs. The only type-record writer,
`semantic_add_type`, now checks `types.length < types.capacity` before its
first write. If lowering discovers one missing derived type, it appends only
to the private spare record, then the opt-in path reports
`OPENC-FUNCTION-TYPE-FREEZE-MISS` and fails immediately after that function.
A second append cannot overrun the copy. No remapping or acceptance of late
worker-local IDs is claimed. The original source pointer and descriptor are
restored before release; the non-freeze opt-in path retains its previous
type-length propagation. A static test checks the sole writer, pre-write
capacity ordering, bounded allocation, pointer binding, and restoration.

At most four existing source chunks can hold a copy concurrently, so this
cut reserves at most 2 MiB for all such copies, not 512 KiB per function in
the source. Any future function-job scheduler must reserve against the same
global four-worker limit, not multiply four jobs inside each of four source
chunks. The exact private-copy size is `(types.length + 1) * 40` bytes on
Windows x64. No full-capacity type arena is cloned.

## Guarded evidence (2026-09-24)

The final source passed byte-exact Stage1/2/3 fixed point. All three PE
SHA-256 hashes were
`d81088d99b58cbab10cc1a6f7043ea3c4096b66d8de5542058c798e10584aa1c`.
Peak private / working-set bytes were Stage1 260,513,792 / 60,162,048;
Stage2 261,566,464 / 61,329,408; Stage3 260,464,640 / 60,211,200.
Report: `build-output/selfhost-sh27/sh27-private-types-v2-20260924/bootstrap-current/bootstrap-current.json`.

An opt-in Stage3→Stage4 self-build produced that same PE hash under the
strict 256 MiB private / 64 MiB working-set limits. Peak private and Job
private were 261,132,288 bytes; peak working set was 60,792,832 bytes.
Private-memory headroom at that observed peak was 7,303,168 bytes. The
existing four-project-cache snapshot remained bounded and zero late type
additions were reported. Report:
`build-output/selfhost-sh27/sh27-private-types-v2-20260924/strict-selfbuild/owned-project-caches-selfbuild.json`.

Four focused cases passed exact default/opt-in checks: zero- and
positive-arity calls (including executable bytes and execution), duplicate
declarations, an import cycle, and an invalid name (exact exit/stdout/stderr).
Generated large/control sources passed exact PE and runtime-output
comparisons. Static ownership tests passed 12/12.
Reports: `build-output/selfhost-sh27/sh27-private-types-v2-20260924/fixtures/function-index-freeze.json`
and `build-output/selfhost-sh27/sh27-private-types-v2-20260924/corpus/function-type-freeze.json`.

## Remaining hard gates

The type registry now has worker-local storage for opt-in function lowering,
but this is a **fail-closed closure probe**, not a general derived-type
interner/remapper: an unfamiliar valid source needing a late type may be
rejected in opt-in mode. In `IrFunctionScratch`, 13 pointer fields remain;
four project-cache pointers and `type_data` now have bounded private storage.
The remaining **eight source-borrowed pointers** are `spelling_cache`,
`local_values`, `block_data`, `instruction_data`, `instruction_detail`,
`operand_data`, `break_data`, and `continue_data`. The spelling cache is
hash-indexed rather than function-partitioned; local values and IR buffers
need independent bounded worker ownership. Function-order machine-code
output and diagnostic ordering still need a deterministic merge. These
blockers prevent worker scheduling and default promotion.
