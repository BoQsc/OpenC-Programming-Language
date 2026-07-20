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

The backend preserves checked failures and all sequenced observable effects. A bootstrap backend may lower to D, LLVM IR, C, or another representation only when inserted checks make OpenC behavior authoritative. Such a backend is an implementation technique, not source compatibility.

Recommended initial targets:

```text
linux-x86_64
windows-x86_64
```

Core execution can begin with an interpreter; Hosted console/filesystem support is a later separate claim.
