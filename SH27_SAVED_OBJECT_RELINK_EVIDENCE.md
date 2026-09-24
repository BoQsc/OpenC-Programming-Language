# SH-27 isolated saved-COFF relink proof

Status: **opt-in isolated slice, not incremental compilation or production
promotion**. The existing `module-coff-set --linked-exe` path now reopens each
published object and verifies its byte length and SHA-256 before linking it.
The new project-free `openc module-coff-link --entry=$openc$HASH --output=FILE
--object=FILE --sha256=HASH [...]` consumes previously saved objects in
explicit order. It requires a hash for every object, reuses the restricted
OpenC-native five-section COFF parser and PE writer, and rejects wrong hashes,
malformed COFF, unsupported relocations, duplicate/undefined symbols, and
input/output path collisions. No C/D compiler or external linker participates
in this command; `lld-link` remains only an independent test oracle.

## Executed evidence, 2026-09-24

- The unchanged production compiler's `check --project` passed on the
  isolated source. A guarded three-stage bootstrap passed with byte-exact
  Stage 2/3 SHA-256
  `2d81c5c1cbb9d341eb0b563c6b78ca4fc16b244ccfe5394c9108709c45689517`.
  Bootstrap used 512 MiB guards; Stage 2 reached 69,083,136 bytes working
  set, so it does **not** prove a strict 64 MiB Stage-2 bound.
- A separate Stage 3→4 self-build reproduced that SHA-256 under 64 MiB
  working set and 256 MiB private-byte limits: observed peaks were
  62,054,400 working-set bytes, 262,701,056 private bytes, and 263,479,296
  Job-private bytes.
- `test_module_coff_set.py` passed. After emitting two module objects, it hid
  the source project manifest, invoked only `module-coff-link` with saved
  object paths/hashes, and reproduced the fresh-link PE byte-for-byte. The
  executable returned 7. A wrong expected hash and a changed object with
  the original hash were rejected without an output PE. A changed object
  paired with its *new* hash was also rejected by the restricted COFF parser.
  The existing body-edit, unrelated-ID, deterministic-order, incomplete-
  manifest recovery, native PE audit, and `lld-link` oracle cases passed.
- The focused test process tree passed a 512 MiB guard, peaking at 31,105,024
  Job-private and 18,038,784 working-set bytes. The stable-symbol/default-
  artifact suite passed its ten checks against the previous isolated compiler.

Ignored local evidence is under
`OpenC-1.0/build-output/sh27-module-coff-saved-relink-20260924/`.

## Remaining blockers

The standalone relinker does not discover a project dependency graph, skip
acceptance/lowering, select cache hits, handle shared `.data`, or invalidate
implementation/interface edits. The caller supplies hashes and object order;
there is no atomic cache index, publish/read-back protocol, or concurrent-
writer protection. The currently exposed `file.read_bytes_raw` allocates for
the file before the 8 MiB object/aggregate cap is checked; the native runtime
still has a 512 MiB live-allocation guard, but a purpose-built pre-read size
limit is needed before this becomes a production cache reader. Do not claim
warm-build speed, true incremental compilation, or broad arbitrary-COFF
support from this proof.
