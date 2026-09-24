# SH-27 public-interface fingerprint prerequisite (isolated candidate)

This branch adds an opt-in `openc interface-fingerprint --project=... --output=...`
projection. It runs after normal semantic acceptance and emits deterministic
JSON with per-module SHA-256 values, lexical module/import order, and a project
SHA-256. It does **not** cache artifacts, skip lowering, emit independent COFF
objects, or satisfy SH-27 incremental Step 6.

## Projection boundary

- `function` (including external declarations): exact spelling from the
  declaration's source span through the signature/semicolon, excluding a
  function body. This includes name, parameter/return types, ownership and
  safety modes, visibility, ABI and external symbol spelling.
- `struct`, `resource`, `enum`, `module const`: exact full declaration span,
  including field/variant layouts and constant values. Resource method bodies
  remain in the span, so body-only resource edits safely overinvalidate.
- Imports: dependency module names from the compiler's existing import scanner,
  emitted in lexical order. Module output order is lexical, so manifest JSON
  key reordering does not perturb the report.
- `when_decl`: explicitly unsupported. The command writes a report with
  `supported=false`, emits `OPENC-INTERFACE-UNSUPPORTED`, and exits nonzero.
  Nested declarations under conditional compilation cannot yet be projected
  with active-branch semantics. No other top-level declaration kind is parsed
  by this compiler version; import nodes and nested enum items/fields/parameters
  are represented via their parent declaration or import list.

Exact source spelling is deliberately conservative: harmless signature
whitespace or private declaration changes can alter the digest. A normal
function body edit does not. This is a *public-interface prerequisite*, not a
rebuild key: a later cache key must combine the module's own source/body hash,
transitive dependency interface hashes, compiler version, target/options, and
stable native symbol identities. No dependent module digest is implicitly
changed merely because one of its imports' declarations changed.

The opt-in command caps total source text at 32 MiB, each source file at
128 KiB, project manifest at 1 MiB, modules at 4096, and symbols at 262144
before its projection allocations. These bounds are not a claim that arbitrary
inputs fit the production strict-RAM gate.

## Falsification and build evidence (2026-09-24)

`python OpenC-1.0/compiler/selfhost/test_interface_fingerprint.py STAGE3.exe`
passed 11 focused checks using temporary projects: deterministic repeat,
manifest-key-order invariance, same-length exported rename, signature change,
struct layout change, constant-value change, visibility change, import-graph
change, body-only stability, external ABI symbol change, and hard rejection of
`when_decl`.

Guarded three-stage bootstrap record:
`OpenC-1.0/build-output/sh27-interface-fingerprint-20260924-e/bootstrap-current/bootstrap-current.json`.
All stages passed 512 MiB private / 128 MiB working-set gates. Stage 2 and 3
were byte-exact (`08cdac4bb53dd9712d96ab7b39e4c518ffa6cb896695cb5cbff8f045da15d9d7`,
7,202,816 bytes). Peak working sets were 59,338,752 / 67,514,368 /
61,177,856 bytes; peak private bytes were 191,602,688 / 261,840,896 /
256,491,520. This is correctness evidence only, not a compiler-throughput win.

## Remaining Step 6 prerequisites

The backend still owns global native symbol IDs and a whole-project native
stream. True incremental compilation requires deterministic per-module COFF
object boundaries, stable external symbol names and relocation contracts,
independent object acceptance/lowering/emission, a native multi-object relink,
and an atomic content-validated cache with exact dependency invalidation. The
fingerprint here addresses only the interface side of that architecture.
