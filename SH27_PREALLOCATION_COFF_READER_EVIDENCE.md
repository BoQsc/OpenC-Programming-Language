# SH-27 saved-COFF pre-allocation guard

Status: **isolated native reader gap resolved; automatic cache remains open**.
The saved-object relinker now checks the file length against the remaining
8 MiB bundle budget using `GetFileSizeEx` on its open input handle, before
allocating the file buffer. Oversized input closes that handle and returns
failure. The subsequent `ReadFile` request is limited to that checked length,
so file growth cannot enlarge the allocation or overflow the buffer; a short
read or changed content remains subject to size/hash/parser validation.
No global raw-file-read semantics or memory ceilings were weakened.

The compiler-private `cli_coff_read_bounded_object` native hook has a
fail-closed ordinary function body. An older native seed can therefore build
the first generation without a new public intrinsic or a C/D bootstrap
bridge; that generation's backend emits the bounded hook into later native
generations. The module-link command is not claimed functional in the old-
seed-built first generation or a generated-C fallback. Stage 2/3 own the
bounded native path. This remains off the production compiler branch.

## Executed evidence, 2026-09-26

- Production compiler guarded `check --project`: PASS. Guarded native
  Stage 1→3 bootstrap: PASS. Stage 2/3 byte-exact SHA-256:
  `b97e857caacdd9c41826ff7355bcf4c1a91baca42959936a5ef0a8a9249f3ef4`.
  Bootstrap used 512 MiB limits; Stage 2 working set was 68,927,488 bytes,
  above the separate strict 64 MiB gate.
- Separate strict Stage 3→4 self-build: PASS, same hash. Limits: 64 MiB
  working set / 256 MiB private. Peaks: 62,054,400 working-set bytes,
  262,230,016 private bytes, 263,774,208 Job-private bytes.
- `test_coff_bounded_reader.py`: PASS 3/3. A 128 MiB input returned normal
  rejection (`exit 1`, `OPENC-COFF-LINK-SAVED`) within a 64 MiB Job/private
  and working-set guard, peaking at 5,615,616 Job-private bytes. An input
  one byte above the exact bundle allowance also rejected before hashing;
  a correctly hashed input at the allowance reached the COFF parser and
  rejected its malformed bytes, proving the accepted boundary was read.
  No case produced a PE or tripped its process guard.
- The same test on the previous isolated saved-object compiler failed the
  oversized case: its allocation was denied by the 64 MiB Job and exited
  70 with `OpenC checked failure`, not graceful size rejection. The guard
  prevented uncontrolled allocation during this negative-control run.
- Guarded `test_module_coff_set.py`: PASS, including executable saved-file
  relink with the source manifest hidden, exact PE bytes, body edits,
  deterministic ordering, bad hashes/malformed COFF, incomplete-manifest
  recovery, native PE audit, and independent `lld-link` oracle. Test tree
  peaks: 31,580,160 Job-private and 18,501,632 working-set bytes.
- `test_coff_stable_symbols.py` against the previous isolated compiler:
  PASS ten identity/invalidation/default-artifact checks.

Ignored records are in `OpenC-1.0/build-output/sh27-bounded-coff-read-20260926/`
and `OpenC-1.0/build-output/sh27-bounded-coff-read-bootstrap-20260926/`.

## Still required for SH-27

Independently accepted/lowered modules, shared-data/runtime-helper ownership,
dependency-complete keys, automatic object hits, atomic cache publication and
concurrent read/write handling, correct implementation/interface invalidation,
and measured cold/warm/edit project performance remain unimplemented. This
reader proof is not an incremental-build or throughput certificate.
