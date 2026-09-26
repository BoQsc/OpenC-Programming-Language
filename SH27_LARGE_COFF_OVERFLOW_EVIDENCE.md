# SH-27 large compiler COFF and relocation-overflow proof

Status: **isolated local and repaired-source hosted PASS; first hosted run
found a representative self-build RAM failure; normal/default incremental
builds and final-source C/D speed parity remain open**.

The 228-source compiler is currently declared as one OpenC module. Its
unlinked COFF set was already writable under a strict 256 MiB private /
64 MiB working-set Job, but a linked object build failed at a 4 MiB native
stream cap, an 8 MiB saved-object cap, and a 4,096-symbol entry/key guard.
After bounded admission of this measured object, the native linker exposed
the real object-format issue: `.text` has more than 65,535 relocations.
The old writer truncated that count into the 16-bit COFF section header,
making its own object unparsable. This cut writes and validates the standard
`IMAGE_SCN_LNK_NRELOC_OVFL` first relocation marker, including that synthetic
record in the physical count, as described in the
[Microsoft PE/COFF specification](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format)
and [LLVM's COFF writer](https://llvm.org/reports/coverage/lib/MC/WinCOFFObjectWriter.cpp.gcov.html).
The reader rejects an overflow flag with a non-`0xffff` header count,
invalid marker fields, fewer than 65,536 real relocations, or an out-of-bounds
table. Small objects keep the original non-overflow encoding and output.

## Local fixed-point and adversarial proof

Final Stage 2/3 compiler SHA-256:
`a324cd00ae9a3f1c273b7f2842da5a9782b8e30ae3c7726cf0b09a7147bd1991`.
Ignored raw reports are in
`OpenC-1.0/build-output/sh27-large-object-bootstrap-20260926c/`; the
short-path three-run representative report is
`OpenC-1.0/build-output/r27-big.json`.

- `test_large_coff_selfhost.py` passed under a 512/128 MiB wrapper and
  enforced 256/64 MiB child guards. The checked-in compiler project produced
  one 8,760,732-byte COFF object with 96,297 real `.text` relocations and
  an authenticated published cache record. The cold cache was 0 hits/1 miss;
  an exact-input no-op was 1 hit/0 misses, skipped validation, and reported
  zero syntax/function work. Its total compiler time was 203 ms in this one
  run, not a stable median or a normal-default claim.
- The cached no-op PE and COFF bytes matched a fresh uncached module-COFF
  build exactly. The linked compiler printed the expected version and,
  when used as the seed for another bootstrap, reproduced the byte-exact
  Stage 2/3 compiler SHA above. A forged overflow-marker count with a
  recomputed object SHA was rejected by the linker and produced no PE.
- Cold, warm, and fresh module-COFF child peaks were respectively
  186,826,752 / 43,196,416 / 188,997,632 private bytes and
  58,208,256 / 33,595,392 / 63,414,272 working-set bytes. These are
  sampled peaks under hard 256 MiB Job private and 64 MiB working-set limits.
- The saved-object pre-allocation falsification passed all three cases at
  the new 16 MiB-minus-four-byte bound. The existing small/multi-module
  object cache, selected-lowering, and native relink tests still pass.
- Strict native self-build passed 13/13 checks and 20/20 byte-exact chained
  generations; peak child private/working set were 267,530,240 / 63,782,912
  bytes. Native conformance passed 278/278 with no failures. The 24-file
  generated cache benchmark passed five repetitions: full/no-op/body-edit/
  ordinary medians were 1.147/0.214/0.489/0.292 s, with a 0.079 s paired
  ordinary-minus-no-op gain.
- The normal-build representative CLI, four-module file app, and edited
  compiler self-build passed three repetitions each. Compiler-self-build
  cold/warm/edit medians were 3.393/3.379/3.378 s. The largest sampled
  normal-build compiler private peak was 268,431,360 bytes—only 4,096 bytes
  below the 256 MiB limit. This is a RAM-headroom warning, not a promotion
  certificate.

The cache still has **one object for all 228 compiler sources**. A single
edited source invalidates that whole module, so this cut establishes large
compiler no-op reuse and full self-host COFF/link correctness, not the
one-source incremental speed demanded by SH-27. It is also opt-in via
`artifact --kind=module-coff-set --cache-prefix=...`; ordinary `openc build`
still uses the existing path. Next engineering work is a stable smaller
object boundary (real modules or source partitions with dependency/interface
keys), bounded/streaming native link storage, and a RAM margin large enough
to survive clean hosted runs without relaxing the 256/64 MiB guards. Final
default-policy C/D parity, retained projects, and release/editor gates remain.

The [first hosted run](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36269809764)
passed the focused large compiler COFF/cache test and earlier steps, but its
three-run representative suite failed on the second edited compiler build
at the 256 MiB Job limit. It did not reach the strict 20-generation gate.
The subsequent [validation-arena lifetime cut](SH27_VALIDATION_ARENA_LIFETIME_EVIDENCE.md)
reduces the representative compiler peak by roughly 23 MiB without relaxing
any guard. Its [clean hosted repeat](https://github.com/BoQsc/OpenC-Programming-Language/actions/runs/36270863013)
passed the same large-object test, all representative repetitions, and the
strict 20-generation native self-build. Use the lifetime-cut evidence for
the repaired compiler SHA and exact hosted memory numbers; the earlier local
SHA and near-limit RAM warning above remain a historical failed revision.
