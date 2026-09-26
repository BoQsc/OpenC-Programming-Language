# SH-27 selective transitive module-object keys

Status: **isolated opt-in compiler cut; local fixed-point, cache, and strict
memory proof passed; hosted and normal-default promotion pending**.

The prior `openc-module-cache-v1` key hashed one project-wide interface
projection. An API change in one module therefore missed every object,
including unrelated modules. The v2 key retains the exact manifest, target,
compiler executable SHA-256, schema and policy in a common base, but hashes
each module's source outside ordinary function bodies separately. Each object
key combines that base, its owner's *full* source bytes, and the projected
interfaces of its own module plus all transitive providers. Thus a body edit
misses only its owner; a public declaration/import/layout/constant edit
misses the owner and dependents, not unrelated modules.

The dependency graph is deliberately broader than `import` statements.
OpenC's resolver accepts exported `module.symbol` and short-module qualifiers
without an import declaration. For every stable source snapshot, the cache
looks for those exact dotted qualifier byte sequences in both declarations
and function bodies, plus the existing conservative import pattern. A match
inside a comment or string creates a harmless extra edge. The 64-module
bounded graph is closed transitively, and hashes are appended in canonical
module order. Unsupported conditional-declaration or unfamiliar parser body
projections still disable the cache. Normal source validation runs on every
edit; only the separate exact-input project snapshot may skip it on a no-op.
Shared runtime `.data` remains fail-closed.

## Local proof on the combined source

Final local Stage 2/3 byte-exact compiler SHA-256:
`e9a4d7794bf42818bd08b50bc6abdc75d29f4867dc907836a6543e1b2269f91a`.
Ignored raw reports are in
`OpenC-1.0/build-output/sh27-selective-deps-bootstrap-20260926a/`.

- An independent Python oracle checks exact v2 base, per-module interface,
  own-content, and dependency-key hashes. The normal cache test proves a
  same-width exported parameter rename rebuilds `alpha` and dependent `beta`
  while unrelated `gamma` hits. Clean and reused COFF/PE hashes, executable
  behavior, and diagnostics match. Corrupt records/snapshots and concurrent
  publication still recover cleanly.
- A four-module test uses no `import` in its `alpha → beta → zapp` qualified
  call chain. After changing `alpha`'s exported signature, all three
  transitive modules miss and unrelated `gamma` hits; the resulting PE and
  COFF objects are byte-identical to a fresh full build. The no-op of that
  project uses the validation snapshot and four object hits.
- Strict native self-build passes 13/13 checks and 20/20 byte-exact chained
  generations. Peak child private **267,005,952 bytes** and working set
  **63,655,936 bytes** remain below 256/64 MiB; the Job limit is 512 MiB.
- Native conformance is `EXECUTED_NATIVE` **278/278**, with zero failed or
  infrastructure cases under a 512 MiB Job/128 MiB working-set guard.
- Five local 24-file/1,153-function runs pass exact object/PE/runtime and
  strict per-command RAM: full COFF median **1.643 s**, no-op **0.306 s**,
  edited body **0.712 s**, ordinary native **0.392 s**. The observed paired
  no-op advantage over ordinary native is **0.086 s**. This is an opt-in
  generated workload, not normal-default or representative-project parity.

The previous [project snapshot proof](SH27_PROJECT_SNAPSHOT_EVIDENCE.md) was
independently hosted on an earlier source revision. It does not certify this
new key code; this revision needs its own hosted proof. General shared-data
objects, wider real-project coverage, normal-build integration, final-source
two-run C/D parity, and release/editor integrity remain open for SH-27.
