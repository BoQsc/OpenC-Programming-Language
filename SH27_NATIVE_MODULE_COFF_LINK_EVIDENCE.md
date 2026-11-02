# SH-27 restricted OpenC-native multi-COFF link slice

Status: **isolated, opt-in vertical slice; no incremental cache or speed
claim**. `openc artifact --kind=module-coff-set --output=PREFIX
--linked-exe=FILE` now links the freshly emitted bounded per-module COFF
objects into a PE32+ executable through OpenC's own restricted COFF reader,
stable-symbol resolver, relocation applicator, and existing PE/import writer.
`lld-link` and a kernel32 import library are used only by the independent
test oracle, not by this OpenC link path. Ordinary PE/COFF output is
unchanged.

The reader accepts only the exact five-section, AMD64 object subset emitted
by the adjacent module writer. It resolves stable `$openc$` cross-module
externs, `REL32` text and `ADDR32NB` unwind relocations, and the documented
KERNEL32 import slots. It rejects unsupported section/relocation/symbol
shapes and shared `.data` references. The bundle grows geometrically from
1 KiB up to an 8 MiB ceiling; growth failure leaves the old bytes intact.
The native stream is separately limited to 4 MiB in linked mode. A small
`INCOMPLETE` manifest is written before object/PE work and becomes
`COMPLETE` only after success. This is not atomic or concurrent-writer-safe.

## Executed proof

The stable production compiler's guarded `check --project` passed before
bootstrap. Guarded Stage 1→3 bootstrap passed with byte-exact Stage 2/3
SHA-256
`757835d4393b6589ecb40c03f27542d4f5851f1b86ed0e6d60cdbfab9c6b4e02`.
Stage 1/2/3 peak private bytes were 195,010,560 / 267,665,408 /
263,647,232; working set 62,058,496 / 69,120,000 / 62,550,016.
The bootstrap used 512 MiB guards, not the strict 64/256 MiB gate. A
separate Stage 3→4 self-build passed **64 MiB working set / 256 MiB private**
and reproduced the same binary hash; peak private was 261,926,912 bytes,
working set 62,001,152 bytes, and Job private 263,012,352 bytes.
Ignored local records are under
`OpenC-1.0/build-output/sh27-module-coff-link-grow-20260924/`.

`test_module_coff_set.py` passed. It parsed the two emitted objects,
matched the importer's undefined stable name to the provider definition,
linked and ran them with `lld-link` as a test oracle, then independently
linked and ran the same set with OpenC's native path (exit 7). A provider
body edit changed only its object and both paths exited 8; manifest key
reorder preserved object and native PE bytes; unrelated declaration
insertion preserved the importer object. Same-prefix rerun reproduced the
manifest, objects and native PE byte-for-byte. A forced second-object write
failure and a forced late native-PE write failure each left the manifest
`INCOMPLETE`; removing the obstacle and rerunning restored the original
bytes. OpenC's `pe-audit` passed on the native-linked executable, including
KERNEL32-only imports, absent forbidden CRT imports, and sorted unwind
records. The focused process tree passed a 512 MiB guard, peaking at
31,158,272 Job-private and 18,108,416 working-set bytes. The older stable
COFF-symbol suite passed ten checks, including byte-exact ordinary COFF and
PE output against the previous isolated compiler.

## What remains before SH-27 Step 6

This still compiles and lowers the whole project before partitioning the
native stream. It cannot reuse an unchanged module object or relink saved
objects from disk. A bounded file-backed COFF reader, independent module
acceptance/lowering, shared data/runtime-helper ownership, dependency-
complete interface/content keys, atomic publish/read-back validation,
correct invalidation, and measured warm hits are all missing. Malformed
external COFF falsification is deferred until external COFF input exists;
the in-memory reader currently consumes only freshly emitted bounded
objects. Do not present this slice as incremental compilation or broad
systems-language throughput parity.
