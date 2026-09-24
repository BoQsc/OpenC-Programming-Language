# SH-27 stable COFF identity prerequisite (isolated candidate)

The new `openc artifact --kind=coff-object --stable-coff-symbols` option is
experimental and off by default. For every non-exported function definition in
the existing whole-project COFF object, it emits an external COFF symbol named
`$openc$` plus 64 lowercase SHA-256 hex characters. The hash input is a
length-delimited module name and the exact parsed function declaration header,
including signature, modes, ABI and visibility, but excluding the body. This
distinguishes identical private declarations in different modules and overloads
with different signatures. Exact spelling means harmless header formatting may
cause a safe name change. `when_decl` is rejected in this opt-in path because
active-branch identity is not yet projected.

The external storage class makes these definitions addressable by a future
multi-object linker. It is **not** a PE/DLL export, and the ordinary executable,
DLL, static-library, and COFF paths remain unchanged. The ordinary COFF path
does not allocate the opt-in digest or offset tables. This option does not
split the object or skip any semantic, IR, or machine-code work. There is no
warm-cache speed claim.

## Falsification

`test_coff_stable_symbols.py` builds temporary two-module COFF projects and
parses the symbol table. It checks byte-exact repeated output; 71-byte stable
names with external storage class 2; different module salts for identical
private headers; stable names under source-file reorder, unrelated declaration
insertion and body-only edit; changed names for signature and module rename;
and byte-exact *ordinary* COFF output versus the previously proven compiler.
It also checks byte-exact ordinary PE output and exit status 2 against the
prior compiler, plus CLI rejection of this option for `--kind=exe`. All ten
checks passed. The body-only variant changed object bytes while
preserving its symbol-name set. No test requires a whole-project object cache.

The final guarded bootstrap record is
`OpenC-1.0/build-output/sh27-coff-identity-20260924-d/bootstrap-current/bootstrap-current.json`.
Stage 1/2/3 passed the 512 MiB private and 128 MiB working-set gates, with
working-set peaks 61,882,368 / 67,981,312 / 59,740,160 bytes and private
peaks 193,417,216 / 261,550,080 / 257,404,928 bytes. Stage 2 and 3 were
byte-exact (`f9ba2f86e6c3af173cb83dc683dbe561d179a4e56319670d45a1e4875845579a`).
The final Stage 3 compiler resides under that record's `stage3/openc.exe`.
This verifies correctness and resource bounds, not compile-speed improvement.

## Remaining Step 6 blockers

The native stream still stores project-global numeric symbol IDs, function
relocations still target those IDs, acceptance/lowering/emission remain coupled
to a whole-project `IrContext`, and the COFF writer emits one object containing
all modules. There is no per-module object boundary, COFF reader, native
multi-object relink, dependency-complete cache key, or atomic content-validated
reuse. The public-interface fingerprint from the prior isolated commit is a
prerequisite, but cannot make a cached object safe by itself. Next engineering
cut: lower each module behind a stable imported/exported symbol table, emit one
deterministic COFF object per module with external relocations, then implement
native multi-object relink before adding cache reuse.
