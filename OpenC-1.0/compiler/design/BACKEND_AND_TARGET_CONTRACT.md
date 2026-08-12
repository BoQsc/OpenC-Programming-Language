# Backend and Target Contract

Every compilation uses one validated target record conforming to `schemas/CORE_TARGET.schema.json`.

The backend supplies:

```text
pointer width and endianness
primitive sizes and alignments
maximum object size
binary32/binary64 support
target fault outcomes
object/executable emission support
```

The backend preserves checked failures and all sequenced observable effects. A
bootstrap backend may lower to D, LLVM IR, C, or another representation only
when inserted checks make OpenC behavior authoritative. Such a backend is an
implementation technique, not source compatibility. The active Windows
independence path replaces the C/TinyCC bootstrap backend with first-party x64
machine-code and PE/COFF writers. The blocking SH-14 throughput/stability gate
and SH-15 ABI/encoder implementation have passed. SH-16 PE32+ and CRT-free
runtime implementation is active.

Active initial target:

```text
windows-x86_64
```

Linux and other targets remain optional future work. Core execution can begin
with an interpreter; Hosted console/filesystem support is a later separate
claim. ABI, native artifact, runtime, and dependency-exit requirements are in
`WINDOWS_NATIVE_INDEPENDENCE.md`.
