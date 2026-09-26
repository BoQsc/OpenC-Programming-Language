# SH-27 prepared-source ownership slice

This is an opt-in, serial ownership boundary, not a throughput promotion or
function-level scheduler. `openc artifact --prepared-function-scratch` takes the
path after source indexing and `acceptance_validate_context` succeed. The
default artifact and compiler self-build paths remain unchanged.

`IrPreparedSource.view` borrows 62 source/project fields, including source text,
tokens, syntax, symbol/detail records and indexes. `IrFunctionScratch` owns the
remaining 57 mutable context fields: type/name/call/expression caches, layout
caches, local values, IR buffers, function identity, and profile counters.
The helper clears all scratch fields from the published view, binds each
function to a local `IrContext`, then captures changed pointers, lengths, and
counters before the next function. A field-by-field unit audit enumerates all
119 `IrContext` fields and fails if a field lacks an owner or a bind/capture.
No source-wide token, syntax, adjacency, declaration, or IR arena is cloned;
the first scratch borrows the existing source allocation and no heap allocation
occurs in the boundary helpers.

The compiler's native backend did not correctly preserve source, syntax,
symbol, and detail pointers in a bulk copy of the large nested context. The
handoff therefore assigns every prepared/view field explicitly. The observed
bulk-copy failure was an access violation in the opt-in path, before IR
lowering; it is not a memory-ceiling failure. Keep the field-wise handoff until
the large-aggregate backend issue is fixed and independently verified.

The view is published only after whole-source acceptance. This is essential:
acceptance currently sweeps assignment, binary, and call nodes across the
source before any function lowering, and first-visit facts reside in
source-lifetime caches. The current scratch is exactly one serial owner and
aliases the source-owned cache allocations. It must **not** be shared between
concurrent function jobs. Safe function-level scheduling still requires:

1. A per-worker scratch allocator with a bounded accounting for the currently
   source-wide caches and IR buffers (no copied full-source arenas).
2. A way to partition or freeze acceptance's first-visit facts without losing
   category/source-order invalid diagnostics.
3. Deterministic function-order byte assembly and a production 4-worker /
   256 MiB child-private proof. The existing source-chunk concurrency remains
   separate from function-level concurrency.

The lexical audit finds direct writes to frozen syntax, token, symbol, and
detail arrays in parsing, indexing, resolution, and acceptance, not in the
lowering/native-emission files checked by the unit test. This is not a full
transitive immutability proof; a scheduler must audit every callee before
publishing the view across threads or processes.

## Focused evidence

- Guarded three-stage self-build passed. Transition Stage1 and byte-exact
  Stage2/3 SHA-256:
  `1a832cdae54b4cadec08591389daa1f9e3d2f3cb3ce672e87b160a8d06a851ef`.
  Peak private: 257.9 / 258.0 / 258.1 MB; peak working set:
  60.0 / 60.0 / 60.2 MB, each below the 512 MiB bootstrap limits
  (and observed private peaks below 256 MiB).
- Opt-in and default `demos/hello` binaries are byte-identical (SHA-256
  `e022baa5f0a806fe93cd65c32e38cd553660cf4f926554ce15474d95c8e1bab0`)
  and execute identically. `tests/sh27_nested_aggregate` binaries are likewise
  byte-identical (SHA-256
  `11e0554e36498c393d388df2f57d3c35ed408902f75651cf13b196e5504230a6`).
- An invalid return-type project produced exactly equal exit code, stdout,
  and stderr with the opt-in flag on and off. Focused artifact runs had hard
  256 MiB private / 64 MiB working-set limits; the nested opt-in proof peaked
  at 5.5 MB private.
- The checked-in four-module project compiled with `--source-chunks=4` both
  with and without the opt-in flag. Its EXEs are byte-identical (SHA-256
  `18c9f115d5eb940be95332025833c2e5ce5718a3bfbfe7523afaa2ad90977d70`)
  and both exit 0. Guarded opt-in peak private was 5.2 MB and working set
  16.5 MB. This tests flag propagation through existing source-chunk workers,
  not function-level parallelism or a production-scale child-memory gate.
- `python -m unittest discover -s OpenC-1.0/compiler/selfhost -p
  test_sh27_prepared_source_boundary.py -v` passes 5/5 static checks.

This evidence makes the boundary a correctness preparation only. It does not
establish a compile-time speedup or satisfy SH-27's DMD/C-class throughput
criterion. Do not enable it by default on the basis of this slice.
