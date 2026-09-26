# SH-27 representative file application on the module-object cache

Status: **isolated opt-in cut; local fixed-point, correctness, and guarded
project proof passed; hosted and normal-default promotion pending**.

The earlier module-object writer rejected all relocations into the compiler's
shared writable runtime `.data`, so the checked-in four-module `medium_audit`
file application could not use saved objects. This cut permits only the
existing 96-byte all-zero runtime template. The COFF parser still rejects a
different template, section size, or `.data` relocation, and the native linker
rejects a `.text` relocation whose `.data` addend is outside `[0, 96)`. It
does not generalize arbitrary writable globals or TLS into the cache.

## Local proof on the combined source

The actual Stage 2 and Stage 3 compiler executables are byte-identical:
SHA-256 `4fc8d6ec2413f0fd9d9b51b995ef558bd263502a068217c87feb402952a65023`.
Raw ignored reports are in
`OpenC-1.0/build-output/sh27-runtime-data-bootstrap-20260926a/` and the
short-path full-suite report is `OpenC-1.0/build-output/r27-data.json`.

- Strict self-build: 13/13 enforced checks and 20/20 byte-exact chained
  generations; peak child private 267,202,560 bytes and working set
  64,020,480 bytes, below the 256/64 MiB limits. The private-memory margin
  is only 1,232,896 bytes and must not be weakened or inferred to be robust
  across hosted runners without their own proof.
- Native conformance: `EXECUTED_NATIVE` 278/278, with zero failed and zero
  infrastructure cases under a 512 MiB Job/128 MiB working-set guard.
- Four-module cache test: cold 0 hits/4 misses, exact-input no-op 4 hits/0
  misses with validation skipped, body edit 3 hits/1 miss with validation
  restored. Cached and fresh COFF objects and linked PE bytes are exact.
  Both executables read the checked-in input file and print the exact
  expected output; the body edit changes only the expected fingerprint.
  A recomputed-SHA forged object with a `.data` addend of 96 is rejected by
  the linker with `OPENC-COFF-LINK-RELOC` and produces no executable.
- Saved-object boundary, selected-module lowering, cache corruption and
  concurrent-publication tests passed. The bounded COFF reader rejected its
  three adversarial cases before allocation.
- Five guarded local 24-file/1,153-function runs: full COFF median 1.235 s,
  no-op 0.215 s, body edit 0.556 s, and ordinary native 0.335 s. The
  measured paired normal-minus-no-op gain is 0.095 s. This is an opt-in
  generated workload, not default-build C/D parity.
- The checked-in representative suite passed three repetitions each for
  `small_cli`, `medium_audit`, and the actual compiler self-build, including
  cold/warm/edit execution, exact outputs, memory bounds, and Stage 2/3
  fixed point. Normal (non-incremental) compiler-self-build median cold/warm/
  edit wall times were 3.430/3.685/3.684 s; these suite warm/edit modes
  intentionally rebuild all sources and are not cache-speed claims. The
  suite's highest sampled compiler child private was 268,025,856 bytes, just
  409,600 bytes below its 256 MiB ceiling; hosted repeat and memory-headroom
  work are important before promotion.

One initial full-suite invocation used a long nested report path and failed
the compiler-self-build lane before compilation, without a diagnostic. The
same source passed all three repetitions from a shorter path. This is a
Windows path-length limitation of the current staging layout; it has not
been hidden as an OpenC compiler-performance failure or counted as a pass.

The branch workflow now runs the same cache adversarial test and three-run
representative suite in addition to strict self-build and the 24-file cache
benchmark. Until that hosted run passes, the `.data` cut has only local proof.
The cache remains restricted to opt-in `artifact --kind=module-coff-set`; it
is not a normal `openc build` speedup. Larger retained projects, default
integration, final-source clean C/D parity, editor/release integrity, and
RAM-margin improvement remain SH-27 work.
